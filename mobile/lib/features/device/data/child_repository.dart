import '../../../core/network/dio_client.dart';

class ChildRepository {
  final _dio = DioClient.instance;

  Future<TodayLimitModel> getTodayLimit(String deviceCode) async {
    final response = await _dio.get('/api/child/today-limit', queryParameters: {
      'deviceCode': deviceCode,
    });
    return TodayLimitModel.fromJson(response.data['data']);
  }

  Future<int> startSession(String deviceCode) async {
    final response = await _dio.post('/api/child/session/start', data: {
      'deviceCode': deviceCode,
    });
    return response.data['data']['sessionId'] as int;
  }

  Future<HeartbeatResult> heartbeat(int sessionId) async {
    final response = await _dio.post('/api/child/session/heartbeat', data: {
      'sessionId': sessionId,
    });
    return HeartbeatResult.fromJson(response.data['data']);
  }

  Future<void> endSession(int sessionId) async {
    await _dio.post('/api/child/session/end', data: {
      'sessionId': sessionId,
    });
  }

  Future<void> logWarning({required String deviceCode, required String type}) async {
    await _dio.post('/api/child/warning', data: {
      'deviceCode': deviceCode,
      'type': type,
    });
  }
}

class TodayLimitModel {
  final int totalMinutes;
  final int remainingMinutes;

  TodayLimitModel({required this.totalMinutes, required this.remainingMinutes});

  factory TodayLimitModel.fromJson(Map<String, dynamic> json) {
    return TodayLimitModel(
      totalMinutes: json['totalMinutes'] as int? ?? 0,
      remainingMinutes: json['remainingMinutes'] as int? ?? 0,
    );
  }
}

class HeartbeatResult {
  final int remainingMinutes;
  final bool isBlocked;

  HeartbeatResult({required this.remainingMinutes, required this.isBlocked});

  factory HeartbeatResult.fromJson(Map<String, dynamic> json) {
    return HeartbeatResult(
      remainingMinutes: json['remainingMinutes'] as int? ?? 0,
      isBlocked: json['isBlocked'] as bool? ?? false,
    );
  }
}
