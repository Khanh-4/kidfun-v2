# KidFun V3 — Sprint 7: GPS, Geofencing & SOS — FRONTEND (Flutter + Kotlin)

> **Sprint Goal:** Tích hợp Mapbox, GPS tracking (30s/5min), Geofence UI, SOS với ghi âm + gọi lại
> **Branch gốc:** `develop`
> **Map:** Mapbox (`mapbox_maps_flutter` package)

---

## Tổng quan Sprint 7 — Frontend Tasks

| Task | Nội dung | Phụ thuộc (Backend) |
|------|----------|---------------------|
| **Task 1** | Mapbox setup + API token | Không |
| **Task 2** | GPS tracking service (linh hoạt 30s/5min) | Backend Task 2 |
| **Task 3** | Child App: Location sync + background | Backend Task 2 |
| **Task 4** | Parent App: Map screen với marker vị trí real-time | Backend Task 2, 6 |
| **Task 5** | Parent App: Geofence UI (tạo/sửa/xóa trên bản đồ) | Backend Task 3 |
| **Task 6** | Parent App: Lịch sử vị trí + geofence events | Backend Task 2, 3 |
| **Task 7** | Child App: Nút SOS + ghi âm 15s | Backend Task 5 |
| **Task 8** | Parent App: SOS Alert screen + nghe audio + gọi lại | Backend Task 5 |
| **Task 9** | Integration test | Backend Task 8 |

---

## Task 1: Mapbox Setup

> **Branch:** `feature/mobile/mapbox-setup`

### 1.1: Đăng ký Mapbox

1. Vào https://account.mapbox.com/ → sign up
2. **Account → Access tokens** → Copy default public token (`pk.xxx`)
3. Tạo secret token (`sk.xxx`) cho download SDK — cần scope `DOWNLOADS:READ`

### 1.2: Cài package

```bash
cd mobile
flutter pub add mapbox_maps_flutter
```

### 1.3: Android config

File sửa: `mobile/android/gradle.properties`

```properties
MAPBOX_DOWNLOADS_TOKEN=sk.xxxxxxxxxxxxx
```

File sửa: `mobile/android/build.gradle.kts` (project level)

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").get()
            }
        }
    }
}
```

File sửa: `mobile/android/app/src/main/AndroidManifest.xml`

```xml
<!-- Permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

### 1.4: Khởi tạo Mapbox trong Flutter

File sửa: `mobile/lib/main.dart`

```dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mapbox access token
  MapboxOptions.setAccessToken('pk.xxxxxxxxxxxxx');
  
  // ... existing init code ...
  runApp(const MyApp());
}
```

### 1.5: Lưu token vào env file (KHÔNG commit)

File tạo: `mobile/.env`

```
MAPBOX_PUBLIC_TOKEN=pk.xxxxxxxxxxxxx
```

Add vào `.gitignore`:

```
mobile/.env
android/gradle.properties
```

### Commit:

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/mapbox-setup
git commit -m "feat(mobile): setup Mapbox SDK and permissions"
git push origin feature/mobile/mapbox-setup
```
→ PR → develop → merge

**Lưu ý:** KHÔNG commit token thật vào git. Dùng placeholder, bạn frontend tự thay token khi build.

---

## Task 2: GPS Tracking Service

> **Branch:** `feature/mobile/gps-tracking`

### 2.1: Cài geolocator

```bash
flutter pub add geolocator
```

### 2.2: Location Service

File tạo mới: `mobile/lib/core/services/location_service.dart`

```dart
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
```

### 2.3: Lifecycle observer để đổi foreground/background

File sửa: `mobile/lib/app.dart`

```dart
class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    LocationService.instance.setForeground(isForeground);
  }
}
```

### Commit:

```bash
git commit -m "feat(mobile): add GPS tracking service with flexible interval"
```

---

## Task 3: Child App — Location Sync

> **Branch:** `feature/mobile/child-location-sync`

### 3.1: Location Repository

File tạo mới: `mobile/lib/features/location/data/location_repository.dart`

```dart
import 'package:dio/dio.dart';

class LocationRepository {
  final Dio _dio;
  LocationRepository(this._dio);

  Future<void> syncLocation({
    required String deviceCode,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    await _dio.post('/api/child/location', data: {
      'deviceCode': deviceCode,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'source': 'GPS',
    });
  }
}
```

### 3.2: Start location tracking trong ChildDashboard

```dart
@override
void initState() {
  super.initState();
  _startLocationTracking();
}

void _startLocationTracking() {
  if (_deviceCode == null) return;
  
  LocationService.instance.start(onUpdate: (position) async {
    try {
      await _locationRepo.syncLocation(
        deviceCode: _deviceCode!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
      print('✅ [LOCATION SYNC] Sent to server');
    } catch (e) {
      print('❌ [LOCATION SYNC] Error: $e');
    }
  });
}

@override
void dispose() {
  LocationService.instance.stop();
  super.dispose();
}
```

### 3.3: Request permission flow

Thêm vào onboarding/permission screen:

```dart
ElevatedButton(
  onPressed: () async {
    // Request foreground location first
    await Geolocator.requestPermission();
    
    // Then request background (Android 10+)
    if (Platform.isAndroid) {
      final status = await Permission.locationAlways.request();
      if (status.isGranted) {
        print('✅ Background location granted');
      }
    }
  },
  child: const Text('Cấp quyền vị trí'),
)
```

### Commit:

```bash
git commit -m "feat(mobile): child app sync location to server"
```

---

## Task 4: Parent App — Map Screen

> **Branch:** `feature/mobile/parent-map-screen`

### 4.1: Màn hình Map

File tạo mới: `mobile/lib/features/location/screens/map_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final int profileId;
  final String profileName;
  
  const MapScreen({super.key, required this.profileId, required this.profileName});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;
  PointAnnotation? _childMarker;

  @override
  void initState() {
    super.initState();
    _listenLocationUpdates();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final location = await _locationRepo.getCurrentLocation(widget.profileId);
      if (location != null) {
        _updateChildMarker(location.latitude, location.longitude);
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  void _listenLocationUpdates() {
    SocketService.instance.socket.on('locationUpdated', (data) {
      if (data['profileId'] == widget.profileId) {
        _updateChildMarker(data['latitude'], data['longitude']);
      }
    });
  }

  Future<void> _updateChildMarker(double lat, double lng) async {
    if (_mapboxMap == null || _annotationManager == null) return;

    final point = Point(coordinates: Position(lng, lat));
    
    if (_childMarker == null) {
      _childMarker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: point,
          iconSize: 1.5,
          iconImage: 'marker-15', // Default Mapbox marker
        ),
      );
    } else {
      _childMarker!.geometry = point;
      await _annotationManager!.update(_childMarker!);
    }

    // Center map
    _mapboxMap!.setCamera(CameraOptions(
      center: point,
      zoom: 15.0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vị trí ${widget.profileName}')),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(106.660172, 10.762622)), // HCM default
          zoom: 12.0,
        ),
        onMapCreated: (MapboxMap mapboxMap) async {
          _mapboxMap = mapboxMap;
          _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
```

### Commit:

```bash
git commit -m "feat(mobile): parent map screen with real-time location"
```

---

## Task 5: Parent App — Geofence UI

> **Branch:** `feature/mobile/geofence-ui`

### 5.1: Geofence list screen

- Danh sách geofences (name, address, radius, toggle active)
- Nút "Thêm mới" → mở map để chọn vị trí

### 5.2: Geofence create screen

File tạo mới: `mobile/lib/features/geofence/screens/geofence_create_screen.dart`

- Map Mapbox fullscreen
- Tap để chọn vị trí → hiện marker
- Slider chọn radius (50-5000m)
- Vẽ circle polygon theo radius
- Text field nhập tên
- Nút "Lưu" → POST API

```dart
// Vẽ circle bằng CircleAnnotationManager
CircleAnnotationOptions(
  geometry: Point(coordinates: Position(lng, lat)),
  circleRadius: _calculateCircleRadius(radius, zoom),
  circleColor: 0x3300FF00,
  circleStrokeColor: 0xFF00FF00,
  circleStrokeWidth: 2.0,
)
```

### 5.3: Listen geofence events

```dart
SocketService.instance.socket.on('geofenceEvent', (data) {
  final type = data['type']; // ENTER | EXIT
  final geofenceName = data['geofenceName'];
  final profileName = data['profileName'];
  
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(type == 'ENTER' ? 'Vào vùng an toàn' : 'Rời vùng an toàn'),
      content: Text('$profileName ${type == 'ENTER' ? 'đã vào' : 'đã rời'} $geofenceName'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );
});
```

### Commit:

```bash
git commit -m "feat(mobile): parent geofence UI with map-based creation"
```

---

## Task 6: Lịch sử Vị trí + Geofence Events

> **Branch:** `feature/mobile/location-history`

### 6.1: Location History Screen

- Chọn ngày (DatePicker)
- Map hiển thị polyline vẽ đường đi
- List events phía dưới (time + place)

```dart
// Vẽ polyline
await _mapboxMap!.style.addSource(GeoJsonSource(
  id: 'route',
  data: jsonEncode({
    'type': 'Feature',
    'geometry': {
      'type': 'LineString',
      'coordinates': history.map((l) => [l.longitude, l.latitude]).toList(),
    },
  }),
));

await _mapboxMap!.style.addLayer(LineLayer(
  id: 'route-line',
  sourceId: 'route',
  lineColor: 0xFF0000FF,
  lineWidth: 4.0,
));
```

### 6.2: Geofence Events Screen

- List timeline ENTER/EXIT events
- Color code: ENTER = xanh, EXIT = cam
- Filter theo ngày

### Commit:

```bash
git commit -m "feat(mobile): location history map and geofence events timeline"
```

---

## Task 7: Child App — Nút SOS + Ghi Âm

> **Branch:** `feature/mobile/child-sos`

### 7.1: Cài package ghi âm

```bash
flutter pub add record
flutter pub add permission_handler
```

### 7.2: SOS Service

File tạo mới: `mobile/lib/features/sos/services/sos_service.dart`

```dart
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

class SOSService {
  final _recorder = AudioRecorder();
  
  Future<void> triggerSOS({
    required String deviceCode,
    String? message,
  }) async {
    // 1. Lấy vị trí ngay lập tức
    final position = await LocationService.instance.getCurrentLocation();
    if (position == null) throw Exception('Cannot get location');

    // 2. Gửi SOS không kèm audio trước (fast alert)
    await _sendSOSFast(deviceCode, position, message);

    // 3. Ghi âm 15s trong background
    await _recordAndUpload(deviceCode, position, message);
  }

  Future<void> _sendSOSFast(String deviceCode, Position pos, String? message) async {
    final formData = FormData.fromMap({
      'deviceCode': deviceCode,
      'latitude': pos.latitude.toString(),
      'longitude': pos.longitude.toString(),
      if (message != null) 'message': message,
    });
    await _dio.post('/api/child/sos', data: formData);
  }

  Future<void> _recordAndUpload(String deviceCode, Position pos, String? message) async {
    try {
      if (!await _recorder.hasPermission()) return;

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/sos_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      // Ghi 15 giây
      await Future.delayed(const Duration(seconds: 15));
      await _recorder.stop();

      // Upload
      final formData = FormData.fromMap({
        'deviceCode': deviceCode,
        'latitude': pos.latitude.toString(),
        'longitude': pos.longitude.toString(),
        if (message != null) 'message': message,
        'audio': await MultipartFile.fromFile(path, filename: 'sos.m4a'),
      });
      await _dio.post('/api/child/sos', data: formData);
    } catch (e) {
      print('❌ SOS record error: $e');
    }
  }
}
```

### 7.3: Nút SOS trên Child Dashboard

```dart
// Hiển thị nổi bật, màu đỏ
FloatingActionButton.extended(
  onPressed: () async {
    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🆘 Gửi SOS?'),
        content: const Text('Phụ huynh sẽ nhận thông báo khẩn cấp kèm vị trí của bạn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('GỬI SOS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && _deviceCode != null) {
      try {
        await SOSService.instance.triggerSOS(deviceCode: _deviceCode!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã gửi SOS cho phụ huynh')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e')),
        );
      }
    }
  },
  backgroundColor: Colors.red,
  icon: const Icon(Icons.sos, color: Colors.white),
  label: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
)
```

### Commit:

```bash
git commit -m "feat(mobile): child SOS button with location and audio recording"
```

---

## Task 8: Parent App — SOS Alert Screen

> **Branch:** `feature/mobile/parent-sos`

### 8.1: Listen SOS alerts

Trong HomeScreen hoặc global listener:

```dart
SocketService.instance.socket.on('sosAlert', (data) async {
  // Hiện dialog ưu tiên cao
  await showDialog(
    context: NavigatorService.navigatorKey.currentContext!,
    barrierDismissible: false,
    builder: (_) => _SOSAlertDialog(data: data),
  );
});
```

### 8.2: SOS Alert Dialog

File tạo mới: `mobile/lib/features/sos/widgets/sos_alert_dialog.dart`

```dart
class _SOSAlertDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SOSAlertDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              '🆘 SOS từ ${data['profileName']}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('${DateTime.parse(data['timestamp']).toLocal()}'),
            const SizedBox(height: 16),
            if (data['audioUrl'] != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Nghe ghi âm'),
                onPressed: () => _playAudio(data['audioUrl']),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('Xem vị trí'),
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to map centered on SOS location
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone),
                    label: const Text('Gọi con'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _callChild(data['profileId']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                // Acknowledge SOS
                await _sosRepo.acknowledge(data['sosId']);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Đã nhận được'),
            ),
          ],
        ),
      ),
    );
  }

  void _playAudio(String url) {
    // Dùng package audioplayers
    AudioPlayer().play(UrlSource(url));
  }

  void _callChild(int profileId) async {
    // Lấy số phone từ profile (giả sử đã có trong DB)
    // Hoặc lấy từ user account liên kết device
    final phone = await _profileRepo.getChildPhone(profileId);
    if (phone != null) {
      final uri = Uri(scheme: 'tel', path: phone);
      await launchUrl(uri);
    }
  }
}
```

### 8.3: SOS History Screen

- List tất cả SOS alerts (sorted newest first)
- Status badge (ACTIVE/ACKNOWLEDGED/RESOLVED)
- Tap → xem chi tiết (vị trí trên map, audio player, timestamp)

### Commit:

```bash
git commit -m "feat(mobile): parent SOS alert dialog with audio playback and call button"
```

---

## Task 9: Integration Test

### Test flows:

| # | Test | ✅ |
|---|------|---|
| 1 | Child cấp quyền Location (foreground + background) | ⬜ |
| 2 | Child di chuyển → vị trí cập nhật mỗi 30s (foreground) | ⬜ |
| 3 | Child minimize app → interval đổi thành 5 phút | ⬜ |
| 4 | Parent mở Map → thấy marker vị trí con real-time | ⬜ |
| 5 | Parent tạo Geofence "Nhà" bằng tap trên map | ⬜ |
| 6 | Child di chuyển vào geofence → Parent nhận ENTER event | ⬜ |
| 7 | Child di chuyển ra ngoài → Parent nhận EXIT event | ⬜ |
| 8 | Parent xem lịch sử vị trí → thấy polyline đường đi | ⬜ |
| 9 | Parent xem lịch sử geofence events → danh sách ENTER/EXIT | ⬜ |
| 10 | Child cấp quyền Record Audio | ⬜ |
| 11 | Child bấm SOS → Parent nhận dialog tức thì (< 2s) | ⬜ |
| 12 | Child ghi âm 15s → upload xong → Parent nghe được audio | ⬜ |
| 13 | Parent nhấn "Gọi con" → mở dialer | ⬜ |
| 14 | Parent nhấn "Xem vị trí" → map center vào SOS location | ⬜ |
| 15 | Parent acknowledge → SOS status đổi | ⬜ |
| 16 | Push notification SOS hoạt động khi Parent chạy ngầm | ⬜ |

---

## Checklist cuối Sprint 7 — Frontend

| # | Task | Status |
|---|------|--------|
| 1 | Mapbox SDK setup + token | ⬜ |
| 2 | Permissions: LOCATION + BACKGROUND_LOCATION + RECORD_AUDIO | ⬜ |
| 3 | LocationService với interval linh hoạt (30s/5min) | ⬜ |
| 4 | Child sync location lên server | ⬜ |
| 5 | Parent Map screen với real-time marker | ⬜ |
| 6 | Geofence create screen (tap-to-select + radius slider) | ⬜ |
| 7 | Geofence list + edit + delete | ⬜ |
| 8 | Geofence event dialog khi Child ENTER/EXIT | ⬜ |
| 9 | Location history screen với polyline | ⬜ |
| 10 | Geofence events history timeline | ⬜ |
| 11 | Child SOS button với confirm dialog | ⬜ |
| 12 | SOS: gửi location ngay + ghi âm 15s upload | ⬜ |
| 13 | Parent SOS alert dialog (barrier dismissible false) | ⬜ |
| 14 | Audio playback trong SOS dialog | ⬜ |
| 15 | Nút "Gọi con" mở dialer | ⬜ |
| 16 | SOS history screen | ⬜ |
| 17 | Push notification SOS priority max | ⬜ |

---

## Lưu ý quan trọng

- **Background location** — Android 10+ cần `ACCESS_BACKGROUND_LOCATION` + xin quyền riêng. Một số hãng (Xiaomi, Oppo) có MIUI/ColorOS kill background aggressive → cần hướng dẫn user whitelist app.
- **Mapbox token** — KHÔNG commit vào git. Dùng file `.env` + `.gitignore`.
- **Ghi âm 15s** cần chạy trong isolate hoặc Future riêng để không block UI.
- **SOS priority** — dùng `IMPORTANCE_HIGH` + sound default + full-screen intent cho notification channel.
- **Test trên thiết bị thật** — emulator không có GPS thật, chỉ mock được.

## Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/<tên-task>
git commit -m "feat(mobile): mô tả"
git push origin feature/mobile/<tên-task>
# → PR → develop → Khanh review → merge
```
