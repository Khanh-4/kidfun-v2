import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/permissions/child_permission.dart';
import 'package:mobile/core/permissions/child_permission_gateway.dart';
import 'package:mobile/core/permissions/child_permission_guard.dart';

/// Gateway giả: giữ trạng thái quyền trong bộ nhớ, `resolve` cấp quyền ngay
/// (giống hộp thoại quyền runtime) hoặc chỉ "mở Cài đặt" (rời app).
class FakeGateway implements ChildPermissionGateway {
  FakeGateway(this.state, {this.opensSettings = const {}});

  PermissionSnapshot state;
  final Set<ChildPermission> opensSettings;
  final resolved = <ChildPermission>[];
  var snapshotCalls = 0;

  @override
  Future<PermissionSnapshot> snapshot() async {
    snapshotCalls++;
    return state;
  }

  @override
  Future<bool> resolve(MissingPermission m) async {
    resolved.add(m.permission);
    if (opensSettings.contains(m.permission)) return true;
    state = _grant(state, m.permission);
    return false;
  }
}

PermissionSnapshot _grant(PermissionSnapshot s, ChildPermission p) =>
    PermissionSnapshot(
      usageStats: p == ChildPermission.usageStats ? true : s.usageStats,
      accessibility: p == ChildPermission.accessibility ? true : s.accessibility,
      locationServiceOn:
          p == ChildPermission.locationService ? true : s.locationServiceOn,
      notification:
          p == ChildPermission.notification ? GrantState.granted : s.notification,
      location: p == ChildPermission.location ? GrantState.granted : s.location,
      backgroundLocation: p == ChildPermission.backgroundLocation
          ? GrantState.granted
          : s.backgroundLocation,
    );

const _allGranted = PermissionSnapshot(
  usageStats: true,
  accessibility: true,
  locationServiceOn: true,
  notification: GrantState.granted,
  location: GrantState.granted,
  backgroundLocation: GrantState.granted,
);

PermissionSnapshot _with({
  bool accessibility = true,
  GrantState notification = GrantState.granted,
  GrantState location = GrantState.granted,
}) =>
    PermissionSnapshot(
      usageStats: true,
      accessibility: accessibility,
      locationServiceOn: true,
      notification: notification,
      location: location,
      backgroundLocation: GrantState.granted,
    );

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: SizedBox());
    }),
  ));
  return ctx;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('đủ quyền thì không hiện pop-up', (tester) async {
    final gw = FakeGateway(_allGranted);
    final guard = ChildPermissionGuard(gateway: gw);
    final ctx = await _pumpHost(tester);

    await guard.check(ctx);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('pop-up liệt kê mọi quyền đang thiếu', (tester) async {
    final gw = FakeGateway(_with(
      accessibility: false,
      notification: GrantState.permanentlyDenied,
      location: GrantState.denied,
    ));
    final guard = ChildPermissionGuard(gateway: gw);
    final ctx = await _pumpHost(tester);

    unawaited(guard.check(ctx));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(ChildPermission.accessibility.title), findsOneWidget);
    expect(find.text(ChildPermission.notification.title), findsOneWidget);
    expect(find.text(ChildPermission.location.title), findsOneWidget);
  });

  testWidgets('quyền runtime: cấp xong tự kiểm tra lại, hết thiếu thì đóng pop-up',
      (tester) async {
    final gw = FakeGateway(_with(location: GrantState.denied));
    var locationCallbacks = 0;
    final guard = ChildPermissionGuard(
      gateway: gw,
      onLocationGranted: () => locationCallbacks++,
    );
    final ctx = await _pumpHost(tester);

    unawaited(guard.check(ctx));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('fix-${ChildPermission.location.name}')));
    await tester.pumpAndSettle();

    expect(gw.resolved, [ChildPermission.location]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(locationCallbacks, 1);
  });

  testWidgets('quyền phải vào Cài đặt: không hiện lại ngay, chờ app resume',
      (tester) async {
    final gw = FakeGateway(_with(accessibility: false),
        opensSettings: {ChildPermission.accessibility});
    final guard = ChildPermissionGuard(gateway: gw);
    final ctx = await _pumpHost(tester);

    unawaited(guard.check(ctx));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ValueKey('fix-${ChildPermission.accessibility.name}')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(gw.snapshotCalls, 1);

    // Người dùng bật Accessibility trong Cài đặt rồi quay lại app.
    gw.state = _allGranted;
    await guard.check(ctx);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('vị trí cấp qua Cài đặt: lần kiểm tra sau khi resume gọi onLocationGranted',
      (tester) async {
    final gw = FakeGateway(_with(location: GrantState.permanentlyDenied),
        opensSettings: {ChildPermission.location});
    var locationCallbacks = 0;
    final guard = ChildPermissionGuard(
      gateway: gw,
      onLocationGranted: () => locationCallbacks++,
    );
    final ctx = await _pumpHost(tester);

    unawaited(guard.check(ctx));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('fix-${ChildPermission.location.name}')));
    await tester.pumpAndSettle();
    expect(locationCallbacks, 0);

    gw.state = _allGranted;
    await guard.check(ctx);
    await tester.pumpAndSettle();
    expect(locationCallbacks, 1);
  });

  testWidgets('gọi check chồng nhau (resume giữa chừng) không mở 2 pop-up',
      (tester) async {
    final gw = FakeGateway(_with(accessibility: false));
    final guard = ChildPermissionGuard(gateway: gw);
    final ctx = await _pumpHost(tester);

    unawaited(guard.check(ctx));
    unawaited(guard.check(ctx));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('allowDismiss: có nút "Để sau", bấm thì đóng', (tester) async {
    final gw = FakeGateway(_with(accessibility: false));
    final guard = ChildPermissionGuard(gateway: gw, allowDismiss: true);
    final ctx = await _pumpHost(tester);

    unawaited(guard.check(ctx));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(gw.resolved, isEmpty);
  });

  testWidgets('mặc định (màn hình trẻ) không có nút "Để sau"', (tester) async {
    final gw = FakeGateway(_with(accessibility: false));
    final guard = ChildPermissionGuard(gateway: gw);
    final ctx = await _pumpHost(tester);

    unawaited(guard.check(ctx));
    await tester.pumpAndSettle();

    expect(find.text('Để sau'), findsNothing);
  });
}
