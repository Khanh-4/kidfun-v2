import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/profile_model.dart';
import 'package:dio/dio.dart';

class ProfileRepository {
  final _dio = DioClient.instance;

  Future<List<ProfileModel>> getProfiles() async {
    try {
      final response = await _dio.get(ApiConstants.profiles);
      final List data = response.data['data'];
      return data.map((json) => ProfileModel.fromJson(json)).toList();
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      // Temporary mock data for UI testing if backend is not ready
      if (e.toString().contains('404')) {
         return [
           ProfileModel(id: 1, userId: 1, profileName: "Bé An", createdAt: DateTime.now()),
           ProfileModel(id: 2, userId: 1, profileName: "Bé Bình", createdAt: DateTime.now()),
         ];
      }
      throw Exception('Lỗi tải danh sách hồ sơ: $e');
    }
  }

  Future<ProfileModel> createProfile(String name, DateTime? dob) async {
    try {
      final data = {
        'profileName': name,
        if (dob != null) 'dateOfBirth': dob.toIso8601String(),
      };
      final response = await _dio.post(ApiConstants.profiles, data: data);
      return ProfileModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi tạo hồ sơ: $e');
    }
  }

  Future<ProfileModel> updateProfile(int id, String? name, DateTime? dob) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['profileName'] = name;
      if (dob != null) data['dateOfBirth'] = dob.toIso8601String();
      
      final response = await _dio.put('${ApiConstants.profiles}/$id', data: data);
      return ProfileModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi cập nhật hồ sơ: $e');
    }
  }

  Future<void> deleteProfile(int id) async {
    try {
      await _dio.delete('${ApiConstants.profiles}/$id');
    } on DioException catch (e) {
      if (e.response != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi xóa hồ sơ: $e');
    }
  }
}
