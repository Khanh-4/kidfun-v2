import 'dart:io';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/device_model.dart';
import 'device_exceptions.dart';

class DeviceRepository {
  final _dio = DioClient.instance;

  Future<({String code, DateTime expiresAt, int deviceId})> generatePairingCode(
      int profileId) async {
    try {
      print('📡 [DeviceRepo] Generating pairing code for profile: $profileId');
      final response = await _dio.post(
        ApiConstants.devicesGeneratePairingCode,
        data: {'profileId': profileId},
      );
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
      }
      final data = response.data['data'];
      final code = data['pairingCode'] as String;
      final expiresAt = DateTime.parse(data['expiresAt'] as String);
      final deviceId = data['deviceId'] as int;
      print('📡 [DeviceRepo] Pairing code generated: $code (expires $expiresAt)');
      return (code: code, expiresAt: expiresAt, deviceId: deviceId);
    } on DioException catch (e) {
      print('❌ [DeviceRepo] generatePairingCode DioError: ${e.message}');
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối server. Vui lòng thử lại.');
    } catch (e) {
      print('❌ [DeviceRepo] generatePairingCode error: $e');
      if (e is Exception) rethrow;
      throw Exception('Lỗi tạo mã QR: $e');
    }
  }

  // Xác thực mã vừa tạo đã có thiết bị nào dùng chưa — dùng để lọc bỏ
  // false-positive từ tín hiệu realtime "device changed" chung chung (vốn cũng
  // bắn lúc INSERT device nháp, trước khi child xác nhận).
  //
  // Dùng /pairing-status chứ không phải /status: khi máy trẻ đã từng liên kết,
  // linkDevice ghi đè lên dòng Device cũ (giữ lịch sử sử dụng) rồi XOÁ dòng
  // nháp, nên /status của deviceId nháp trả 404 và màn hình treo mãi ở "Đang
  // chờ kết nối" dù liên kết đã thành công. /pairing-status tự truy ra thiết bị
  // thật trong trường hợp đó.
  Future<bool> isPairingLinked(int deviceId, int profileId) async {
    try {
      final response = await _dio.get(
        '/api/devices/$deviceId/pairing-status',
        queryParameters: {'profileId': profileId},
      );
      if (response.data['success'] == false) return false;
      final status = response.data['data']['status'];
      print('📡 [DeviceRepo] Pairing status của device $deviceId: $status');
      return status == 'LINKED';
    } catch (e) {
      print('❌ [DeviceRepo] isPairingLinked error: $e');
      return false;
    }
  }

  // Huỷ mã liên kết đang chờ + xoá device nháp mà generate-pairing-code đã
  // INSERT sẵn. Server tự bỏ qua nếu thiết bị đã liên kết thật (race: trẻ xác
  // nhận mã đúng lúc phụ huynh thoát màn hình).
  Future<bool> cancelPairing(int deviceId) async {
    try {
      print('📡 [DeviceRepo] Cancelling pairing for device: $deviceId');
      final response = await _dio.post(
        ApiConstants.devicesCancelPairing,
        data: {'deviceId': deviceId},
      );
      final cancelled = response.data['data']?['cancelled'] == true;
      print('📡 [DeviceRepo] Cancel pairing result: cancelled=$cancelled');
      return cancelled;
    } on DioException catch (e) {
      print('❌ [DeviceRepo] cancelPairing DioError: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ [DeviceRepo] cancelPairing error: $e');
      rethrow;
    }
  }

  Future<void> linkDevice(String pairingCode) async {
    try {
      print('📡 [DeviceRepo] Linking device with pairing code: $pairingCode');
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Thiết bị không rõ';
      String deviceCode = 'unknown_device_code';

      if (Platform.isAndroid) {
        print('📡 [DeviceRepo] Getting Android device info...');
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}'.trim();
        deviceCode = androidInfo.id; // unique ID on Android
        print('📡 [DeviceRepo] Android info: $deviceName, $deviceCode');
      } else if (Platform.isIOS) {
        print('📡 [DeviceRepo] Getting iOS device info...');
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
        deviceCode = iosInfo.identifierForVendor ?? 'unknown_ios_id';
        print('📡 [DeviceRepo] iOS info: $deviceName, $deviceCode');
      }

      print('📡 [DeviceRepo] Sending link request to server...');
      final response = await _dio.post(
        ApiConstants.devicesLink,
        data: {
          'pairingCode': pairingCode,
          'deviceCode': deviceCode,
          'deviceName': deviceName,
        },
      );
      
      if (response.data['success'] == false) {
        print('❌ [DeviceRepo] linkDevice server error: ${response.data['message']}');
        throw Exception(response.data['message']);
      }

      print('✅ [DeviceRepo] linkDevice SUCCESS. Saving local credentials...');
      
      // Fix loop root cause - save device_code even if token is null
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_code', deviceCode);
      print('✅ [DeviceRepo] Saved device_code to SharedPreferences: $deviceCode');

      // Extract token if exists (optional during link)
      final data = response.data['data'];
      if (data != null) {
        final token = data['token'] ?? data['accessToken'];
        if (token != null && token.toString().isNotEmpty) {
          await prefs.setString('device_token', token.toString());
          print('✅ [DeviceRepo] Saved device_token to SharedPreferences');
        } else {
          print('⚠️ [DeviceRepo] No token found in response data');
        }
      } else {
        print('⚠️ [DeviceRepo] No data object found in response');
      }
    } on DioException catch (e) {
      print('❌ [DeviceRepo] linkDevice DioError: ${e.message}');
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      print('❌ [DeviceRepo] linkDevice error: $e');
      if (e is Exception) rethrow;
      throw Exception('Lỗi liên kết thiết bị: $e');
    }
  }

  Future<List<DeviceModel>> getDevices() async {
    try {
      final response = await _dio.get(ApiConstants.devices);
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
      }
      final data = response.data['data'];
      List devicesData = [];
      if (data is List) {
        devicesData = data;
      } else if (data['devices'] is List) {
        devicesData = data['devices'];
      }
      return devicesData.map((json) => DeviceModel.fromJson(json)).toList();
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Lỗi tải danh sách thiết bị: $e');
    }
  }

  Future<DeviceModel> createDevice(String name, {int? profileId}) async {
    try {
      final data = {
        'deviceName': name,
        if (profileId != null) 'profileId': profileId,
      };
      final response = await _dio.post('/api/devices', data: data);
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
      }
      return DeviceModel.fromJson(response.data['data']['device']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi tạo thiết bị: $e');
    }
  }

  Future<DeviceModel> assignProfile(int deviceId, int profileId) async {
    try {
      final response = await _dio.put('/api/devices/$deviceId', data: {
        'profileId': profileId,
      });
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
      }
      return DeviceModel.fromJson(response.data['data']['device']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi gán profile vào thiết bị: $e');
    }
  }

  /// Xoá thiết bị khỏi tài khoản phụ huynh.
  ///
  /// Server trả 409 `DEVICE_OFFLINE` nếu máy trẻ đã quá 3 phút không gửi
  /// heartbeat — khi đó nó chưa thể biết mình bị gỡ. Đặt [force] = true để xoá
  /// bất chấp (phụ huynh đã bấm "Vẫn gỡ" trên dialog cảnh báo).
  Future<void> deleteDevice(int id, {bool force = false}) async {
    try {
      final response = await _dio.delete(
        '/api/devices/$id',
        queryParameters: force ? {'force': 'true'} : null,
      );
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 409 &&
          data is Map &&
          data['code'] == 'DEVICE_OFFLINE') {
        final payload = data['data'];
        throw DeviceOfflineException(
          minutesSinceLastSeen:
              payload is Map ? payload['minutesSinceLastSeen'] as int? : null,
        );
      }
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi xóa thiết bị: $e');
    }
  }
}
