import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import '../services/native_service.dart';

/// PolicyService — Sync tất cả Sprint 8 policies từ backend thống nhất
/// qua endpoint GET /api/child/policy?deviceCode=XXX
///
/// Gọi [syncAll] khi:
/// 1. Child dashboard init
/// 2. Socket events: blockedDomainsUpdated, appTimeLimitUpdated, schoolScheduleUpdated
class PolicyService {
  static final PolicyService instance = PolicyService._();
  PolicyService._();

  final _dio = DioClient.instance;

  /// Sync toàn bộ policy từ server -> native
  Future<void> syncAll(String deviceCode) async {
    try {
      final response = await _dio.get('/api/child/policy?deviceCode=$deviceCode');
      final data = response.data;

      if (data == null) {
        debugPrint('⚠️ [POLICY] No data returned from server');
        return;
      }

      // 1. Web Filtering — blocked domains
      await _syncBlockedDomains(data);

      // 2. Per-app Time Limits
      await _syncAppTimeLimits(data);

      // 3. School Mode
      await _syncSchoolMode(data);

      debugPrint('✅ [POLICY] All policies synced successfully');
    } catch (e) {
      debugPrint('❌ [POLICY] Sync error: $e');
    }
  }

  Future<void> _syncBlockedDomains(Map<String, dynamic> data) async {
    try {
      final blockedDomains = data['blockedDomains'];
      if (blockedDomains is List) {
        final domains = blockedDomains
            .map((d) => d is Map ? (d['domain'] ?? '').toString() : d.toString())
            .where((d) => d.isNotEmpty)
            .toList();
        await NativeService.setBlockedDomains(domains);
        debugPrint('🌐 [POLICY] Synced ${domains.length} blocked domains');
      }
    } catch (e) {
      debugPrint('❌ [POLICY] Blocked domains sync error: $e');
    }
  }

  Future<void> _syncAppTimeLimits(Map<String, dynamic> data) async {
    try {
      final appLimits = data['appTimeLimits'];
      if (appLimits is List) {
        final limits = appLimits.map<Map<String, dynamic>>((l) {
          return {
            'packageName': l['packageName'] ?? '',
            'appName': l['appName'] ?? l['packageName'] ?? '',
            'dailyLimitMinutes': l['dailyLimitMinutes'] ?? 0,
            'usedSeconds': l['usedSeconds'] ?? 0,
            'remainingSeconds': l['remainingSeconds'] ?? 0,
          };
        }).where((l) => (l['packageName'] as String).isNotEmpty).toList();
        await NativeService.setAppTimeLimits(limits);
        debugPrint('⏰ [POLICY] Synced ${limits.length} app time limits');
      }
    } catch (e) {
      debugPrint('❌ [POLICY] App time limits sync error: $e');
    }
  }

  Future<void> _syncSchoolMode(Map<String, dynamic> data) async {
    try {
      final schoolMode = data['schoolMode'];
      if (schoolMode is Map) {
        final isActive = schoolMode['isActive'] == true;
        final allowedApps = (schoolMode['allowedApps'] as List?)
            ?.map((a) => a is Map ? (a['packageName'] ?? '').toString() : a.toString())
            .where((a) => a.isNotEmpty)
            .toList() ?? [];
        final startTime = schoolMode['startTime']?.toString();
        final endTime = schoolMode['endTime']?.toString();

        await NativeService.setSchoolMode(
          isActive: isActive,
          allowedApps: allowedApps,
          startTime: startTime,
          endTime: endTime,
        );
        debugPrint('📚 [POLICY] School mode: active=$isActive, allowed=${allowedApps.length}');
      }
    } catch (e) {
      debugPrint('❌ [POLICY] School mode sync error: $e');
    }
  }
}
