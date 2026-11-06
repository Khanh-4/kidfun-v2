import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'behavior_alert.dart';

/// Gọi API cảnh báo hành vi. Màn hình nhận repository qua constructor để widget test truyền bản giả.
class BehaviorAlertRepository {
  final Dio? _dio;

  BehaviorAlertRepository({Dio? dio}) : _dio = dio;

  Dio get _client => _dio ?? DioClient.instance;

  /// GET /api/profiles/:id/behavior-alerts — mới nhất trước.
  Future<List<BehaviorAlert>> list(int profileId, {int limit = 50}) async {
    final res = await _client.get('/api/profiles/$profileId/behavior-alerts', queryParameters: {'limit': limit});
    final raw = (res.data['data']['alerts'] as List?) ?? const [];
    return raw.map((e) => BehaviorAlert.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// POST /api/behavior-alerts/:id/feedback { feedback } — xem [AlertFeedback].
  Future<void> sendFeedback(int alertId, String feedback) async {
    await _client.post('/api/behavior-alerts/$alertId/feedback', data: {'feedback': feedback});
  }
}
