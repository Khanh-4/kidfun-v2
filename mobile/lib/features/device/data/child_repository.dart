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
    final response = await _dio.post(
      '/api/child/session/start',
      data: {},
      options: Options(headers: {'X-Device-Code': deviceCode}),
    );
    return response.data['data']['session']['id'] as int;
  }

  Future<HeartbeatResult> heartbeat({
    required int sessionId,
    required String deviceCode,
  }) async {
    final response = await _dio.post(
      '/api/child/session/heartbeat',
      data: {'sessionId': sessionId},
      options: Options(headers: {'X-Device-Code': deviceCode}),
    );
    return HeartbeatResult.fromJson(response.data['data']);
  }

  Future<void> endSession(int sessionId, String deviceCode) async {
    await _dio.post(
      '/api/child/session/end',
      data: {'sessionId': sessionId},
      options: Options(headers: {'X-Device-Code': deviceCode}),
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

  /// POST /api/child/app-usage — gửi batch app usage data lên server
  Future<void> syncAppUsage(String deviceCode, List<Map<String, dynamic>> usageData) async {
    await _dio.post(
      '/api/child/app-usage',
      data: {'deviceCode': deviceCode, 'usageData': usageData},
    );
  }

  /// GET /api/child/blocked-apps — lấy danh sách app bị chặn cho child
  Future<List<BlockedAppModel>> getBlockedApps(String deviceCode) async {
    final response = await _dio.get(
      '/api/child/blocked-apps',
      queryParameters: {'deviceCode': deviceCode},
    );
    final List<dynamic> list = response.data['data']['blockedApps'] as List<dynamic>;
    return list.map((e) => BlockedAppModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class BlockedAppModel {
  final String packageName;
  final String? appName;

  BlockedAppModel({required this.packageName, this.appName});

  factory BlockedAppModel.fromJson(Map<String, dynamic> json) {
    return BlockedAppModel(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String?,
    );
  }
}

class TodayLimitModel {
  final int limitMinutes;
  final int remainingMinutes;
  final int remainingSeconds;
  final bool isLimitEnabled;

  TodayLimitModel({required this.limitMinutes, required this.remainingMinutes, required this.remainingSeconds, this.isLimitEnabled = true});

  factory TodayLimitModel.fromJson(Map<String, dynamic> json) {
    bool enabled = true;
    if (json.containsKey('isLimitEnabled') && json['isLimitEnabled'] != null) {
      enabled = json['isLimitEnabled'] as bool;
    } else if (json['baseLimit'] == 0 || json['baseLimit'] == null) {
      enabled = false;
    }

    return TodayLimitModel(
      limitMinutes: json['limitMinutes'] as int? ?? 0,
      remainingMinutes: json['remainingMinutes'] as int? ?? 0,
      remainingSeconds: json['remainingSeconds'] as int? ?? (json['remainingMinutes'] as int? ?? 0) * 60,
      isLimitEnabled: enabled,
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
