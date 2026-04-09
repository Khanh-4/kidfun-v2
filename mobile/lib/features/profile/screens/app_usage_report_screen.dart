import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/app_usage_repository.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class AppUsageReportScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const AppUsageReportScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<AppUsageReportScreen> createState() => _AppUsageReportScreenState();
}

class _AppUsageReportScreenState extends State<AppUsageReportScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AppUsageRepository();
  late TabController _tabController;

  List<AppUsageEntry> _dailyUsage = [];
  WeeklyUsageData? _weeklyUsage;
  bool _isLoadingDaily = true;
  bool _isLoadingWeekly = true;
  String _selectedDate =
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDailyUsage();
    _loadWeeklyUsage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyUsage() async {
    setState(() => _isLoadingDaily = true);
    try {
      final data =
          await _repo.getDailyUsage(widget.profileId, _selectedDate);
      if (mounted) setState(() => _dailyUsage = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi tải dữ liệu: $e',
              style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoadingDaily = false);
    }
  }

  Future<void> _loadWeeklyUsage() async {
    setState(() => _isLoadingWeekly = true);
    try {
      final data = await _repo.getWeeklyUsage(widget.profileId);
      if (mounted) setState(() => _weeklyUsage = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi tải dữ liệu: $e',
              style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoadingWeekly = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.indigo600,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() =>
          _selectedDate = DateFormat('yyyy-MM-dd').format(picked));
      _loadDailyUsage();
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 phút';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}g ${m}p';
    return '$m phút';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text('Báo cáo — ${widget.profileName}',
            overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.nunito(),
          tabs: const [
            Tab(text: 'Hôm nay'),
            Tab(text: '7 ngày qua'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyTab(),
          _buildWeeklyTab(),
        ],
      ),
    );
  }

  // ── Daily Tab ─────────────────────────────────────────────────────────────

  Widget _buildDailyTab() {
    return Column(
      children: [
        _buildDateRow(),
        Expanded(
          child: _buildGroupedDailyList(_dailyUsage, _isLoadingDaily),
        ),
      ],
    );
  }

  Widget _buildDateRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.screenPadding, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 18, color: AppColors.slate400),
          const SizedBox(width: 8),
          Text(
            DateFormat('dd/MM/yyyy').format(DateTime.parse(_selectedDate)),
            style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.edit_calendar_outlined,
                size: 16, color: AppColors.indigo600),
            label: Text('Đổi ngày',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.indigo600)),
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedDailyList(
      List<AppUsageEntry> items, bool isLoading) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.indigo600));
    }
    if (items.isEmpty) {
      return _buildEmptyState('Không có dữ liệu sử dụng ngày này');
    }

    final Map<String, List<AppUsageEntry>> byDevice = {};
    for (final entry in items) {
      final key = entry.deviceName ?? 'Thiết bị không xác định';
      byDevice.putIfAbsent(key, () => []).add(entry);
    }

    return RefreshIndicator(
      onRefresh: _loadDailyUsage,
      color: AppColors.indigo600,
      child: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding, vertical: 12),
        children: byDevice.entries.expand((deviceEntry) {
          final deviceItems = deviceEntry.value;
          final maxSeconds = deviceItems.fold(
              0, (m, e) => e.usageSeconds > m ? e.usageSeconds : m);
          final totalSeconds =
              deviceItems.fold(0, (sum, e) => sum + e.usageSeconds);
          return [
            _buildDeviceHeader(deviceEntry.key, totalSeconds),
            const SizedBox(height: 8),
            _buildAppCards(deviceItems, maxSeconds, totalSeconds),
            const SizedBox(height: 16),
          ];
        }).toList(),
      ),
    );
  }

  // ── Weekly Tab ────────────────────────────────────────────────────────────

  Widget _buildWeeklyTab() {
    if (_isLoadingWeekly) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.indigo600));
    }
    if (_weeklyUsage == null || _weeklyUsage!.topApps.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildEmptyState('Không có dữ liệu 7 ngày qua'),
          TextButton.icon(
            onPressed: _loadWeeklyUsage,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.indigo600),
            label: Text('Thử lại',
                style: GoogleFonts.nunito(color: AppColors.indigo600)),
          ),
        ],
      );
    }

    final totalFormatted =
        _formatDuration(_weeklyUsage!.totalWeeklySeconds);
    final avgFormatted =
        _formatDuration(_weeklyUsage!.dailyAverageSeconds);
    final maxSeconds = _weeklyUsage!.topApps.isNotEmpty
        ? _weeklyUsage!.topApps.first.usageSeconds
        : 1;
    final totalSeconds = _weeklyUsage!.topApps
        .fold(0, (sum, e) => sum + e.usageSeconds);

    return Column(
      children: [
        _buildWeeklySummary(totalFormatted, avgFormatted),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadWeeklyUsage,
            color: AppColors.indigo600,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding, vertical: 12),
              children: [
                _buildAppCards(
                    _weeklyUsage!.topApps, maxSeconds, totalSeconds),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklySummary(String total, String avg) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryStat('Tổng thời gian', total,
              Icons.timeline_rounded, AppColors.indigo600),
          Container(width: 1, height: 44, color: AppColors.slate200),
          _buildSummaryStat('Trung bình/ngày', avg,
              Icons.assessment_rounded, AppColors.purple600),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800)),
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 12, color: AppColors.slate500)),
      ],
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────

  Widget _buildDeviceHeader(String deviceName, int totalSeconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.requestBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.indigo600.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded,
              size: 16, color: AppColors.indigo600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(deviceName,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigo600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            _formatDuration(totalSeconds),
            style: GoogleFonts.nunito(
                fontSize: 12, color: AppColors.indigo600),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCards(List<AppUsageEntry> items, int maxSeconds,
      int totalSeconds) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.slate100),
            _buildAppRow(items[i], i, maxSeconds, totalSeconds),
          ],
        ],
      ),
    );
  }

  Widget _buildAppRow(AppUsageEntry entry, int index, int maxSeconds,
      int totalSeconds) {
    final ratio =
        maxSeconds > 0 ? entry.usageSeconds / maxSeconds : 0.0;
    final percent = totalSeconds > 0
        ? (entry.usageSeconds / totalSeconds * 100).toStringAsFixed(1)
        : '0.0';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: index < 3
                      ? AppColors.requestBg
                      : AppColors.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: index < 3
                          ? AppColors.indigo600
                          : AppColors.slate400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.appName,
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.slate800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(entry.packageName,
                        style: GoogleFonts.nunito(
                            fontSize: 11, color: AppColors.slate400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(entry.formattedDuration,
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.slate800)),
                  Text('$percent%',
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: AppColors.slate400)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: AppColors.slate100,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_barColor(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.slate100, shape: BoxShape.circle),
              child: const Icon(Icons.phone_android_rounded,
                  size: 40, color: AppColors.slate400),
            ),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate500)),
          ],
        ),
      ),
    );
  }

  Color _barColor(int index) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFFF472B6),
      Color(0xFF34D399),
      Color(0xFFFBBF24),
      Color(0xFF60A5FA),
      Color(0xFFF87171),
      Color(0xFFA78BFA),
      Color(0xFF2DD4BF),
      Color(0xFFFB923C),
      Color(0xFF94A3B8),
    ];
    return colors[index % colors.length];
  }
}
