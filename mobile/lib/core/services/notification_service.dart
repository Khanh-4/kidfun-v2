import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// NotificationService: wraps flutter_local_notifications for KidFun.
///
/// Channels:
///   - sos_channel      → Priority.max, fullScreen intent (TC-21)
///   - geofence_channel → Priority.high (TC-09/10)
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when user taps a notification while app is foreground/background.
  /// Receives the payload string (e.g. "SOS_ALERT" or "GEOFENCE_EVENT").
  Function(String? payload)? onNotificationTap;

  // ── Channel IDs ────────────────────────────────────────────────────────────
  static const String _sosChannelId = 'sos_channel';
  static const String _sosChannelName = 'Cảnh báo SOS';
  static const String _geofenceChannelId = 'geofence_channel';
  static const String _geofenceChannelName = 'Geofence Events';

  // ── Notification IDs ───────────────────────────────────────────────────────
  static const int sosNotificationId = 1000;
  static const int geofenceNotificationId = 1001;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Android: use @mipmap/launcher_icon (default Flutter icon)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        onNotificationTap?.call(details.payload);
      },
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createSOSChannel();
      await _createGeofenceChannel();
    }

    print('🔔 [NOTIFICATION] NotificationService initialized');
  }

  Future<void> _createSOSChannel() async {
    const channel = AndroidNotificationChannel(
      _sosChannelId,
      _sosChannelName,
      description: 'Nhận cảnh báo SOS khẩn cấp từ trẻ',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _createGeofenceChannel() async {
    const channel = AndroidNotificationChannel(
      _geofenceChannelId,
      _geofenceChannelName,
      description: 'Thông báo khi trẻ vào hoặc rời vùng an toàn',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// TC-21: Show SOS push notification.
  /// [profileName] — tên trẻ, [payload] — JSON/string để navigate khi tap.
  Future<void> showSOSNotification({
    required String profileName,
    String payload = 'SOS_ALERT',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _sosChannelId,
      _sosChannelName,
      channelDescription: 'Nhận cảnh báo SOS khẩn cấp từ trẻ',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,   // Bật màn hình ngay cả khi điện thoại đang khoá
      playSound: true,
      enableVibration: true,
      ticker: '🆘 SOS KHẨN CẤP',
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      sosNotificationId,
      '🆘 SOS KHẨN CẤP từ $profileName',
      'Trẻ cần trợ giúp gấp! Nhấn để xem chi tiết.',
      details,
      payload: payload,
    );

    print('🆘 [NOTIFICATION] SOS notification shown for $profileName');
  }

  /// TC-09/10: Show geofence enter/exit notification.
  Future<void> showGeofenceNotification({
    required String profileName,
    required String geofenceName,
    required bool isEnter,
    String payload = 'GEOFENCE_EVENT',
  }) async {
    final title = isEnter
        ? '✅ $profileName vào vùng an toàn'
        : '⚠️ $profileName rời vùng an toàn';
    final body = isEnter
        ? '$profileName đã vào "$geofenceName"'
        : '$profileName đã rời khỏi "$geofenceName"';

    const androidDetails = AndroidNotificationDetails(
      _geofenceChannelId,
      _geofenceChannelName,
      channelDescription: 'Thông báo khi trẻ vào hoặc rời vùng an toàn',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      geofenceNotificationId,
      title,
      body,
      details,
      payload: payload,
    );

    print('🌍 [NOTIFICATION] Geofence notification shown: $title');
  }
}
