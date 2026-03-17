import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/socket_service.dart';

class TimeExtensionListener extends ConsumerStatefulWidget {
  final Widget child;
  const TimeExtensionListener({super.key, required this.child});

  @override
  ConsumerState<TimeExtensionListener> createState() => _TimeExtensionListenerState();
}

class _TimeExtensionListenerState extends ConsumerState<TimeExtensionListener> {
  @override
  void initState() {
    super.initState();
    _setupSocketListener();
  }

  void _setupSocketListener() {
    SocketService.instance.addTimeExtensionRequestListener(_onTimeExtensionRequest);
  }

  void _onTimeExtensionRequest(Map<String, dynamic> data) {
    if (!mounted) return;

    final requestId = data['id']; // Server uses id from Date.now() or similar
    final profileName = data['profileName'] ?? 'Bé';
    final deviceName = data['deviceName'] ?? 'Thiết bị';
    final requestMinutes = data['requestedMinutes'] as int? ?? 15;
    final reason = data['reason'] ?? '';

    // Lấy context global nhất có thể nếu được, hoặc dùng context hiện tại
    showDialog(
      context: context,
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
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _respondExtension(requestId, false, 0);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _respondExtension(requestId, true, requestMinutes);
            },
            child: Text('Duyệt ($requestMinutes phút)'),
          ),
        ],
      ),
    );
  }

  void _respondExtension(dynamic requestId, bool approved, int minutes) {
    SocketService.instance.socket.emit('respondTimeExtension', {
      'requestId': requestId,
      'approved': approved,
      'responseMinutes': minutes,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approved ? '✅ Đã duyệt thêm $minutes phút' : '❌ Đã từ chối yêu cầu'),
        backgroundColor: approved ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    SocketService.instance.removeTimeExtensionRequestListener(_onTimeExtensionRequest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
