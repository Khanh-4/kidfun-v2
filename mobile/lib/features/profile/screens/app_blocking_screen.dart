import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_usage_repository.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class AppBlockingScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const AppBlockingScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<AppBlockingScreen> createState() => _AppBlockingScreenState();
}

class _AppBlockingScreenState extends State<AppBlockingScreen> {
  final _repo = AppUsageRepository();

  List<AppUsageEntry> _knownApps = [];
  Set<String> _blockedPackages = {};
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, bool> _pendingToggle = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _repo.getAllApps(widget.profileId),
        _repo.getBlockedApps(widget.profileId),
      ]);
      final apps = results[0] as List<AppUsageEntry>;
      final blocked = results[1] as List<BlockedApp>;
      final blockedSet = blocked.map((b) => b.packageName).toSet();

      final Map<String, AppUsageEntry> appMap = {
        for (final a in apps) a.packageName: a,
      };
      for (final b in blocked) {
        if (!appMap.containsKey(b.packageName)) {
          appMap[b.packageName] = AppUsageEntry(
            packageName: b.packageName,
            appName: b.appName ?? b.packageName,
            usageSeconds: 0,
          );
        }
      }
      if (mounted) {
        setState(() {
          _knownApps = appMap.values.toList()
            ..sort((a, b) => b.usageSeconds.compareTo(a.usageSeconds));
          _blockedPackages = blockedSet;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Lỗi kết nối. Vui lòng thử lại sau.');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi tải dữ liệu: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlock(AppUsageEntry app) async {
    final pkg = app.packageName;
    final isCurrentlyBlocked = _blockedPackages.contains(pkg);
    setState(() => _pendingToggle[pkg] = true);
    try {
      if (isCurrentlyBlocked) {
        await _repo.removeBlockedApp(widget.profileId, pkg);
        if (mounted) setState(() => _blockedPackages.remove(pkg));
      } else {
        await _repo.addBlockedApp(widget.profileId, pkg,
            appName: app.appName);
        if (mounted) setState(() => _blockedPackages.add(pkg));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _pendingToggle.remove(pkg));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text('Chặn app — ${widget.profileName}',
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
          : _errorMessage != null
              ? _buildErrorPlaceholder()
              : _knownApps.isEmpty
                  ? _buildEmptyState()
                  : _buildAppList(),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Lỗi: $_errorMessage', 
               textAlign: TextAlign.center,
               style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: AppColors.requestBg, shape: BoxShape.circle),
              child: const Icon(Icons.apps_rounded,
                  size: 40, color: AppColors.indigo600),
            ),
            const SizedBox(height: 16),
            Text('Chưa có dữ liệu ứng dụng',
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate700)),
            const SizedBox(height: 8),
            Text(
              'Khi thiết bị con gửi dữ liệu sử dụng,\ncác ứng dụng sẽ hiện ở đây.',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.nunito(fontSize: 13, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppList() {
    final Map<String, List<AppUsageEntry>> byDevice = {};
    for (final app in _knownApps) {
      final key = app.deviceName ?? 'Thiết bị không xác định';
      byDevice.putIfAbsent(key, () => []).add(app);
    }
    final blockedApps =
        _knownApps.where((a) => _blockedPackages.contains(a.packageName)).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.indigo600,
      child: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding, vertical: 12),
        children: [
          if (blockedApps.isNotEmpty) ...[
            _buildSectionLabel(
              'Đang bị chặn (${blockedApps.length})',
              AppColors.danger,
              AppColors.dangerBg,
              Icons.block_rounded,
            ),
            const SizedBox(height: 8),
            _buildAppGroup(blockedApps),
            const SizedBox(height: 16),
          ],
          ...byDevice.entries.expand((entry) {
            final unblocked = entry.value
                .where((a) => !_blockedPackages.contains(a.packageName))
                .toList();
            if (unblocked.isEmpty) return <Widget>[];
            return [
              _buildDeviceLabel(entry.key),
              const SizedBox(height: 8),
              _buildAppGroup(unblocked),
              const SizedBox(height: 16),
            ];
          }),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(
      String text, Color color, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildDeviceLabel(String deviceName) {
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
        ],
      ),
    );
  }

  Widget _buildAppGroup(List<AppUsageEntry> apps) {
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
          for (int i = 0; i < apps.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.slate100),
            _buildAppTile(apps[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildAppTile(AppUsageEntry app) {
    final isBlocked = _blockedPackages.contains(app.packageName);
    final isPending = _pendingToggle[app.packageName] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isBlocked ? AppColors.dangerBg : AppColors.requestBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isBlocked ? Icons.block_rounded : Icons.apps_rounded,
              color: isBlocked ? AppColors.danger : AppColors.indigo600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isBlocked ? AppColors.danger : AppColors.slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  app.usageSeconds > 0
                      ? 'Tổng dùng: ${app.formattedDuration}'
                      : app.packageName,
                  style: GoogleFonts.nunito(
                      fontSize: 11, color: AppColors.slate400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isPending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.indigo600),
                )
              : Switch(
                  value: isBlocked,
                  activeThumbColor: AppColors.danger,
                  inactiveThumbColor: AppColors.slate400,
                  onChanged: (_) => _toggleBlock(app),
                ),
        ],
      ),
    );
  }
}
