import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';

class SchoolModeRepository {
  final _dio = DioClient.instance;

  Future<Map<String, dynamic>> getSchedule(int profileId) async {
    try {
      final response = await _dio.get('${ApiConstants.profiles}/$profileId/school-schedule');
      return response.data['data'] as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e, 'Lỗi tải lịch học');
    }
  }

  Future<void> upsertSchedule(int profileId, Map<String, dynamic> data) async {
    try {
      await _dio.put('${ApiConstants.profiles}/$profileId/school-schedule', data: data);
    } catch (e) {
      throw _handleError(e, 'Lỗi lưu lịch học');
    }
  }

  Future<void> manualOverride(int profileId, String overrideType, int? durationMinutes) async {
    try {
      await _dio.post(
        '${ApiConstants.profiles}/$profileId/school-schedule/override',
        data: {
          'overrideType': overrideType,
          if (durationMinutes != null) 'durationMinutes': durationMinutes,
        },
      );
    } catch (e) {
      throw _handleError(e, 'Lỗi bật/tắt tạm thời chế độ học tập');
    }
  }

  Exception _handleError(dynamic e, String defaultMessage) {
    if (e is DioException && e.response?.data?['message'] != null) {
      return Exception(e.response!.data['message']);
    }
    return Exception('$defaultMessage: $e');
  }
}
