// Dữ liệu cho màn "AI Insights" (đồ án chuyên ngành, T7.5).

/// Một dòng của GET /api/profiles/:id/predictions — dự đoán M1 cho một ngày.
class UsagePrediction {
  final String date; // YYYY-MM-DD theo giờ VN
  final double predictedMinutes;
  final double? pOverLimit;
  final int? limitMinutes;
  final String? message;

  const UsagePrediction({
    required this.date,
    required this.predictedMinutes,
    this.pOverLimit,
    this.limitMinutes,
    this.message,
  });

  factory UsagePrediction.fromJson(Map<String, dynamic> json) => UsagePrediction(
        date: json['date'] as String,
        predictedMinutes: (json['predictedMinutes'] as num).toDouble(),
        pOverLimit: (json['pOverLimit'] as num?)?.toDouble(),
        limitMinutes: (json['limitMinutes'] as num?)?.toInt(),
        message: json['message'] as String?,
      );
}

/// GET /api/profiles/:id/usage-heatmap — grid[thứ 0=CN..6][giờ 0..23] = phút trung bình mỗi tuần (giờ VN).
class UsageHeatmap {
  final int weeks;
  final List<List<double>> grid;
  final int daysWithData;
  final int minDaysForPrediction;

  const UsageHeatmap({
    required this.weeks,
    required this.grid,
    required this.daysWithData,
    required this.minDaysForPrediction,
  });

  factory UsageHeatmap.empty() => UsageHeatmap(
        weeks: 4,
        grid: List.generate(7, (_) => List<double>.filled(24, 0)),
        daysWithData: 0,
        minDaysForPrediction: 7,
      );

  factory UsageHeatmap.fromJson(Map<String, dynamic> json) => UsageHeatmap(
        weeks: (json['weeks'] as num).toInt(),
        grid: [
          for (final row in json['grid'] as List) [for (final v in row as List) (v as num).toDouble()],
        ],
        daysWithData: (json['daysWithData'] as num).toInt(),
        minDaysForPrediction: (json['minDaysForPrediction'] as num?)?.toInt() ?? 7,
      );

  bool get isEmpty => daysWithData == 0;

  /// Số ngày còn thiếu trước khi tác vụ ban đêm bắt đầu dự đoán (0 = đã đủ).
  int get missingDays => (minDaysForPrediction - daysWithData).clamp(0, minDaysForPrediction);

  double get maxValue => grid.expand((r) => r).fold(0, (a, b) => a > b ? a : b);
}
