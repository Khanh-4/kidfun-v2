import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chặn tái phát lỗi test 05/11: PR #333 chèn hàm khác vào giữa
/// `@pragma('vm:entry-point')` và handler FCM nền → isolate nền không tìm
/// thấy handler, mọi push (blocked_apps_update, policy_update,
/// location_request) khi app chạy nền đều văng NoSuchMethodError.
void main() {
  test('handler FCM nền có @pragma(vm:entry-point) ngay phía trên', () {
    final lines = File('lib/main.dart').readAsLinesSync();
    final idx = lines.indexWhere(
      (l) => l.contains('Future<void> _firebaseMessagingBackgroundHandler('),
    );

    expect(idx, greaterThan(0), reason: 'không tìm thấy handler trong main.dart');
    expect(lines[idx - 1].trim(), "@pragma('vm:entry-point')");
  });
}
