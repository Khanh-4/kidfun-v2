import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class ReportRepository {
  final Dio _dio;
  ReportRepository() : _dio = DioClient.instance;

  /// Lấy daily report. Nếu không truyền date thì lấy hôm nay.
  Future<Map<String, dynamic>> getDailyReport(int profileId, {DateTime? date}) async {
    final params = <String, dynamic>{};
    if (date != null) {
      params['date'] = date.toIso8601String().substring(0, 10);
    }
    final response = await _dio.get(
      '/api/profiles/$profileId/reports/daily',
      queryParameters: params,
    );
    // Defensive unwrap: backend trả { success, data: { report: { data: {...} } } }
    final outer = response.data['data'];
    if (outer is Map) {
      final report = outer['report'];
      if (report is Map) {
        final inner = report['data'];
        if (inner is Map) return Map<String, dynamic>.from(inner);
        return Map<String, dynamic>.from(report);
      }
      return Map<String, dynamic>.from(outer);
    }
    return {};
  }

  /// Lấy weekly report. Nếu không truyền weekStart thì lấy tuần hiện tại.
  Future<Map<String, dynamic>> getWeeklyReport(int profileId, {DateTime? weekStart}) async {
    final params = <String, dynamic>{};
    if (weekStart != null) {
      params['weekStart'] = weekStart.toIso8601String().substring(0, 10);
    }
    final response = await _dio.get(
      '/api/profiles/$profileId/reports/weekly',
      queryParameters: params,
    );
    final outer = response.data['data'];
    if (outer is Map) {
      final report = outer['report'];
      if (report is Map) {
        final inner = report['data'];
        if (inner is Map) return Map<String, dynamic>.from(inner);
        return Map<String, dynamic>.from(report);
      }
      return Map<String, dynamic>.from(outer);
    }
    return {};
  }

  /// Lấy activity history theo ngày.
  Future<List<dynamic>> getActivityHistory(int profileId, {DateTime? date}) async {
    final params = <String, dynamic>{};
    if (date != null) {
      params['date'] = date.toIso8601String().substring(0, 10);
    }
    final response = await _dio.get(
      '/api/profiles/$profileId/activity-history',
      queryParameters: params,
    );
    final data = response.data['data'];
    if (data is Map) {
      return (data['activities'] as List?) ?? [];
    }
    return [];
  }
}
