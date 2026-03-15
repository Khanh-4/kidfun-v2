import 'dart:io';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/device_model.dart';

class DeviceRepository {
  final _dio = DioClient.instance;

  Future<String> generatePairingCode(int profileId) async {
    try {
      final response = await _dio.post(
        ApiConstants.devicesGeneratePairingCode,
        data: {'profileId': profileId},
      );
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
      }
      return response.data['data']['pairingCode'];
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Lỗi tạo mã QR: $e');
    }
  }

  Future<void> linkDevice(String pairingCode) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Thiết bị không rõ';
      String deviceCode = 'unknown_device_code';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}'.trim();
        deviceCode = androidInfo.id; // unique ID on Android
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
        deviceCode = iosInfo.identifierForVendor ?? 'unknown_ios_id';
      }

      final response = await _dio.post(
        ApiConstants.devicesLink,
        data: {
          'pairingCode': pairingCode,
          'deviceCode': deviceCode,
          'deviceName': deviceName,
        },
      );
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
      }

      // Build 15: Fix loop root cause - save device_code even if token is null
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_code', deviceCode);

      // Extract token if exists (optional during link)
      final data = response.data['data'];
      if (data != null) {
        final token = data['token'] ?? data['accessToken'];
        if (token != null && token.toString().isNotEmpty) {
          await prefs.setString('device_token', token.toString());
        }
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
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
      // Assuming response.data['data'] has 'devices' array based on the new specs
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
      // fallback to directly typing endpoint
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

  Future<void> deleteDevice(int id) async {
    try {
      final response = await _dio.delete('/api/devices/$id');
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi xóa thiết bị: $e');
    }
  }
}
