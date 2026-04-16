import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../data/report_repository.dart';

class DailyReportTab extends StatefulWidget {
  final int profileId;
  const DailyReportTab({super.key, required this.profileId});

  @override
  State<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<DailyReportTab> {
  final _repo = ReportRepository();

  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  static const _pieColors = [
    Color(0xFF6366F1), Color(0xFFCC0000), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFF8B5CF6),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.getDailyReport(widget.profileId, date: _selectedDate);
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text('Lỗi tải dữ liệu', style: GoogleFonts.nunito(color: Colors.red)),
      TextButton(onPressed: _load, child: const Text('Thử lại')),
    ]));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDatePicker(),
          const SizedBox(height: 16),
          if (_data == null || _data!.isEmpty)
            _buildEmpty()
          else ...[
            _buildSummaryCards(),
            const SizedBox(height: 16),
            _buildTopAppsChart(),
            const SizedBox(height: 16),
            _buildYouTubeDangerLevels(),
            const SizedBox(height: 16),
            _buildLocationSection(),
            const SizedBox(height: 16),
            _buildAlertsSection(),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 300,
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        Text('Không có dữ liệu cho ngày này', style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16)),
      ])),
    );
  }

  // ── DatePicker ─────────────────────────────────────────────────────────────

  Widget _buildDatePicker() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 90)),
          lastDate: DateTime.now(),
        );
        if (picked != null && mounted) {
          setState(() => _selectedDate = picked);
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: AppColors.indigo600),
            const SizedBox(width: 10),
            Text(
              isToday ? 'Hôm nay (${_selectedDate.day}/${_selectedDate.month})'
                  : '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.slate700),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── Summary Cards ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    final screenMinutes = (_data!['totalScreenMinutes'] as num?)?.toInt() ?? 0;
    final topApps = (_data!['topApps'] as List?) ?? [];
    final ytStats = _data!['youtubeStats'] as Map? ?? {};
    final sosCount = (_data!['sosAlertsCount'] as num?)?.toInt() ?? 0;
    final aiAlertsCount = (_data!['aiAlertsCount'] as num?)?.toInt() ?? 0;
    final ytMinutes = (ytStats['totalMinutes'] as num?)?.toInt() ?? 0;
    final ytVideos = (ytStats['totalVideos'] as num?)?.toInt() ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _summaryCard('⏱️ Thời gian màn hình', _formatDuration(screenMinutes), AppColors.indigo600),
        _summaryCard('📱 Apps đã dùng', '${topApps.length}', Colors.green),
        _summaryCard('📺 YouTube', '${ytMinutes}m · $ytVideos video', const Color(0xFFCC0000)),
        _summaryCard('⚠️ Cảnh báo', '${aiAlertsCount + sosCount}', aiAlertsCount + sosCount > 0 ? Colors.red : Colors.grey),
      ],
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate500)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── Top Apps Pie Chart ────────────────────────────────────────────────────

  Widget _buildTopAppsChart() {
    final topApps = (_data!['topApps'] as List?)?.take(5).toList() ?? [];
    if (topApps.isEmpty) return const SizedBox.shrink();

    return _sectionCard(
      title: 'TOP APPS',
      icon: Icons.pie_chart,
      iconColor: AppColors.indigo600,
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: topApps.asMap().entries.map((e) {
                  final app = e.value as Map;
                  final seconds = (app['seconds'] as num?)?.toDouble() ?? 0;
                  return PieChartSectionData(
                    value: seconds,
                    color: _pieColors[e.key % _pieColors.length],
                    radius: 55,
                    title: '',
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...topApps.asMap().entries.map((e) {
            final app = e.value as Map;
            final name = (app['appName'] as String?) ?? (app['packageName'] as String?) ?? 'Unknown';
            final secs = (app['seconds'] as num?)?.toInt() ?? 0;
            final mins = secs ~/ 60;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _pieColors[e.key % _pieColors.length], borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: GoogleFonts.nunito(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${mins}m', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── YouTube Danger Levels ─────────────────────────────────────────────────

  Widget _buildYouTubeDangerLevels() {
    final ytStats = _data!['youtubeStats'] as Map? ?? {};
    final dangerLevels = ytStats['dangerLevels'] as Map? ?? {};
    final totalVideos = (ytStats['totalVideos'] as num?)?.toInt() ?? 0;
    if (totalVideos == 0) return const SizedBox.shrink();

    final levels = [
      (1, 'An toàn', Colors.green),
      (2, 'Nhẹ', Colors.lightGreen),
      (3, 'Đáng nghi', Colors.orange),
      (4, 'Nguy hiểm', Colors.deepOrange),
      (5, 'Cực nguy hiểm', Colors.red.shade900),
    ];

    return _sectionCard(
      title: 'MỨC ĐỘ VIDEO YOUTUBE',
      icon: Icons.ondemand_video,
      iconColor: const Color(0xFFCC0000),
      child: Column(
        children: levels.map((lvl) {
          final count = (dangerLevels['${lvl.$1}'] as num?)?.toInt() ?? 0;
          final pct = totalVideos > 0 ? count / totalVideos : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text('Level ${lvl.$1} (${lvl.$2})', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate600))),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 9, backgroundColor: Colors.grey.shade100, color: lvl.$3),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 28, child: Text('$count', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate600), textAlign: TextAlign.end)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Location/Geofence ─────────────────────────────────────────────────────

  Widget _buildLocationSection() {
    final loc = _data!['locationStats'] as Map? ?? {};
    final events = (loc['geofenceEvents'] as List?) ?? [];
    if (events.isEmpty) return const SizedBox.shrink();

    return _sectionCard(
      title: 'DI CHUYỂN',
      icon: Icons.place_outlined,
      iconColor: Colors.blue,
      child: Column(
        children: events.take(10).map((e) {
          final eMap = e as Map;
          final type = eMap['type'] as String? ?? '';
          final name = eMap['geofenceName'] as String? ?? 'Khu vực';
          final ts = eMap['timestamp'] as String?;
          final isEnter = type == 'ENTER';
          DateTime? time;
          if (ts != null) time = DateTime.tryParse(ts)?.toLocal();
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(isEnter ? Icons.login_rounded : Icons.logout_rounded, color: isEnter ? Colors.green : Colors.orange, size: 20),
            title: Text('${isEnter ? "Vào" : "Rời"} "$name"', style: GoogleFonts.nunito(fontSize: 13)),
            trailing: time != null ? Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500),
            ) : null,
          );
        }).toList(),
      ),
    );
  }

  // ── Alerts Summary ────────────────────────────────────────────────────────

  Widget _buildAlertsSection() {
    final aiCount = (_data!['aiAlertsCount'] as num?)?.toInt() ?? 0;
    final sosCount = (_data!['sosAlertsCount'] as num?)?.toInt() ?? 0;
    final extCount = (_data!['approvedExtensionsCount'] as num?)?.toInt() ?? 0;
    if (aiCount == 0 && sosCount == 0 && extCount == 0) return const SizedBox.shrink();

    return _sectionCard(
      title: 'SỰ KIỆN',
      icon: Icons.notifications_active_outlined,
      iconColor: Colors.orange,
      child: Column(
        children: [
          if (aiCount > 0) _eventRow(Icons.psychology, '$aiCount cảnh báo AI', Colors.red),
          if (sosCount > 0) _eventRow(Icons.sos, '$sosCount SOS khẩn cấp', Colors.red.shade900),
          if (extCount > 0) _eventRow(Icons.access_time_filled, '$extCount xin thêm giờ được duyệt', Colors.blue),
        ],
      ),
    );
  }

  Widget _eventRow(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionCard({required String title, required IconData icon, required Color iconColor, required Widget child}) {
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
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate500, letterSpacing: 0.5)),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
