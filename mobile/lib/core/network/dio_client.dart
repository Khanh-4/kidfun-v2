import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import '../network/auth_event_bus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Mutex: ngăn nhiều request đồng thời cùng thử refresh token
  static bool _isRefreshing = false;
  // Completer để các request đang chờ lấy token mới sau khi refresh xong
  static Completer<String>? _refreshCompleter;

  static Dio get instance {
    _dio.interceptors.clear();
    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    return _dio;
  }

  static Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('user_role');

        String? token;
        if (role == 'child') {
          token = prefs.getString('device_token');
        } else {
          token = await SecureStorage.getToken();
        }

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode != 401) {
          return handler.next(error);
        }

        // Không refresh cho chính request refresh-token (tránh đệ quy)
        final requestUrl = error.requestOptions.path;
        if (requestUrl.contains(ApiConstants.refreshToken)) {
          return handler.next(error);
        }

        // Nếu đang có refresh đang chạy → đợi kết quả của lần đó
        if (_isRefreshing) {
          try {
            final newToken = await _refreshCompleter!.future;
            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            return handler.resolve(await _dio.fetch(error.requestOptions));
          } catch (_) {
            return handler.next(error);
          }
        }

        // Bắt đầu refresh
        _isRefreshing = true;
        _refreshCompleter = Completer<String>();

        try {
          final refreshToken = await SecureStorage.getRefreshToken();
          if (refreshToken == null || refreshToken.isEmpty) {
            throw Exception('no_refresh_token');
          }

          final response = await Dio().post(
            '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
            data: {'refreshToken': refreshToken},
          );

          if (response.data['success'] != true) {
            throw Exception(response.data['code'] ?? 'refresh_failed');
          }

          final newToken = response.data['data']['token'] as String;
          final newRefreshToken = response.data['data']['refreshToken'] as String;
          await SecureStorage.saveToken(newToken);
          await SecureStorage.saveRefreshToken(newRefreshToken);

          _refreshCompleter!.complete(newToken);

          // Retry request gốc với token mới
          error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          return handler.resolve(await _dio.fetch(error.requestOptions));
        } catch (e) {
          // Refresh thất bại (token hết hạn, JWT_SECRET thay đổi, v.v.)
          // → xóa tokens và phát sự kiện logout để UI điều hướng về login
          _refreshCompleter!.completeError(e);
          await SecureStorage.clearAll();
          AuthEventBus.instance.forceLogout(e.toString());
          return handler.next(error);
        } finally {
          _isRefreshing = false;
          _refreshCompleter = null;
        }
      },
    );
  }
}
