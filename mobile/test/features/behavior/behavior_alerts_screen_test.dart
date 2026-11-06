import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/behavior/data/behavior_alert.dart';
import 'package:mobile/features/behavior/data/behavior_alert_repository.dart';
import 'package:mobile/features/behavior/screens/behavior_alerts_screen.dart';

class FakeRepo extends BehaviorAlertRepository {
  FakeRepo(this.alerts, {this.failList = false, this.failFeedback = false});

  final List<BehaviorAlert> alerts;
  final bool failList;
  final bool failFeedback;
  final sent = <(int, String)>[];

  @override
  Future<List<BehaviorAlert>> list(int profileId, {int limit = 50}) async {
    if (failList) throw Exception('offline');
    return alerts;
  }

  @override
  Future<void> sendFeedback(int alertId, String feedback) async {
    if (failFeedback) throw Exception('offline');
    sent.add((alertId, feedback));
  }
}

BehaviorAlert alert(int id, {String source = 'TIER1', String rule = 'night', String? feedback}) => BehaviorAlert(
      id: id,
      profileId: 7,
      source: source,
      rule: rule,
      message: 'Câu cảnh báo số $id',
      slotStart: DateTime(2026, 11, 6, 23),
      createdAt: DateTime(2026, 11, 6, 23, 5),
      feedback: feedback,
    );

Future<void> pump(WidgetTester tester, FakeRepo repo, {int? highlightId}) async {
  await tester.pumpWidget(MaterialApp(
    home: BehaviorAlertsScreen(profileId: 7, profileName: 'Bé An', highlightAlertId: highlightId, repository: repo),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hiện câu giải thích, nguồn cảnh báo và đánh dấu cảnh báo vừa nhận', (tester) async {
    final repo = FakeRepo([
      alert(1),
      alert(2, source: 'TIER2', rule: 'day_anomaly'),
      alert(3, source: 'M1', rule: 'over_limit'),
    ]);
    await pump(tester, repo, highlightId: 2);

    expect(find.text('Câu cảnh báo số 1'), findsOneWidget);
    expect(find.text('Phát hiện trên máy bé'), findsOneWidget);
    expect(find.text('Ngày bất thường'), findsOneWidget);
    expect(find.text('Dự đoán ngày mai'), findsOneWidget);
    expect(find.text('Vừa nhận'), findsOneWidget);
  });

  testWidgets('"Đúng là bất thường" gửi CONFIRMED rồi thay nút bằng trạng thái đã phản hồi', (tester) async {
    final repo = FakeRepo([alert(1)]);
    await pump(tester, repo);

    await tester.tap(find.text('Đúng là bất thường'));
    await tester.pumpAndSettle();

    expect(repo.sent, [(1, AlertFeedback.confirmed)]);
    expect(find.text('Đúng là bất thường'), findsNothing);
    expect(find.text(AlertFeedback.label(AlertFeedback.confirmed)), findsOneWidget);
  });

  testWidgets('"Được phép" hỏi lý do, chọn cuối tuần → ALLOWED_WEEKEND', (tester) async {
    final repo = FakeRepo([alert(1)]);
    await pump(tester, repo);

    await tester.tap(find.text('Được phép'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AlertFeedback.allowedReasons[AlertFeedback.allowedWeekend]!));
    await tester.pumpAndSettle();

    expect(repo.sent, [(1, AlertFeedback.allowedWeekend)]);
    expect(find.text(AlertFeedback.label(AlertFeedback.allowedWeekend)), findsOneWidget);
  });

  testWidgets('cảnh báo đã phản hồi từ trước không hiện nút', (tester) async {
    await pump(tester, FakeRepo([alert(1, feedback: AlertFeedback.allowedHoliday)]));

    expect(find.text('Đúng là bất thường'), findsNothing);
    expect(find.text(AlertFeedback.label(AlertFeedback.allowedHoliday)), findsOneWidget);
  });

  testWidgets('gửi phản hồi lỗi → báo lỗi, vẫn giữ nút để thử lại', (tester) async {
    final repo = FakeRepo([alert(1)], failFeedback: true);
    await pump(tester, repo);

    await tester.tap(find.text('Đúng là bất thường'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không gửi được'), findsOneWidget);
    expect(find.text('Đúng là bất thường'), findsOneWidget);
  });

  testWidgets('danh sách rỗng', (tester) async {
    await pump(tester, FakeRepo([]));
    expect(find.textContaining('Chưa có cảnh báo'), findsOneWidget);
  });

  testWidgets('lỗi tải → nút thử lại', (tester) async {
    await pump(tester, FakeRepo([], failList: true));
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
