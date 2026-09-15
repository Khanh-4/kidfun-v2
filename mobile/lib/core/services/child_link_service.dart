import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';
import '../network/realtime_service.dart';
import '../network/socket_service.dart';
import 'location_service.dart';
import 'native_service.dart';
import 'youtube_service.dart';

/// Xử lý việc thiết bị trẻ bị phụ huynh gỡ liên kết ("Xoá thiết bị" ở app
/// parent). Server xoá hẳn dòng Device (kèm cascade các bảng con), nên phía trẻ
/// KHÔNG có "lệnh xoá" nào được gửi tới — trước đây app trẻ cứ thế chạy tiếp
/// với deviceCode đã chết, gọi API 404 liên tục mà không bao giờ quay về màn
/// hình quét mã.
///
/// Cách phát hiện, xếp theo thứ tự nhanh → chắc chắn:
///   1. Signal Realtime `Device` DELETE (gần như tức thì).
///   2. Mỗi lần app trẻ được resume.
///   3. Heartbeat 60s và các API child khác trả 404 INVALID_DEVICE_CODE.
/// Cả 3 đường đều gọi [isDeviceStillLinked] để XÁC MINH lại bằng REST trước khi
/// xoá dữ liệu, vì payload DELETE của Postgres Changes chỉ mang primary key
/// (không đủ để biết có phải thiết bị của mình không) và vì không được phép xoá
/// dữ liệu chỉ vì một lần rớt mạng.
class ChildLinkService {
  ChildLinkService._();

  /// Hỏi server xem deviceCode này còn tồn tại không.
  ///
  /// Chỉ trả `false` khi server khẳng định thiết bị không còn (404
  /// INVALID_DEVICE_CODE). Mọi lỗi khác — mất mạng, timeout, 5xx, hoặc 400
  /// DEVICE_NOT_ASSIGNED (thiết bị còn nhưng chưa gán hồ sơ) — đều trả `true`
  /// để tuyệt đối không xoá nhầm một liên kết đang hợp lệ.
  static Future<bool> isDeviceStillLinked(String deviceCode) async {
    try {
      await DioClient.instance.get(
        '/api/child/status',
        options: Options(headers: {'X-Device-Code': deviceCode}),
      );
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map ? data['code'] : null;
      if (e.response?.statusCode == 404 && code == 'INVALID_DEVICE_CODE') {
        print('🔗 [LINK] Server báo deviceCode không còn tồn tại — đã bị phụ huynh xoá');
        return false;
      }
      print('🔗 [LINK] Chưa xác minh được liên kết '
          '(${e.response?.statusCode ?? e.type}) — coi như vẫn còn');
      return true;
    } catch (e) {
      print('🔗 [LINK] Lỗi không rõ khi xác minh liên kết: $e — coi như vẫn còn');
      return true;
    }
  }

  /// Trả lời ping của server: "tôi còn sống".
  ///
  /// Gọi `POST /api/child/ping` — endpoint tối giản chỉ ghi `lastSeen`. KHÔNG
  /// dùng `/api/child/status` cho việc này: endpoint đó kéo theo calcRemaining
  /// và đo thật mất 13-14 giây, tức câu trả lời về tới nơi thì server đã hết
  /// thời gian chờ và báo máy trẻ mất kết nối.
  ///
  /// Trả `false` khi server khẳng định thiết bị không còn (404) — app trẻ dùng
  /// đó để tự gỡ liên kết ngay, khỏi chờ heartbeat.
  static Future<bool> respondToPing(String deviceCode) async {
    try {
      await DioClient.instance.post(
        '/api/child/ping',
        options: Options(headers: {'X-Device-Code': deviceCode}),
      );
      print('📡 [PING] Đã điểm danh với server');
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map ? data['code'] : null;
      if (e.response?.statusCode == 404 && code == 'INVALID_DEVICE_CODE') {
        print('📡 [PING] Server báo thiết bị không còn — đã bị phụ huynh xoá');
        return false;
      }
      print('📡 [PING] Điểm danh thất bại (${e.response?.statusCode ?? e.type})');
      return true; // mất mạng không phải bằng chứng bị gỡ
    } catch (e) {
      print('📡 [PING] Lỗi không rõ khi điểm danh: $e');
      return true;
    }
  }

  /// Đưa thiết bị trẻ về đúng trạng thái "chưa liên kết": dừng mọi thứ đang
  /// chạy nền và xoá sạch dấu vết liên kết dưới máy.
  ///
  /// KHÔNG đụng tới `user_role` — trẻ vẫn là vai trò child, chỉ là chưa liên
  /// kết, nên router sẽ đưa về màn quét mã (/devices/scan) chứ không phải màn
  /// chọn vai trò. Việc đổi state Riverpod (`roleProvider.setLinked(false)`) do
  /// phía UI gọi, vì service này không giữ `ref`.
  static Future<void> clearLocalLink() async {
    print('🔗 [LINK] Gỡ liên kết cục bộ: dừng dịch vụ nền + xoá dữ liệu liên kết');

    // 1. Dừng mọi thứ đang giám sát / khoá máy. Từng lời gọi tự nuốt lỗi để một
    //    platform channel hỏng không chặn các bước dọn dẹp còn lại.
    YouTubeService.instance.stop();
    LocationService.instance.stop();
    await NativeService.cancelScheduledLock()
        .catchError((e) => print('🔗 [LINK] cancelScheduledLock lỗi (bỏ qua): $e'));
    await NativeService.exitLockedState()
        .catchError((e) => print('🔗 [LINK] exitLockedState lỗi (bỏ qua): $e'));
    await NativeService.setBlockedApps(const [])
        .catchError((e) => print('🔗 [LINK] setBlockedApps lỗi (bỏ qua): $e'));
    await NativeService.setBlockedDomains(const [])
        .catchError((e) => print('🔗 [LINK] setBlockedDomains lỗi (bỏ qua): $e'));
    await NativeService.stopForegroundService()
        .catchError((e) => print('🔗 [LINK] stopForegroundService lỗi (bỏ qua): $e'));

    // 2. Ngắt kênh realtime — token realtime của child gắn với deviceId vừa bị
    //    xoá nên giữ lại cũng vô nghĩa.
    await RealtimeService.instance.disconnect();
    SocketService.instance.disconnect();

    // 3. Xoá dữ liệu liên kết dưới máy. Xoá cả key mốc hết giờ theo deviceCode
    //    (`end_time_epoch_ms_<deviceCode>`) — nếu để lại, lần liên kết sau trên
    //    cùng thiết bị sẽ khôi phục nhầm mốc hết giờ của lần liên kết cũ.
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('end_time_epoch_ms_')) {
        await prefs.remove(key);
      }
    }
    await prefs.remove('device_code');
    await prefs.remove('device_token');
    await prefs.setBool('is_linked', false);

    print('🔗 [LINK] Đã gỡ liên kết cục bộ xong');
  }
}
