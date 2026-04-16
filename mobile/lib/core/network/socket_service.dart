import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

typedef SocketCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;

  // Connection credentials for auto-rejoin
  int? _lastUserId;
  String? _lastDeviceCode;
  String? _currentRole; // 'parent' or 'child'

  // Guard flags to prevent duplicate joins
  bool _hasJoinedFamily = false;
  bool _hasJoinedDevice = false;

  // ★★★ FIXED: Use list-based listeners for ALL events to support multiple subscribers
  final List<SocketCallback> _deviceLinkedListeners = [];
  final List<SocketCallback> _deviceOnlineListeners = [];
  final List<SocketCallback> _deviceOfflineListeners = [];
  final List<SocketCallback> _timeExtensionRequestListeners = [];
  final List<SocketCallback> _geofenceEventListeners = [];
  final List<SocketCallback> _sosAlertListeners = [];
  // Sprint 9: AI alert listeners — dangerous YouTube content detected
  final List<SocketCallback> _aiAlertListeners = [];

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._() {
    print('🚀 [SOCKET] SocketService Singleton Initialized');
  }

  // ── Listener Management ──────────────────────────────────────────────

  // deviceLinked listeners
  void addDeviceLinkedListener(SocketCallback callback) {
    _deviceLinkedListeners.add(callback);
    print('🔗 [SOCKET] deviceLinked listener added. Total: ${_deviceLinkedListeners.length}');
  }
  void removeDeviceLinkedListener(SocketCallback callback) {
    _deviceLinkedListeners.remove(callback);
    print('🔗 [SOCKET] deviceLinked listener removed. Total: ${_deviceLinkedListeners.length}');
  }

  // deviceOnline listeners
  void addDeviceOnlineListener(SocketCallback callback) => _deviceOnlineListeners.add(callback);
  void removeDeviceOnlineListener(SocketCallback callback) => _deviceOnlineListeners.remove(callback);

  // deviceOffline listeners
  void addDeviceOfflineListener(SocketCallback callback) => _deviceOfflineListeners.add(callback);
  void removeDeviceOfflineListener(SocketCallback callback) => _deviceOfflineListeners.remove(callback);

  // timeExtensionRequest listeners
  void addTimeExtensionRequestListener(SocketCallback callback) => _timeExtensionRequestListeners.add(callback);
  void removeTimeExtensionRequestListener(SocketCallback callback) => _timeExtensionRequestListeners.remove(callback);

  // geofenceEvent listeners — TC-09-10: routed through list system so multiple screens
  // can subscribe independently without raw socket.off() wiping each other's handlers
  void addGeofenceEventListener(SocketCallback callback) => _geofenceEventListeners.add(callback);
  void removeGeofenceEventListener(SocketCallback callback) => _geofenceEventListeners.remove(callback);

  // sosAlert listeners — TC-21: global handler so any screen receives SOS
  void addSosAlertListener(SocketCallback callback) => _sosAlertListeners.add(callback);
  void removeSosAlertListener(SocketCallback callback) => _sosAlertListeners.remove(callback);

  // aiAlert listeners — Sprint 9: AI detected dangerous YouTube content
  void addAiAlertListener(SocketCallback callback) => _aiAlertListeners.add(callback);
  void removeAiAlertListener(SocketCallback callback) => _aiAlertListeners.remove(callback);

  // ★★★ DEPRECATED: kept for backward compat but now just proxy to list-based listeners
  // These are no-op setters; do NOT use them for new code.
  set onDeviceLinkedCallback(SocketCallback? _) {}
  set onDeviceOnlineCallback(SocketCallback? _) {}
  set onDeviceOfflineCallback(SocketCallback? _) {}

  bool get isConnected => _socket?.connected ?? false;

  /// 'parent' | 'child' | null — used to gate parent-only UI (SOS dialog, etc.)
  String? get currentRole => _currentRole;

  IO.Socket get socket {
    if (_socket == null) {
      print('🚀 [SOCKET] Creating new IO.socket instance for ${ApiConstants.baseUrl}');
      _socket = IO.io(ApiConstants.baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(99999)
        .setReconnectionDelay(2000)
        .build()
      );

      _socket!.onConnect((_) {
        print('🟢🟢🟢 [SOCKET] CONNECTED: ${_socket!.id} (Role: $_currentRole)');
        if (_currentRole == 'parent' && _lastUserId != null) {
          _emitJoinFamily(_lastUserId!);
        } else if (_currentRole == 'child' && _lastDeviceCode != null) {
          _emitJoinDevice(_lastDeviceCode!);
        }
      });

      _socket!.onDisconnect((reason) {
        print('🔴🔴🔴 [SOCKET] DISCONNECTED: $reason');
        _hasJoinedFamily = false;
        _hasJoinedDevice = false;
      });

      _socket!.onConnectError((err) => print('❌ [SOCKET] CONNECTION ERROR: $err'));

      // ── Event Handlers (dispatch to ALL registered listeners) ─────────

      _socket!.on('deviceLinked', (data) {
        print('🔗 [SOCKET] RECEIVED deviceLinked: $data (listeners: ${_deviceLinkedListeners.length})');
        final mapData = Map<String, dynamic>.from(data as Map);
        for (final cb in List.from(_deviceLinkedListeners)) {
          cb(mapData);
        }
      });

      // Alias: device_linked_success (same payload, same listeners)
      _socket!.on('device_linked_success', (data) {
        print('🔗 [SOCKET] RECEIVED device_linked_success: $data (listeners: ${_deviceLinkedListeners.length})');
        final mapData = Map<String, dynamic>.from(data as Map);
        for (final cb in List.from(_deviceLinkedListeners)) {
          cb(mapData);
        }
      });

      _socket!.on('deviceOnline', (data) {
        print('🟢 [SOCKET] RECEIVED deviceOnline: $data (listeners: ${_deviceOnlineListeners.length})');
        final mapData = Map<String, dynamic>.from(data as Map);
        for (final cb in List.from(_deviceOnlineListeners)) {
          cb(mapData);
        }
      });

      _socket!.on('deviceOffline', (data) {
        print('🔴 [SOCKET] RECEIVED deviceOffline: $data (listeners: ${_deviceOfflineListeners.length})');
        final mapData = Map<String, dynamic>.from(data as Map);
        for (final cb in List.from(_deviceOfflineListeners)) {
          cb(mapData);
        }
      });

      // device_status_changed: { deviceId, isOnline } — routes to online or offline listeners
      _socket!.on('device_status_changed', (data) {
        print('📶 [SOCKET] RECEIVED device_status_changed: $data');
        final mapData = Map<String, dynamic>.from(data as Map);
        final isOnline = mapData['isOnline'] as bool? ?? false;
        if (isOnline) {
          for (final cb in List.from(_deviceOnlineListeners)) {
            cb(mapData);
          }
        } else {
          for (final cb in List.from(_deviceOfflineListeners)) {
            cb(mapData);
          }
        }
      });

      _socket!.on('timeExtensionRequest', (data) {
        print('⏰ [SOCKET] RECEIVED timeExtensionRequest: $data (listeners: ${_timeExtensionRequestListeners.length})');
        final mapData = Map<String, dynamic>.from(data as Map);
        for (final cb in List.from(_timeExtensionRequestListeners)) {
          cb(mapData);
        }
      });

      // TC-09-10: geofenceEvent routed through list system — avoids socket.off() wipe issues
      _socket!.on('geofenceEvent', (data) {
        print('🌍 [SOCKET] RECEIVED geofenceEvent: $data (listeners: ${_geofenceEventListeners.length})');
        final mapData = Map<String, dynamic>.from(data as Map);
        for (final cb in List.from(_geofenceEventListeners)) {
          cb(mapData);
        }
      });

      // TC-21: sosAlert routed through list system — global handler active from any screen
      _socket!.on('sosAlert', (data) {
        print('🆘 [SOCKET] RECEIVED sosAlert: $data (listeners: ${_sosAlertListeners.length})');
        final mapData = Map<String, dynamic>.from(data as Map);
        for (final cb in List.from(_sosAlertListeners)) {
          cb(mapData);
        }
      });

      // Sprint 9: aiAlert — parent notified when AI flags dangerous YouTube content
      _socket!.on('aiAlert', (data) {
        print('🪓 [SOCKET] RECEIVED aiAlert: $data (listeners: ${_aiAlertListeners.length})');
        final mapData = Map<String, dynamic>.from(data as Map);
        for (final cb in List.from(_aiAlertListeners)) {
          cb(mapData);
        }
      });
    }
    return _socket!;
  }

  // ── Room Join Logic ────────────────────────────────────────────────────

  void joinFamily(int userId) {
    if (userId == 0) return;

    print('📡 [SOCKET] joinFamily called for userId=$userId');
    _lastUserId = userId;
    _currentRole = 'parent';
    _lastDeviceCode = null;
    _hasJoinedFamily = false;

    socket.connect();

    if (socket.connected) {
      _emitJoinFamily(userId);
    }
    // If not connected yet, onConnect will call _emitJoinFamily
  }

  void _emitJoinFamily(int userId) {
    if (_hasJoinedFamily) return;
    print('👨‍👩‍👧 [SOCKET] Emitting joinFamily: userId=$userId');
    socket.emit('joinFamily', {'userId': userId, 'role': 'parent'});
    _hasJoinedFamily = true;
  }

  void joinDevice(String deviceCode) {
    if (deviceCode.isEmpty) return;

    print('📱 [SOCKET] joinDevice called for deviceCode=$deviceCode');
    _lastDeviceCode = deviceCode;
    _currentRole = 'child';
    _lastUserId = null;
    _hasJoinedDevice = false;

    socket.connect();

    if (socket.connected) {
      _emitJoinDevice(deviceCode);
    }
  }

  void _emitJoinDevice(String deviceCode) {
    if (_hasJoinedDevice) return;
    print('📱 [SOCKET] Emitting joinDevice: deviceCode=$deviceCode');
    socket.emit('joinDevice', {'deviceCode': deviceCode});
    _hasJoinedDevice = true;
  }

  // Backward compatibility aliases
  void connectAsParent(int userId) => joinFamily(userId);
  void connectAsChild(String deviceCode) => joinDevice(deviceCode);

  // ── Lifecycle Management ─────────────────────────────────────────────

  void onAppPaused() {
    if (_currentRole == 'child') {
      print('⏸️ [SOCKET] Child App Paused: Keeping connection alive for background sync');
      // socket.disconnect();
    }
  }

  void onAppResumed() {
    print('▶️ [SOCKET] App Resumed. Checking connection for $_currentRole');
    if (_currentRole == 'child' && _lastDeviceCode != null) {
      joinDevice(_lastDeviceCode!);
    } else if (_currentRole == 'parent' && _lastUserId != null) {
      if (!socket.connected) {
        joinFamily(_lastUserId!);
      }
    }
  }

  void reconnect() {
    print('🔄 [SOCKET] Manually triggering reconnect...');
    socket.disconnect();
    socket.connect();
  }

  void disconnect() {
    print('🔌 [SOCKET] Full disconnect initiated');
    _lastUserId = null;
    _lastDeviceCode = null;
    _currentRole = null;
    _hasJoinedFamily = false;
    _hasJoinedDevice = false;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
