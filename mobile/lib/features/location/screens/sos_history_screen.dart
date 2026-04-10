import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';

class SosHistoryScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const SosHistoryScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchSOSHistory();
  }

  Future<void> _fetchSOSHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await DioClient.instance.get(
        '/api/profiles/${widget.profileId}/sos',
      );
      final data = resp.data as Map<String, dynamic>;
      final list = (data['data']?['alerts'] ?? data['alerts'] ?? []) as List<dynamic>;
      setState(() {
        _alerts = list.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Không thể tải lịch sử SOS: $e';
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '—';
    try {
      return DateFormat('HH:mm  dd/MM/yyyy').format(DateTime.parse(isoTime).toLocal());
    } catch (_) {
      return isoTime;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'RESOLVED':
        return AppColors.emerald400;
      case 'ACKNOWLEDGED':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'RESOLVED':
        return 'Đã giải quyết';
      case 'ACKNOWLEDGED':
        return 'Đã xác nhận';
      default:
        return 'Chưa xử lý';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text(
          'Lịch sử SOS — ${widget.profileName}',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _fetchSOSHistory,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.indigo600));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(color: AppColors.danger)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchSOSHistory,
                child: Text('Thử lại', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }
    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded, size: 40, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text('Chưa có sự kiện SOS nào',
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate700)),
            const SizedBox(height: 8),
            Text('Tất cả cảnh báo SOS sẽ xuất hiện ở đây',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchSOSHistory,
      color: AppColors.indigo600,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildSOSCard(_alerts[index]),
      ),
    );
  }

  Widget _buildSOSCard(Map<String, dynamic> alert) {
    final status = alert['status'] as String?;
    final audioUrl = alert['audioUrl'] as String?;
    final lat = (alert['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (alert['longitude'] as num?)?.toDouble() ?? 0.0;
    final createdAt = alert['createdAt'] as String?;

    return GestureDetector(
      onTap: () {
        // TC-15 B6: Tap to open SOS detail with audio playback + map
        context.push('/sos-alert', extra: {
          'profileName': widget.profileName,
          'latitude': lat,
          'longitude': lng,
          'audioUrl': audioUrl,
          'phone': null,
          'sosTime': createdAt,
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          border: Border.all(
            color: status == 'ACTIVE' ? Colors.red.shade200 : AppColors.slate200,
            width: status == 'ACTIVE' ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // SOS icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sos_rounded,
                  color: _statusColor(status), size: 24),
            ),
            const SizedBox(width: 14),
            // Date + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Text(_formatTime(createdAt),
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                      if (audioUrl != null && audioUrl.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.indigo600.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mic, size: 10,
                                  color: AppColors.indigo600),
                              const SizedBox(width: 2),
                              Text('Có ghi âm',
                                  style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.indigo600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.slate400, size: 22),
          ],
        ),
      ),
    );
  }
}
