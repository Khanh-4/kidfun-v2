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

        // Vai trò child KHÔNG có phiên đăng nhập kiểu parent: nó xác thực
        // bằng device_token / X-Device-Code và không bao giờ có refresh
        // token. 401 ở đây chỉ nghĩa là "endpoint này của parent, child
        // không có quyền" — KHÔNG phải phiên hết hạn. Chạy tiếp luồng
        // refresh bên dưới sẽ luôn ném no_refresh_token → clearAll() +
        // forceLogout(), lặp lại mỗi lần có request 401 (log thực tế:
        // 230 lần liên tiếp ở vai trò child trước khi liên kết thiết bị).
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('user_role') == 'child') {
          return handler.next(error);
        }

        // Không refresh cho chính request refresh-token (tránh đệ quy).
        // Cũng bỏ qua các request dọn dẹp lúc logout (fcmUnregister, logout)
        // — nếu token đã hỏng thì các request này 401 là chuyện bình thường
        // (AuthRepository.logout() đã tự try/catch, không quan tâm kết quả).
        // Không loại trừ sẽ tạo vòng lặp vô hạn: logout() gọi 2 request này
        // → 401 → forceLogout() → AuthNotifier.logout() gọi lại → lặp lại mỗi
        // ~0.3-0.4s (khớp log thực tế "Force logout triggered" lặp 230 lần).
        final requestUrl = error.requestOptions.path;
        if (requestUrl.contains(ApiConstants.refreshToken) ||
            requestUrl.contains(ApiConstants.logout) ||
            requestUrl.contains(ApiConstants.fcmUnregister)) {
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

        // Chưa từng đăng nhập (không có cả access token lẫn refresh token):
        // 401 là chuyện đương nhiên, không phải phiên hết hạn. Không được
        // clearAll() + forceLogout() ở đây — làm vậy vừa vô nghĩa, vừa có
        // nguy cơ xoá mất token vừa lưu nếu một request 401 cũ về muộn
        // ngay sau khi đăng nhập xong (khớp lỗi "văng ra ngoài" khi đổi
        // vai trò rồi đăng nhập lại bằng Google).
        final existingToken = await SecureStorage.getToken();
        final existingRefreshToken = await SecureStorage.getRefreshToken();
        final hasSession = (existingToken != null && existingToken.isNotEmpty) ||
            (existingRefreshToken != null && existingRefreshToken.isNotEmpty);
        if (!hasSession) {
          return handler.next(error);
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
