import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/behavior/data/insights.dart';
import 'package:mobile/features/behavior/data/insights_repository.dart';
import 'package:mobile/features/behavior/screens/ai_insights_screen.dart';

class FakeInsightsRepo extends InsightsRepository {
  FakeInsightsRepo({this.predictions = const [], UsageHeatmap? heatmap, this.fail = false})
      : heatmap = heatmap ?? UsageHeatmap.empty();

  final List<UsagePrediction> predictions;
  final UsageHeatmap heatmap;
  final bool fail;

  @override
  Future<List<UsagePrediction>> fetchPredictions(int profileId) async {
    if (fail) throw Exception('offline');
    return predictions;
  }

  @override
  Future<UsageHeatmap> fetchHeatmap(int profileId) async {
    if (fail) throw Exception('offline');
    return heatmap;
  }
}

UsageHeatmap heatmapWith({int days = 10, double mondayEvening = 30}) {
  final grid = List.generate(7, (_) => List<double>.filled(24, 0));
  grid[1][20] = mondayEvening;
  return UsageHeatmap(weeks: 4, grid: grid, daysWithData: days, minDaysForPrediction: 7);
}

final today = DateTime(2026, 11, 11);

Future<void> pump(WidgetTester tester, FakeInsightsRepo repo) async {
  await tester.pumpWidget(MaterialApp(
    home: AiInsightsScreen(profileId: 7, profileName: 'Bé An', repository: repo, today: today),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('thẻ Ngày mai: số phút dự đoán, giới hạn, xác suất vượt và câu giải thích', (tester) async {
    await pump(
      tester,
      FakeInsightsRepo(
        predictions: [
          const UsagePrediction(date: '2026-11-12', predictedMinutes: 95, pOverLimit: 0.72, limitMinutes: 120,
              message: 'Ngày mai là thứ Năm, bé thường dùng nhiều buổi tối.'),
          const UsagePrediction(date: '2026-11-11', predictedMinutes: 40, pOverLimit: 0.1, limitMinutes: 120),
        ],
        heatmap: heatmapWith(),
      ),
    );

    expect(find.text('Ngày mai'), findsOneWidget);
    expect(find.text('1 giờ 35 phút'), findsOneWidget);
    expect(find.textContaining('2 giờ'), findsOneWidget); // giới hạn 120 phút
    expect(find.text('72%'), findsOneWidget);
    expect(find.textContaining('thứ Năm'), findsOneWidget);
  });

  testWidgets('chưa đủ dữ liệu → "cần thêm N ngày", không có thẻ dự đoán', (tester) async {
    await pump(tester, FakeInsightsRepo(heatmap: heatmapWith(days: 3)));

    expect(find.textContaining('Cần thêm 4 ngày'), findsOneWidget);
    expect(find.text('72%'), findsNothing);
  });

  testWidgets('đủ dữ liệu nhưng chưa có dự đoán ngày mai → báo chờ tác vụ ban đêm', (tester) async {
    await pump(tester, FakeInsightsRepo(heatmap: heatmapWith(days: 9)));

    expect(find.textContaining('21:00'), findsOneWidget);
  });

  testWidgets('heatmap có đủ 7 hàng × 24 ô', (tester) async {
    await pump(tester, FakeInsightsRepo(heatmap: heatmapWith()));
    expect(find.byKey(const ValueKey('heat-1-20')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-6-23')), findsOneWidget);
  });

  testWidgets('heatmap chưa có dữ liệu → câu trống thay cho lưới', (tester) async {
    await pump(tester, FakeInsightsRepo(heatmap: heatmapWith(days: 0, mondayEvening: 0)));
    expect(find.byKey(const ValueKey('heat-1-20')), findsNothing);
    expect(find.textContaining('Chưa có dữ liệu'), findsWidgets);
  });

  testWidgets('lỗi mạng → thông báo + nút thử lại', (tester) async {
    await pump(tester, FakeInsightsRepo(fail: true));

    expect(find.textContaining('Không tải được'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
