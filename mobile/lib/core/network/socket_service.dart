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

  // Specific callbacks as requested in BUGFIX Round 2
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
    print('🚀 [SOCKET] SocketService Singleton Initialized');
  }

  // ── Listener Management ──────────────────────────────────────────────

  void addDeviceOnlineListener(SocketCallback callback) => _onlineListeners.add(callback);
  void removeDeviceOnlineListener(SocketCallback callback) => _onlineListeners.remove(callback);
  void addDeviceOfflineListener(SocketCallback callback) => _offlineListeners.add(callback);
  void removeDeviceOfflineListener(SocketCallback callback) => _offlineListeners.remove(callback);

  bool get isConnected => _socket?.connected ?? false;

  IO.Socket get socket {
    if (_socket == null) {
      print('🚀 [SOCKET] Creating new IO.socket instance for ${ApiConstants.baseUrl}');
      _socket = IO.io(ApiConstants.baseUrl, IO.OptionBuilder()
        .setTransports(['websocket', 'polling']) 
        .enableAutoConnect() 
        .enableReconnection()
        .setReconnectionAttempts(99999)
        .setReconnectionDelay(2000)
        .build()
      );

      _socket!.onConnect((_) {
        print('🟢🟢🟢 [SOCKET] CONNECTED: ${_socket!.id} (Role: $_currentRole)');
        // Khi reconnect, ta cần emit lại lệnh join
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
    }
    return _socket!;
  }

  // ── Room Join Logic (Robust with connection check) ───────────────────

  /// Parent: join family room
  void joinFamily(int userId) {
    if (userId == 0) return;
    
    print('📡 [SOCKET] joinFamily called for userId=$userId');
    _lastUserId = userId;
    _currentRole = 'parent';
    _lastDeviceCode = null;
    _hasJoinedFamily = false;

    // Đảm bảo socket đang mở
    socket.connect();

    // Nếu đã connect rồi -> emit ngay
    if (socket.connected) {
      _emitJoinFamily(userId);
    } 
    // Nếu chưa, nó sẽ được gọi trong onConnect listener ở trên
  }

  void _emitJoinFamily(int userId) {
    if (_hasJoinedFamily) return; // Tránh emit trùng lặp nếu onConnect và manual call cả hai cùng chạy
    print('👨‍👩‍👧 [SOCKET] Emitting joinFamily: userId=$userId');
    socket.emit('joinFamily', {'userId': userId, 'role': 'parent'});
    _hasJoinedFamily = true;
  }

  /// Child: join device room
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

  // Backward compatibility alias (if any)
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
