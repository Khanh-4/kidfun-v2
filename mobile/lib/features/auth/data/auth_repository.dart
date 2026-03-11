import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';

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
      await _dio.post(ApiConstants.logout);
    } catch (e) {
      // Ignore errors when logging out
    } finally {
      await SecureStorage.clearAll();
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await SecureStorage.getToken();
    return token != null;
  }
}
