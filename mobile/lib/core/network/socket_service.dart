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
  
  // Multiple listeners support - KEEP these even when socket is null
  final List<SocketCallback> _onlineListeners = [];
  final List<SocketCallback> _offlineListeners = [];
  
  // Heartbeat timer
  Timer? _heartbeatTimer;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._() {
    print('🚀 [SOCKET] Singleton instance created');
    _startHeartbeat();
  }

  // ── Listener Management ──────────────────────────────────────────────

  void addDeviceOnlineListener(SocketCallback callback) {
    if (!_onlineListeners.contains(callback)) {
      _onlineListeners.add(callback);
      print('📡 [SOCKET] Added online listener. Total: ${_onlineListeners.length}');
    }
  }

  void removeDeviceOnlineListener(SocketCallback callback) {
    _onlineListeners.remove(callback);
    print('📡 [SOCKET] Removed online listener. Total: ${_onlineListeners.length}');
  }

  void addDeviceOfflineListener(SocketCallback callback) {
    if (!_offlineListeners.contains(callback)) {
      _offlineListeners.add(callback);
      print('📡 [SOCKET] Added offline listener. Total: ${_offlineListeners.length}');
    }
  }

  void removeDeviceOfflineListener(SocketCallback callback) {
    _offlineListeners.remove(callback);
    print('📡 [SOCKET] Removed offline listener. Total: ${_offlineListeners.length}');
  }

  bool get isConnected => _socket?.connected ?? false;

  // ── Initialization ───────────────────────────────────────────────────

  void _ensureSocket() {
    if (_socket != null) {
      print('🚀 [SOCKET] Socket already exists (connected: ${_socket!.connected})');
      return;
    }

    print('🚀 [SOCKET] Initializing new socket for: ${ApiConstants.baseUrl}');
    
    try {
      // Config cực kỳ bền bỉ cho Railway/Proxy
      _socket = IO.io(ApiConstants.baseUrl, IO.OptionBuilder()
        .setTransports(['polling', 'websocket']) // Polling trước để handshake chắc chắn
        .setExtraHeaders({'origin': 'mobile-app'})
        .enableAutoConnect() 
        .enableReconnection()
        .setReconnectionAttempts(99999)
        .setReconnectionDelay(2000)
        .setReconnectionDelayMax(5000)
        .build()
      );

      _socket!.onConnect((_) {
        print('🟢🟢🟢 [SOCKET] CONNECTED: ${_socket!.id} as $role');
        _rejoinRooms();
      });

      _socket!.onConnecting((_) => print('🟡 [SOCKET] Connecting...'));

      _socket!.onDisconnect((reason) {
        print('🔴🔴🔴 [SOCKET] DISCONNECTED: $reason');
      });

      _socket!.onConnectError((err) {
        print('❌ [SOCKET] CONNECTION ERROR ($role): $err');
      });

      _socket!.onReconnect((_) => print('🔄🟢 [SOCKET] RECONNECTED'));
      _socket!.onReconnectAttempt((_) => print('🔄 [SOCKET] Reconnecting...'));

      // ── Event Handlers ────────────────────────────────────────────────
      
      _socket!.on('deviceOnline', (data) {
        print('📱 [SOCKET] RECEIVED deviceOnline: $data');
        final mapData = Map<String, dynamic>.from(data);
        // Dispatch to all listeners
        for (final listener in List.from(_onlineListeners)) {
          listener(mapData);
        }
      });

      _socket!.on('deviceOffline', (data) {
        print('📱 [SOCKET] RECEIVED deviceOffline: $data');
        final mapData = Map<String, dynamic>.from(data);
        for (final listener in List.from(_offlineListeners)) {
          listener(mapData);
        }
      });
      
      // Heartbeat from server
      _socket!.on('pong', (data) => print('💓 [SOCKET] Heartbeat (pong)'));

    } catch (e) {
      print('❌ [SOCKET] CRITICAL ERROR during initialization: $e');
    }
  }

  void _rejoinRooms() {
    if (_userId != null) {
      print('👨‍👩‍👧 [SOCKET] Emitting joinFamily: userId=$_userId, role=$_role');
      _socket?.emit('joinFamily', {
        'userId': _userId,
        'role': _role ?? 'parent',
      });
    }
    
    if (_deviceCode != null) {
      print('📱 [SOCKET] Emitting joinDevice: deviceCode=$_deviceCode');
      _socket?.emit('joinDevice', {
        'deviceCode': _deviceCode,
      });
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (isConnected) {
        _socket?.emit('ping', {'role': _role, 'timestamp': DateTime.now().toIso8601String()});
      }
    });
  }

  // ── Public API ───────────────────────────────────────────────────────

  String get role => _role ?? 'unknown';

  void connectAsParent(int userId) {
    if (userId == 0) {
      print('⚠️ [SOCKET] connectAsParent called with userId 0. Ignoring.');
      return;
    }
    print('👨‍👩‍👧 [SOCKET] connectAsParent: $userId');
    _userId = userId;
    _role = 'parent';
    _deviceCode = null;
    _ensureSocket();
    if (_socket != null && !_socket!.connected) {
      print('📡 [SOCKET] Triggering manual connect()...');
      _socket!.connect();
    } else {
      _rejoinRooms();
    }
  }

  void connectAsChild(String deviceCode) {
    if (deviceCode.isEmpty) {
       print('⚠️ [SOCKET] connectAsChild called with empty deviceCode. Ignoring.');
       return;
    }
    print('📱 [SOCKET] connectAsChild: $deviceCode');
    _deviceCode = deviceCode;
    _role = 'child';
    _userId = null;
    _ensureSocket();
    if (_socket != null && !_socket!.connected) {
      print('📡 [SOCKET] Triggering manual connect()...');
      _socket!.connect();
    } else {
      _rejoinRooms();
    }
  }

  void reconnect() {
    print('🔄 [SOCKET] Force reconnecting...');
    if (_socket != null) {
      _socket!.disconnect();
      // Ta không set _socket = null ở đây để giữ instance và listeners
      _socket!.connect();
    } else {
      if (_role == 'parent' && _userId != null) {
        connectAsParent(_userId!);
      } else if (_role == 'child' && _deviceCode != null) {
        connectAsChild(_deviceCode!);
      }
    }
  }

  void disconnect() {
    print('🔌 [SOCKET] Manual disconnect triggered');
    _userId = null;
    _deviceCode = null;
    _role = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    // CRITICAL: We DO NOT set _instance = null anymore.
    // This allows Riverpod providers to keep their listeners registered.
  }
}
