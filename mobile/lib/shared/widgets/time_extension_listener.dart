import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    // BUG 3 FIX: Store named reference so we can remove it in dispose().
    // Previously the raw socket.on('connect', ...) was never cleaned up, causing
    // N listeners to stack on every widget recreation → N dialogs per reconnect.
    SocketService.instance.socket.on('connect', _onSocketReconnect);
  }

  // Named handler so it can be deregistered with off() in dispose()
  void _onSocketReconnect(_) {
    print('🔄 [SOCKET] Reconnected. Checking pending extension requests...');
    _checkPendingRequests();
  }

  void _setupSocketListener() {
    SocketService.instance.addTimeExtensionRequestListener(_onTimeExtensionRequest);
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
                  child: Text('Duyệt ($requestMinutes phút)'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _respondExtension(requestId, false, 0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade900,
                    elevation: 0,
                  ),
                  child: const Text('Từ chối'),
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
    // BUG 3 FIX: Remove the named connect handler to prevent stacking
    SocketService.instance.socket.off('connect', _onSocketReconnect);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

