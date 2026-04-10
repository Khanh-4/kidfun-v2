import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/socket_service.dart';
import '../../core/network/dio_client.dart';

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
  // Uses addPostFrameCallback so showDialog is never called mid-frame (socket callbacks
  // can fire during setState/layout and cause showDialog to fail silently).
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  // TC-21: Global sosAlert handler — active from any screen, not just ProfileListScreen
  void _onSosAlert(Map<String, dynamic> data) {
    if (!mounted) return;
    final profileName = data['profileName'] as String? ?? 'Bé';
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    final audioUrl = data['audioUrl'] as String?;
    final sosTime = data['timestamp']?.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = widget.navigatorKey?.currentContext;
      if (ctx == null) return;
      ctx.push('/sos-alert', extra: {
        'profileName': profileName,
        'latitude': lat,
        'longitude': lng,
        'audioUrl': audioUrl,
        'phone': null,
        'sosTime': sosTime,
      });
    });
  }

  // TC-21 Step 4: REST check for ACTIVE SOS missed while parent was offline.
  // Checks the most recent SOS for each profile — if status=ACTIVE and within
  // the last 10 minutes, navigate to the SOS alert screen.
  Future<void> _checkActiveSOS() async {
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

        print('🆘 [REST] Found active SOS for profile $profileName — navigating to alert');
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = widget.navigatorKey?.currentContext;
          if (ctx == null) return;
          ctx.push('/sos-alert', extra: {
            'profileName': profileName,
            'latitude': (latest['latitude'] as num?)?.toDouble() ?? 0.0,
            'longitude': (latest['longitude'] as num?)?.toDouble() ?? 0.0,
            'audioUrl': latest['audioUrl'] as String?,
            'phone': null,
            'sosTime': latest['createdAt']?.toString(),
          });
        });
        return; // Show only the first active SOS found
      }
    } catch (e) {
      print('❌ [REST] Error checking active SOS: $e');
    }
  }

  void _onTimeExtensionRequest(Map<String, dynamic> data) {
    if (!mounted) return;

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

