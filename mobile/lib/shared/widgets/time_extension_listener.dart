import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/socket_service.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _setupSocketListener();
    _checkPendingRequests();
    _checkActiveSOS();

    // BUG 3 FIX: Store named reference so we can remove it in dispose().
    // Previously the raw socket.on('connect', ...) was never cleaned up, causing
    // N listeners to stack on every widget recreation → N dialogs per reconnect.
    SocketService.instance.socket.on('connect', _onSocketReconnect);
  }

  // Named handler so it can be deregistered with off() in dispose()
  void _onSocketReconnect(_) {
    print('🔄 [SOCKET] Reconnected. Checking pending extension requests...');
    _checkPendingRequests();
    _checkActiveSOS();
  }

  void _setupSocketListener() {
    SocketService.instance.addTimeExtensionRequestListener(_onTimeExtensionRequest);
    // TC-09-10: Route through list system — raw socket.on() was unreliable because type
    // errors in the callback silently swallowed exceptions before showDialog was reached
    SocketService.instance.addGeofenceEventListener(_onGeofenceEvent);
    // TC-21: Global sosAlert listener so parent sees SOS from any screen
    SocketService.instance.addSosAlertListener(_onSosAlert);
  }

  Future<void> _checkPendingRequests() async {
    // Only parents check pending extension requests
    if (SocketService.instance.currentRole != 'parent') return;
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

  // TC-09-10: Receives Map<String, dynamic> (SocketService converts raw Map before dispatching)
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

  // TC-21: Global sosAlert handler — active from any screen, not just ProfileListScreen.
  // L2 FIX: Use showDialog directly (via Timer.run) instead of ctx.push + addPostFrameCallback.
  //
  // Root cause of original bug: addPostFrameCallback only fires when Flutter schedules
  // a new frame. When the parent app is open but idle (no animation/scroll), no new
  // frame is scheduled — so the callback never runs until the user touches the screen.
  //
  // Fix: showDialog is called immediately on the next event loop tick (Timer.run),
  // which works even when the app is completely idle.
  void _onSosAlert(Map<String, dynamic> data) {
    if (!mounted) return;
    // Only parents handle SOS alerts — child app must not show this dialog
    if (SocketService.instance.currentRole != 'parent') return;
    final profileName = data['profileName'] as String? ?? 'Bé';
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    final audioUrl = data['audioUrl'] as String?;
    final sosTime = data['timestamp']?.toString();

    Timer.run(() {
      if (!mounted) return;
      final ctx = widget.navigatorKey?.currentContext ?? context;
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => _SOSAlertDialog(
          profileName: profileName,
          lat: lat,
          lng: lng,
          audioUrl: audioUrl,
          sosTime: sosTime,
          navigatorKey: widget.navigatorKey,
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
    if (SocketService.instance.currentRole != 'parent') return;

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

  void _onTimeExtensionRequest(Map<String, dynamic> data) {
    if (!mounted) return;
    // Only parents approve/deny time extension requests
    if (SocketService.instance.currentRole != 'parent') return;

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

  void _respondExtension(int requestId, bool approved, int minutes) {
    // Remove from Set now that Parent has responded — future polls won't re-show this dialog
    _activeRequestIds.remove(requestId);

    SocketService.instance.socket.emit('respondTimeExtension', {
      'requestId': requestId,
      'approved': approved,
      'responseMinutes': minutes,
    });

    final dialogContext = widget.navigatorKey?.currentContext ?? context;
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(
        content: Text(approved ? '✅ Đã duyệt thêm $minutes phút' : '❌ Đã từ chối yêu cầu'),
        backgroundColor: approved ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    SocketService.instance.removeTimeExtensionRequestListener(_onTimeExtensionRequest);
    SocketService.instance.removeGeofenceEventListener(_onGeofenceEvent);
    SocketService.instance.removeSosAlertListener(_onSosAlert);
    // BUG 3 FIX: Remove the named connect handler to prevent stacking
    SocketService.instance.socket.off('connect', _onSocketReconnect);
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
