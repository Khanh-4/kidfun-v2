import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/storage/secure_storage.dart';

// Auth states
sealed class AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final _repo = AuthRepository();

  AuthNotifier() : super(AuthLoading()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      final hasToken = await _repo.isLoggedIn();
      if (hasToken) {
        // Tạm thời chỉ check xem có token không, vì user model chưa có endpoint fetch riêng `getMe()`
        // Tương lai có thể gọi getProfile hoặc getUserDetails để lấy thông tin.
        // Ở đây giả lập lấy UserModel rỗng
        // Để pass qua Authenticated, token sẽ được interceptor validate khi gọi API get profiles
        state = AuthAuthenticated(UserModel(id: 0, email: 'temp@mail.com', fullName: 'Đang tải...'));
      } else {
        state = AuthUnauthenticated();
      }
    } catch (_) {
      state = AuthUnauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.login(email, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.register(name, email, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    state = AuthLoading();
    await _repo.logout();
    state = AuthUnauthenticated();
  }
}
