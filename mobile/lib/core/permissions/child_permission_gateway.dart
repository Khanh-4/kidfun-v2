import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/native_service.dart';
import 'child_permission.dart';

/// Cầu nối tới hệ điều hành. Tách interface để test không cần máy thật.
abstract class ChildPermissionGateway {
  Future<PermissionSnapshot> snapshot();

  /// Xử lý một quyền đang thiếu. Trả `true` nếu đã mở màn Cài đặt hệ thống
  /// (app rời foreground — lúc quay lại `resumed` sẽ kiểm tra lại);
  /// `false` nếu là hộp thoại quyền ngay trong app và đã có kết quả.
  Future<bool> resolve(MissingPermission missing);
}

class SystemChildPermissionGateway implements ChildPermissionGateway {
  const SystemChildPermissionGateway();

  @override
  Future<PermissionSnapshot> snapshot() async {
    final results = await Future.wait<Object>([
      NativeService.hasUsageStatsPermission(),
      NativeService.isAccessibilityEnabled(),
      Geolocator.isLocationServiceEnabled(),
      Permission.notification.status,
      Geolocator.checkPermission(),
    ]);
    final location = results[4] as LocationPermission;
    return PermissionSnapshot(
      usageStats: results[0] as bool,
      accessibility: results[1] as bool,
      locationServiceOn: results[2] as bool,
      notification: _fromStatus(results[3] as PermissionStatus),
      location: _fromLocation(location),
      backgroundLocation: location == LocationPermission.always
          ? GrantState.granted
          : _fromStatus(await Permission.locationAlways.status),
    );
  }

  @override
  Future<bool> resolve(MissingPermission missing) async {
    switch (missing.permission) {
      case ChildPermission.usageStats:
        await NativeService.requestUsageStatsPermission();
        return true;
      case ChildPermission.accessibility:
        await NativeService.requestAccessibilityPermission();
        return true;
      case ChildPermission.locationService:
        await Geolocator.openLocationSettings();
        return true;
      case ChildPermission.notification:
        if (missing.permanentlyDenied) return _openAppSettings();
        await Permission.notification.request();
        return false;
      case ChildPermission.location:
        if (missing.permanentlyDenied) return _openAppSettings();
        await Geolocator.requestPermission();
        return false;
      case ChildPermission.backgroundLocation:
        if (missing.permanentlyDenied) return _openAppSettings();
        await Permission.locationAlways.request();
        return false;
    }
  }

  Future<bool> _openAppSettings() async {
    await openAppSettings();
    return true;
  }

  static GrantState _fromStatus(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) return GrantState.granted;
    if (s.isPermanentlyDenied) return GrantState.permanentlyDenied;
    return GrantState.denied;
  }

  static GrantState _fromLocation(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return GrantState.granted;
      case LocationPermission.deniedForever:
        return GrantState.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return GrantState.denied;
    }
  }
}
