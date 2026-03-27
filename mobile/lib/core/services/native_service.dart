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

  /// Lấy danh sách TẤT CẢ app đã cài đặt (không phải system app)
  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final result = await _channel.invokeMethod('getInstalledApps');
    return List<Map<String, dynamic>>.from(
      (result as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  /// Lên lịch khoá màn hình lúc [endTime] — hoạt động kể cả khi app chạy ngầm
  static Future<void> scheduleLockAt(DateTime endTime) async {
    await _channel.invokeMethod('scheduleLockAt', {
      'epochMillis': endTime.millisecondsSinceEpoch,
    });
  }

  /// Huỷ lịch khoá màn hình đã đặt trước
  static Future<void> cancelScheduledLock() async {
    await _channel.invokeMethod('cancelScheduledLock');
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

  /// Force-check foreground app ngay lập tức và chặn nếu nằm trong blocked list
  static Future<void> checkAndBlockCurrentApp() async {
    await _channel.invokeMethod('checkAndBlockCurrentApp');
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

  /// Bật chế độ khoá liên tục: sau khi hết giờ, thiết bị sẽ tự khoá lại
  /// mỗi khi trẻ mở khoá, cho đến khi phụ huynh cấp thêm thời gian
  static Future<void> enterLockedState() async {
    await _channel.invokeMethod('enterLockedState');
  }

  /// Tắt chế độ khoá liên tục (gọi khi phụ huynh cấp thêm thời gian)
  static Future<void> exitLockedState() async {
    await _channel.invokeMethod('exitLockedState');
  }

  /// Kiểm tra xem thiết bị có đang ở trạng thái khoá liên tục không
  /// (dùng để phục hồi sau reboot)
  static Future<bool> isInLockedState() async {
    return await _channel.invokeMethod('isInLockedState') as bool;
  }
}
