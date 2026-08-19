import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';

class WebFilterRepository {
  final _dio = DioClient.instance;

  /// Lấy tất cả categories từ server (dùng cho UI danh mục đen)
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final response = await _dio.get(ApiConstants.webCategories);
      final raw = List<dynamic>.from(response.data['data']['categories'] ?? []);
      return raw.map<Map<String, dynamic>>((e) {
        final domains = (e['domains'] as List? ?? []);
        final domainList = domains
            .map((d) => (d['domain'] ?? '').toString())
            .where((d) => d.isNotEmpty)
            .toList();
        return {
          'id': e['id'],
          'categoryId': e['id'],
          'name': e['name'] ?? '',
          'displayName': e['displayName'] ?? e['name'] ?? '',
          'description': e['description'] ?? '',
          'domainCount': domainList.length,
          'domains': domainList,
          'isBlocked': false, // will be merged with blocked status
        };
      }).toList();
    } catch (e) {
      throw _handleError(e, 'Lỗi tải danh mục web');
    }
  }

  Future<List<Map<String, dynamic>>> getBlockedCategories(int profileId) async {
    try {
      final response = await _dio.get('${ApiConstants.profiles}/$profileId/blocked-categories');
      // Backend returns: { data: { blockedCategories: [ { id, categoryId, isBlocked, category: { id, name, displayName }, overrides: [] } ] } }
      final raw = List<dynamic>.from(response.data['data']['blockedCategories'] ?? []);
      return raw.map<Map<String, dynamic>>((e) {
        final cat = e['category'] as Map<String, dynamic>? ?? {};
        final overrides = List<Map<String, dynamic>>.from(
          (e['overrides'] as List? ?? []).map((o) => Map<String, dynamic>.from(o)),
        );
        return {
          'id': e['categoryId'],         // categoryId used as primary key in toggleCategory
          'categoryId': e['categoryId'],
          'blockedRecordId': e['id'],    // actual DB row id
          'name': cat['name'] ?? '',
          'displayName': cat['displayName'] ?? cat['name'] ?? '',
          'isBlocked': e['isBlocked'] ?? false,
          'overrides': overrides,
        };
      }).toList();
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
      // Backend returns: { data: { domains: [...] } }
      return List<Map<String, dynamic>>.from(
        (response.data['data']['domains'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
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
