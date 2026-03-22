import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_usage_repository.dart';

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
  final Map<String, bool> _pendingToggle = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final results = await Future.wait([
        _repo.getDailyUsage(widget.profileId, today),
        _repo.getBlockedApps(widget.profileId),
      ]);

      final apps = results[0] as List<AppUsageEntry>;
      final blocked = results[1] as List<BlockedApp>;
      final blockedSet = blocked.map((b) => b.packageName).toSet();

      // Merge: show apps from usage + any already blocked apps not in today's usage
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e'), backgroundColor: Colors.red),
        );
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
        await _repo.addBlockedApp(widget.profileId, pkg, appName: app.appName);
        if (mounted) setState(() => _blockedPackages.add(pkg));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingToggle.remove(pkg));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chặn app — ${widget.profileName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _knownApps.isEmpty
              ? _buildEmptyState()
              : _buildAppList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apps, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Chưa có dữ liệu app',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Khi thiết bị trẻ gửi dữ liệu sử dụng,\ncác app sẽ hiện ở đây.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppList() {
    final blockedApps = _knownApps.where((a) => _blockedPackages.contains(a.packageName)).toList();
    final otherApps = _knownApps.where((a) => !_blockedPackages.contains(a.packageName)).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (blockedApps.isNotEmpty) ...[
            _buildSectionHeader('Đang bị chặn (${blockedApps.length})', Colors.red.shade700),
            ...blockedApps.map((app) => _buildAppTile(app)),
            const Divider(),
          ],
          _buildSectionHeader('App đã dùng hôm nay (${otherApps.length})', Colors.grey.shade700),
          ...otherApps.map((app) => _buildAppTile(app)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAppTile(AppUsageEntry app) {
    final isBlocked = _blockedPackages.contains(app.packageName);
    final isPending = _pendingToggle[app.packageName] ?? false;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isBlocked ? Colors.red.shade50 : Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isBlocked ? Icons.block : Icons.apps,
          color: isBlocked ? Colors.red.shade600 : Colors.indigo.shade400,
          size: 24,
        ),
      ),
      title: Text(
        app.appName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isBlocked ? Colors.red.shade700 : null,
          decoration: isBlocked ? TextDecoration.none : null,
        ),
      ),
      subtitle: Text(
        app.usageSeconds > 0 ? 'Hôm nay: ${app.formattedDuration}' : app.packageName,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isPending
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: isBlocked,
              activeColor: Colors.red,
              onChanged: (_) => _toggleBlock(app),
            ),
    );
  }
}
