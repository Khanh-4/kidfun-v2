import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class ChildRepository {
  final _dio = DioClient.instance;

  Future<TodayLimitModel> getTodayLimit(String deviceCode) async {
    final response = await _dio.get('/api/child/today-limit', queryParameters: {
      'deviceCode': deviceCode,
    });
    final data = response.data['data'];
    print('📊 [DEBUG] getTodayLimit raw data: $data');
    return TodayLimitModel.fromJson(data);
  }

  Future<int> startSession(String deviceCode) async {
    final response = await _dio.post('/api/child/session/start', 
      data: { 'deviceCode': deviceCode }
    );
    // Backend returns { success: true, data: { sessionId: ... } }
    return response.data['data']['sessionId'] as int;
  }

  Future<HeartbeatResult> heartbeat({
    required int sessionId,
  }) async {
    final response = await _dio.post('/api/child/session/heartbeat', 
      data: { 'sessionId': sessionId },
    );
    return HeartbeatResult.fromJson(response.data['data']);
  }

  Future<void> endSession(int sessionId) async {
    await _dio.post('/api/child/session/end', 
      data: { 'sessionId': sessionId },
    );
  }

  Future<void> logWarning({
    required String deviceCode, 
    required String type, 
    int remainingMinutes = 0,
  }) async {
    // ChildController uses header X-Device-Code and body warningType, message, remainingMinutes
    await _dio.post('/api/child/warnings', 
      data: {
        'warningType': type,
        'remainingMinutes': remainingMinutes,
        'message': 'Cảnh báo: $type - Còn $remainingMinutes phút'
      },
      options: Options(headers: {'X-Device-Code': deviceCode}),
    );
  }
}

class TodayLimitModel {
  final int limitMinutes;
  final int remainingMinutes;
  final int remainingSeconds;

  TodayLimitModel({required this.limitMinutes, required this.remainingMinutes, required this.remainingSeconds});

  factory TodayLimitModel.fromJson(Map<String, dynamic> json) {
    return TodayLimitModel(
      limitMinutes: json['limitMinutes'] as int? ?? 0,
      remainingMinutes: json['remainingMinutes'] as int? ?? 0,
      remainingSeconds: json['remainingSeconds'] as int? ?? (json['remainingMinutes'] as int? ?? 0) * 60,
    );
  }
}

class HeartbeatResult {
  final int remainingMinutes;
  final int remainingSeconds;
  final bool isBlocked;

  HeartbeatResult({required this.remainingMinutes, required this.remainingSeconds, required this.isBlocked});

  factory HeartbeatResult.fromJson(Map<String, dynamic> json) {
    return HeartbeatResult(
      remainingMinutes: json['remainingMinutes'] as int? ?? 0,
      remainingSeconds: json['remainingSeconds'] as int? ?? (json['remainingMinutes'] as int? ?? 0) * 60,
      isBlocked: json['isBlocked'] as bool? ?? false,
    );
  }
}
