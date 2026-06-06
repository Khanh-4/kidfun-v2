import 'dart:async';

/// Cầu nối giữa DioClient (static, không có Riverpod ref) và AuthNotifier.
/// DioClient gọi [forceLogout] khi refresh token thất bại.
/// AuthNotifier subscribe [onForceLogout] để tự động logout và điều hướng về login.
class AuthEventBus {
  AuthEventBus._();
  static final AuthEventBus instance = AuthEventBus._();

  final _controller = StreamController<String>.broadcast();

  /// Stream mà AuthNotifier lắng nghe.
  Stream<String> get onForceLogout => _controller.stream;

  /// DioClient gọi hàm này khi refresh token trả 401 hoặc bất kỳ lỗi nào
  /// khiến không thể làm mới phiên đăng nhập.
  void forceLogout(String reason) {
    if (!_controller.isClosed) {
      _controller.add(reason);
    }
  }

  void dispose() => _controller.close();
}
