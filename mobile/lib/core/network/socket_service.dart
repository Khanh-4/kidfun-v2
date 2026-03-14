import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

typedef SocketCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;

  // Connection credentials — kept for auto-rejoin on reconnect
  int? _userId;
  String? _deviceCode;
  bool _intentionalDisconnect = false;

  // Multiple listeners support
  final List<SocketCallback> _onlineListeners = [];
  final List<SocketCallback> _offlineListeners = [];

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

  // ── Listener management ──────────────────────────────────────────────

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

  bool get isConnected => _socket?.connected ?? false;

  // ── Internal: create socket & wire up all listeners ──────────────────

  void _ensureSocket() {
    if (_socket != null) return;

    print('🚀 Creating NEW Socket.IO instance for: ${ApiConstants.baseUrl}');

    _socket = IO.io(ApiConstants.baseUrl, <String, dynamic>{
      'transports': ['polling', 'websocket'], // polling first — safer on Railway
      'autoConnect': false,
      'forceNew': true,
      'reconnection': true,
      'reconnectionAttempts': 999999, // keep trying
      'reconnectionDelay': 2000,
      'reconnectionDelayMax': 10000,
    });

    _socket!.onConnect((_) {
      print('🟢🟢🟢 SOCKET CONNECTED: ${_socket!.id}');
      // Re-join rooms every time we (re)connect
      _rejoinRooms();
    });

    _socket!.onDisconnect((reason) {
      print('🔴🔴🔴 SOCKET DISCONNECTED: $reason');
      if (!_intentionalDisconnect) {
        print('🔄 Unexpected disconnect — socket_io_client will auto-reconnect');
      }
    });

    _socket!.onConnectError((err) {
      print('❌ SOCKET CONNECT ERROR: $err');
    });

    _socket!.onReconnect((_) {
      print('🔄🟢 SOCKET RECONNECTED');
    });

    _socket!.onReconnectAttempt((_) {
      print('🔄 Socket reconnection attempt...');
    });

    // ── Device events ──────────────────────────────────────────────────
    _socket!.on('deviceOnline', (data) {
      print('📱 deviceOnline event: $data');
      final mapData = Map<String, dynamic>.from(data);
      for (final listener in List.from(_onlineListeners)) {
        listener(mapData);
      }
    });

    _socket!.on('deviceOffline', (data) {
      print('📱 deviceOffline event: $data');
      final mapData = Map<String, dynamic>.from(data);
      for (final listener in List.from(_offlineListeners)) {
        listener(mapData);
      }
    });

    // Sprint 4 placeholders
    _socket!.on('timeLimitUpdated', (data) {
      print('⏰ Time limit updated: $data');
    });

    _socket!.on('timeExtensionResponse', (data) {
      print('⏳ Time extension response: $data');
    });
  }

  /// Emit joinFamily / joinDevice after every (re)connect
  void _rejoinRooms() {
    if (_userId != null) {
      print('👨‍👩‍👧 Emitting joinFamily for user $_userId');
      _socket?.emit('joinFamily', {'userId': _userId});
    }
    if (_deviceCode != null) {
      print('📱 Emitting joinDevice for $_deviceCode');
      _socket?.emit('joinDevice', {'deviceCode': _deviceCode});
    }
  }

  // ── Public API ───────────────────────────────────────────────────────

  /// Parent: connect and join family room. Stays connected until [disconnect].
  void connectAsParent(int userId) {
    print('👨‍👩‍👧 connectAsParent userId=$userId');
    _userId = userId;
    _deviceCode = null;
    _intentionalDisconnect = false;
    _ensureSocket();
    if (!_socket!.connected) {
      _socket!.connect();
    } else {
      // Already connected — just (re)join room
      _rejoinRooms();
    }
  }

  /// Child: connect and join device room. Stays connected until [disconnect].
  void connectAsChild(String deviceCode) {
    print('📱 connectAsChild deviceCode=$deviceCode');
    _deviceCode = deviceCode;
    _userId = null;
    _intentionalDisconnect = false;
    _ensureSocket();
    if (!_socket!.connected) {
      _socket!.connect();
    } else {
      _rejoinRooms();
    }
  }

  /// Backward-compat aliases
  void joinFamily(int userId) => connectAsParent(userId);
  void joinDevice(String deviceCode) => connectAsChild(deviceCode);

  /// Disconnect — call ONLY on logout.
  void disconnect() {
    print('🔌 INTENTIONAL disconnect (logout)');
    print('📍 StackTrace:\n${StackTrace.current}');
    _intentionalDisconnect = true;
    _userId = null;
    _deviceCode = null;
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
    _onlineListeners.clear();
    _offlineListeners.clear();
  }
}
