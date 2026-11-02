import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'child_permission.dart';
import 'child_permission_gateway.dart';

/// Rà soát quyền thật của máy trẻ và hiện MỘT pop-up liệt kê mọi quyền thiếu.
///
/// Gọi `check()` khi màn hình mở và mỗi lần app `resumed` — vì đọc trạng
/// thái thật từ hệ điều hành nên tự bắt được trường hợp quyền bị thu hồi sau
/// khi cập nhật/cài lại app, không cần cờ "lần đầu mở app".
class ChildPermissionGuard {
  ChildPermissionGuard({
    ChildPermissionGateway? gateway,
    this.onLocationGranted,
    this.allowDismiss = false,
  }) : _gateway = gateway ?? const SystemChildPermissionGateway();

  final ChildPermissionGateway _gateway;

  /// Gọi khi quyền vị trí vừa chuyển từ thiếu → đủ (để khởi động lại tracking).
  final VoidCallback? onLocationGranted;

  /// Cho phép bấm "Để sau". Màn ghép nối bật (người lớn đang cài đặt máy,
  /// không nên bị chặn ghép nối); màn hình trẻ tắt để trẻ không bỏ qua được.
  final bool allowDismiss;

  bool _busy = false;
  bool _locationWasMissing = false;

  Future<void> check(BuildContext context) async {
    // Hộp thoại quyền hệ thống làm app inactive → resumed, gọi check lần nữa
    // trong khi lần trước chưa xong: bỏ qua để không chồng 2 pop-up.
    if (_busy) return;
    _busy = true;
    try {
      while (context.mounted) {
        final missing = computeMissing(await _gateway.snapshot());
        _trackLocation(missing);
        if (missing.isEmpty || !context.mounted) return;

        final choice = await showDialog<MissingPermission>(
          context: context,
          barrierDismissible: false,
          builder: (_) => MissingPermissionsDialog(
            missing: missing,
            allowDismiss: allowDismiss,
          ),
        );
        if (choice == null) return;

        final leftApp = await _gateway.resolve(choice);
        // Đã sang màn Cài đặt: lúc quay lại `resumed` sẽ gọi check() mới.
        if (leftApp) return;
      }
    } catch (e) {
      debugPrint('❌ [PERMISSION] Kiểm tra quyền thất bại: $e');
    } finally {
      _busy = false;
    }
  }

  void _trackLocation(List<MissingPermission> missing) {
    final isMissing = missing.any((m) => m.permission.isLocation);
    if (_locationWasMissing && !isMissing) onLocationGranted?.call();
    _locationWasMissing = isMissing;
  }
}

class MissingPermissionsDialog extends StatelessWidget {
  const MissingPermissionsDialog({
    super.key,
    required this.missing,
    this.allowDismiss = false,
  });

  final List<MissingPermission> missing;
  final bool allowDismiss;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: allowDismiss,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF6366f1)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'KidFun còn thiếu ${missing.length} quyền',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cấp đủ các quyền dưới đây để KidFun hoạt động đầy đủ:',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
              const SizedBox(height: 12),
              for (final m in missing) _MissingTile(missing: m),
            ],
          ),
        ),
        actions: [
          if (allowDismiss)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Để sau', style: GoogleFonts.nunito()),
            ),
        ],
      ),
    );
  }
}

class _MissingTile extends StatelessWidget {
  const _MissingTile({required this.missing});

  final MissingPermission missing;

  bool get _opensSettings =>
      missing.permanentlyDenied ||
      missing.permission == ChildPermission.usageStats ||
      missing.permission == ChildPermission.accessibility ||
      missing.permission == ChildPermission.locationService;

  @override
  Widget build(BuildContext context) {
    final p = missing.permission;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(p.icon, color: const Color(0xFF6366f1), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title,
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(p.reason, style: GoogleFonts.nunito(fontSize: 13)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    key: ValueKey('fix-${p.name}'),
                    onPressed: () => Navigator.pop(context, missing),
                    icon: Icon(_opensSettings ? Icons.settings : Icons.check,
                        size: 16),
                    label: Text(
                      _opensSettings ? 'Mở Cài đặt' : 'Cấp quyền',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
