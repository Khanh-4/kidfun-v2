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
  
  // Multiple listeners support
  final List<SocketCallback> _onlineListeners = [];
  final List<SocketCallback> _offlineListeners = [];

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

  // ── Listener Management ──────────────────────────────────────────────

  void addDeviceOnlineListener(SocketCallback callback) {
    if (!_onlineListeners.contains(callback)) _onlineListeners.add(callback);
  }

  void removeDeviceOnlineListener(SocketCallback callback) {
    _onlineListeners.remove(callback);
  }

  void addDeviceOfflineListener(SocketCallback callback) {
    if (!_offlineListeners.contains(callback)) _offlineListeners.add(callback);
  }

  void removeDeviceOfflineListener(SocketCallback callback) {
    _offlineListeners.remove(callback);
  }

  // Backward compatibility sets
  set onDeviceOnlineCallback(SocketCallback? callback) {
    _onlineListeners.clear();
    if (callback != null) _onlineListeners.add(callback);
  }

  set onDeviceOfflineCallback(SocketCallback? callback) {
    _offlineListeners.clear();
    if (callback != null) _offlineListeners.add(callback);
  }

  bool get isConnected => _socket?.connected ?? false;

  // ── Initialization ───────────────────────────────────────────────────

  void _ensureSocket() {
    if (_socket != null) return;

    print('🚀 [SOCKET] Initializing for: ${ApiConstants.baseUrl}');
    
    // Use OptionBuilder for more reliable configuration
    _socket = IO.io(ApiConstants.baseUrl, IO.OptionBuilder()
      .setTransports(['polling', 'websocket']) 
      .enableAutoConnect() 
      .enableReconnection()
      .setReconnectionAttempts(99999)
      .setReconnectionDelay(2000)
      .setReconnectionDelayMax(5000)
      .build()
    );

    _socket!.onConnect((_) {
      print('🟢🟢🟢 [SOCKET] CONNECTED: ${_socket!.id}');
      _rejoinRooms();
    });

    _socket!.onConnecting((_) => print('🟡 [SOCKET] Connecting...'));

    _socket!.onDisconnect((reason) {
      print('🔴🔴🔴 [SOCKET] DISCONNECTED: $reason');
    });

    _socket!.onConnectError((err) {
      print('❌ [SOCKET] CONNECTION ERROR: $err');
    });

    _socket!.onReconnect((_) => print('🔄🟢 [SOCKET] RECONNECTED'));
    _socket!.onReconnectAttempt((_) => print('🔄 [SOCKET] Reconnecting...'));

    // ── Event Handlers ────────────────────────────────────────────────
    
    _socket!.on('deviceOnline', (data) {
      print('📱 [SOCKET] RECEIVED deviceOnline: $data');
      final mapData = Map<String, dynamic>.from(data);
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

    // Sprint 4 Placeholders
    _socket!.on('timeLimitUpdated', (data) => print('⏰ [SOCKET] Time limit updated: $data'));
    _socket!.on('timeExtensionResponse', (data) => print('⏳ [SOCKET] Extension response: $data'));
  }

  void _rejoinRooms() {
    if (_userId != null) {
      print('👨‍👩‍👧 [SOCKET] Joining family room for user: $_userId, role: $_role');
      _socket?.emit('joinFamily', {
        'userId': _userId,
        'role': _role ?? 'parent',
      });
    }
    
    if (_deviceCode != null) {
      print('📱 [SOCKET] Joining device room for code: $_deviceCode');
      _socket?.emit('joinDevice', {
        'deviceCode': _deviceCode,
      });
    }
  }

  // ── Public API ───────────────────────────────────────────────────────

  /// Dùng cho Parent apps
  void connectAsParent(int userId) {
    print('👨‍👩‍👧 [SOCKET] connectAsParent: $userId');
    _userId = userId;
    _role = 'parent';
    _deviceCode = null;
    _ensureSocket();
    if (!_socket!.connected) {
      _socket!.connect();
    } else {
      _rejoinRooms();
    }
  }

  /// Dùng cho Child apps
  void connectAsChild(String deviceCode) {
    print('📱 [SOCKET] connectAsChild: $deviceCode');
    _deviceCode = deviceCode;
    _role = 'child';
    _userId = null;
    _ensureSocket();
    if (!_socket!.connected) {
      _socket!.connect();
    } else {
      _rejoinRooms();
    }
  }

  // Alias for backward compatibility
  void joinFamily(int userId) => connectAsParent(userId);
  void joinDevice(String deviceCode) => connectAsChild(deviceCode);

  /// Disconnect hoàn toàn (khi logout)
  void disconnect() {
    print('🔌 [SOCKET] Manual disconnect triggered');
    print('📍 StackTrace:\n${StackTrace.current}');
    _userId = null;
    _deviceCode = null;
    _role = null;
    _socket?.disconnect();
    _socket?.dispose(); // Proper clean up for socket_io_client
    _socket = null;
    _instance = null; // Reset singleton
  }
}
