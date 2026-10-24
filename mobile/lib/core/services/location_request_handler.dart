import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../../features/location/data/location_repository.dart';

/// Máy trẻ nhận lệnh FCM data-only `location_request` (phụ huynh bấm "Yêu cầu
/// cập nhật vị trí ngay") → lấy GPS 1 lần và gửi lên POST /api/child/location.
/// Thay cho event Socket.IO 'locationRequested' đã chết từ khi lên Vercel.
///
/// Gọi được từ cả isolate chính (app đang mở) lẫn isolate nền của
/// onBackgroundMessage — nên không dùng DioClient (cần token/interceptor của
/// isolate chính); endpoint /api/child/location không cần xác thực.
Future<void> respondToLocationRequest() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final deviceCode = prefs.getString('device_code');
    if (deviceCode == null) return; // Không phải máy trẻ đã liên kết

    if (!await Geolocator.isLocationServiceEnabled()) {
      print('📍 [LOCATION REQUEST] GPS đang tắt — bỏ qua');
      return;
    }
    // Không requestPermission: có thể đang chạy nền, không hiện được hộp thoại.
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('📍 [LOCATION REQUEST] Chưa cấp quyền vị trí — bỏ qua');
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    await LocationRepository(dio).syncLocation(
      deviceCode: deviceCode,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
    print('✅ [LOCATION REQUEST] Đã gửi vị trí theo yêu cầu phụ huynh');
  } catch (e) {
    print('❌ [LOCATION REQUEST] Không gửi được vị trí: $e');
  }
}
