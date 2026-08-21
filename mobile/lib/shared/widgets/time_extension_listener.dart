import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/realtime_service.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/notification_service.dart';
import '../../features/youtube/widgets/ai_alert_dialog.dart';
import '../../features/youtube/screens/ai_alerts_screen.dart';

class TimeExtensionListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const TimeExtensionListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  ConsumerState<TimeExtensionListener> createState() => _TimeExtensionListenerState();
}

class _TimeExtensionListenerState extends ConsumerState<TimeExtensionListener> {
  final Set<int> _activeRequestIds = {};
  // Dedup cho geofence/AI alert: khác _activeRequestIds (dialog time-extension
  // được phép hiện lại tới khi Parent phản hồi), 2 loại này chỉ hiện 1 lần mỗi
  // phiên app — refetch-on-signal (notify-then-refetch) có thể gọi lại nhiều
  // lần (initState, mỗi signal, mỗi reconnect) nên cần chặn hiện trùng dialog.
  final Set<int> _seenGeofenceEventIds = {};
  final Set<int> _seenAiAlertIds = {};

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    _checkPendingRequests();
    _checkActiveSOS();
    _checkRecentGeofenceEvents();
    _checkPendingAiAlerts();

    // BUG 3 FIX (giữ nguyên tinh thần): named reference để remove đúng trong
    // dispose(), tránh N listener chồng lên nhau mỗi lần widget recreate.
    RealtimeService.instance.addConnectionRestoredListener(_onRealtimeReconnected);
  }

  // Named handler so it can be deregistered in dispose()
  void _onRealtimeReconnected(Map<String, dynamic> data) {
    print('🔄 [Realtime] Reconnected. Checking pending extension requests...');
    _checkPendingRequests();
    _checkActiveSOS();
    _checkRecentGeofenceEvents();
    _checkPendingAiAlerts();
  }

  void _setupRealtimeListeners() {
    // notify-then-refetch: signal chỉ báo "có thay đổi", không mang field cụ
    // thể — mỗi wrapper trigger đúng REST refetch tương ứng, sau đó tái dùng
    // nguyên logic dialog cũ (_onTimeExtensionRequest/_onSosAlert/
    // _onGeofenceEvent/_onAiAlert) với data thật lấy từ REST.
    RealtimeService.instance.addTimeExtensionRequestListener(_onTimeExtensionRequestSignal);
    RealtimeService.instance.addGeofenceEventListener(_onGeofenceEventSignal);
    RealtimeService.instance.addSosAlertListener(_onSosAlertSignal);
    RealtimeService.instance.addAiAlertListener(_onAiAlertSignal);
  }

  void _onTimeExtensionRequestSignal(Map<String, dynamic> data) => _checkPendingRequests();
  void _onGeofenceEventSignal(Map<String, dynamic> data) => _checkRecentGeofenceEvents();
  void _onSosAlertSignal(Map<String, dynamic> data) => _checkActiveSOS();
  void _onAiAlertSignal(Map<String, dynamic> data) => _checkPendingAiAlerts();

  Future<void> _checkPendingRequests() async {
    // Only parents check pending extension requests
    if (RealtimeService.instance.currentRole != 'parent') return;
    try {
      final response = await DioClient.instance.get('/api/extension-requests/pending');
      final requests = response.data['data']['requests'] as List?;
      
      if (requests != null && requests.isNotEmpty) {
        print('⏳ [REST] Found ${requests.length} pending extension requests');
        for (var request in requests) {
          final mappedData = {
            'requestId': request['id'],
            'profileName': request['profile']?['profileName'],
            'deviceName': request['device']?['deviceName'],
            'requestMinutes': request['requestMinutes'],
            'reason': request['reason'],
          };
          _onTimeExtensionRequest(mappedData);
        }
      }
    } catch (e) {
      print('❌ [REST] Error checking pending requests: $e');
    }
  }

  // TC-09-10: Receives Map<String, dynamic> đã map sẵn từ REST (xem
  // _checkRecentGeofenceEvents) — cùng shape với payload Socket.IO cũ.
  // Uses Timer.run() so showDialog is deferred to the next event loop tick —
  // this avoids calling showDialog mid-frame AND avoids the addPostFrameCallback
  // trap where callbacks only fire when Flutter renders a new frame (causing the
  // dialog to appear only after the user touches the screen).
  void _onGeofenceEvent(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = data['type'] as String? ?? '';
    final geofenceName = data['geofenceName'] as String? ?? 'Khu vực';
    final profileName = data['profileName'] as String? ?? 'Bé';

    final isEnter = type == 'ENTER';
    final icon = isEnter ? Icons.login_rounded : Icons.logout_rounded;
    final color = isEnter ? Colors.green : Colors.orange;
    final action = isEnter ? 'đã vào' : 'đã rời khỏi';
    final title = isEnter ? 'Bé vào vùng an toàn' : 'Bé rời vùng an toàn';

    // TC-09/10 Push Notification: show local notification regardless of app state
    NotificationService.instance.showGeofenceNotification(
      profileName: profileName,
      geofenceName: geofenceName,
      isEnter: isEnter,
    );

    // TC-09/10 Foreground Dialog: Timer.run defers to next event loop tick,
    // which is sufficient to avoid build-phase conflicts without waiting for a frame.
    Timer.run(() {
      if (!mounted) return;
      final dialogContext = widget.navigatorKey?.currentContext ?? context;
      showDialog(
        context: dialogContext,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text('$profileName $action "$geofenceName"'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  // TC-21 Step 4: REST check for ACTIVE SOS missed while parent was offline.
  // Guards: (1) Only runs if current socket role is 'parent' — prevents child
  // devices (which share the parent JWT) from showing parent-only SOS dialogs.
  // (2) Skips dialog if the user is already viewing /sos-alert (e.g. arrived via
  // notification tap), preventing a duplicate dialog stacked on top of the screen.
  Future<void> _checkActiveSOS() async {
    // Guard 1: Parent-only — child devices must not show SOS dialogs
    if (RealtimeService.instance.currentRole != 'parent') return;

    try {
      final profilesResponse = await DioClient.instance.get('/api/profiles');
      final profiles = profilesResponse.data['data'] as List? ?? [];

      final cutoff = DateTime.now().subtract(const Duration(minutes: 10));

      for (final profile in profiles) {
        final profileId = profile['id'];
        final profileName = profile['profileName'] as String? ?? 'Bé';

        final sosResponse = await DioClient.instance.get('/api/profiles/$profileId/sos');
        final alerts = sosResponse.data['data']['alerts'] as List? ?? [];

        if (alerts.isEmpty) continue;
        final latest = alerts.first; // Ordered by createdAt desc
        if (latest['status'] != 'ACTIVE') continue;

        final createdAt = DateTime.tryParse(latest['createdAt']?.toString() ?? '');
        if (createdAt == null || !createdAt.isAfter(cutoff)) continue;

        print('🆘 [REST] Found active SOS for profile $profileName — showing alert dialog');
        if (!mounted) return;

        // TC-21 RACE FIX: Use a 1-second delay (instead of Timer.run / next-tick)
        // so that the FCM notification navigation (safelyNavigate → ctx.push) has
        // time to push '/sos-alert' onto the stack BEFORE the guard check runs.
        // Without the delay, path was still '/home' at check time → dialog showed ON
        // TOP of the SOS screen that was being pushed in parallel (race condition).
        Timer(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          // Guard 2: Skip dialog if already on /sos-alert (arrived via notification tap)
          final ctx = widget.navigatorKey?.currentContext ?? context;
          try {
            final path = GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.path;
            if (path == '/sos-alert') return;
          } catch (_) {}
          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (_) => _SOSAlertDialog(
              profileName: profileName,
              lat: (latest['latitude'] as num?)?.toDouble() ?? 0.0,
              lng: (latest['longitude'] as num?)?.toDouble() ?? 0.0,
              audioUrl: latest['audioUrl'] as String?,
              sosTime: latest['createdAt']?.toString(),
              navigatorKey: widget.navigatorKey,
            ),
          );
        });
        return; // Show only the first active SOS found
      }
    } catch (e) {
      print('❌ [REST] Error checking active SOS: $e');
    }
  }

  // notify-then-refetch cho GeofenceEvent: signal Realtime không mang field
  // cụ thể nên phải refetch qua REST để lấy type/geofenceName/profileName
  // thật, rồi tái dùng _onGeofenceEvent (dialog + push notification) y hệt
  // logic cũ. Chỉ lấy event mới nhất mỗi profile (tránh spam dialog nếu bé
  // ra vào khu vực nhiều lần), giới hạn 10 phút gần nhất (khớp cutoff SOS).
  Future<void> _checkRecentGeofenceEvents() async {
    if (RealtimeService.instance.currentRole != 'parent') return;
    try {
      final profilesResponse = await DioClient.instance.get('/api/profiles');
      final profiles = profilesResponse.data['data'] as List? ?? [];
      final cutoff = DateTime.now().subtract(const Duration(minutes: 10));

      for (final profile in profiles) {
        final profileId = profile['id'];
        final profileName = profile['profileName'] as String? ?? 'Bé';

        final eventsResponse =
            await DioClient.instance.get('/api/profiles/$profileId/geofences/events');
        final events = eventsResponse.data['data']['events'] as List? ?? [];
        if (events.isEmpty) continue;

        final latest = events.first; // Ordered by createdAt desc
        final eventId = latest['id'] as int?;
        if (eventId == null || _seenGeofenceEventIds.contains(eventId)) continue;

        final createdAt = DateTime.tryParse(latest['createdAt']?.toString() ?? '');
        if (createdAt == null || !createdAt.isAfter(cutoff)) continue;

        _seenGeofenceEventIds.add(eventId);
        _onGeofenceEvent({
          'type': latest['type']?.toString() ?? '',
          'geofenceName': latest['geofence']?['name']?.toString() ?? 'Khu vực',
          'profileName': profileName,
        });
      }
    } catch (e) {
      print('❌ [REST] Error checking recent geofence events: $e');
    }
  }

  // notify-then-refetch cho AIAlert: dùng ?unread=true (giống bộ lọc
  // AIAlertsScreen đã dùng) thay vì cutoff thời gian — khớp domain model hơn
  // (alert coi là "mới" tới khi Parent xem trong AIAlertsScreen, không phải
  // theo mốc thời gian cố định). Vẫn cần _seenAiAlertIds vì dialog này không
  // tự markRead khi hiện/đóng — không dedup ở client sẽ hiện lại mỗi lần
  // check chạy lại (initState/signal/reconnect) tới khi Parent vào
  // AIAlertsScreen xem qua.
  Future<void> _checkPendingAiAlerts() async {
    if (RealtimeService.instance.currentRole != 'parent') return;
    try {
      final profilesResponse = await DioClient.instance.get('/api/profiles');
      final profiles = profilesResponse.data['data'] as List? ?? [];

      for (final profile in profiles) {
        final profileId = profile['id'];
        final profileName = profile['profileName'] as String? ?? 'Con';

        final alertsResponse = await DioClient.instance
            .get('/api/profiles/$profileId/ai-alerts', queryParameters: {'unread': 'true'});
        final alerts = alertsResponse.data['data']['alerts'] as List? ?? [];

        for (final alert in alerts) {
          final alertId = alert['id'] as int?;
          if (alertId == null || _seenAiAlertIds.contains(alertId)) continue;
          _seenAiAlertIds.add(alertId);

          final youtubeLog = alert['youtubeLog'] as Map<String, dynamic>?;
          _onAiAlert({
            'alertId': alertId,
            'profileId': profileId,
            'profileName': profileName,
            'videoTitle': youtubeLog?['videoTitle'],
            'channelName': youtubeLog?['channelName'],
            'dangerLevel': alert['dangerLevel'],
            'category': alert['category'],
            'summary': alert['summary'],
          });
        }
      }
    } catch (e) {
      print('❌ [REST] Error checking pending AI alerts: $e');
    }
  }

  void _onTimeExtensionRequest(Map<String, dynamic> data) {
    if (!mounted) return;
    // Only parents approve/deny time extension requests
    if (RealtimeService.instance.currentRole != 'parent') return;

    final requestId = data['requestId'] as int?;
    if (requestId == null || _activeRequestIds.contains(requestId)) return;

    _activeRequestIds.add(requestId);

    final profileName = data['profileName'] ?? 'Bé';
    final deviceName = data['deviceName'] ?? 'Thiết bị';
    final requestMinutes = data['requestMinutes'] as int? ?? 15;
    final reason = data['reason'] ?? '';

    // Use navigatorKey if provided, otherwise fallback to widget's context
    final dialogContext = widget.navigatorKey?.currentContext ?? context;

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('⏳ $profileName xin thêm giờ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Từ thiết bị: $deviceName'),
            const SizedBox(height: 8),
            Text('Số phút xin thêm: $requestMinutes phút'),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Lý do: $reason', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _respondExtension(requestId, true, requestMinutes);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Duyệt ($requestMinutes phút)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _respondExtension(requestId, false, 0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    ).then((_) {
      // Bug C fix: do NOT remove from _activeRequestIds here (on dismiss).
      // The ID is only cleared after the Parent explicitly responds (approve/reject).
      // This prevents duplicate dialogs from socket + REST + reconnect paths.
      // _activeRequestIds.remove(requestId);  ← intentionally omitted
    });
  }

  // Sprint 9: AI Alert handler — shows dialog when AI detects dangerous YouTube content.
  // Follows same Timer.run() pattern as _onSosAlert to avoid mid-frame showDialog issues.
  void _onAiAlert(Map<String, dynamic> data) {
    if (!mounted) return;
    // Only parents receive AI alerts
    if (RealtimeService.instance.currentRole != 'parent') return;

    final profileId = data['profileId'] as int?;
    final profileName = data['profileName'] as String? ?? 'Con';

    Timer.run(() {
      if (!mounted) return;
      final ctx = widget.navigatorKey?.currentContext ?? context;
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => AIAlertDialog(data: data),
      ).then((result) {
        if (result == 'view_details' && profileId != null) {
          final navCtx = widget.navigatorKey?.currentContext ?? context;
          Navigator.push(navCtx, MaterialPageRoute(
            builder: (_) => AIAlertsScreen(
              profileId: profileId,
              profileName: profileName,
            ),
          ));
        }
      });
    });
  }

  // Chuyển từ socket.emit('respondTimeExtension') sang REST — approve đã có
  // sẵn PUT .../approve (BUG 2 FIX cũ), reject là REST endpoint mới thêm
  // riêng cho cutover này. Backend vẫn emit Socket.IO 'timeExtensionResponse'
  // xuống thiết bị con y hệt trước (child_dashboard_screen.dart chưa cutover,
  // vẫn cần nghe qua Socket.IO).
  Future<void> _respondExtension(int requestId, bool approved, int minutes) async {
    // Remove from Set now that Parent has responded — future polls won't re-show this dialog
    _activeRequestIds.remove(requestId);

    final dialogContext = widget.navigatorKey?.currentContext ?? context;

    try {
      if (approved) {
        await DioClient.instance.put(
          '/api/extension-requests/$requestId/approve',
          data: {'responseMinutes': minutes},
        );
      } else {
        await DioClient.instance.put('/api/extension-requests/$requestId/reject');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text(approved ? '✅ Đã duyệt thêm $minutes phút' : '❌ Đã từ chối yêu cầu'),
          backgroundColor: approved ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi gửi phản hồi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    RealtimeService.instance.removeTimeExtensionRequestListener(_onTimeExtensionRequestSignal);
    RealtimeService.instance.removeGeofenceEventListener(_onGeofenceEventSignal);
    RealtimeService.instance.removeSosAlertListener(_onSosAlertSignal);
    RealtimeService.instance.removeAiAlertListener(_onAiAlertSignal);
    RealtimeService.instance.removeConnectionRestoredListener(_onRealtimeReconnected);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SOSAlertDialog: Inline SOS alert dialog shown via showDialog (not navigate).
// Benefit: shows immediately without needing a Navigator route transition,
// works even when app is idle with no pending frames.
// ─────────────────────────────────────────────────────────────────────────────
class _SOSAlertDialog extends StatelessWidget {
  final String profileName;
  final double lat;
  final double lng;
  final String? audioUrl;
  final String? sosTime;
  final GlobalKey<NavigatorState>? navigatorKey;

  const _SOSAlertDialog({
    required this.profileName,
    required this.lat,
    required this.lng,
    this.audioUrl,
    this.sosTime,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    String formattedTime = 'Vừa xảy ra';
    if (sosTime != null) {
      final dt = DateTime.tryParse(sosTime!);
      if (dt != null) {
        final local = dt.toLocal();
        formattedTime =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} '
            '${local.day}/${local.month}/${local.year}';
      }
    }

    return AlertDialog(
      backgroundColor: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🆘 SOS KHẨN CẤP',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text(profileName,
                    style: TextStyle(
                        color: Colors.red.shade700, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⏰ $formattedTime',
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 8),
          if (lat != 0.0 || lng != 0.0)
            Text('📌 Vị trí: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          if (audioUrl != null) ...[
            const SizedBox(height: 8),
            const Text('🎤 Có file ghi âm',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo)),
          ],
        ],
      ),
      actions: [
        // View on map
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final ctx = navigatorKey?.currentContext ?? context;
              ctx.push('/sos-alert', extra: {
                'profileName': profileName,
                'latitude': lat,
                'longitude': lng,
                'audioUrl': audioUrl,
                'phone': null,
                'sosTime': sosTime,
              });
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Xem chi tiết'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đã nhận được'),
          ),
        ),
      ],
    );
  }
}
