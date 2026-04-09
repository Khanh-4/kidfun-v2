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

  // Get current location for Parent App MapScreen
  Future<dynamic> getCurrentLocation(int profileId) async {
    final response = await _dio.get('/api/profiles/$profileId/location/current');
    return response.data['data']['location'];
  }

  // Geofence endpoints
  Future<List<dynamic>> getGeofences(int profileId) async {
    final response = await _dio.get('/api/profiles/$profileId/geofences');
    return (response.data['data']['geofences'] as List?) ?? [];
  }

  Future<dynamic> createGeofence({
    required int profileId,
    required String name,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    final response = await _dio.post(
      '/api/profiles/$profileId/geofences',
      data: {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      },
    );
    return response.data['data']['geofence'];
  }

  Future<void> deleteGeofence(int profileId, int geofenceId) async {
    await _dio.delete('/api/geofences/$geofenceId');
  }

  // History: location logs for the day
  Future<List<dynamic>> getHistory(int profileId, String date) async {
    final response = await _dio.get(
      '/api/profiles/$profileId/location/history',
      queryParameters: {'date': date},
    );
    final historyList = (response.data['data']['history'] as List?) ?? [];
    return historyList
        .map((item) => {
              'type': 'LOCATION',
              'timestamp': item['createdAt'],
              'latitude': item['latitude'],
              'longitude': item['longitude'],
            })
        .toList();
  }
}
