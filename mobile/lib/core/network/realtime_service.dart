import 'dart:async';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'dio_client.dart';

typedef RealtimeCallback = void Function(Map<String, dynamic> data);

/// Thay thế cho SocketService, dùng Supabase Realtime (Postgres Changes)
/// thay vì Socket.IO. API giống hệt SocketService (cùng tên method) để
/// cutover từng file chỉ cần đổi import, không cần sửa logic từng consumer.
///
/// Thiết kế "notify-then-refetch": mọi callback chỉ báo "có gì đó thay đổi ở
/// bảng X" (KHÔNG chứa profileName/deviceName — raw Postgres row không có
/// field join). Consumer luôn tự refetch qua REST API hiện có để lấy data
/// đầy đủ — đúng pattern đã dùng ở _checkPendingRequests()/_checkActiveSOS()
/// trong shared/widgets/time_extension_listener.dart. Không đọc field nào từ
/// payload trong file này, tránh rủi ro map sai/thiếu field mà flutter
/// analyze không bắt được (lỗi runtime, không phải lỗi type).
///
/// CHƯA xử lý: locationRequested (lệnh tức thời, không gắn DB row — cần
/// Realtime Broadcast riêng, để lại cho bước sau).
class RealtimeService {
  static RealtimeService? _instance;
  static RealtimeService get instance {
    _instance ??= RealtimeService._();
    return _instance!;
  }

  RealtimeService._();

  // Bảng public, không phải secret — an toàn nhúng trong mobile app (đúng
  // thiết kế Supabase: publishable key + RLS quyết định quyền truy cập thật).
  static const String _supabaseUrl = 'https://hoaxvwzglvplmjwyeuov.supabase.co';
  static const String _supabaseAnonKey =
      'sb_publishable_KU8MyUUYPlCW3D-sk4TtCw_tvlZAAjB';

  bool _initialized = false;
  String? _currentRole; // 'parent' | 'child'
  int? _lastUserId;
  String? _lastDeviceCode;
  Timer? _tokenRefreshTimer;
  final List<sb.RealtimeChannel> _channels = [];

  final List<RealtimeCallback> _deviceLinkedListeners = [];
  final List<RealtimeCallback> _deviceOnlineListeners = [];
  final List<RealtimeCallback> _deviceOfflineListeners = [];
  final List<RealtimeCallback> _timeExtensionRequestListeners = [];
  final List<RealtimeCallback> _timeExtensionResponseListeners = [];
  final List<RealtimeCallback> _geofenceEventListeners = [];
  final List<RealtimeCallback> _sosAlertListeners = [];
  final List<RealtimeCallback> _aiAlertListeners = [];
  final List<RealtimeCallback> _deviceErrorListeners = [];
  final List<RealtimeCallback> _connectionRestoredListeners = [];
  final List<RealtimeCallback> _timeLimitUpdatedListeners = [];
  final List<RealtimeCallback> _blockedAppsUpdatedListeners = [];
  final List<RealtimeCallback> _blockedDomainsUpdatedListeners = [];
  final List<RealtimeCallback> _blockedVideosUpdatedListeners = [];
  final List<RealtimeCallback> _appTimeLimitUpdatedListeners = [];
  final List<RealtimeCallback> _schoolScheduleUpdatedListeners = [];
  final List<RealtimeCallback> _locationUpdatedListeners = [];

  // ── Listener Management (cùng tên method với SocketService) ─────────────

  void addDeviceLinkedListener(RealtimeCallback callback) =>
      _deviceLinkedListeners.add(callback);
  void removeDeviceLinkedListener(RealtimeCallback callback) =>
      _deviceLinkedListeners.remove(callback);

  void addDeviceOnlineListener(RealtimeCallback callback) =>
      _deviceOnlineListeners.add(callback);
  void removeDeviceOnlineListener(RealtimeCallback callback) =>
      _deviceOnlineListeners.remove(callback);

  void addDeviceOfflineListener(RealtimeCallback callback) =>
      _deviceOfflineListeners.add(callback);
  void removeDeviceOfflineListener(RealtimeCallback callback) =>
      _deviceOfflineListeners.remove(callback);

  void addTimeExtensionRequestListener(RealtimeCallback callback) =>
      _timeExtensionRequestListeners.add(callback);
  void removeTimeExtensionRequestListener(RealtimeCallback callback) =>
      _timeExtensionRequestListeners.remove(callback);

  /// UPDATE trên TimeExtensionRequest (status → APPROVED/REJECTED) — phía
  /// Child dùng để biết yêu cầu của mình vừa được phản hồi (khác với
  /// addTimeExtensionRequestListener ở trên là INSERT, phía Parent).
  void addTimeExtensionResponseListener(RealtimeCallback callback) =>
      _timeExtensionResponseListeners.add(callback);
  void removeTimeExtensionResponseListener(RealtimeCallback callback) =>
      _timeExtensionResponseListeners.remove(callback);

  void addGeofenceEventListener(RealtimeCallback callback) =>
      _geofenceEventListeners.add(callback);
  void removeGeofenceEventListener(RealtimeCallback callback) =>
      _geofenceEventListeners.remove(callback);

  void addSosAlertListener(RealtimeCallback callback) =>
      _sosAlertListeners.add(callback);
  void removeSosAlertListener(RealtimeCallback callback) =>
      _sosAlertListeners.remove(callback);

  void addAiAlertListener(RealtimeCallback callback) =>
      _aiAlertListeners.add(callback);
  void removeAiAlertListener(RealtimeCallback callback) =>
      _aiAlertListeners.remove(callback);

  void addDeviceErrorListener(RealtimeCallback callback) =>
      _deviceErrorListeners.add(callback);
  void removeDeviceErrorListener(RealtimeCallback callback) =>
      _deviceErrorListeners.remove(callback);

  /// Báo khi kết nối vừa được (tái) thiết lập thành công — dùng để consumer
  /// tự refetch REST, bù các event có thể đã bỏ lỡ lúc mất kết nối. Khớp vai
  /// trò với `socket.on('connect', ...)` cũ bên SocketService.
  void addConnectionRestoredListener(RealtimeCallback callback) =>
      _connectionRestoredListeners.add(callback);
  void removeConnectionRestoredListener(RealtimeCallback callback) =>
      _connectionRestoredListeners.remove(callback);

  void addTimeLimitUpdatedListener(RealtimeCallback callback) =>
      _timeLimitUpdatedListeners.add(callback);
  void removeTimeLimitUpdatedListener(RealtimeCallback callback) =>
      _timeLimitUpdatedListeners.remove(callback);

  void addBlockedAppsUpdatedListener(RealtimeCallback callback) =>
      _blockedAppsUpdatedListeners.add(callback);
  void removeBlockedAppsUpdatedListener(RealtimeCallback callback) =>
      _blockedAppsUpdatedListeners.remove(callback);

  void addBlockedDomainsUpdatedListener(RealtimeCallback callback) =>
      _blockedDomainsUpdatedListeners.add(callback);
  void removeBlockedDomainsUpdatedListener(RealtimeCallback callback) =>
      _blockedDomainsUpdatedListeners.remove(callback);

  void addBlockedVideosUpdatedListener(RealtimeCallback callback) =>
      _blockedVideosUpdatedListeners.add(callback);
  void removeBlockedVideosUpdatedListener(RealtimeCallback callback) =>
      _blockedVideosUpdatedListeners.remove(callback);

  void addAppTimeLimitUpdatedListener(RealtimeCallback callback) =>
      _appTimeLimitUpdatedListeners.add(callback);
  void removeAppTimeLimitUpdatedListener(RealtimeCallback callback) =>
      _appTimeLimitUpdatedListeners.remove(callback);

  void addSchoolScheduleUpdatedListener(RealtimeCallback callback) =>
      _schoolScheduleUpdatedListeners.add(callback);
  void removeSchoolScheduleUpdatedListener(RealtimeCallback callback) =>
      _schoolScheduleUpdatedListeners.remove(callback);

  /// INSERT trên LocationLog — dùng bởi map_screen.dart (phía Parent) để
  /// biết cần refetch vị trí mới nhất qua REST (GET .../location/current).
  void addLocationUpdatedListener(RealtimeCallback callback) =>
      _locationUpdatedListeners.add(callback);
  void removeLocationUpdatedListener(RealtimeCallback callback) =>
      _locationUpdatedListeners.remove(callback);

  /// 'parent' | 'child' | null
  String? get currentRole => _currentRole;
  bool get isConnected => _channels.isNotEmpty;

  // ── Token minting (đổi JWT app-riêng lấy JWT Supabase-Realtime-riêng) ───

  Future<String?> _fetchParentToken() async {
    try {
      final res = await DioClient.instance.get('/api/auth/realtime-token');
      return res.data['data']['token'] as String?;
    } catch (e) {
      print('❌ [Realtime] Failed to fetch parent token: $e');
      return null;
    }
  }

  Future<String?> _fetchChildToken(String deviceCode) async {
    try {
      final res = await DioClient.instance.post(
        '/api/child/realtime-token',
        options: Options(headers: {'X-Device-Code': deviceCode}),
      );
      return res.data['data']['token'] as String?;
    } catch (e) {
      print('❌ [Realtime] Failed to fetch child token: $e');
      return null;
    }
  }

  Future<String?> _fetchTokenForCurrentRole() {
    if (_currentRole == 'parent' && _lastUserId != null) {
      return _fetchParentToken();
    }
    if (_currentRole == 'child' && _lastDeviceCode != null) {
      return _fetchChildToken(_lastDeviceCode!);
    }
    return Future.value(null);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await sb.Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
    _initialized = true;
  }

  // ── Room Join Logic (giữ đúng tên method như SocketService) ─────────────

  Future<void> joinFamily(int userId) async {
    if (userId == 0) return;
    print('📡 [Realtime] joinFamily called for userId=$userId');
    _currentRole = 'parent';
    _lastUserId = userId;
    _lastDeviceCode = null;
    await _connect();
  }

  Future<void> joinDevice(String deviceCode) async {
    if (deviceCode.isEmpty) return;
    print('📱 [Realtime] joinDevice called for deviceCode=$deviceCode');
    _currentRole = 'child';
    _lastDeviceCode = deviceCode;
    _lastUserId = null;
    await _connect();
  }

  // Backward compatibility aliases (khớp SocketService)
  Future<void> connectAsParent(int userId) => joinFamily(userId);
  Future<void> connectAsChild(String deviceCode) => joinDevice(deviceCode);

  Future<void> _connect() async {
    await _ensureInitialized();
    final token = await _fetchTokenForCurrentRole();

    if (token == null) {
      print('❌ [Realtime] No token — cannot connect (role=$_currentRole)');
      for (final cb in List<RealtimeCallback>.from(_deviceErrorListeners)) {
        cb({'code': 'REALTIME_AUTH_FAILED'});
      }
      return;
    }

    await sb.Supabase.instance.client.realtime.setAuth(token);
    _scheduleTokenRefresh();
    await _subscribeChannels();

    // Khớp semantics socket.on('connect', ...) cũ: bắn mỗi lần connect thành
    // công (kể cả lần đầu), không chỉ lúc reconnect — consumer tự refetch,
    // gọi thừa vài lần không hại gì (idempotent).
    for (final cb in List<RealtimeCallback>.from(_connectionRestoredListeners)) {
      cb({'source': 'realtime', 'event': 'connected'});
    }
  }

  void _scheduleTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    // Token hết hạn sau 1h (REALTIME_TOKEN_TTL_SECONDS ở backend) — refresh
    // sớm hơn 5 phút để không bao giờ bị hết hạn giữa chừng.
    _tokenRefreshTimer = Timer(const Duration(minutes: 55), () async {
      final token = await _fetchTokenForCurrentRole();
      if (token != null) {
        await sb.Supabase.instance.client.realtime.setAuth(token);
        print('🔄 [Realtime] Token refreshed');
      }
      _scheduleTokenRefresh();
    });
  }

  // ── Subscriptions (notify-then-refetch, không đọc field từ payload) ─────

  void _notify(List<RealtimeCallback> listeners, String table, String eventType) {
    final signal = <String, dynamic>{
      'table': table,
      'eventType': eventType,
      'source': 'realtime',
    };
    for (final cb in List<RealtimeCallback>.from(listeners)) {
      cb(signal);
    }
  }

  Future<void> _subscribeChannels() async {
    await _unsubscribeAll();
    final client = sb.Supabase.instance.client;

    final channel = client.channel('family_updates');

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.all,
      schema: 'public',
      table: 'Device',
      callback: (payload) {
        final type = payload.eventType.name;
        // Việc link thật sự luôn là UPDATE (ghi đè device nháp hoặc device
        // phần cứng đã tồn tại) — INSERT chỉ xảy ra lúc generate-pairing-code
        // tạo device nháp, KHÔNG phải lúc child xác nhận. Báo cả 2 loại vì
        // consumer (add_device_screen) tự verify lại qua REST theo deviceId
        // cụ thể trước khi coi là đã liên kết thật (tránh false-positive).
        if (payload.eventType == sb.PostgresChangeEvent.insert ||
            payload.eventType == sb.PostgresChangeEvent.update) {
          _notify(_deviceLinkedListeners, 'Device', type);
        }
        // UPDATE có thể là online hoặc offline — không đọc field isOnline ở
        // đây (notify-then-refetch), báo cả 2 phía, consumer tự refetch để
        // biết trạng thái thật.
        _notify(_deviceOnlineListeners, 'Device', type);
        _notify(_deviceOfflineListeners, 'Device', type);
      },
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.insert,
      schema: 'public',
      table: 'TimeExtensionRequest',
      callback: (payload) => _notify(
          _timeExtensionRequestListeners, 'TimeExtensionRequest', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.update,
      schema: 'public',
      table: 'TimeExtensionRequest',
      callback: (payload) => _notify(
          _timeExtensionResponseListeners, 'TimeExtensionRequest', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.insert,
      schema: 'public',
      table: 'GeofenceEvent',
      callback: (payload) =>
          _notify(_geofenceEventListeners, 'GeofenceEvent', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.insert,
      schema: 'public',
      table: 'SOSAlert',
      callback: (payload) => _notify(_sosAlertListeners, 'SOSAlert', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.insert,
      schema: 'public',
      table: 'AIAlert',
      callback: (payload) => _notify(_aiAlertListeners, 'AIAlert', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.all,
      schema: 'public',
      table: 'TimeLimit',
      callback: (payload) =>
          _notify(_timeLimitUpdatedListeners, 'TimeLimit', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.all,
      schema: 'public',
      table: 'BlockedApp',
      callback: (payload) =>
          _notify(_blockedAppsUpdatedListeners, 'BlockedApp', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.all,
      schema: 'public',
      table: 'CustomBlockedDomain',
      callback: (payload) => _notify(
          _blockedDomainsUpdatedListeners, 'CustomBlockedDomain', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.all,
      schema: 'public',
      table: 'BlockedVideo',
      callback: (payload) =>
          _notify(_blockedVideosUpdatedListeners, 'BlockedVideo', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.all,
      schema: 'public',
      table: 'AppTimeLimit',
      callback: (payload) =>
          _notify(_appTimeLimitUpdatedListeners, 'AppTimeLimit', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.all,
      schema: 'public',
      table: 'SchoolSchedule',
      callback: (payload) =>
          _notify(_schoolScheduleUpdatedListeners, 'SchoolSchedule', payload.eventType.name),
    );

    channel.onPostgresChanges(
      event: sb.PostgresChangeEvent.insert,
      schema: 'public',
      table: 'LocationLog',
      callback: (payload) =>
          _notify(_locationUpdatedListeners, 'LocationLog', payload.eventType.name),
    );

    channel.subscribe();
    _channels.add(channel);
  }

  Future<void> _unsubscribeAll() async {
    for (final ch in _channels) {
      await sb.Supabase.instance.client.removeChannel(ch);
    }
    _channels.clear();
  }

  // ── Lifecycle (khớp SocketService) ───────────────────────────────────────

  void onAppPaused() {
    // Supabase Realtime tự quản lý kết nối nền, không cần xử lý riêng.
  }

  void onAppResumed() {
    print('▶️ [Realtime] App Resumed. Checking connection for $_currentRole');
    if (_currentRole == 'child' && _lastDeviceCode != null) {
      joinDevice(_lastDeviceCode!);
    } else if (_currentRole == 'parent' && _lastUserId != null) {
      joinFamily(_lastUserId!);
    }
  }

  void reconnect() {
    print('🔄 [Realtime] Manually triggering reconnect...');
    _connect();
  }

  Future<void> disconnect() async {
    print('🔌 [Realtime] Full disconnect initiated');
    _tokenRefreshTimer?.cancel();
    await _unsubscribeAll();
    _lastUserId = null;
    _lastDeviceCode = null;
    _currentRole = null;
  }
}
