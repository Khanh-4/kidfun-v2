import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

typedef SocketCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;
  
  // Connection credentials for auto-rejoin
  int? _userId;
  String? _deviceCode;
  String? _role; // 'parent' or 'child'
  
  // Callbacks as requested in Sprint document
  SocketCallback? onDeviceLinkedCallback;
  SocketCallback? onDeviceOnlineCallback;
  SocketCallback? onDeviceOfflineCallback;

  // Multiple listeners support (for providers)
  final List<SocketCallback> _onlineListeners = [];
  final List<SocketCallback> _offlineListeners = [];

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._() {
    print('🚀 [SOCKET] Singleton instance created');
  }

  // ── Listener Management ──────────────────────────────────────────────

  void addDeviceOnlineListener(SocketCallback callback) => _onlineListeners.add(callback);
  void removeDeviceOnlineListener(SocketCallback callback) => _onlineListeners.remove(callback);
  void addDeviceOfflineListener(SocketCallback callback) => _offlineListeners.add(callback);
  void removeDeviceOfflineListener(SocketCallback callback) => _offlineListeners.remove(callback);

  bool get isConnected => _socket?.connected ?? false;

  // ── Initialization ───────────────────────────────────────────────────

  void _ensureSocket() {
    if (_socket != null) return;

    print('🚀 [SOCKET] Initializing for: ${ApiConstants.baseUrl}');
    
    try {
      _socket = IO.io(ApiConstants.baseUrl, IO.OptionBuilder()
        .setTransports(['websocket', 'polling']) 
        .enableAutoConnect() 
        .enableReconnection()
        .setReconnectionAttempts(99999)
        .setReconnectionDelay(2000)
        .build()
      );

      _socket!.onConnect((_) {
        print('🟢🟢🟢 [SOCKET] CONNECTED: ${_socket!.id} as $role');
        _rejoinRooms();
      });

      _socket!.onDisconnect((reason) => print('🔴🔴🔴 [SOCKET] DISCONNECTED: $reason'));
      _socket!.onConnectError((err) => print('❌ [SOCKET] CONNECTION ERROR: $err'));

      // ── Event Handlers ────────────────────────────────────────────────
      
      _socket!.on('deviceLinked', (data) {
        print('🔗 [SOCKET] RECEIVED deviceLinked: $data');
        onDeviceLinkedCallback?.call(Map<String, dynamic>.from(data));
      });

      _socket!.on('deviceOnline', (data) {
        print('🟢 [SOCKET] RECEIVED deviceOnline: $data');
        final mapData = Map<String, dynamic>.from(data);
        onDeviceOnlineCallback?.call(mapData);
        for (final listener in List.from(_onlineListeners)) {
          listener(mapData);
        }
      });

      _socket!.on('deviceOffline', (data) {
        print('🔴 [SOCKET] RECEIVED deviceOffline: $data');
        final mapData = Map<String, dynamic>.from(data);
        onDeviceOfflineCallback?.call(mapData);
        for (final listener in List.from(_offlineListeners)) {
          listener(mapData);
        }
      });
      
    } catch (e) {
      print('❌ [SOCKET] CRITICAL ERROR during initialization: $e');
    }
  }

  void _rejoinRooms() {
    if (_userId != null) {
      print('👨‍👩‍👧 [SOCKET] Re-joining family room: $_userId');
      _socket?.emit('joinFamily', {'userId': _userId, 'role': _role});
    }
    if (_deviceCode != null) {
       print('📱 [SOCKET] Re-joining device room: $_deviceCode');
      _socket?.emit('joinDevice', {'deviceCode': _deviceCode});
    }
  }

  // ── Public API ───────────────────────────────────────────────────────

  String get role => _role ?? 'unknown';

  void connectAsParent(int userId) {
    if (userId == 0) return;
    _userId = userId;
    _role = 'parent';
    _ensureSocket();
    if (!_socket!.connected) _socket!.connect();
    _rejoinRooms();
  }

  void connectAsChild(String deviceCode) {
    if (deviceCode.isEmpty) return;
    _deviceCode = deviceCode;
    _role = 'child';
    _ensureSocket();
    if (!_socket!.connected) _socket!.connect();
    _rejoinRooms();
  }

  /// ★ Handle App Lifecycle (Bug 3)
  void onAppPaused() {
    if (_role == 'child') {
      print('⏸️ [SOCKET] App Paused: Disconnecting Child to show Offline');
      _socket?.disconnect();
    }
  }

  void onAppResumed() {
    if (_role == 'child' && _deviceCode != null) {
      print('▶️ [SOCKET] App Resumed: Reconnecting Child');
      _socket?.connect();
    } else if (_role == 'parent' && _userId != null) {
      if (!isConnected) {
        print('▶️ [SOCKET] App Resumed: Reconnecting Parent');
        _socket?.connect();
      }
    }
  }

  void reconnect() {
    _socket?.disconnect();
    _socket?.connect();
  }

  void disconnect() {
    print('🔌 [SOCKET] Full disconnect');
    _userId = null;
    _deviceCode = null;
    _role = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
