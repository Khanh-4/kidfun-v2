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
      _socket = IO.io(ApiConstants.baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _socket!.on('connect', (_) {
        print('🟢 Socket connected: ${_socket!.id}');
      });

      _socket!.on('disconnect', (_) {
        print('🔴 Socket disconnected');
      });

      _socket!.on('connect_error', (err) {
        print('❌ Socket error: $err');
      });

      // Device events
      _socket!.on('deviceOnline', (data) {
        print('📱 Device online: $data');
        onDeviceOnlineCallback?.call(Map<String, dynamic>.from(data));
      });

      _socket!.on('deviceOffline', (data) {
        print('📱 Device offline: $data');
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
    socket.connect();
    socket.emit('joinFamily', {'userId': userId});
    print('👨👩👧 Joined family room for user $userId');
  }

  /// Child: join device room sau khi link
  void joinDevice(String deviceCode) {
    socket.connect();
    socket.emit('joinDevice', {'deviceCode': deviceCode});
    print('📱 Joined device room: $deviceCode');
  }

  /// Kiểm tra kết nối
  bool get isConnected => _socket?.connected ?? false;

  /// Disconnect (khi logout)
  void disconnect() {
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
    print('🔌 Socket disconnected and destroyed');
  }
}
