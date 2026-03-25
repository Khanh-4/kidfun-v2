import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class AppUsageEntry {
  final String packageName;
  final String appName;
  final int usageSeconds;
  final int? deviceId;
  final String? deviceName;

  AppUsageEntry({
    required this.packageName,
    required this.appName,
    required this.usageSeconds,
    this.deviceId,
    this.deviceName,
  });

  factory AppUsageEntry.fromJson(Map<String, dynamic> json) {
    return AppUsageEntry(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String? ?? json['packageName'] as String,
      usageSeconds: json['usageSeconds'] as int? ?? 0,
      deviceId: json['deviceId'] as int?,
      deviceName: json['deviceName'] as String?,
    );
  }

  String get formattedDuration {
    final h = usageSeconds ~/ 3600;
    final m = (usageSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}g ${m}p';
    if (m > 0) return '${m} phút';
    return '${usageSeconds}s';
  }
}

class BlockedApp {
  final String packageName;
  final String? appName;

  BlockedApp({required this.packageName, this.appName});

  factory BlockedApp.fromJson(Map<String, dynamic> json) {
    return BlockedApp(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String?,
    );
  }
}

class WeeklyUsageData {
  final List<AppUsageEntry> topApps;
  final int totalWeeklySeconds;
  final int dailyAverageSeconds;

  WeeklyUsageData({
    required this.topApps,
    required this.totalWeeklySeconds,
    required this.dailyAverageSeconds,
  });
}

class AppUsageRepository {
  final _dio = DioClient.instance;

  Future<List<AppUsageEntry>> getDailyUsage(int profileId, String date) async {
    final response = await _dio.get(
      '${ApiConstants.profiles}/$profileId/app-usage',
      queryParameters: {'date': date},
    );
    final List list = response.data['data']['apps'] as List? ?? [];
    return list.map((e) => AppUsageEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WeeklyUsageData> getWeeklyUsage(int profileId) async {
    final response = await _dio.get(
      '${ApiConstants.profiles}/$profileId/app-usage/weekly',
    );
    
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final dailyTotalsMap = data['dailyTotals'] as Map<String, dynamic>? ?? {};
    
    int totalWeeklySeconds = 0;
    dailyTotalsMap.values.forEach((val) {
      if (val is int) totalWeeklySeconds += val;
      else if (val is double) totalWeeklySeconds += val.toInt();
    });
    
    final int dailyAverageSeconds = totalWeeklySeconds ~/ 7;

    final List list = data['topApps'] as List? ?? [];
    final topApps = list.map((e) => AppUsageEntry.fromJson(e as Map<String, dynamic>)).toList();
    
    return WeeklyUsageData(
      topApps: topApps,
      totalWeeklySeconds: totalWeeklySeconds,
      dailyAverageSeconds: dailyAverageSeconds,
    );
  }

  /// GET /api/profiles/:id/all-apps — tất cả app đã từng cài trên thiết bị con
  Future<List<AppUsageEntry>> getAllApps(int profileId) async {
    final response = await _dio.get(
      '${ApiConstants.profiles}/$profileId/all-apps',
    );
    final List list = response.data['data']['apps'] as List? ?? [];
    return list.map((e) => AppUsageEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BlockedApp>> getBlockedApps(int profileId) async {
    final response = await _dio.get(
      '${ApiConstants.profiles}/$profileId/blocked-apps',
    );
    final List list = response.data['data']['blockedApps'] as List? ?? [];
    return list.map((e) => BlockedApp.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addBlockedApp(int profileId, String packageName, {String? appName}) async {
    await _dio.post(
      '${ApiConstants.profiles}/$profileId/blocked-apps',
      data: {
        'packageName': packageName,
        if (appName != null) 'appName': appName,
      },
    );
  }

  Future<void> removeBlockedApp(int profileId, String packageName) async {
    await _dio.delete(
      '${ApiConstants.profiles}/$profileId/blocked-apps/${Uri.encodeComponent(packageName)}',
    );
  }
}
