import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/network/dio_client.dart';
import '../data/location_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_colors.dart';

class _MyPolygonClickListener extends OnPolygonAnnotationClickListener {
  final Function(PolygonAnnotation) onClick;
  _MyPolygonClickListener(this.onClick);
  @override
  void onPolygonAnnotationClick(PolygonAnnotation annotation) {
    onClick(annotation);
  }
}

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
  PolygonAnnotationManager? _polygonManager;
  PointAnnotation? _childMarker;
  double? _lastLat;
  double? _lastLng;
  final _locationRepo = LocationRepository(DioClient.instance);

  List<dynamic> _geofences = [];
  Map<String, int> _annotationGeofenceMap = {};
  bool _isAddingMode = false;
  double _newRadius = 500.0;
  PointAnnotation? _tempCenterMarker;
  PolygonAnnotation? _tempGeofencePolygon;
  double? _tempLat;
  double? _tempLng;
  
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenLocationUpdates();
    _fetchCurrentLocation();
    _fetchGeofences();
  }

  Future<void> _fetchGeofences() async {
    try {
      final data = await _locationRepo.getGeofences(widget.profileId);
      setState(() => _geofences = data);
      _drawGeofences();
    } catch (e) {
      print('Error fetching geofences: $e');
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final location = await _locationRepo.getCurrentLocation(widget.profileId);
      if (location != null && location['latitude'] != null) {
        _updateChildMarker(location['latitude'] as double, location['longitude'] as double);
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  void _listenLocationUpdates() {
    SocketService.instance.socket.on('locationUpdated', (data) {
      if (data['profileId'] == widget.profileId) {
        _updateChildMarker(data['latitude'] as double, data['longitude'] as double);
      }
    });
  }

  Future<void> _updateChildMarker(double lat, double lng) async {
    _lastLat = lat;
    _lastLng = lng;
    
    if (_mapboxMap == null || _annotationManager == null) return;

    final point = Point(coordinates: Position(lng, lat));
    
    if (_childMarker == null) {
      try {
        _childMarker = await _annotationManager!.create(
          PointAnnotationOptions(
            geometry: point,
            iconSize: 1.5,
            iconImage: 'marker-15', // Default Mapbox marker
          ),
        );
      } catch (e) {
        print('Error creating marker: $e');
      }
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

  List<Position> _createCirclePolygon(double lat, double lng, double radiusInMeters) {
    const int points = 64;
    final List<Position> coordinates = [];
    const earthRadius = 6378137.0;

    final latRad = lat * math.pi / 180.0;
    final lngRad = lng * math.pi / 180.0;
    final d = radiusInMeters / earthRadius;

    for (int i = 0; i <= points; i++) {
        final bearing = i * 2 * math.pi / points;
        final pointLatRad = math.asin(
            math.sin(latRad) * math.cos(d) + math.cos(latRad) * math.sin(d) * math.cos(bearing));
        final pointLngRad = lngRad +
            math.atan2(math.sin(bearing) * math.sin(d) * math.cos(latRad),
                math.cos(d) - math.sin(latRad) * math.sin(pointLatRad));
        
        coordinates.add(Position(pointLngRad * 180.0 / math.pi, pointLatRad * 180.0 / math.pi));
    }
    return coordinates;
  }

  Future<void> _drawGeofences() async {
    if (_polygonManager == null) return;
    await _polygonManager!.deleteAll();
    _annotationGeofenceMap.clear();

    for (final gf in _geofences) {
      final lat = gf['latitude'] as double;
      final lng = gf['longitude'] as double;
      final rad = gf['radius'] is int ? (gf['radius'] as int).toDouble() : gf['radius'] as double;

      final coords = _createCirclePolygon(lat, lng, rad);
      final polygon = await _polygonManager!.create(PolygonAnnotationOptions(
        geometry: Polygon(coordinates: [coords]),
        fillColor: Colors.blue.withOpacity(0.3).value,
        fillOutlineColor: Colors.blue.value,
      ));
      _annotationGeofenceMap[polygon.id] = gf['id'] as int;
    }
  }

  Future<void> _drawTempGeofence() async {
    if (_polygonManager == null || _annotationManager == null || _tempLat == null || _tempLng == null) return;
    
    // Clear old temp
    if (_tempCenterMarker != null) await _annotationManager!.delete(_tempCenterMarker!);
    if (_tempGeofencePolygon != null) await _polygonManager!.delete(_tempGeofencePolygon!);

    // Draw marker
    final point = Point(coordinates: Position(_tempLng!, _tempLat!));
    _tempCenterMarker = await _annotationManager!.create(PointAnnotationOptions(
      geometry: point,
      iconImage: 'marker-15',
    ));

    // Draw polygon
    final coords = _createCirclePolygon(_tempLat!, _tempLng!, _newRadius);
    _tempGeofencePolygon = await _polygonManager!.create(PolygonAnnotationOptions(
      geometry: Polygon(coordinates: [coords]),
      fillColor: Colors.green.withOpacity(0.4).value,
      fillOutlineColor: Colors.green.value,
    ));
  }

  void _onMapTap(MapContentGestureContext context) {
    if (!_isAddingMode) return;
    final pos = context.point.coordinates;
    setState(() {
      _tempLat = pos.lat.toDouble();
      _tempLng = pos.lng.toDouble();
    });
    _drawTempGeofence();
  }

  void _showSaveGeofenceDialog() {
    if (_tempLat == null || _tempLng == null) return;
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Lưu Vùng an toàn", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
      content: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: 'Tên vùng (VD: Trường học, Nhà)',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.trim().isEmpty) return;
            Navigator.pop(ctx);
            
            try {
              await _locationRepo.createGeofence(
                profileId: widget.profileId,
                name: _nameController.text.trim(),
                latitude: _tempLat!,
                longitude: _tempLng!,
                radius: _newRadius,
              );
              _nameController.clear();
              setState(() {
                _isAddingMode = false;
                _tempLat = null;
                _tempLng = null;
              });
              
              if (_tempCenterMarker != null) await _annotationManager!.delete(_tempCenterMarker!);
              if (_tempGeofencePolygon != null) await _polygonManager!.delete(_tempGeofencePolygon!);
              
              _fetchGeofences();
            } catch (e) {
              print("Lỗi lưu vùng an toàn: $e");
            }
          },
          child: const Text("Lưu"),
        )
      ],
    ));
  }

  void _showDeleteGeofenceDialog(PolygonAnnotation annotation) {
    final geofenceId = _annotationGeofenceMap[annotation.id];
    if (geofenceId == null) return;

    final gf = _geofences.firstWhere((g) => g['id'] == geofenceId, orElse: () => null);
    if (gf == null) return;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Xóa Vùng an toàn?", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
      content: Text('Bạn có chắc muốn xóa vùng "${gf['name']}" không?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              await _locationRepo.deleteGeofence(widget.profileId, geofenceId);
              _fetchGeofences();
            } catch (e) {
              print('Lỗi xóa vùng an toàn: $e');
            }
          },
          child: const Text("Xóa", style: TextStyle(color: Colors.white)),
        )
      ],
    ));
  }

  @override
  void dispose() {
    SocketService.instance.socket.off('locationUpdated');
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vị trí ${widget.profileName}'),
        actions: [
           IconButton(
             icon: Icon(_isAddingMode ? Icons.close : Icons.add_location_alt),
             onPressed: () {
               setState(() => _isAddingMode = !_isAddingMode);
               if (!_isAddingMode) {
                 if (_tempCenterMarker != null) _annotationManager?.delete(_tempCenterMarker!);
                 if (_tempGeofencePolygon != null) _polygonManager?.delete(_tempGeofencePolygon!);
                 _tempLat = null;
                 _tempLng = null;
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                   content: Text("Chạm lên bản đồ để chọn tâm vùng an toàn"),
                   duration: Duration(seconds: 2),
                 ));
               }
             },
             tooltip: 'Thêm Vùng an toàn',
           )
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(106.660172, 10.762622)), // HCM default
              zoom: 12.0,
            ),
            onTapListener: _onMapTap,
            onMapCreated: (MapboxMap mapboxMap) async {
              _mapboxMap = mapboxMap;
              _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
              _polygonManager = await mapboxMap.annotations.createPolygonAnnotationManager();
              
              _polygonManager!.addOnPolygonAnnotationClickListener(_MyPolygonClickListener((annotation) {
                if (_isAddingMode) return;
                _showDeleteGeofenceDialog(annotation);
              }));
              
              if (_lastLat != null && _lastLng != null) {
                 _updateChildMarker(_lastLat!, _lastLng!);
              }
              _drawGeofences();
            },
          ),

          if (_isAddingMode && _tempLat != null)
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Bán kính: ${_newRadius.toInt()} mét", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                      Slider(
                        value: _newRadius,
                        min: 100, max: 2000, divisions: 19,
                        onChanged: (v) {
                          setState(() => _newRadius = v);
                          _drawTempGeofence();
                        },
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showSaveGeofenceDialog,
                          child: const Text('Tiếp tục'),
                        )
                      )
                    ],
                  ),
                ),
              ),
            ),
            
           if (!_isAddingMode)
             Positioned(
               bottom: 20, right: 20,
               child: FloatingActionButton(
                 onPressed: _fetchCurrentLocation,
                 child: const Icon(Icons.my_location),
               ),
             )
        ],
      ),
    );
  }
}
