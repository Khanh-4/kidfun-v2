import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;
  
  // Callbacks
  Function(Map<String, dynamic>)? onDeviceOnlineCallback;
  Function(Map<String, dynamic>)? onDeviceOfflineCallback;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

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
        onDeviceOnlineCallback?.call(Map<String, dynamic>.from(data));
      });

      _socket!.on('deviceOffline', (data) {
        print('📱 Device offline event received: $data');
        onDeviceOfflineCallback?.call(Map<String, dynamic>.from(data));
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
    print('🔌 Manually calling disconnect()');
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
    print('🔌 Socket disconnected and destroyed');
  }
}
