import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';

class PerAppTimeLimitScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const PerAppTimeLimitScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<PerAppTimeLimitScreen> createState() => _PerAppTimeLimitScreenState();
}

class _PerAppTimeLimitScreenState extends State<PerAppTimeLimitScreen> {
  final _dio = DioClient.instance;

  List<Map<String, dynamic>> _apps = [];
  List<Map<String, dynamic>> _limits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _dio.get('/api/profiles/${widget.profileId}/all-apps'),
        _dio.get('/api/profiles/${widget.profileId}/app-time-limits'),
      ]);

      final appsData = results[0].data['data']['apps'] as List? ?? [];
      final limitsData = results[1].data['data']?['limits'] as List? ?? [];

      if (mounted) {
        setState(() {
          _apps = appsData.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
          _limits = limitsData.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int? _getLimitForApp(String packageName) {
    final limit = _limits.firstWhere(
      (l) => l['packageName'] == packageName,
      orElse: () => {},
    );
    return limit.isEmpty ? null : (limit['dailyLimitMinutes'] as num?)?.toInt();
  }

  Future<void> _setLimit(String packageName, String appName, int? currentLimit) async {
    final controller = TextEditingController(
      text: currentLimit?.toString() ?? '',
    );

    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('⏰ Giới hạn cho $appName',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nhập số phút sử dụng tối đa mỗi ngày.\nĐể trống và nhấn "Xóa" để bỏ giới hạn.',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số phút / ngày',
                labelStyle: GoogleFonts.nunito(),
                hintText: 'vd: 30',
                hintStyle: GoogleFonts.nunito(color: AppColors.slate300),
                suffixText: 'phút',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (currentLimit != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, -1), // sentinel: remove
              child: Text('Xóa giới hạn',
                  style: GoogleFonts.nunito(color: AppColors.danger, fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx, val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Vui lòng nhập số phút hợp lệ', style: GoogleFonts.nunito()),
                ));
              }
            },
            child: Text('Lưu', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      if (result == -1) {
        // Remove limit
        await _dio.delete(
          '/api/profiles/${widget.profileId}/app-time-limits/${Uri.encodeComponent(packageName)}',
        );
      } else {
        // Upsert limit
        await _dio.post(
          '/api/profiles/${widget.profileId}/app-time-limits',
          data: {
            'packageName': packageName,
            'appName': appName,
            'dailyLimitMinutes': result,
          },
        );
      }
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            result == -1 ? 'Đã xóa giới hạn cho $appName' : 'Đã đặt giới hạn ${result}p cho $appName',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text('Giới hạn app — ${widget.profileName}',
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apps.isEmpty
              ? _buildEmptyState()
              : _buildAppList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: AppColors.requestBg, shape: BoxShape.circle),
            child: const Icon(Icons.timer_off_outlined, size: 40, color: AppColors.indigo600),
          ),
          const SizedBox(height: 16),
          Text('Chưa có dữ liệu ứng dụng',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate700)),
          const SizedBox(height: 8),
          Text('Khi thiết bị con gửi dữ liệu,\ncác ứng dụng sẽ hiện ở đây.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate400)),
        ],
      ),
    );
  }

  Widget _buildAppList() {
    // Apps with limits first
    final withLimit = _apps.where((a) => _getLimitForApp(a['packageName']) != null).toList();
    final withoutLimit = _apps.where((a) => _getLimitForApp(a['packageName']) == null).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.indigo600,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding, vertical: 12),
        children: [
          if (withLimit.isNotEmpty) ...[
            _buildSectionLabel('Đang giới hạn (${withLimit.length})', AppColors.warningDark, AppColors.warningBg, Icons.timer_rounded),
            const SizedBox(height: 8),
            _buildAppGroup(withLimit),
            const SizedBox(height: 16),
          ],
          if (withoutLimit.isNotEmpty) ...[
            _buildSectionLabel('Tất cả ứng dụng (${withoutLimit.length})', AppColors.indigo600, AppColors.requestBg, Icons.apps_rounded),
            const SizedBox(height: 8),
            _buildAppGroup(withoutLimit),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, Color color, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildAppGroup(List<Map<String, dynamic>> apps) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < apps.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.slate100),
            _buildAppTile(apps[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildAppTile(Map<String, dynamic> app) {
    final pkg = app['packageName'] as String;
    final name = (app['appName'] as String?) ?? pkg;
    final limit = _getLimitForApp(pkg);
    final hasLimit = limit != null;

    return InkWell(
      onTap: () => _setLimit(pkg, name, limit),
      borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: hasLimit ? AppColors.warningBg : AppColors.requestBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasLimit ? Icons.timer_rounded : Icons.apps_rounded,
                color: hasLimit ? AppColors.warningDark : AppColors.indigo600,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.slate800,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    hasLimit ? 'Giới hạn: $limit phút / ngày' : pkg,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: hasLimit ? AppColors.warningDark : AppColors.slate400,
                      fontWeight: hasLimit ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_rounded, size: 18,
                color: hasLimit ? AppColors.warningDark : AppColors.slate300),
          ],
        ),
      ),
    );
  }
}
