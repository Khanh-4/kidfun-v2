import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import 'native_service.dart';

/// YouTubeService — Batch upload YouTube logs + sync blocked videos.
/// Khởi động khi Child Dashboard init, dừng khi dispose.
///
/// Log chỉ sinh ra khi trẻ rời YouTube / chuyển video, và nằm trong RAM của
/// tiến trình native — nên kiểm tra mỗi phút (rẻ: chỉ gọi HTTP khi có log) và
/// đẩy ngay khi app trẻ quay lại foreground, thay vì chờ 5 phút như trước.
class YouTubeService {
  static const _uploadInterval = Duration(minutes: 1);
  static const _syncInterval = Duration(minutes: 2);

  static final YouTubeService instance = YouTubeService._();
  YouTubeService._();

  final _dio = DioClient.instance;
  Timer? _uploadTimer;
  Timer? _syncTimer;
  bool _isUploading = false;

  /// Bắt đầu periodic upload (1 phút) + sync blocked videos (2 phút)
  void start(String deviceCode) {
    stop(); // cancel timers cũ nếu có

    // Sync blocked videos ngay khi start
    _syncBlockedVideos(deviceCode);

    _uploadTimer = Timer.periodic(_uploadInterval, (_) {
      _uploadPending(deviceCode);
    });

    _syncTimer = Timer.periodic(_syncInterval, (_) {
      _syncBlockedVideos(deviceCode);
    });
  }

  void stop() {
    _uploadTimer?.cancel();
    _syncTimer?.cancel();
    _uploadTimer = null;
    _syncTimer = null;
  }

  Future<void> _uploadPending(String deviceCode) async {
    // Timer và sự kiện resume có thể trùng nhau — không gửi một lô hai lần.
    if (_isUploading) return;
    _isUploading = true;
    try {
      final pending = await NativeService.getPendingYouTubeLogs();
      if (pending.isEmpty) return;

      await _dio.post('/api/child/youtube-logs', data: {
        'deviceCode': deviceCode,
        'logs': pending,
      });

      await NativeService.clearPendingYouTubeLogs(count: pending.length);
      debugPrint('✅ [YOUTUBE] Uploaded ${pending.length} logs');
    } catch (e) {
      debugPrint('❌ [YOUTUBE] Upload error: $e');
    } finally {
      _isUploading = false;
    }
  }

  Future<void> _syncBlockedVideos(String deviceCode) async {
    try {
      final response = await _dio.get(
        '/api/child/blocked-videos',
        queryParameters: {'deviceCode': deviceCode},
      );
      final blocked = List<Map<String, dynamic>>.from(
        response.data['data']['blockedVideos'] ?? [],
      );
      await NativeService.setBlockedVideos(blocked);
      debugPrint('✅ [YOUTUBE] Synced ${blocked.length} blocked videos');
    } catch (e) {
      debugPrint('❌ [YOUTUBE] Sync blocked error: $e');
    }
  }

  /// Force sync blocked videos — gọi khi nhận Socket.IO event blockedVideosUpdated
  void forceSyncBlocked(String deviceCode) {
    _syncBlockedVideos(deviceCode);
  }

  /// Force upload ngay lập tức — gọi khi app trẻ quay lại foreground
  Future<void> flushPending(String deviceCode) async {
    await _uploadPending(deviceCode);
  }
}
