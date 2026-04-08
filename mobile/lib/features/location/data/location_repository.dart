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

  // Task 4: Get current location for Parent App MapScreen
  Future<dynamic> getCurrentLocation(int profileId) async {
    final response = await _dio.get('/api/parent/profiles/$profileId/location');
    return response.data;
  }

  // Task 5: Geofence endpoints
  Future<List<dynamic>> getGeofences(int profileId) async {
    final response = await _dio.get('/api/parent/profiles/$profileId/geofences');
    return response.data['data'] ?? [];
  }

  Future<dynamic> createGeofence({
    required int profileId, 
    required String name, 
    required double latitude, 
    required double longitude, 
    required double radius,
  }) async {
    final response = await _dio.post(
      '/api/parent/profiles/$profileId/geofences',
      data: {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      }
    );
    return response.data['data'];
  }

  Future<void> deleteGeofence(int profileId, int geofenceId) async {
    await _dio.delete('/api/parent/profiles/$profileId/geofences/$geofenceId');
  }

  // Task 6: History
  Future<List<dynamic>> getHistory(int profileId, String date) async {
    final response = await _dio.get(
      '/api/parent/profiles/$profileId/location-events',
      queryParameters: {'date': date},
    );
    return response.data['data'] ?? [];
  }
}

