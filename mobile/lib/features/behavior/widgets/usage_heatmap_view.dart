import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/insights.dart';

/// Heatmap giờ × thứ (T7.5.2). Hàng theo thứ tự T2..CN như lịch VN; ô càng đậm = dùng càng nhiều.
class UsageHeatmapView extends StatelessWidget {
  final UsageHeatmap heatmap;

  const UsageHeatmapView({super.key, required this.heatmap});

  static const _rows = [1, 2, 3, 4, 5, 6, 0]; // chỉ số thứ của API (0 = CN)
  static const _labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _hourMarks = {0: '0h', 6: '6h', 12: '12h', 18: '18h'};

  @override
  Widget build(BuildContext context) {
    if (heatmap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Chưa có dữ liệu sử dụng theo giờ.', style: TextStyle(color: AppColors.slate400))),
      );
    }
    final max = heatmap.maxValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const SizedBox(width: 28),
          for (var h = 0; h < 24; h++)
            Expanded(
              child: Text(_hourMarks[h] ?? '', style: const TextStyle(fontSize: 9, color: AppColors.slate400), softWrap: false, overflow: TextOverflow.visible),
            ),
        ]),
        const SizedBox(height: 2),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(children: [
              SizedBox(width: 28, child: Text(_labels[i], style: const TextStyle(fontSize: 11, color: AppColors.slate500))),
              for (var h = 0; h < 24; h++) Expanded(child: _cell(_rows[i], h, max)),
            ]),
          ),
        const SizedBox(height: 8),
        Text(
          'Trung bình mỗi tuần trong ${heatmap.weeks} tuần gần nhất · ô đậm nhất ≈ ${max.round()} phút/giờ',
          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
        ),
      ],
    );
  }

  Widget _cell(int day, int hour, double max) {
    final value = heatmap.grid[day][hour];
    final t = max == 0 ? 0.0 : value / max;
    return Tooltip(
      message: '${_labels[_rows.indexOf(day)]} ${hour}h: ${value.round()} phút',
      child: Container(
        key: ValueKey('heat-$day-$hour'),
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 0.5),
        decoration: BoxDecoration(
          color: value == 0 ? AppColors.slate100 : Color.lerp(const Color(0xFFE0E7FF), AppColors.request, t),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
