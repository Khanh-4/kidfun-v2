import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/socket_service.dart';

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
        state = AuthAuthenticated(UserModel(id: 0, email: '', fullName: 'Đang tải...'));
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
      _sendFcmTokenIfAvailable();
      SocketService.instance.joinFamily(user.id);
    } catch (e) {
      state = AuthError((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.register(name, email, password);
      state = AuthAuthenticated(user);
      _sendFcmTokenIfAvailable();
      SocketService.instance.joinFamily(user.id);
    } catch (e) {
      state = AuthError((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    state = AuthLoading();
    await _repo.logout();
    SocketService.instance.disconnect();
    state = AuthUnauthenticated();
  }

  Future<void> _sendFcmTokenIfAvailable() async {
    final fcmToken = await SecureStorage.getFcmToken();
    if (fcmToken != null) {
      await _repo.registerFcmToken(fcmToken);
    }
  }
}

// ─── Forgot Password State ───────────────────────────────────────────────────

class ForgotPasswordState {
  final bool isOtpSent;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const ForgotPasswordState({
    this.isOtpSent = false,
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  ForgotPasswordState copyWith({
    bool? isOtpSent,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return ForgotPasswordState(
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

final forgotPasswordProvider =
    StateNotifierProvider.autoDispose<ForgotPasswordNotifier, ForgotPasswordState>(
  (ref) => ForgotPasswordNotifier(),
);

class ForgotPasswordNotifier extends StateNotifier<ForgotPasswordState> {
  final _repo = AuthRepository();

  ForgotPasswordNotifier() : super(const ForgotPasswordState());

  /// Bước 1: Gửi email → nhận OTP 6 số
  Future<void> sendOtp(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.forgotPassword(email);
      state = state.copyWith(isLoading: false, isOtpSent: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: (e as Exception).toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Bước 2: Xác nhận OTP + đặt mật khẩu mới
  Future<void> resetPassword(String email, String otp, String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.resetPasswordWithOtp(email, otp, newPassword);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: (e as Exception).toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void reset() => state = const ForgotPasswordState();
}
