import '../../../core/network/dio_client.dart';
import '../../../shared/models/time_limit_model.dart';

class TimeLimitRepository {
  final _dio = DioClient.instance;

  Future<List<TimeLimitModel>> getTimeLimits(int profileId) async {
    final response = await _dio.get('/api/profiles/$profileId');
    // Cấu trúc response dự kiến: data: { profile: { timeLimits: [...] } }
    final data = response.data['data'];

    // API trả data trực tiếp, KHÔNG có tầng 'profile'
    // data = { id, profileName, timeLimits: [...] }
    final timeLimitsRaw = data['timeLimits'] as List? ?? [];
    
    if (timeLimitsRaw.isEmpty) {
      // Tạo default 7 ngày, mỗi ngày 120 phút (2 tiếng)
      return List.generate(7, (i) => TimeLimitModel(
        dayOfWeek: i,
        limitMinutes: 120,
        isActive: true,
      ));
    }

    return timeLimitsRaw.map((tl) => TimeLimitModel.fromJson(tl)).toList();
  }

  Future<void> updateTimeLimits(int profileId, List<TimeLimitModel> limits) async {
    await _dio.put('/api/profiles/$profileId/time-limits', data: {
      'timeLimits': limits.map((tl) => tl.toJson()).toList(),
    });
  }
}
