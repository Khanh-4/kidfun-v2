import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/widgets.dart';

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  bool _isForeground = true;
  
  Function(Position position)? onLocationUpdate;

  /// Khởi động tracking
  Future<void> start({required Function(Position) onUpdate}) async {
    onLocationUpdate = onUpdate;

    // Kiểm tra quyền
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      print('❌ [LOCATION] Permission denied');
      return;
    }

    // Start với interval tùy theo foreground/background
    _startPeriodicFetch();
    print('✅ [LOCATION] Tracking started');
  }

  void stop() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    print('🛑 [LOCATION] Tracking stopped');
  }

  /// Gọi khi app resume/pause
  void setForeground(bool foreground) {
    if (_isForeground == foreground) return;
    _isForeground = foreground;
    print('🔄 [LOCATION] Foreground: $foreground');
    _locationTimer?.cancel();
    _startPeriodicFetch();
  }

  void _startPeriodicFetch() {
    final interval = _isForeground
        ? const Duration(seconds: 30)
        : const Duration(minutes: 5);

    // Fetch ngay lập tức
    _fetchAndNotify();

    // Rồi fetch định kỳ
    _locationTimer = Timer.periodic(interval, (_) => _fetchAndNotify());
  }

  Future<void> _fetchAndNotify() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Chỉ update khi di chuyển > 10m
        ),
      );
      onLocationUpdate?.call(position);
      print('📍 [LOCATION] ${position.latitude}, ${position.longitude} (±${position.accuracy}m)');
    } catch (e) {
      print('❌ [LOCATION] Fetch error: $e');
    }
  }

  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Lấy vị trí hiện tại 1 lần (cho SOS)
  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      return null;
    }
  }
}
