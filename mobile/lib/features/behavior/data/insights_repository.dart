import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'insights.dart';

/// Gọi API cho màn "AI Insights" (T7.5). Màn hình nhận repository qua constructor để widget test truyền bản giả.
class InsightsRepository {
  final Dio? _dio;

  InsightsRepository({Dio? dio}) : _dio = dio;

  Dio get _client => _dio ?? DioClient.instance;

  /// GET /api/profiles/:id/predictions — mới nhất trước, gồm cả ngày mai.
  Future<List<UsagePrediction>> fetchPredictions(int profileId) async {
    final res = await _client.get('/api/profiles/$profileId/predictions', queryParameters: {'days': 7});
    final raw = (res.data['data']['predictions'] as List?) ?? const [];
    return raw.map((e) => UsagePrediction.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// GET /api/profiles/:id/usage-heatmap — 4 tuần gần nhất.
  Future<UsageHeatmap> fetchHeatmap(int profileId) async {
    final res = await _client.get('/api/profiles/$profileId/usage-heatmap');
    return UsageHeatmap.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  /// GET /api/profiles/:id/habit-insight — null khi tác vụ ban đêm chưa tính cho bé.
  Future<HabitInsight?> fetchHabitInsight(int profileId) async {
    final res = await _client.get('/api/profiles/$profileId/habit-insight');
    final raw = res.data['data']['insight'];
    return raw == null ? null : HabitInsight.fromJson(Map<String, dynamic>.from(raw as Map));
  }
}
