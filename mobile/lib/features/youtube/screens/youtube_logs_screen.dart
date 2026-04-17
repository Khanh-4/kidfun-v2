import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';

class YouTubeLogsScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const YouTubeLogsScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<YouTubeLogsScreen> createState() => _YouTubeLogsScreenState();
}

class _YouTubeLogsScreenState extends State<YouTubeLogsScreen> {
  final _dio = DioClient.instance;
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const _limit = 20;

  // Filters
  DateTime? _filterDate;
  double _minDanger = 0;
  String? _filterChannel;

  // Channel options gathered from loaded data
  final Set<String> _channels = {};

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() { _loading = true; _page = 1; _logs = []; _hasMore = true; });
    }
    try {
      final params = <String, dynamic>{
        'page': _page,
        'limit': _limit,
        if (_filterDate != null) 'date': _filterDate!.toIso8601String().substring(0, 10),
        if (_minDanger > 0) 'minDanger': _minDanger.toInt(),
        if (_filterChannel != null) 'channel': _filterChannel,
      };
      final res = await _dio.get('/api/profiles/${widget.profileId}/youtube/logs', queryParameters: params);
      final data = res.data['data'] as Map<String, dynamic>;
      final items = (data['logs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      final total = data['total'] as int? ?? 0;

      // Gather channel names
      for (final log in items) {
        final ch = log['channelName'] as String?;
        if (ch != null && ch.isNotEmpty) _channels.add(ch);
      }

      setState(() {
        if (reset) _logs = items;
        else _logs.addAll(items);
        _hasMore = _logs.length < total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() { _loadingMore = true; _page++; });
    await _load(reset: false);
  }

  Future<void> _toggleBlock(Map<String, dynamic> log) async {
    final isBlocked = log['isBlocked'] as bool? ?? false;
    try {
      if (isBlocked) {
        // Find blockedVideo record: we block by title match
        final res = await _dio.get('/api/profiles/${widget.profileId}/blocked-videos');
        final blocked = (res.data['data']['blockedVideos'] as List? ?? [])
            .firstWhere((b) => b['videoTitle'] == log['videoTitle'], orElse: () => null);
        if (blocked != null) {
          await _dio.delete('/api/blocked-videos/${blocked['id']}');
        }
      } else {
        await _dio.post('/api/profiles/${widget.profileId}/blocked-videos', data: {
          'videoTitle': log['videoTitle'],
          'channelName': log['channelName'],
          'videoId': log['videoId'],
          'reason': 'PARENT_MANUAL',
        });
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        initialDate: _filterDate,
        initialMinDanger: _minDanger,
        initialChannel: _filterChannel,
        channels: _channels.toList()..sort(),
        onApply: (date, danger, channel) {
          setState(() {
            _filterDate = date;
            _minDanger = danger;
            _filterChannel = channel;
          });
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _filterDate != null || _minDanger > 0 || _filterChannel != null;
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lịch sử YouTube', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(widget.profileName, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterSheet),
              if (hasFilter) Positioned(
                right: 8, top: 8,
                child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle)),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : _logs.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Không có video nào', style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16)),
                    if (hasFilter) ...[
                      const SizedBox(height: 8),
                      TextButton(onPressed: () {
                        setState(() { _filterDate = null; _minDanger = 0; _filterChannel = null; });
                        _load();
                      }, child: const Text('Xoá bộ lọc')),
                    ],
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  color: const Color(0xFFCC0000),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _logs.length) return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                      return _buildLogItem(_logs[i]);
                    },
                  ),
                ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final title = log['videoTitle'] as String? ?? 'Không có tiêu đề';
    final channel = log['channelName'] as String? ?? '';
    final duration = (log['durationSeconds'] as int?) ?? 0;
    final dangerLevel = log['dangerLevel'] as int?;
    final category = log['category'] as String?;
    final summary = log['aiSummary'] as String?;
    final isBlocked = log['isBlocked'] as bool? ?? false;
    final isAnalyzed = log['isAnalyzed'] as bool? ?? false;
    final watchedAt = log['watchedAt'] as String?;

    final dangerColor = dangerLevel == null ? Colors.grey
        : dangerLevel >= 5 ? Colors.red.shade900
        : dangerLevel >= 4 ? Colors.red
        : dangerLevel >= 3 ? Colors.orange
        : dangerLevel >= 2 ? Colors.lightGreen
        : Colors.green;

    DateTime? watchedTime;
    if (watchedAt != null) watchedTime = DateTime.tryParse(watchedAt)?.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
        border: isBlocked ? Border.all(color: Colors.red.shade200, width: 1) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Danger badge
                if (dangerLevel != null) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: dangerColor.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 8, color: dangerColor),
                    const SizedBox(width: 4),
                    Text('Level $dangerLevel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: dangerColor)),
                  ]),
                ) else Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                  child: Text(isAnalyzed ? 'SAFE' : 'Chưa phân tích', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
                if (category != null && category != 'SAFE') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: dangerColor.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: Text(category, style: TextStyle(fontSize: 10, color: dangerColor, fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
                if (watchedTime != null)
                  Text(_formatTime(watchedTime), style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate400)),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (channel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(channel, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
            ],
            // Duration
            const SizedBox(height: 4),
            Text('⏱️ ${_formatDuration(duration)}', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate400)),
            // AI Summary
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('🤖 $summary', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate600), maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ],
            const SizedBox(height: 12),
            // Block/Unblock button
            SizedBox(
              width: double.infinity,
              child: isBlocked
                  ? OutlinedButton.icon(
                      onPressed: () => _toggleBlock(log),
                      icon: const Icon(Icons.lock_open_outlined, size: 16),
                      label: const Text('Bỏ chặn video này'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _toggleBlock(log),
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Chặn video này'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Filter Bottom Sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final DateTime? initialDate;
  final double initialMinDanger;
  final String? initialChannel;
  final List<String> channels;
  final void Function(DateTime? date, double danger, String? channel) onApply;

  const _FilterSheet({
    required this.initialDate,
    required this.initialMinDanger,
    required this.initialChannel,
    required this.channels,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _date;
  double _minDanger = 0;
  String? _channel;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _minDanger = widget.initialMinDanger;
    _channel = widget.initialChannel;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Bộ lọc', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () { setState(() { _date = null; _minDanger = 0; _channel = null; }); },
                child: const Text('Xoá tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date picker
          Text('Ngày', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.slate600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.slate200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(_date == null ? 'Tất cả ngày' : '${_date!.day}/${_date!.month}/${_date!.year}',
                    style: GoogleFonts.nunito(color: _date == null ? Colors.grey : AppColors.slate800)),
                  const Spacer(),
                  if (_date != null) GestureDetector(
                    onTap: () => setState(() => _date = null),
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Danger filter
          Row(
            children: [
              Text('Mức độ tối thiểu: ', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.slate600)),
              Text(_minDanger == 0 ? 'Tất cả' : 'Level ${_minDanger.toInt()}+',
                style: GoogleFonts.nunito(color: const Color(0xFFCC0000), fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: _minDanger,
            min: 0,
            max: 5,
            divisions: 5,
            activeColor: const Color(0xFFCC0000),
            onChanged: (v) => setState(() => _minDanger = v),
          ),
          // Channel filter
          if (widget.channels.isNotEmpty) ...[
            Text('Kênh', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.slate600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _channel,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tất cả kênh')),
                ...widget.channels.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _channel = v),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(_date, _minDanger, _channel);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Áp dụng', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
