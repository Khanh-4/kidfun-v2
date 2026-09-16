import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/device/data/device_exceptions.dart';
import 'package:mobile/features/device/providers/device_provider.dart';
import 'package:mobile/features/device/screens/device_list_screen.dart';
import 'package:mobile/features/profile/providers/profile_provider.dart';
import 'package:mobile/shared/models/device_model.dart';

/// Luồng D1: phụ huynh xoá thiết bị trong lúc máy trẻ mất mạng.
///
/// Không đụng mạng thật: notifier giả đóng vai server (409 DEVICE_OFFLINE) và
/// máy trẻ (không bao giờ trả lời, hoặc vòng dò lỗi).
class FakeDeviceNotifier extends StateNotifier<DeviceState>
    implements DeviceNotifier {
  FakeDeviceNotifier(this.device, {required this.probe})
      : super(DeviceLoaded([device]));

  final DeviceModel device;
  final Future<bool> Function() probe;
  final deleteCalls = <bool>[];

  var probeCancelled = false;

  @override
  Future<void> fetchDevices() async {}

  @override
  Future<bool> waitForDeviceAlive(int id, DateTime? baseline,
      {Future<void>? cancel}) {
    cancel?.then((_) => probeCancelled = true);
    return probe();
  }

  @override
  Future<void> deleteDevice(int id, {bool force = false}) async {
    deleteCalls.add(force);
    if (!force) {
      throw DeviceOfflineException(
        minutesSinceLastSeen: 1,
        baselineLastSeen: device.lastSeen,
      );
    }
    state = DeviceLoaded(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProfileNotifier extends StateNotifier<ProfileState>
    implements ProfileNotifier {
  FakeProfileNotifier() : super(ProfileLoaded(const []));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _device = DeviceModel(
  id: 181,
  userId: 1,
  deviceName: 'Máy của bé',
  deviceCode: 'TQ2B',
  lastSeen: DateTime.utc(2026, 9, 16, 16, 6, 13),
  createdAt: DateTime.utc(2026, 9, 16),
);

Future<FakeDeviceNotifier> _openDeleteFlow(
  WidgetTester tester, {
  required Future<bool> Function() probe,
}) async {
  final notifier = FakeDeviceNotifier(_device, probe: probe);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      deviceProvider.overrideWith((ref) => notifier),
      profileProvider.overrideWith((ref) => FakeProfileNotifier()),
    ],
    child: const MaterialApp(home: DeviceListScreen()),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text(_device.deviceName));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xóa thiết bị')); // nút trong bảng tuỳ chọn
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xoá thiết bị')); // nút xác nhận
  await tester.pump();
  return notifier;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('máy trẻ im lặng → tắt vòng xoay và hiện cảnh báo mất kết nối',
      (tester) async {
    final notifier = await _openDeleteFlow(
      tester,
      probe: () => Future.delayed(const Duration(seconds: 6), () => false),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Đang kiểm tra kết nối'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang kiểm tra kết nối'), findsNothing);
    expect(find.text('Máy trẻ đang mất kết nối'), findsOneWidget);

    await tester.tap(find.text('Vẫn gỡ'));
    await tester.pumpAndSettle();
    expect(notifier.deleteCalls, [false, true]);
  });

  testWidgets('bấm Huỷ lúc đang dò → đóng spinner, không cảnh báo, không xoá',
      (tester) async {
    final notifier = await _openDeleteFlow(
      tester,
      probe: () => Future.delayed(const Duration(seconds: 75), () => false),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang kiểm tra kết nối'), findsNothing);
    expect(find.text('Máy trẻ đang mất kết nối'), findsNothing);
    expect(notifier.deleteCalls, [false]);
    // Huỷ phải dừng cả vòng dò, không để nó poll server ngầm tới hết giờ.
    expect(notifier.probeCancelled, isTrue);

    // Cho vòng dò giả chạy hết: kết quả muộn không được mở lại dialog nào.
    await tester.pump(const Duration(seconds: 80));
    await tester.pumpAndSettle();
    expect(find.text('Máy trẻ đang mất kết nối'), findsNothing);
  });

  testWidgets('máy trẻ trả lời → xoá luôn, không cảnh báo', (tester) async {
    final notifier = await _openDeleteFlow(
      tester,
      probe: () => Future.delayed(const Duration(seconds: 2), () => true),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang kiểm tra kết nối'), findsNothing);
    expect(find.text('Máy trẻ đang mất kết nối'), findsNothing);
    expect(notifier.deleteCalls, [false, true]);
  });

  testWidgets('vòng dò ném lỗi → vẫn hiện cảnh báo, không kẹt', (tester) async {
    await _openDeleteFlow(
      tester,
      probe: () => Future.delayed(
          const Duration(seconds: 2), () => throw Exception('timeout')),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang kiểm tra kết nối'), findsNothing);
    expect(find.text('Máy trẻ đang mất kết nối'), findsOneWidget);
  });
}
