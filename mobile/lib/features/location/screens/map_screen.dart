import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/network/dio_client.dart';
import '../data/location_repository.dart';

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
  double? _lastLat;
  double? _lastLng;
  final _locationRepo = LocationRepository(DioClient.instance);

  @override
  void initState() {
    super.initState();
    _listenLocationUpdates();
    _fetchCurrentLocation();
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

  @override
  void dispose() {
    SocketService.instance.socket.off('locationUpdated');
    super.dispose();
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
          if (_lastLat != null && _lastLng != null) {
             _updateChildMarker(_lastLat!, _lastLng!);
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
