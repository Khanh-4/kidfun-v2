import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

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
      const clientId = '130046544171-q4pllsneq42l2cbgc577mah6c6hvjgto.apps.googleusercontent.com';
      final redirectUri = '${ApiConstants.baseUrl}/api/auth/google/callback';

      // Tạo URL đăng nhập Google
      final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      // Mở trình duyệt để đăng nhập, backend sẽ redirect về app qua custom scheme
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: 'com.kidfun.mobile',
      );

      // Parse kết quả từ redirect URL
      final uri = Uri.parse(result);
      final params = uri.queryParameters;

      // Kiểm tra lỗi
      if (params.containsKey('error')) {
        throw Exception('Đăng nhập Google thất bại: ${params['error']}');
      }

      final token = params['token'];
      final refreshToken = params['refreshToken'];

      if (token == null || refreshToken == null) {
        throw Exception('Không nhận được token từ server');
      }

      // Lưu token
      await SecureStorage.saveToken(token);
      await SecureStorage.saveRefreshToken(refreshToken);

      final user = UserModel(
        id: int.tryParse(params['userId'] ?? '0') ?? 0,
        email: params['email'] ?? '',
        fullName: params['fullName'] ?? '',
      );

      final missingPhoneNumber = params['missingPhoneNumber'] == 'true';

      return {
        'user': user,
        'missingPhoneNumber': missingPhoneNumber,
      };
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Lỗi đăng nhập Google: $e');
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
