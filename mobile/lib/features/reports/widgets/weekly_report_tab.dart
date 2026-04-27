import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../data/report_repository.dart';

class WeeklyReportTab extends StatefulWidget {
  final int profileId;
  const WeeklyReportTab({super.key, required this.profileId});

  @override
  State<WeeklyReportTab> createState() => _WeeklyReportTabState();
}

class _WeeklyReportTabState extends State<WeeklyReportTab> {
  final _repo = ReportRepository();

  late DateTime _weekStart;
  Map<String, dynamic>? _data;
  List<double> _dailyMinutes = List.filled(7, 0);
  bool _loading = true;
  String? _error;

  static const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  static DateTime _thisMonday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _weekStart = _thisMonday();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Load weekly summary + 7 daily reports in parallel
      final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
      final results = await Future.wait([
        _repo.getWeeklyReport(widget.profileId, weekStart: _weekStart),
        ...days.map((d) => _repo.getDailyReport(widget.profileId, date: d)),
      ]);

      final weekly = results[0] as Map<String, dynamic>;
      final dailies = results.sublist(1).map((r) {
        final val = r as Map<String, dynamic>;
        return (val['totalScreenMinutes'] as num?)?.toDouble() ?? 0.0;
      }).toList();

      setState(() {
        _data = weekly;
        _dailyMinutes = dailies;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    final nextMonday = _weekStart.add(const Duration(days: 7));
    if (nextMonday.isAfter(DateTime.now())) return;
    setState(() => _weekStart = nextMonday);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildErrorState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWeekPicker(),
          const SizedBox(height: 16),
          _buildBarChart(),
          const SizedBox(height: 16),
          _buildWeeklySummary(),
          const SizedBox(height: 16),
          _buildTopAppsWeekly(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Week Picker ───────────────────────────────────────────────────────────

  Widget _buildWeekPicker() {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final isCurrentWeek = _weekStart.isAtSameMomentAs(_thisMonday());
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevWeek, color: AppColors.slate600),
          Expanded(
            child: Center(
              child: Text(
                '${_weekStart.day}/${_weekStart.month} – ${weekEnd.day}/${weekEnd.month}/${weekEnd.year}',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.slate700),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentWeek ? null : _nextWeek,
            color: isCurrentWeek ? Colors.grey.shade300 : AppColors.slate600,
          ),
        ],
      ),
    );
  }

  // ── Bar Chart 7 Ngày ──────────────────────────────────────────────────────

  Widget _buildBarChart() {
    final maxY = _dailyMinutes.isEmpty ? 60.0 :
      (_dailyMinutes.reduce((a, b) => a > b ? a : b));
    final maxBarY = maxY > 0 ? maxY * 1.25 : 60.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              const Icon(Icons.bar_chart, size: 15, color: AppColors.indigo600),
              const SizedBox(width: 6),
              Text('THỜI GIAN MÀN HÌNH TỪNG NGÀY', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate500, letterSpacing: 0.5)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxBarY,
                  barGroups: List.generate(7, (i) => BarChartGroupData(
                    x: i,
                    barRods: [BarChartRodData(
                      toY: _dailyMinutes[i],
                      color: AppColors.indigo600,
                      width: 26,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxBarY, color: Colors.grey.shade100),
                    )],
                  )),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxBarY > 120 ? 60 : 30,
                      getTitlesWidget: (v, _) => Text(
                        v > 0 ? '${v.toInt()}m' : '',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    )),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= 7) return const SizedBox.shrink();
                        final minutes = _dailyMinutes[i];
                        return Column(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(height: 4),
                          Text(_dayLabels[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: minutes > 0 ? AppColors.indigo600 : Colors.grey)),
                        ]);
                      },
                    )),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: maxBarY > 120 ? 60 : 30,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (_, __, rod, ___) {
                        final m = rod.toY.toInt();
                        return BarTooltipItem(
                          '${m ~/ 60}h ${m % 60}m',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly Summary ────────────────────────────────────────────────────────

  Widget _buildWeeklySummary() {
    final totalMinutes = _dailyMinutes.fold(0.0, (a, b) => a + b).toInt();
    final totalVideos = (_data?['youtubeStats'] as Map?)?['totalVideos'] ?? 0;
    final aiAlerts = (_data?['aiAlertsCount'] as num?)?.toInt() ?? 0;
    final sosAlerts = (_data?['sosAlertsCount'] as num?)?.toInt() ?? 0;

    return Row(
      children: [
        Expanded(child: _weekCard('⏱️ Tổng thời gian', _formatDuration(totalMinutes), AppColors.indigo600)),
        const SizedBox(width: 10),
        Expanded(child: _weekCard('📺 Videos', '$totalVideos', const Color(0xFFCC0000))),
        const SizedBox(width: 10),
        Expanded(child: _weekCard('⚠️ Cảnh báo', '${aiAlerts + sosAlerts}', aiAlerts + sosAlerts > 0 ? Colors.red : Colors.green)),
      ],
    );
  }

  Widget _weekCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate500)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  // ── Top Apps Weekly ───────────────────────────────────────────────────────

  Widget _buildTopAppsWeekly() {
    final topApps = (_data?['topApps'] as List?) ?? [];
    if (topApps.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              const Icon(Icons.apps, size: 15, color: Colors.green),
              const SizedBox(width: 6),
              Text('TOP APPS CẢ TUẦN', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate500, letterSpacing: 0.5)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: topApps.take(5).map((app) {
                final aMap = app as Map;
                final name = (aMap['appName'] as String?) ?? (aMap['packageName'] as String?) ?? 'Unknown';
                final secs = (aMap['seconds'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(name, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${secs ~/ 60}m', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Lỗi kết nối. Vui lòng thử lại sau.',
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text('Thử lại', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

