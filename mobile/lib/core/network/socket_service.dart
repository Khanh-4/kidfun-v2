import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

typedef SocketCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;
  
  // Multiple listeners support
  final List<SocketCallback> _onlineListeners = [];
  final List<SocketCallback> _offlineListeners = [];

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

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

  // Backward compatibility for single callback (if needed, but better to migrate)
  set onDeviceOnlineCallback(SocketCallback? callback) {
    _onlineListeners.clear();
    if (callback != null) _onlineListeners.add(callback);
  }

  set onDeviceOfflineCallback(SocketCallback? callback) {
    _offlineListeners.clear();
    if (callback != null) _offlineListeners.add(callback);
  }

  IO.Socket get socket {
    if (_socket == null) {
      print('🚀 Creating Socket.IO instance for: ${ApiConstants.baseUrl}');
      _socket = IO.io(ApiConstants.baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 10,
        'reconnectionDelay': 3000,
      });

      _socket!.on('connect', (_) {
        print('🟢🟢🟢 SOCKET CONNECTED: ${_socket!.id}');
      });

      _socket!.on('connecting', (_) {
        print('🟡 Socket connecting...');
      });

      _socket!.on('disconnect', (_) {
        print('🔴🔴🔴 SOCKET DISCONNECTED');
      });

      _socket!.on('connect_error', (err) {
        print('❌❌❌ SOCKET ERROR: $err');
      });

      // Device events
      _socket!.on('deviceOnline', (data) {
        print('📱 Device online event received: $data');
        final mapData = Map<String, dynamic>.from(data);
        for (final listener in List.from(_onlineListeners)) {
          listener(mapData);
        }
      });

      _socket!.on('deviceOffline', (data) {
        print('📱 Device offline event received: $data');
        final mapData = Map<String, dynamic>.from(data);
        for (final listener in List.from(_offlineListeners)) {
          listener(mapData);
        }
      });

      // Events cho Sprint 4 (placeholder)
      _socket!.on('timeLimitUpdated', (data) {
        print('⏰ Time limit updated: $data');
      });

      _socket!.on('timeExtensionResponse', (data) {
        print('⏳ Time extension response: $data');
      });
    }
    return _socket!;
  }

  /// Parent: join family room sau khi login
  void joinFamily(int userId) {
    print('👨👩👧 CALLING joinFamily for user $userId');
    print('📡 Socket connected before emit: ${socket.connected}');
    socket.connect();
    print('📡 Socket connected after connect(): ${socket.connected}');
    socket.emit('joinFamily', {'userId': userId});
  }

  /// Child: join device room sau khi link
  void joinDevice(String deviceCode) {
    print('📱 CALLING joinDevice: $deviceCode');
    print('📡 Socket connected before emit: ${socket.connected}');
    socket.connect();
    print('📡 Socket connected after connect(): ${socket.connected}');
    socket.emit('joinDevice', {'deviceCode': deviceCode});
  }

  /// Kiểm tra kết nối
  bool get isConnected => _socket?.connected ?? false;

  /// Disconnect (khi logout)
  void disconnect() {
    print('🔌🔌🔌 SocketService.disconnect() CALLED');
    print('📍 StackTrace:\n${StackTrace.current}');
    
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
    _onlineListeners.clear();
    _offlineListeners.clear();
    
    // Reset instance so next call to .instance creates a fresh service
    _instance = null;
    print('🔌 Socket disconnected, cleared, and instance reset');
  }
}
