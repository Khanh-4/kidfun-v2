import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../data/location_repository.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_colors.dart';

class LocationHistoryScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const LocationHistoryScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  final _locationRepo = LocationRepository(DioClient.instance);
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _events = [];
  bool _isLoading = true;

  // Map
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleManager;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await _locationRepo.getHistory(widget.profileId, dateStr);
      setState(() {
        _events = data;
        _isLoading = false;
      });
      if (_mapReady) await _drawPolyline();
    } catch (e) {
      print('Error fetching history: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _drawPolyline() async {
    if (_mapboxMap == null) return;

    // Remove old layers/sources to allow redraw when date changes
    try {
      await _mapboxMap!.style.removeStyleLayer('history-line');
    } catch (_) {}
    try {
      await _mapboxMap!.style.removeStyleSource('history-route');
    } catch (_) {}
    await _circleManager?.deleteAll();

    // Only LOCATION-type events have lat/lng for polyline
    final locationPoints = _events
        .where((e) => e['type'] == 'LOCATION')
        .toList();

    if (locationPoints.isEmpty) return;

    // Draw polyline if >= 2 points
    if (locationPoints.length >= 2) {
      final coords = locationPoints
          .map((p) => [p['longitude'] as double, p['latitude'] as double])
          .toList();

      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: 'history-route',
        data: jsonEncode({
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coords},
        }),
      ));

      await _mapboxMap!.style.addLayer(LineLayer(
        id: 'history-line',
        sourceId: 'history-route',
        lineColor: const Color(0xFF0066FF).value,
        lineColor: '#0066FF',
        lineWidth: 3.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));
    }

    // Start marker (green) and end marker (red)
    final first = locationPoints.first;
    await _circleManager?.create(CircleAnnotationOptions(
      geometry: Point(
          coordinates: Position(
              first['longitude'] as double, first['latitude'] as double)),
      circleRadius: 8.0,
      circleColor: Colors.green.value,
      circleStrokeWidth: 2.0,
      circleStrokeColor: Colors.white.value,
    ));

    if (locationPoints.length > 1) {
      final last = locationPoints.last;
      await _circleManager?.create(CircleAnnotationOptions(
        geometry: Point(
            coordinates: Position(
                last['longitude'] as double, last['latitude'] as double)),
        circleRadius: 8.0,
        circleColor: Colors.red.value,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      ));
    }

    // Fit camera to show all points
    final lats = locationPoints.map((p) => p['latitude'] as double).toList();
    final lngs = locationPoints.map((p) => p['longitude'] as double).toList();
    final lats =
        locationPoints.map((p) => p['latitude'] as double).toList();
    final lngs =
        locationPoints.map((p) => p['longitude'] as double).toList();

    if (locationPoints.length == 1) {
      await _mapboxMap!.setCamera(CameraOptions(
        center: Point(coordinates: Position(lngs.first, lats.first)),
        zoom: 15.0,
      ));
    } else {
      final minLat = lats.reduce(math.min);
      final maxLat = lats.reduce(math.max);
      final minLng = lngs.reduce(math.min);
      final maxLng = lngs.reduce(math.max);
      final padLat = math.max((maxLat - minLat) * 0.2, 0.001);
      final padLng = math.max((maxLng - minLng) * 0.2, 0.001);

      try {
        final camera = await _mapboxMap!.cameraForCoordinateBounds(
          CoordinateBounds(
            southwest: Point(
                coordinates: Position(minLng - padLng, minLat - padLat)),
            northeast: Point(
                coordinates: Position(maxLng + padLng, maxLat + padLat)),
                coordinates:
                    Position(minLng - padLng, minLat - padLat)),
            northeast: Point(
                coordinates:
                    Position(maxLng + padLng, maxLat + padLat)),
            infiniteBounds: false,
          ),
          MbxEdgeInsets(top: 60, left: 40, bottom: 40, right: 40),
          null,
          null,
          null,
          null,
        );
        await _mapboxMap!.setCamera(camera);
      } catch (_) {
        // Fallback: center between first and last
        await _mapboxMap!.setCamera(CameraOptions(
          center: Point(
              coordinates: Position(
                  (minLng + maxLng) / 2, (minLat + maxLat) / 2)),
          zoom: 14.0,
        ));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch sử: ${widget.profileName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector bar
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: AppColors.slate50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: _selectDate,
                  child: const Text('Thay đổi'),
                ),
              ],
            ),
          ),

          // Map showing polyline
          SizedBox(
            height: 260,
            child: MapWidget(
              key: const ValueKey("historyMapWidget"),
              textureView: true,
              styleUri: MapboxStyles.MAPBOX_STREETS,
              cameraOptions: CameraOptions(
                center: Point(
                    coordinates:
                        Position(106.660172, 10.762622)), // HCM default
                zoom: 12.0,
              ),
              onMapCreated: (MapboxMap mapboxMap) async {
                _mapboxMap = mapboxMap;
                _circleManager = await mapboxMap.annotations
                    .createCircleAnnotationManager();
                _mapReady = true;
                // Draw if data is already loaded
                if (_events.isNotEmpty) await _drawPolyline();
              },
            ),
          ),

          // Map legend
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _LegendDot(color: Colors.green, label: 'Bắt đầu'),
                const SizedBox(width: 16),
                _LegendDot(color: Colors.red, label: 'Kết thúc'),
                const SizedBox(width: 16),
                _LegendDot(color: Colors.blue, label: 'Đường đi'),
              ],
            ),
          ),

          const Divider(height: 1),

          // Events list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? Center(
                        child: Text(
                          'Không có dữ liệu vị trí',
                          style: GoogleFonts.nunito(
                              color: AppColors.slate500, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final type =
                              event['type'] as String? ?? 'LOCATION';
                          final timeStr =
                              event['timestamp'] as String;
                          final time =
                              DateTime.tryParse(timeStr)?.toLocal() ??
                                  DateTime.now();

                          IconData iconData = Icons.location_on;
                          Color iconColor = Colors.blue;
                          String title = 'Cập nhật vị trí';

                          if (type == 'ENTER') {
                            iconData = Icons.login;
                            iconColor = Colors.green;
                            title =
                                'Vào vùng: ${event['geofenceName']}';
                          } else if (type == 'EXIT') {
                            iconData = Icons.logout;
                            iconColor = Colors.orange;
                            title =
                                'Rời vùng: ${event['geofenceName']}';
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  iconColor.withOpacity(0.15),
                              child: Icon(iconData, color: iconColor),
                            ),
                            title: Text(title,
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                DateFormat('HH:mm:ss').format(time)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}
