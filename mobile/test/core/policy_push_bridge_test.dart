import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/policy_push_bridge.dart';

void main() {
  tearDown(PolicyPushBridge.resetForTest);

  test('kết quả xin thêm giờ đi qua isolate chính (nơi có màn hình trẻ)', () {
    // Lỗi test 10/11: duyệt/từ chối lúc app trẻ chạy nền phải tới được
    // child_dashboard_screen để hiện kết quả và gỡ khoá.
    expect(PolicyPushBridge.nativeTypes, contains('extension_response'));
  });

  test('không có isolate chính → trả false ngay', () async {
    final ok = await PolicyPushBridge.forwardToMainIsolate({'type': 'policy_update'});
    expect(ok, isFalse);
  });

  test('isolate chính nhận đúng dữ liệu push và báo nhận', () async {
    final received = Completer<Map<String, String>>();
    PolicyPushBridge.registerMainIsolate((data) async => received.complete(data));

    final ok = await PolicyPushBridge.forwardToMainIsolate({
      'type': 'blocked_apps_update',
      'packageNames': '["com.android.chrome"]',
    });

    expect(ok, isTrue);
    expect(await received.future, {
      'type': 'blocked_apps_update',
      'packageNames': '["com.android.chrome"]',
    });
  });

  test('push từ isolate khác (giống isolate nền FCM) vẫn tới isolate chính', () async {
    final received = Completer<Map<String, String>>();
    PolicyPushBridge.registerMainIsolate((data) async => received.complete(data));

    final ok = await Isolate.run(
      () => PolicyPushBridge.forwardToMainIsolate({'type': 'policy_update'}),
    );

    expect(ok, isTrue);
    expect((await received.future)['type'], 'policy_update');
  });

  test('cổng mồ côi (isolate chính đã chết) → false và xoá tên cổng', () async {
    final dead = ReceivePort()..close();
    IsolateNameServer.registerPortWithName(dead.sendPort, PolicyPushBridge.portName);

    final ok = await PolicyPushBridge.forwardToMainIsolate(
      {'type': 'policy_update'},
      ackTimeout: const Duration(milliseconds: 200),
    );

    expect(ok, isFalse);
    expect(IsolateNameServer.lookupPortByName(PolicyPushBridge.portName), isNull);
  });

  test('đăng ký lại thay cổng cũ — chỉ handler mới nhận push', () async {
    var oldCalls = 0;
    final received = Completer<void>();
    PolicyPushBridge.registerMainIsolate((_) async => oldCalls++);
    PolicyPushBridge.registerMainIsolate((_) async => received.complete());

    expect(await PolicyPushBridge.forwardToMainIsolate({'type': 'policy_update'}), isTrue);
    await received.future;
    expect(oldCalls, 0);
  });
}
