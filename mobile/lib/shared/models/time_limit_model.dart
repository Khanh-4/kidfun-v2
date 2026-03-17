class TimeLimitModel {
  final int dayOfWeek;    // 0 = CN, 1-6 = T2-T7
  final int limitMinutes;
  final bool isActive;

  TimeLimitModel({
    required this.dayOfWeek,
    required this.limitMinutes,
    this.isActive = true,
  });

  factory TimeLimitModel.fromJson(Map<String, dynamic> json) {
    return TimeLimitModel(
      dayOfWeek: (json['dayOfWeek'] as int?) ?? 0,
      limitMinutes: (json['limitMinutes'] as int?) ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'limitMinutes': limitMinutes,
    'isActive': isActive,
  };

  TimeLimitModel copyWith({
    int? dayOfWeek,
    int? limitMinutes,
    bool? isActive,
  }) {
    return TimeLimitModel(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      isActive: isActive ?? this.isActive,
    );
  }

  String get dayName {
    const names = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
    return names[dayOfWeek];
  }

  String get formattedTime {
    final hours = limitMinutes ~/ 60;
    final mins = limitMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}
