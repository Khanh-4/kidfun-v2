import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Chuyển push chặn app / lọc web từ isolate nền của FCM sang isolate chính.
///
/// Vì sao cần (lỗi test 10/11): push tới lúc app chạy nền được xử lý trên một
/// FlutterEngine riêng của firebase_messaging. Kênh `com.kidfun.native` chỉ
/// được đăng ký trên engine của MainActivity, nên mọi lệnh native trong isolate
/// nền văng `MissingPluginException` → danh sách chặn chỉ tới máy khi trẻ mở
/// lại app hoặc tới lượt đồng bộ 5 phút. Hai engine chạy chung một process và
/// chung Dart VM, nên isolate nền gửi được message qua [IsolateNameServer] cho
/// isolate chính — nơi gọi native được.
class PolicyPushBridge {
  PolicyPushBridge._();

  static const portName = 'kidfun_policy_push_main_isolate';

  /// Loại push cần gọi native, chỉ isolate chính xử lý được.
  static const nativeTypes = {'blocked_apps_update', 'policy_update'};

  /// Isolate nền chờ isolate chính báo đã nhận trong khoảng này. Quá hạn nghĩa
  /// là cổng cũ của một isolate chính đã chết (vd. trẻ vuốt tắt app).
  static const defaultAckTimeout = Duration(seconds: 3);

  static ReceivePort? _port;

  /// Gọi trong isolate chính (main()). Đăng ký lại mỗi lần app khởi động để
  /// thay cổng cũ còn sót trong VM.
  static void registerMainIsolate(
    Future<void> Function(Map<String, String> data) onPush,
  ) {
    _port?.close();
    IsolateNameServer.removePortNameMapping(portName);

    final port = ReceivePort();
    _port = port;
    IsolateNameServer.registerPortWithName(port.sendPort, portName);

    port.listen((msg) {
      if (msg is! List || msg.length != 2) return;
      final data = Map<String, String>.from(msg[0] as Map);
      final reply = msg[1] as SendPort;
      // Báo nhận ngay, không đợi gọi API/native xong (có thể mất vài giây).
      reply.send(true);
      onPush(data).catchError((Object e) {
        debugPrint('[FCM] ❌ Main isolate failed to apply ${data['type']}: $e');
      });
    });
  }

  /// Gọi trong isolate nền. Trả `true` nếu isolate chính đã nhận push;
  /// `false` nếu không có isolate chính (process mới bị đánh thức chỉ để nhận
  /// push) — khi đó app tự lấy lại chính sách lúc mở / mỗi 5 phút.
  static Future<bool> forwardToMainIsolate(
    Map<String, String> data, {
    Duration ackTimeout = defaultAckTimeout,
  }) async {
    final mainPort = IsolateNameServer.lookupPortByName(portName);
    if (mainPort == null) return false;

    final ack = ReceivePort();
    try {
      mainPort.send([data, ack.sendPort]);
      await ack.first.timeout(ackTimeout);
      return true;
    } on TimeoutException {
      // Cổng mồ côi: isolate chính đã chết nhưng tên vẫn còn trong VM.
      IsolateNameServer.removePortNameMapping(portName);
      return false;
    } finally {
      ack.close();
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _port?.close();
    _port = null;
    IsolateNameServer.removePortNameMapping(portName);
  }
}
