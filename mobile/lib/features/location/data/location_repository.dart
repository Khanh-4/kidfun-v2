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
}
