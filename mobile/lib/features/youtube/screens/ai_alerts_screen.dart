import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';

class AIAlertsScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const AIAlertsScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<AIAlertsScreen> createState() => _AIAlertsScreenState();
}

class _AIAlertsScreenState extends State<AIAlertsScreen> with SingleTickerProviderStateMixin {
  final _dio = DioClient.instance;
  late TabController _tabController;

  List<Map<String, dynamic>> _allAlerts = [];
  List<Map<String, dynamic>> _unreadAlerts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/api/profiles/${widget.profileId}/ai-alerts');
      final alerts = (res.data['data']['alerts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _allAlerts = alerts;
        _unreadAlerts = alerts.where((a) => a['isRead'] == false).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Lỗi kết nối mạng, vui lòng thử lại';
      });
    }
  }

  Future<void> _markRead(int alertId) async {
    try {
      await _dio.put('/api/ai-alerts/$alertId/read');
      setState(() {
        for (final a in _allAlerts) {
          if (a['id'] == alertId) a['isRead'] = true;
        }
        _unreadAlerts = _allAlerts.where((a) => a['isRead'] == false).toList();
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final unread = _unreadAlerts.toList();
    for (final a in unread) {
      await _markRead(a['id'] as int);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trung tâm cảnh báo AI', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(widget.profileName, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_unreadAlerts.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Đọc tất cả', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Chưa đọc'),
                if (_unreadAlerts.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Colors.yellow.shade700, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_unreadAlerts.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ],
              ]),
            ),
            const Tab(text: 'Tất cả'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, style: GoogleFonts.nunito(fontSize: 16, color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: Text('Thử lại', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _AlertsList(alerts: _unreadAlerts, onMarkRead: _markRead, emptyText: 'Không có cảnh báo chưa đọc 🎉', onRefresh: _load),
                    _AlertsList(alerts: _allAlerts, onMarkRead: _markRead, emptyText: 'Chưa có cảnh báo nào', onRefresh: _load),
                  ],
                ),
    );
  }
}

class _AlertsList extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  final Future<void> Function(int id) onMarkRead;
  final String emptyText;
  final Future<void> Function() onRefresh;

  const _AlertsList({required this.alerts, required this.onMarkRead, required this.emptyText, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: Colors.red.shade800,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(emptyText, style: GoogleFonts.nunito(color: Colors.grey, fontSize: 15)),
                ]),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.red.shade800,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: alerts.length,
        itemBuilder: (_, i) => _AlertCard(alert: alerts[i], onMarkRead: onMarkRead),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final Future<void> Function(int id) onMarkRead;

  const _AlertCard({required this.alert, required this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    final id = alert['id'] as int;
    final level = alert['dangerLevel'] as int? ?? 0;
    final category = alert['category'] as String? ?? '';
    final summary = alert['summary'] as String? ?? '';
    final isRead = alert['isRead'] as bool? ?? false;
    final createdAt = alert['createdAt'] as String?;
    final log = alert['youtubeLog'] as Map? ?? {};
    final title = log['videoTitle'] as String? ?? 'Không có tiêu đề';
    final channel = log['channelName'] as String? ?? '';

    final color = level >= 5 ? Colors.red.shade900 : level >= 4 ? Colors.red : Colors.orange;
    DateTime? time;
    if (createdAt != null) time = DateTime.tryParse(createdAt)?.toLocal();

    return GestureDetector(
      onTap: () { if (!isRead) onMarkRead(id); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))],
          border: Border.all(color: isRead ? Colors.transparent : Colors.red.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                    child: Icon(Icons.psychology, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                          child: Text('Level $level · $category', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        ],
                      ]),
                      if (time != null) ...[
                        const SizedBox(height: 2),
                        Text(_formatTime(time), style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate400)),
                      ],
                    ],
                  )),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (channel.isNotEmpty)
                Text(channel, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('🤖 $summary', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate600), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (!isRead) ...[
                const SizedBox(height: 8),
                Text('Nhấn để đánh dấu đã đọc', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate400, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
