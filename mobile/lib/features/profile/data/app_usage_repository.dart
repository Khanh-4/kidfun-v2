import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class AppUsageEntry {
  final String packageName;
  final String appName;
  final int usageSeconds;

  AppUsageEntry({
    required this.packageName,
    required this.appName,
    required this.usageSeconds,
  });

  factory AppUsageEntry.fromJson(Map<String, dynamic> json) {
    return AppUsageEntry(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String? ?? json['packageName'] as String,
      usageSeconds: json['usageSeconds'] as int? ?? 0,
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

class AppUsageRepository {
  final _dio = DioClient.instance;

  Future<List<AppUsageEntry>> getDailyUsage(int profileId, String date) async {
    final response = await _dio.get(
      '${ApiConstants.profiles}/$profileId/app-usage',
      queryParameters: {'date': date},
    );
    final List list = response.data['data']['appUsage'] as List? ?? [];
    return list.map((e) => AppUsageEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AppUsageEntry>> getWeeklyUsage(int profileId) async {
    final response = await _dio.get(
      '${ApiConstants.profiles}/$profileId/app-usage/weekly',
    );
    final List list = response.data['data']['appUsage'] as List? ?? [];
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
