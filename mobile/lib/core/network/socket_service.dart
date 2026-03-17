import 'dart:async';
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

  // ★★★ DEPRECATED: kept for backward compat but now just proxy to list-based listeners
  // These are no-op setters; do NOT use them for new code.
  set onDeviceLinkedCallback(SocketCallback? _) {}
  set onDeviceOnlineCallback(SocketCallback? _) {}
  set onDeviceOfflineCallback(SocketCallback? _) {}

  bool get isConnected => _socket?.connected ?? false;

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
      print('⏸️ [SOCKET] Child App Paused: Disconnecting to show offline status');
      socket.disconnect();
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
