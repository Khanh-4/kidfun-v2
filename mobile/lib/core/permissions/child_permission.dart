import 'package:flutter/material.dart';

/// Các quyền app trẻ cần để theo dõi/chặn app, gửi thông báo và vị trí.
/// Thứ tự khai báo = thứ tự hiển thị trong pop-up (quan trọng nhất trước).
enum ChildPermission {
  usageStats(
    title: 'Đọc dữ liệu sử dụng ứng dụng',
    reason: 'Để phụ huynh xem và quản lý các app con đang dùng.',
    icon: Icons.bar_chart,
  ),
  accessibility(
    title: 'Hỗ trợ tiếp cận (Accessibility)',
    reason: 'Để chặn các ứng dụng khi phụ huynh yêu cầu.',
    icon: Icons.accessibility,
  ),
  notification(
    title: 'Thông báo',
    reason: 'Để nhận cảnh báo hết giờ và chặn app.',
    icon: Icons.notifications_active,
  ),
  locationService(
    title: 'Bật định vị (GPS)',
    reason: 'Định vị đang tắt, phụ huynh không xem được vị trí của con.',
    icon: Icons.gps_fixed,
  ),
  location(
    title: 'Vị trí',
    reason: 'Để gửi vị trí hiện tại cho phụ huynh.',
    icon: Icons.location_on,
  ),
  backgroundLocation(
    title: 'Vị trí chạy ngầm ("Luôn cho phép")',
    reason: 'Để vẫn gửi được vị trí khi con không mở KidFun.',
    icon: Icons.my_location,
  );

  const ChildPermission({
    required this.title,
    required this.reason,
    required this.icon,
  });

  final String title;
  final String reason;
  final IconData icon;

  bool get isLocation =>
      this == location || this == backgroundLocation || this == locationService;
}

enum GrantState { granted, denied, permanentlyDenied }

/// Trạng thái quyền THẬT đọc từ hệ điều hành tại một thời điểm — không dựa
/// vào cờ lưu cục bộ, nên phản ánh đúng cả khi cập nhật/cài lại app.
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.usageStats,
    required this.accessibility,
    required this.locationServiceOn,
    required this.notification,
    required this.location,
    required this.backgroundLocation,
  });

  final bool usageStats;
  final bool accessibility;
  final bool locationServiceOn;
  final GrantState notification;
  final GrantState location;
  final GrantState backgroundLocation;
}

class MissingPermission {
  const MissingPermission(this.permission, {this.permanentlyDenied = false});

  final ChildPermission permission;

  /// Android không cho hỏi lại bằng hộp thoại hệ thống — phải mở Cài đặt.
  final bool permanentlyDenied;
}

List<MissingPermission> computeMissing(PermissionSnapshot s) {
  final hasLocation = s.location == GrantState.granted;
  return [
    if (!s.usageStats) const MissingPermission(ChildPermission.usageStats),
    if (!s.accessibility) const MissingPermission(ChildPermission.accessibility),
    if (s.notification != GrantState.granted)
      MissingPermission(
        ChildPermission.notification,
        permanentlyDenied: s.notification == GrantState.permanentlyDenied,
      ),
    if (!s.locationServiceOn)
      const MissingPermission(ChildPermission.locationService),
    if (!hasLocation)
      MissingPermission(
        ChildPermission.location,
        permanentlyDenied: s.location == GrantState.permanentlyDenied,
      ),
    // Android chỉ cho xin "Luôn cho phép" sau khi đã có vị trí thường.
    if (hasLocation && s.backgroundLocation != GrantState.granted)
      MissingPermission(
        ChildPermission.backgroundLocation,
        permanentlyDenied: s.backgroundLocation == GrantState.permanentlyDenied,
      ),
  ];
}
