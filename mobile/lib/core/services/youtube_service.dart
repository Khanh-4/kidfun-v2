import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import 'native_service.dart';

/// YouTubeService — Batch upload YouTube logs + sync blocked videos.
/// Khởi động khi Child Dashboard init, dừng khi dispose.
class YouTubeService {
  static final YouTubeService instance = YouTubeService._();
  YouTubeService._();

  final _dio = DioClient.instance;
  Timer? _uploadTimer;
  Timer? _syncTimer;

  /// Bắt đầu periodic upload (5 phút) + sync blocked videos (2 phút)
  void start(String deviceCode) {
    stop(); // cancel timers cũ nếu có

    // Sync blocked videos ngay khi start
    _syncBlockedVideos(deviceCode);

    // Upload pending logs mỗi 5 phút
    _uploadTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _uploadPending(deviceCode);
    });

    // Sync blocked videos mỗi 2 phút
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
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
    try {
      final pending = await NativeService.getPendingYouTubeLogs();
      if (pending.isEmpty) return;

      await _dio.post('/api/child/youtube-logs', data: {
        'deviceCode': deviceCode,
        'logs': pending,
      });

      await NativeService.clearPendingYouTubeLogs();
      debugPrint('✅ [YOUTUBE] Uploaded ${pending.length} logs');
    } catch (e) {
      debugPrint('❌ [YOUTUBE] Upload error: $e');
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

  /// Force upload ngay lập tức — gọi trước khi app dispose
  Future<void> flushPending(String deviceCode) async {
    await _uploadPending(deviceCode);
  }
}
