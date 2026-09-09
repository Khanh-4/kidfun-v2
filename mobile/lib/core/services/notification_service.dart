import 'dart:io';
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
  static const String _extensionChannelId = 'extension_channel';
  static const String _extensionChannelName = 'Yêu cầu thời gian';

  // ── Notification IDs ───────────────────────────────────────────────────────
  static const int sosNotificationId = 1000;
  static const int geofenceNotificationId = 1001;
  static const int extensionNotificationId = 1002;
  // Android hiển thị thông báo FCM bằng notify(tag, 0, ...) — id luôn là 0 khi
  // message có tag, nên chỉ cần biết tag là gỡ được.
  static const int _fcmTaggedNotificationId = 0;
  static const String _extensionFcmTag = 'time_extension';
  // Bắt cả thông báo cũ đẩy từ trước khi backend gắn tag: tiêu đề server dựng
  // theo mẫu "⏳ <tên bé> xin thêm giờ" (extensionController.js).
  static const String _extensionTitleMarker = 'xin thêm giờ';

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init({Function(String?)? onNotificationTap}) async {
    if (onNotificationTap != null) {
      this.onNotificationTap = onNotificationTap;
    }
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
        this.onNotificationTap?.call(details.payload);
      },
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createSOSChannel();
      await _createGeofenceChannel();
      await _createExtensionChannel();
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

  Future<void> _createExtensionChannel() async {
    const channel = AndroidNotificationChannel(
      _extensionChannelId,
      _extensionChannelName,
      description: 'Thông báo khi trẻ xin thêm thời gian sử dụng',
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

  /// Khung hiển thị thông báo "Xin thêm giờ"
  Future<void> showTimeExtensionNotification({
    required String title,
    required String body,
    String payload = 'TIME_EXTENSION',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _extensionChannelId,
      _extensionChannelName,
      channelDescription: 'Thông báo khi trẻ xin thêm thời gian sử dụng',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      extensionNotificationId,
      title,
      body,
      details,
      payload: payload,
    );

    print('⏳ [NOTIFICATION] Time extension notification shown: $title');
  }

  /// Gỡ thông báo "xin thêm giờ" khỏi khay sau khi phụ huynh đã duyệt/từ chối
  /// ngay trong app. Phải quét 3 nguồn vì thông báo có thể do bên nào cũng được
  /// đẩy ra, mỗi bên đánh id khác nhau:
  ///   1. App tự hiện lúc đang mở  → plugin, id [extensionNotificationId].
  ///   2. FCM SDK hiện lúc app chạy nền → notify(tag, 0, ...) với tag server gửi
  ///      kèm (androidTag: 'time_extension' trong extensionController.js).
  ///   3. Thông báo đẩy từ bản build/backend cũ chưa có tag → không đoán được
  ///      id, phải rà danh sách thông báo đang hiện và đối chiếu tiêu đề.
  Future<void> cancelTimeExtensionNotification() async {
    try {
      await _plugin.cancel(extensionNotificationId);
      await _plugin.cancel(_fcmTaggedNotificationId, tag: _extensionFcmTag);

      if (!Platform.isAndroid) return;

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final active = await android?.getActiveNotifications() ?? [];
      for (final n in active) {
        final id = n.id;
        if (id == null) continue;
        final isExtension = n.channelId == _extensionChannelId ||
            n.tag == _extensionFcmTag ||
            (n.title?.contains(_extensionTitleMarker) ?? false);
        if (!isExtension) continue;
        await _plugin.cancel(id, tag: n.tag);
        print('🧹 [NOTIFICATION] Đã gỡ thông báo xin thêm giờ (id=$id, tag=${n.tag})');
      }
    } catch (e) {
      // Không chặn luồng duyệt/từ chối chỉ vì không gỡ được thông báo —
      // getActiveNotifications cần API 23+ và có thể ném trên máy cũ.
      print('❌ [NOTIFICATION] Không gỡ được thông báo xin thêm giờ: $e');
    }
  }
}
