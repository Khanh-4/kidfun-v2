import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../data/report_repository.dart';

class ActivityHistoryScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const ActivityHistoryScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final _repo = ReportRepository();

  DateTime _selectedDate = DateTime.now();
  List<dynamic> _activities = [];
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
      final items = await _repo.getActivityHistory(widget.profileId, date: _selectedDate);
      setState(() {
        _activities = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi kết nối. Vui lòng thử lại sau.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.slate700,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lịch sử hoạt động', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(widget.profileName, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDatePicker(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _activities.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text('Không có hoạt động nào', style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16)),
                          ]))
                        : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _activities.length,
                          itemBuilder: (_, i) => _buildTimelineItem(_activities[i] as Map<String, dynamic>, i),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: GestureDetector(
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 10),
              Text(
                isToday ? 'Hôm nay (${_selectedDate.day}/${_selectedDate.month})'
                    : '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: AppColors.slate700),
              ),
              const Spacer(),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> activity, int index) {
    final type = activity['type'] as String? ?? '';
    final title = activity['title'] as String? ?? type;
    final description = activity['description'] as String? ?? '';
    final tsStr = activity['timestamp'] as String?;
    DateTime? timestamp;
    if (tsStr != null) timestamp = DateTime.tryParse(tsStr)?.toLocal();

    final config = _typeConfig(type);
    final isLast = index == _activities.length - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 52,
            child: Column(
              children: [
                if (timestamp != null)
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate600),
                  ),
                const SizedBox(height: 4),
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: config.color.withAlpha(25), shape: BoxShape.circle),
                  child: Icon(config.icon, color: config.color, size: 18),
                ),
                if (!isLast)
                  Expanded(child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey.shade200,
                  )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 12, right: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: config.color.withAlpha(51)),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(description, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (!isLast) SizedBox(height: isLast ? 0 : 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _TypeConfig _typeConfig(String type) {
    switch (type) {
      case 'SOS': return _TypeConfig(Icons.sos_rounded, Colors.red.shade900);
      case 'AI_ALERT': return _TypeConfig(Icons.psychology, Colors.red);
      case 'GEOFENCE_ENTER': return _TypeConfig(Icons.login_rounded, Colors.green);
      case 'GEOFENCE_EXIT': return _TypeConfig(Icons.logout_rounded, Colors.orange);
      case 'TIME_EXTENSION': return _TypeConfig(Icons.access_time_filled, Colors.blue);
      case 'WARNING': return _TypeConfig(Icons.notifications, Colors.yellow.shade800);
      case 'SESSION_START': return _TypeConfig(Icons.play_arrow_rounded, AppColors.indigo600);
      case 'SESSION_END': return _TypeConfig(Icons.stop_rounded, Colors.grey);
      default: return _TypeConfig(Icons.circle, Colors.grey);
    }
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

class _TypeConfig {
  final IconData icon;
  final Color color;
  _TypeConfig(this.icon, this.color);
}
