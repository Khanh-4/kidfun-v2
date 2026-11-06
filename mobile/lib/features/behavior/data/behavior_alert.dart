/// Cảnh báo hành vi bất thường (đồ án chuyên ngành) — bảng BehaviorAlert ở backend.
///
/// Nguồn: TIER1 (luật chạy trên máy trẻ), TIER2 (mô hình ML ban đêm: theo giờ hoặc `day_anomaly` cả ngày),
/// M1 (dự đoán ngày mai có khả năng vượt giới hạn).
class BehaviorAlert {
  final int id;
  final int profileId;
  final String source;
  final String rule;
  final String message;
  final DateTime slotStart;
  final DateTime createdAt;
  final String? feedback;

  const BehaviorAlert({
    required this.id,
    required this.profileId,
    required this.source,
    required this.rule,
    required this.message,
    required this.slotStart,
    required this.createdAt,
    this.feedback,
  });

  factory BehaviorAlert.fromJson(Map<String, dynamic> json) => BehaviorAlert(
        id: json['id'] as int,
        profileId: json['profileId'] as int,
        source: json['source'] as String? ?? 'TIER1',
        rule: json['rule'] as String? ?? '',
        message: json['message'] as String? ?? '',
        slotStart: DateTime.parse(json['slotStart'] as String).toLocal(),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        feedback: json['feedback'] as String?,
      );

  bool get hasFeedback => feedback != null;

  BehaviorAlert withFeedback(String value) => BehaviorAlert(
        id: id,
        profileId: profileId,
        source: source,
        rule: rule,
        message: message,
        slotStart: slotStart,
        createdAt: createdAt,
        feedback: value,
      );

  /// Nhãn ngắn cho phụ huynh biết cảnh báo từ đâu ra.
  String get sourceLabel {
    if (source == 'M1') return 'Dự đoán ngày mai';
    if (source == 'TIER2' && rule == 'day_anomaly') return 'Ngày bất thường';
    if (source == 'TIER2') return 'Phân tích ban đêm';
    return 'Phát hiện trên máy bé';
  }
}

/// Giá trị `feedback` mà POST /api/behavior-alerts/:id/feedback chấp nhận.
class AlertFeedback {
  static const confirmed = 'CONFIRMED';
  static const allowedWeekend = 'ALLOWED_WEEKEND';
  static const allowedHoliday = 'ALLOWED_HOLIDAY';
  static const allowedOther = 'ALLOWED_OTHER';

  static const allowedReasons = {
    allowedWeekend: 'Cuối tuần, cho phép',
    allowedHoliday: 'Ngày lễ / nghỉ, cho phép',
    allowedOther: 'Lý do khác, cho phép',
  };

  static String label(String value) =>
      value == confirmed ? 'Bạn xác nhận: đúng là bất thường' : 'Bạn đánh dấu: ${allowedReasons[value] ?? 'được phép'}';
}
