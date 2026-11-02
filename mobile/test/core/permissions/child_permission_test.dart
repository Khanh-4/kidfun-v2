import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/permissions/child_permission.dart';

PermissionSnapshot _snap({
  bool usageStats = true,
  bool accessibility = true,
  bool locationServiceOn = true,
  GrantState notification = GrantState.granted,
  GrantState location = GrantState.granted,
  GrantState backgroundLocation = GrantState.granted,
}) =>
    PermissionSnapshot(
      usageStats: usageStats,
      accessibility: accessibility,
      locationServiceOn: locationServiceOn,
      notification: notification,
      location: location,
      backgroundLocation: backgroundLocation,
    );

List<ChildPermission> _kinds(List<MissingPermission> m) =>
    m.map((e) => e.permission).toList();

void main() {
  group('computeMissing', () {
    test('trả về rỗng khi đã cấp đủ mọi quyền', () {
      expect(computeMissing(_snap()), isEmpty);
    });

    test('liệt kê TẤT CẢ quyền thiếu cùng lúc, đúng thứ tự ưu tiên', () {
      final missing = computeMissing(_snap(
        usageStats: false,
        accessibility: false,
        locationServiceOn: false,
        notification: GrantState.denied,
        location: GrantState.denied,
      ));

      expect(_kinds(missing), [
        ChildPermission.usageStats,
        ChildPermission.accessibility,
        ChildPermission.notification,
        ChildPermission.locationService,
        ChildPermission.location,
      ]);
    });

    test('chỉ thiếu Accessibility (kịch bản người test gặp) thì chỉ báo Accessibility', () {
      expect(_kinds(computeMissing(_snap(accessibility: false))),
          [ChildPermission.accessibility]);
    });

    test('vị trí bị từ chối vĩnh viễn vẫn được báo, kèm cờ permanentlyDenied', () {
      final missing = computeMissing(_snap(location: GrantState.permanentlyDenied));

      expect(_kinds(missing), [ChildPermission.location]);
      expect(missing.single.permanentlyDenied, isTrue);
    });

    test('thông báo bị từ chối vĩnh viễn vẫn được báo', () {
      final missing =
          computeMissing(_snap(notification: GrantState.permanentlyDenied));

      expect(_kinds(missing), [ChildPermission.notification]);
      expect(missing.single.permanentlyDenied, isTrue);
    });

    test('chỉ cho phép vị trí "khi đang dùng app" thì báo thiếu vị trí chạy ngầm', () {
      expect(
        _kinds(computeMissing(_snap(backgroundLocation: GrantState.denied))),
        [ChildPermission.backgroundLocation],
      );
    });

    test('chưa có vị trí thường thì chưa hỏi vị trí chạy ngầm (Android bắt buộc theo thứ tự)', () {
      final missing = computeMissing(_snap(
        location: GrantState.denied,
        backgroundLocation: GrantState.denied,
      ));

      expect(_kinds(missing), [ChildPermission.location]);
    });

    test('tắt GPS được báo riêng', () {
      expect(_kinds(computeMissing(_snap(locationServiceOn: false))),
          [ChildPermission.locationService]);
    });
  });
}
