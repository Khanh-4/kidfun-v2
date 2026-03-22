import 'package:flutter/services.dart';

class NativeService {
  static const _channel = MethodChannel('com.kidfun.native');

  /// Lấy danh sách app usage từ Android UsageStatsManager
  static Future<List<Map<String, dynamic>>> getAppUsage() async {
    final result = await _channel.invokeMethod('getAppUsage');
    return List<Map<String, dynamic>>.from(
      (result as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  /// Bắt đầu foreground service
  static Future<void> startForegroundService() async {
    await _channel.invokeMethod('startForegroundService');
  }

  /// Dừng foreground service
  static Future<void> stopForegroundService() async {
    await _channel.invokeMethod('stopForegroundService');
  }

  /// Chặn app bằng AccessibilityService
  static Future<void> setBlockedApps(List<String> packageNames) async {
    await _channel.invokeMethod('setBlockedApps', {'packages': packageNames});
  }

  /// Lock screen bằng DevicePolicyManager
  /// Trả về true nếu lock thành công, false nếu cần cấp quyền Device Admin
  static Future<bool> lockScreen() async {
    return await _channel.invokeMethod('lockScreen') as bool;
  }

  /// Kiểm tra quyền UsageStats đã cấp chưa
  static Future<bool> hasUsageStatsPermission() async {
    return await _channel.invokeMethod('hasUsageStatsPermission') as bool;
  }

  /// Mở Settings để cấp quyền UsageStats
  static Future<void> requestUsageStatsPermission() async {
    await _channel.invokeMethod('requestUsageStatsPermission');
  }

  /// Kiểm tra AccessibilityService đã bật chưa
  static Future<bool> isAccessibilityEnabled() async {
    return await _channel.invokeMethod('isAccessibilityEnabled') as bool;
  }

  /// Mở Settings để bật AccessibilityService
  static Future<void> requestAccessibilityPermission() async {
    await _channel.invokeMethod('requestAccessibilityPermission');
  }
}
