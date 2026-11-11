import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/insights.dart';

/// Nhóm thói quen (M3) + gợi ý có nguồn (M4) — T7.5.3.
class HabitInsightView extends StatelessWidget {
  final HabitInsight? insight;
  final int minDays;

  const HabitInsightView({super.key, required this.insight, required this.minDays});

  @override
  Widget build(BuildContext context) {
    final i = insight;
    if (i == null) {
      return Text('Hệ thống sẽ mô tả thói quen và gợi ý cho bé sau khi có đủ $minDays ngày dữ liệu.',
          style: const TextStyle(color: AppColors.slate500, height: 1.4));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (i.habitSummary != null) ...[
        Text('So với các bé khác: ${i.habitSummary}.',
            style: const TextStyle(color: AppColors.slate700, fontWeight: FontWeight.w600, height: 1.4)),
        if (i.clusterId != null && i.clusterCount != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Nhóm ${i.clusterId! + 1}/${i.clusterCount} (phân nhóm K-Means)',
                style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          ),
        const SizedBox(height: 12),
      ],
      if (i.suggestions.isEmpty)
        const Text('Chưa có gợi ý nào — thói quen của bé đang ổn.', style: TextStyle(color: AppColors.slate500))
      else
        for (final s in i.suggestions) _suggestion(s),
    ]);
  }

  Widget _suggestion(HabitSuggestion s) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.text, style: const TextStyle(color: AppColors.slate700, height: 1.4)),
          const SizedBox(height: 6),
          Text(s.source, style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontStyle: FontStyle.italic)),
        ]),
      );
}
