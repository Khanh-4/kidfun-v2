import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/socket_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
        final userId = await SecureStorage.getUserId();
        final fullName = await SecureStorage.getFullName() ?? 'Phụ huynh';
        final email = await SecureStorage.getEmail() ?? '';
        state = AuthAuthenticated(
          UserModel(id: userId ?? 0, email: email, fullName: fullName),
        );
        // Reconnect socket for returning users
        if (userId != null && userId > 0) {
          SocketService.instance.joinFamily(userId);
          print('📡 Auto-login: called joinFamily for user $userId');
        }
      } else {
        state = AuthUnauthenticated();
      }
    } catch (e) {
      print('❌ [Auth] checkAuth error: $e');
      state = AuthUnauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.login(email, password);
      await SecureStorage.saveUserId(user.id);
      await SecureStorage.saveFullName(user.fullName);
      await SecureStorage.saveEmail(user.email);
      state = AuthAuthenticated(user);
      sendFcmTokenIfAvailable();
      SocketService.instance.joinFamily(user.id);
      print('📡 Login success: called joinFamily for user ${user.id}');
    } catch (e) {
      state = AuthError((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.register(name, email, password);
      await SecureStorage.saveUserId(user.id);
      await SecureStorage.saveFullName(user.fullName);
      await SecureStorage.saveEmail(user.email);
      state = AuthAuthenticated(user);
      sendFcmTokenIfAvailable();
      SocketService.instance.joinFamily(user.id);
      print('📡 Register success: called joinFamily for user ${user.id}');
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

  Future<void> sendFcmTokenIfAvailable() async {
    try {
      // FIX TEST 9: Request notification permissions first before getting token
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _repo.registerFcmToken(fcmToken);
        await SecureStorage.saveFcmToken(fcmToken);
      } else {
        // Fallback
        final storedToken = await SecureStorage.getFcmToken();
        if (storedToken != null) {
          await _repo.registerFcmToken(storedToken);
        }
      }
    } catch (e) {
      print('❌ [FCM] check/send token error: $e');
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
