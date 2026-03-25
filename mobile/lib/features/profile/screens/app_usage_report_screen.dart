import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_usage_repository.dart';

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
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

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
      final data = await _repo.getDailyUsage(widget.profileId, _selectedDate);
      if (mounted) setState(() => _dailyUsage = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e'), backgroundColor: Colors.red),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e'), backgroundColor: Colors.red),
        );
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
    );
    if (picked != null) {
      setState(() => _selectedDate = DateFormat('yyyy-MM-dd').format(picked));
      _loadDailyUsage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Báo cáo sử dụng — ${widget.profileName}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildDailyTab() {
    return Column(
      children: [
        // Date picker
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd/MM/yyyy').format(DateTime.parse(_selectedDate)),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text('Đổi ngày'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildUsageList(_dailyUsage, _isLoadingDaily)),
      ],
    );
  }

  Widget _buildWeeklyTab() {
    if (_isLoadingWeekly) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_weeklyUsage == null || _weeklyUsage!.topApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Không có dữ liệu sử dụng', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadWeeklyUsage, 
              icon: const Icon(Icons.refresh), 
              label: const Text('Thử lại')
            )
          ],
        ),
      );
    }

    final totalFormatted = _formatDuration(_weeklyUsage!.totalWeeklySeconds);
    final avgFormatted = _formatDuration(_weeklyUsage!.dailyAverageSeconds);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryStat('Tổng thời gian', totalFormatted, Icons.timeline),
              Container(width: 1, height: 40, color: Colors.blue.shade200),
              _buildSummaryStat('Trung bình ngày', avgFormatted, Icons.assessment),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildUsageList(_weeklyUsage!.topApps, false, showRefresh: true, onRefresh: _loadWeeklyUsage),
        ),
      ],
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 phút';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}g ${m}p';
    return '${m} phút';
  }

  Widget _buildUsageList(List<AppUsageEntry> items, bool isLoading,
      {bool showRefresh = false, VoidCallback? onRefresh}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Không có dữ liệu sử dụng', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    final maxSeconds = items.first.usageSeconds;
    final totalSeconds = items.fold(0, (sum, e) => sum + e.usageSeconds);

    Widget list = ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = items[index];
        final ratio = maxSeconds > 0 ? entry.usageSeconds / maxSeconds : 0.0;
        final percent = totalSeconds > 0 ? (entry.usageSeconds / totalSeconds * 100).toStringAsFixed(1) : '0.0';

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.appName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            entry.packageName,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          entry.formattedDuration,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '$percent%',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.toDouble(),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _barColor(index),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (showRefresh && onRefresh != null) {
      return RefreshIndicator(onRefresh: () async => onRefresh(), child: list);
    }
    return list;
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
