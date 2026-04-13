import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';

class WebFilterRepository {
  final _dio = DioClient.instance;

  Future<List<Map<String, dynamic>>> getBlockedCategories(int profileId) async {
    try {
      final response = await _dio.get('${ApiConstants.profiles}/$profileId/blocked-categories');
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      throw _handleError(e, 'Lỗi tải danh mục chặn');
    }
  }

  Future<void> toggleCategory(int profileId, int categoryId, bool isBlocked) async {
    try {
      await _dio.post(
        '${ApiConstants.profiles}/$profileId/blocked-categories',
        data: {
          'categoryId': categoryId,
          'isBlocked': isBlocked,
        },
      );
    } catch (e) {
      throw _handleError(e, 'Lỗi cập nhật danh mục chặn');
    }
  }

  Future<void> addCategoryOverride(int profileId, int categoryId, String domain) async {
    try {
      await _dio.post(
        '${ApiConstants.profiles}/$profileId/blocked-categories/$categoryId/override',
        data: {'domain': domain},
      );
    } catch (e) {
      throw _handleError(e, 'Lỗi thêm ngoại lệ domain');
    }
  }

  Future<void> removeCategoryOverride(int profileId, int categoryId, String domain) async {
    try {
      await _dio.delete(
        '${ApiConstants.profiles}/$profileId/blocked-categories/$categoryId/override/$domain',
      );
    } catch (e) {
      throw _handleError(e, 'Lỗi xóa ngoại lệ domain');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomDomains(int profileId) async {
    try {
      final response = await _dio.get('${ApiConstants.profiles}/$profileId/custom-blocked-domains');
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      throw _handleError(e, 'Lỗi tải danh sách domain chặn thủ công');
    }
  }

  Future<void> addCustomDomain(int profileId, String domain) async {
    try {
      await _dio.post(
        '${ApiConstants.profiles}/$profileId/custom-blocked-domains',
        data: {'domain': domain},
      );
    } catch (e) {
      throw _handleError(e, 'Lỗi thêm domain tự chọn');
    }
  }

  Future<void> deleteCustomDomain(int profileId, String domain) async {
    try {
      await _dio.delete('${ApiConstants.profiles}/$profileId/custom-blocked-domains/$domain');
    } catch (e) {
      throw _handleError(e, 'Lỗi xóa domain tự chọn');
    }
  }

  Exception _handleError(dynamic e, String defaultMessage) {
    if (e is DioException && e.response?.data?['message'] != null) {
      return Exception(e.response!.data['message']);
    }
    return Exception('$defaultMessage: $e');
  }
}
