import 'package:dio/dio.dart';
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

  Future<void> linkDevice(String pairingCode, String deviceName) async {
    try {
      final response = await _dio.post(
        ApiConstants.devicesLink,
        data: {
          'pairingCode': pairingCode,
          'deviceName': deviceName,
        },
      );
      if (response.data['success'] == false) {
        throw Exception(response.data['message']);
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
      final List data = response.data['data'];
      return data.map((json) => DeviceModel.fromJson(json)).toList();
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
}
