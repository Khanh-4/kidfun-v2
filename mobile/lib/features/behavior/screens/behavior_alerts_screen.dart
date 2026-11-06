import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/behavior_alert.dart';
import '../data/behavior_alert_repository.dart';

/// Cảnh báo hành vi của một trẻ (đồ án chuyên ngành, T7.4): câu giải thích + 2 nút phản hồi.
///
/// Mở từ menu hồ sơ trẻ, hoặc từ thông báo FCM `BEHAVIOR_ALERT` (khi đó [highlightAlertId] = cảnh báo vừa nhận,
/// được đánh dấu "Vừa nhận" và cuộn tới). Phản hồi "Được phép" giúp tác vụ ban đêm nới ngưỡng tầng 1.
class BehaviorAlertsScreen extends StatefulWidget {
  final int profileId;
  final String profileName;
  final int? highlightAlertId;
  final BehaviorAlertRepository? repository;

  const BehaviorAlertsScreen({
    super.key,
    required this.profileId,
    required this.profileName,
    this.highlightAlertId,
    this.repository,
  });

  @override
  State<BehaviorAlertsScreen> createState() => _BehaviorAlertsScreenState();
}

class _BehaviorAlertsScreenState extends State<BehaviorAlertsScreen> {
  late final BehaviorAlertRepository _repo = widget.repository ?? BehaviorAlertRepository();
  final _highlightKey = GlobalKey();

  List<BehaviorAlert> _alerts = const [];
  final Set<int> _sending = {};
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
      final alerts = await _repo.list(widget.profileId);
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlight());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được cảnh báo, vui lòng kiểm tra mạng.';
      });
    }
  }

  void _scrollToHighlight() {
    final ctx = _highlightKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
  }

  Future<void> _send(BehaviorAlert alert, String feedback) async {
    setState(() => _sending.add(alert.id));
    try {
      await _repo.sendFeedback(alert.id, feedback);
      if (!mounted) return;
      setState(() {
        _alerts = [for (final a in _alerts) a.id == alert.id ? a.withFeedback(feedback) : a];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không gửi được phản hồi, vui lòng thử lại.')),
      );
    } finally {
      if (mounted) setState(() => _sending.remove(alert.id));
    }
  }

  Future<void> _askAllowedReason(BehaviorAlert alert) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Vì sao lần này được phép?', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final entry in AlertFeedback.allowedReasons.entries)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                title: Text(entry.value),
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (reason != null) await _send(alert, reason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cảnh báo hành vi · ${widget.profileName}')),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(child: FilledButton(onPressed: _load, child: const Text('Thử lại'))),
      ]);
    }
    if (_alerts.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: const [
        Text('Chưa có cảnh báo nào. KidFun sẽ báo khi bé dùng máy khác thường.', textAlign: TextAlign.center),
      ]);
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Column(children: [for (final a in _alerts) _card(a)]),
    );
  }

  Widget _card(BehaviorAlert alert) {
    final isHighlight = alert.id == widget.highlightAlertId;
    return Card(
      key: isHighlight ? _highlightKey : ValueKey(alert.id),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isHighlight ? AppColors.warning : AppColors.infoBorder, width: isHighlight ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _chip(alert.sourceLabel, AppColors.info, AppColors.infoBg),
            if (isHighlight) ...[const SizedBox(width: 6), _chip('Vừa nhận', AppColors.warningDark, AppColors.warningBg)],
            const Spacer(),
            Text(_time(alert.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          Text(alert.message, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 10),
          _feedbackArea(alert),
        ]),
      ),
    );
  }

  Widget _feedbackArea(BehaviorAlert alert) {
    if (alert.hasFeedback) {
      return Text(AlertFeedback.label(alert.feedback!),
          style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600));
    }
    if (_sending.contains(alert.id)) return const LinearProgressIndicator();
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => _send(alert, AlertFeedback.confirmed),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Đúng là bất thường'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton(
          onPressed: () => _askAllowedReason(alert),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
          child: const Text('Được phép'),
        ),
      ),
    ]);
  }

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
      );

  String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} ${two(t.day)}/${two(t.month)}';
  }
}
