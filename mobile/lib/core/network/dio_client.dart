import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class DioClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  static Dio get instance {
    _dio.interceptors.clear();
    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    return _dio;
  }

  static Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Tự động attach JWT token
        final token = await SecureStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Nếu 401 → thử refresh token
        if (error.response?.statusCode == 401) {
          try {
            final refreshToken = await SecureStorage.getRefreshToken();
            if (refreshToken != null) {
              final response = await Dio().post(
                '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
                data: {'refreshToken': refreshToken},
              );
              if (response.data['success'] == true) {
                // Lưu token mới
                await SecureStorage.saveToken(response.data['data']['token']);
                await SecureStorage.saveRefreshToken(response.data['data']['refreshToken']);
                // Retry request gốc
                error.requestOptions.headers['Authorization'] =
                    'Bearer ${response.data['data']['token']}';
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              }
            }
          } catch (_) {}
        }
        handler.next(error);
      },
    );
  }
}
