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

  // History: merge location logs + geofence events for the day
  Future<List<dynamic>> getHistory(int profileId, String date) async {
    final results = await Future.wait([
      _dio.get('/api/profiles/$profileId/location/history',
          queryParameters: {'date': date}),
      _dio.get('/api/profiles/$profileId/geofences/events',
          queryParameters: {'date': date}),
    ]);

    final locationLogs = (results[0].data['data']['history'] as List?) ?? [];
    final geofenceEvents = (results[1].data['data']['events'] as List?) ?? [];

    final combined = <Map<String, dynamic>>[
      ...locationLogs.map((item) => {
            'type': 'LOCATION',
            'timestamp': item['createdAt'] as String,
            'latitude': item['latitude'],
            'longitude': item['longitude'],
          }),
      ...geofenceEvents.map((item) => {
            'type': item['type'] as String, // ENTER hoặc EXIT
            'timestamp': item['createdAt'] as String,
            'latitude': item['latitude'],
            'longitude': item['longitude'],
            'geofenceName': (item['geofence'] as Map?)?['name'] ?? '',
          }),
    ];

    // Sắp xếp theo thời gian tăng dần
    combined.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp'] as String) ?? DateTime(0);
      final tb = DateTime.tryParse(b['timestamp'] as String) ?? DateTime(0);
      return ta.compareTo(tb);
    });

    return combined;
  }
}
