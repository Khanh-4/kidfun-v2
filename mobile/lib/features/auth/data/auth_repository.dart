import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final _dio = DioClient.instance;

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      final data = response.data['data'];
      await SecureStorage.saveToken(data['token']);
      await SecureStorage.saveRefreshToken(data['refreshToken']);
      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi đăng nhập: $e');
    }
  }

  Future<UserModel> register(String fullName, String email, String password) async {
    try {
      final response = await _dio.post(ApiConstants.register, data: {
        'fullName': fullName,
        'email': email,
        'password': password,
      });
      final data = response.data['data'];
      await SecureStorage.saveToken(data['token']);
      await SecureStorage.saveRefreshToken(data['refreshToken']);
      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi đăng ký: $e');
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile', 'openid'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('User canceled login');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Không lấy được xác thực từ Google');
      }

      final response = await _dio.post(ApiConstants.loginGoogle, data: {
        'idToken': idToken,
      });

      final data = response.data['data'];
      await SecureStorage.saveToken(data['token']);
      await SecureStorage.saveRefreshToken(data['refreshToken']);

      final user = UserModel.fromJson(data['user']);
      final isNewUser = data['isNewUser'] ?? false;
      final missingPhoneNumber = data['missingPhoneNumber'] ?? false;

      return {
        'user': user,
        'isNewUser': isNewUser,
        'missingPhoneNumber': missingPhoneNumber,
      };
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối Server. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Đăng nhập Google thất bại: $e');
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(ApiConstants.forgotPassword, data: {'email': email});
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi yêu cầu quên mật khẩu: $e');
    }
  }

  Future<void> logout() async {
    try {
      // Unregister FCM token trước khi logout
      final fcmToken = await SecureStorage.getFcmToken();
      if (fcmToken != null) {
        await _dio.post(ApiConstants.fcmUnregister, data: {'token': fcmToken});
      }
      await _dio.post(ApiConstants.logout);
    } catch (e) {
      // Ignore errors when logging out
    } finally {
      await SecureStorage.clearAll();
    }
  }

  /// Đăng ký FCM token lên server sau khi đăng nhập/đăng ký thành công
  Future<void> registerFcmToken(String fcmToken) async {
    try {
      await _dio.post(ApiConstants.fcmRegister, data: {'token': fcmToken});
      await SecureStorage.saveFcmToken(fcmToken);
    } catch (_) {
      // Không throw — lỗi FCM không ảnh hưởng luồng chính
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await SecureStorage.getToken();
    return token != null;
  }

  /// Đặt lại mật khẩu bằng OTP 6 số đã nhận qua email
  Future<void> resetPasswordWithOtp(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.resetPasswordOtp,
        data: {
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        },
      );
      // Throw nếu server trả success: false
      if (response.data['success'] == false) {
        throw Exception(response.data['message'] ?? 'Đặt lại mật khẩu thất bại');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Lỗi đặt lại mật khẩu: $e');
    }
  }
}
