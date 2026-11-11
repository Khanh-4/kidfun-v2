import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/insights.dart';
import '../data/insights_repository.dart';
import '../widgets/usage_heatmap_view.dart';

/// "AI Insights" của một trẻ (đồ án chuyên ngành, T7.5): thẻ "Ngày mai" (M1), heatmap giờ × thứ (M3),
/// và trạng thái rỗng khi tác vụ ban đêm chưa đủ dữ liệu để dự đoán.
class AiInsightsScreen extends StatefulWidget {
  final int profileId;
  final String profileName;
  final InsightsRepository? repository;

  /// Ngày hôm nay theo máy — test truyền vào để cố định "ngày mai".
  final DateTime? today;

  const AiInsightsScreen({super.key, required this.profileId, required this.profileName, this.repository, this.today});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  late final InsightsRepository _repo = widget.repository ?? InsightsRepository();

  List<UsagePrediction> _predictions = const [];
  UsageHeatmap _heatmap = UsageHeatmap.empty();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_repo.fetchPredictions(widget.profileId), _repo.fetchHeatmap(widget.profileId)]);
      if (!mounted) return;
      setState(() {
        _predictions = results[0] as List<UsagePrediction>;
        _heatmap = results[1] as UsageHeatmap;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được dữ liệu, vui lòng kiểm tra mạng.';
      });
    }
  }

  UsagePrediction? get _tomorrow {
    final t = (widget.today ?? DateTime.now()).add(const Duration(days: 1));
    final key = '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    for (final p in _predictions) {
      if (p.date == key) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(title: Text('AI Insights · ${widget.profileName}')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppColors.slate500)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Thử lại')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Ngày mai', _tomorrowContent()),
          const SizedBox(height: 16),
          _section('Thói quen theo giờ', UsageHeatmapView(heatmap: _heatmap)),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate900)),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );

  Widget _tomorrowContent() {
    final p = _tomorrow;
    if (p == null) {
      final missing = _heatmap.missingDays;
      return _note(missing > 0
          ? 'Cần thêm $missing ngày dữ liệu để bắt đầu dự đoán '
              '(đã có ${_heatmap.daysWithData}/${_heatmap.minDaysForPrediction} ngày). Hãy để máy của bé bật KidFun mỗi ngày.'
          : 'Dự đoán cho ngày mai sẽ có sau khi hệ thống phân tích lúc 21:00 tối nay.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatMinutes(p.predictedMinutes),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.request)),
        const SizedBox(width: 8),
        if (p.limitMinutes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('/ giới hạn ${formatMinutes(p.limitMinutes!.toDouble())}',
                style: const TextStyle(color: AppColors.slate500)),
          ),
      ]),
      const Text('thời gian dự đoán bé sẽ dùng', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
      if (p.pOverLimit != null) ...[const SizedBox(height: 12), _overLimitChip(p.pOverLimit!)],
      if (p.message != null && p.message!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(p.message!, style: const TextStyle(color: AppColors.slate700, height: 1.4)),
      ],
    ]);
  }

  Widget _overLimitChip(double p) {
    final (color, bg) = p >= 0.6
        ? (AppColors.danger, AppColors.dangerBg)
        : p >= 0.3
            ? (AppColors.warning, AppColors.warningBg)
            : (AppColors.success, AppColors.successBg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('Khả năng vượt giới hạn: ', style: TextStyle(color: AppColors.slate700)),
        Text('${(p * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _note(String text) => Text(text, style: const TextStyle(color: AppColors.slate500, height: 1.4));
}

/// 95 → "1 giờ 35 phút", 120 → "2 giờ", 40 → "40 phút".
String formatMinutes(double minutes) {
  final m = minutes.round();
  final h = m ~/ 60, r = m % 60;
  if (h == 0) return '$r phút';
  return r == 0 ? '$h giờ' : '$h giờ $r phút';
}
