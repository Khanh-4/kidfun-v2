import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import 'youtube_logs_screen.dart';
import '../screens/ai_alerts_screen.dart';

class YouTubeDashboardScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const YouTubeDashboardScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<YouTubeDashboardScreen> createState() => _YouTubeDashboardScreenState();
}

class _YouTubeDashboardScreenState extends State<YouTubeDashboardScreen> {
  final _dio = DioClient.instance;
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _selectedDays = 7;

  static const _dayOptions = [7, 14, 30];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _dio.get(
        '/api/profiles/${widget.profileId}/youtube/dashboard',
        queryParameters: {'days': _selectedDays},
      );
      setState(() {
        _data = response.data['data'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📺 YouTube Activity',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              widget.profileName,
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Day filter
          PopupMenuButton<int>(
            initialValue: _selectedDays,
            onSelected: (val) {
              setState(() => _selectedDays = val);
              _load();
            },
            itemBuilder: (_) => _dayOptions.map((d) => PopupMenuItem(
              value: d,
              child: Text('$d ngày'),
            )).toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text('$_selectedDays ngày', style: const TextStyle(color: Colors.white)),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
          // AI Alerts shortcut
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Cảnh báo AI',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AIAlertsScreen(
                profileId: widget.profileId,
                profileName: widget.profileName,
              ),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : _data == null
              ? const Center(child: Text('Không có dữ liệu'))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFCC0000),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      _buildDangerLevelChart(),
                      const SizedBox(height: 16),
                      _buildTopChannels(),
                      const SizedBox(height: 16),
                      _buildCategoriesGrid(),
                      const SizedBox(height: 16),
                      _buildDailyActivity(),
                      const SizedBox(height: 16),
                      _buildRecentAlerts(),
                      const SizedBox(height: 16),
                      _buildViewAllButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // ── Summary Cards ────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    final totalVideos = _data!['totalVideos'] ?? 0;
    final totalMinutes = _data!['totalWatchMinutes'] ?? 0;
    final recentAlerts = (_data!['recentAlerts'] as List?) ?? [];
    final unreadAlerts = recentAlerts.where((a) => a['isRead'] == false).length;

    return Row(
      children: [
        Expanded(child: _summaryCard(
          icon: Icons.play_circle_outline,
          label: 'Videos',
          value: '$totalVideos',
          color: const Color(0xFFCC0000),
        )),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard(
          icon: Icons.timer_outlined,
          label: 'Thời gian xem',
          value: _formatMinutes(totalMinutes),
          color: Colors.orange,
        )),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard(
          icon: Icons.warning_amber_outlined,
          label: 'Cảnh báo',
          value: '$unreadAlerts',
          color: unreadAlerts > 0 ? Colors.red : Colors.green,
          badge: unreadAlerts > 0,
        )),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool badge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              if (badge)
                Positioned(
                  top: -2, right: -2,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Danger Level Chart ────────────────────────────────────────────────────

  Widget _buildDangerLevelChart() {
    final danger = _data!['dangerSummary'] as Map? ?? {};
    final totalVideos = (_data!['totalVideos'] ?? 1) as int;
    final total = totalVideos > 0 ? totalVideos : 1;

    final levels = [
      (1, 'An toàn', Colors.green),
      (2, 'Nhẹ', Colors.lightGreen),
      (3, 'Đáng nghi', Colors.orange),
      (4, 'Nguy hiểm', Colors.deepOrange),
      (5, 'Cực nguy hiểm', Colors.red.shade900),
    ];

    return _sectionCard(
      title: 'MỨC ĐỘ NỘI DUNG',
      icon: Icons.security,
      iconColor: Colors.orange,
      child: Column(
        children: [
          ...levels.map((lvl) {
            final count = (danger['${lvl.$1}'] ?? 0) as int;
            final pct = count / total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text('Level ${lvl.$1}',
                      style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate600)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade100,
                        color: lvl.$3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text('$count', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate600), textAlign: TextAlign.end),
                  ),
                ],
              ),
            );
          }),
          if ((danger['unanalyzed'] ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 90),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (danger['unanalyzed'] as int) / total,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade100,
                    color: Colors.grey,
                  ),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 48, child: Text('${danger['unanalyzed']}',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate600), textAlign: TextAlign.end)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                const SizedBox(width: 90),
                Text('Chưa phân tích', style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Top Channels ─────────────────────────────────────────────────────────

  Widget _buildTopChannels() {
    final channels = (_data!['topChannels'] as List?) ?? [];
    if (channels.isEmpty) return const SizedBox.shrink();

    final maxWatch = channels.isEmpty ? 1.0 :
      (channels.map((c) => (c['watchSeconds'] as num).toDouble()).reduce((a, b) => a > b ? a : b));

    return _sectionCard(
      title: 'TOP CHANNELS',
      icon: Icons.subscriptions_rounded,
      iconColor: const Color(0xFFCC0000),
      child: Column(
        children: channels.take(5).toList().asMap().entries.map((e) {
          final ch = e.value as Map;
          final name = ch['name'] as String? ?? 'Unknown';
          final secs = (ch['watchSeconds'] as num?)?.toInt() ?? 0;
          final count = (ch['count'] as num?)?.toInt() ?? 0;
          final pct = maxWatch > 0 ? secs / maxWatch : 0.0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: const Color(0xFFCC0000), shape: BoxShape.circle),
                      child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(_formatMinutes(secs ~/ 60), style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
                    const SizedBox(width: 6),
                    Text('· $count vid', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate400)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade100,
                    color: const Color(0xFFCC0000),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Categories Grid ───────────────────────────────────────────────────────

  Widget _buildCategoriesGrid() {
    final cats = _data!['categorySummary'] as Map? ?? {};
    final dangerous = cats.entries.where((e) => e.key != 'SAFE' && (e.value as int) > 0).toList();
    if (dangerous.isEmpty) {
      return _sectionCard(
        title: 'DANH MỤC NỘI DUNG',
        icon: Icons.category_outlined,
        iconColor: Colors.blue,
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text('Không phát hiện nội dung đáng ngờ', style: GoogleFonts.nunito(color: Colors.green, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    final catInfo = {
      'BULLY': ('Bắt nạt', Icons.person_off, Colors.orange),
      'SEXUAL': ('Tình dục', Icons.warning, Colors.red),
      'DRUG': ('Ma túy', Icons.medication_outlined, Colors.deepOrange),
      'VIOLENCE': ('Bạo lực', Icons.sports_martial_arts, Colors.red),
      'SELF_HARM': ('Tự hại', Icons.healing_outlined, Colors.red.shade900),
      'DISTURBING': ('Đáng sợ', Icons.psychology_alt, Colors.purple),
    };

    return _sectionCard(
      title: 'DANH MỤC ĐÁNG NGHI',
      icon: Icons.category_outlined,
      iconColor: Colors.red,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: dangerous.map((e) {
          final info = catInfo[e.key];
          final label = info?.$1 ?? e.key;
          final icon = info?.$2 ?? Icons.warning;
          final color = info?.$3 ?? Colors.orange;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Text('$label: ${e.value}', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Daily Activity Bar Chart ──────────────────────────────────────────────

  Widget _buildDailyActivity() {
    final daily = _data!['dailyActivity'] as Map? ?? {};
    if (daily.isEmpty) return const SizedBox.shrink();

    // Get last _selectedDays entries sorted
    final sorted = daily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final recent = sorted.length > _selectedDays ? sorted.sublist(sorted.length - _selectedDays) : sorted;
    if (recent.isEmpty) return const SizedBox.shrink();

    final maxY = recent.map((e) => (e.value as int).toDouble()).reduce((a, b) => a > b ? a : b);

    return _sectionCard(
      title: 'HOẠT ĐỘNG THEO NGÀY',
      icon: Icons.bar_chart,
      iconColor: AppColors.indigo600,
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: maxY > 0 ? maxY * 1.2 : 5,
            barGroups: recent.asMap().entries.map((e) {
              final count = (e.value.value as int).toDouble();
              return BarChartGroupData(
                x: e.key,
                barRods: [BarChartRodData(
                  toY: count,
                  color: const Color(0xFFCC0000),
                  width: recent.length > 14 ? 8 : 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )],
              );
            }).toList(),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= recent.length) return const SizedBox.shrink();
                    final dateStr = recent[idx].key as String;
                    final parts = dateStr.split('-');
                    if (parts.length < 3) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${parts[2]}/${parts[1]}',
                        style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  // ── Recent Alerts ─────────────────────────────────────────────────────────

  Widget _buildRecentAlerts() {
    final alerts = (_data!['recentAlerts'] as List?) ?? [];
    if (alerts.isEmpty) return const SizedBox.shrink();

    return _sectionCard(
      title: '⚠️ CẢNH BÁO GẦN ĐÂY',
      icon: Icons.notifications_active,
      iconColor: Colors.red,
      child: Column(
        children: alerts.take(3).map((a) {
          final log = a['youtubeLog'] as Map? ?? {};
          final level = a['dangerLevel'] as int? ?? 0;
          final cat = a['category'] as String? ?? '';
          final summary = a['summary'] as String? ?? '';
          final title = log['videoTitle'] as String? ?? 'Unknown';
          final isRead = a['isRead'] as bool? ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isRead ? Colors.grey.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isRead ? Colors.grey.shade200 : Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: level >= 5 ? Colors.red.shade900 : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Level $level · $cat', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (!isRead) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(title, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('🤖 $summary', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── View All Button ───────────────────────────────────────────────────────

  Widget _buildViewAllButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => YouTubeLogsScreen(
            profileId: widget.profileId,
            profileName: widget.profileName,
          ),
        )),
        icon: const Icon(Icons.list_alt, color: Color(0xFFCC0000)),
        label: Text('Xem tất cả videos', style: GoogleFonts.nunito(color: const Color(0xFFCC0000), fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCC0000)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Widget _sectionCard({required String title, required IconData icon, required Color iconColor, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 6),
                Text(title, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate500, letterSpacing: 0.5)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
