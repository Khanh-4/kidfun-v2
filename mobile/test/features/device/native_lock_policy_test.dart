import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/device/data/native_lock_policy.dart';

void main() {
  group('shouldReleaseNativeLock', () {
    test('gỡ cờ native khi máy đang khoá ngầm mà server báo còn giờ (sáng hôm sau)', () {
      expect(
        shouldReleaseNativeLock(
          nativeLocked: true,
          timeUpShowing: false,
          limitEnabled: true,
          remainingSeconds: 23700,
        ),
        isTrue,
      );
    });

    test('gỡ cờ khi phụ huynh tắt giới hạn dù remaining = 0', () {
      expect(
        shouldReleaseNativeLock(
          nativeLocked: true,
          timeUpShowing: false,
          limitEnabled: false,
          remainingSeconds: 0,
        ),
        isTrue,
      );
    });

    test('không gỡ khi đã hết giờ thật', () {
      expect(
        shouldReleaseNativeLock(
          nativeLocked: true,
          timeUpShowing: false,
          limitEnabled: true,
          remainingSeconds: 0,
        ),
        isFalse,
      );
    });

    test('không đụng khi màn hình khoá Flutter đang hiện — luồng đó tự gỡ', () {
      expect(
        shouldReleaseNativeLock(
          nativeLocked: true,
          timeUpShowing: true,
          limitEnabled: true,
          remainingSeconds: 600,
        ),
        isFalse,
      );
    });

    test('không làm gì khi native không khoá', () {
      expect(
        shouldReleaseNativeLock(
          nativeLocked: false,
          timeUpShowing: false,
          limitEnabled: true,
          remainingSeconds: 600,
        ),
        isFalse,
      );
    });
  });

  group('shouldScheduleNativeLock', () {
    final now = DateTime(2026, 11, 26, 21, 59);

    test('hẹn khoá khi app xuống nền lúc màn hình còn bật', () {
      expect(
        shouldScheduleNativeLock(
          limitEnabled: true,
          screenOff: false,
          endTime: now.add(const Duration(minutes: 146)),
          now: now,
        ),
        isTrue,
      );
    });

    test('KHÔNG hẹn khoá khi màn hình tắt — server đã ngừng đếm giờ', () {
      expect(
        shouldScheduleNativeLock(
          limitEnabled: true,
          screenOff: true,
          endTime: now.add(const Duration(minutes: 146)),
          now: now,
        ),
        isFalse,
      );
    });

    test('không hẹn khi mốc đã qua hoặc không có mốc', () {
      expect(
        shouldScheduleNativeLock(
          limitEnabled: true,
          screenOff: false,
          endTime: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldScheduleNativeLock(limitEnabled: true, screenOff: false, endTime: null, now: now),
        isFalse,
      );
    });

    test('không hẹn khi tắt giới hạn', () {
      expect(
        shouldScheduleNativeLock(
          limitEnabled: false,
          screenOff: false,
          endTime: now.add(const Duration(minutes: 10)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
