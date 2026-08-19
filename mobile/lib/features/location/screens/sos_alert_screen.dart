import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';

class SOSAlertScreen extends StatefulWidget {
  final String profileName;
  final double latitude;
  final double longitude;
  final String? audioUrl;
  final String? phone;
  /// ISO 8601 timestamp string from server (e.g. createdAt). Optional.
  final String? sosTime;
  /// SOS alert ID từ server — dùng để acknowledge/resolve.
  final int? sosId;
  /// Trạng thái hiện tại: 'ACTIVE' | 'ACKNOWLEDGED' | 'RESOLVED'
  final String? status;

  const SOSAlertScreen({
    super.key,
    required this.profileName,
    required this.latitude,
    required this.longitude,
    this.audioUrl,
    this.phone,
    this.sosTime,
    this.sosId,
    this.status,
  });

  @override
  State<SOSAlertScreen> createState() => _SOSAlertScreenState();
}

class _SOSAlertScreenState extends State<SOSAlertScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _circleManager;
  bool _isUpdating = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status ?? 'ACTIVE';
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl!));
    }
  }

  Future<void> _updateSOSStatus(String action) async {
    if (widget.sosId == null || _isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await DioClient.instance.put('/api/sos/${widget.sosId}/$action');
      final newStatus = action == 'acknowledge' ? 'ACKNOWLEDGED' : 'RESOLVED';
      setState(() => _currentStatus = newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'ACKNOWLEDGED' ? 'Đã xác nhận SOS' : 'Đã giải quyết SOS',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            backgroundColor: newStatus == 'ACKNOWLEDGED' ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật trạng thái: $e',
                style: GoogleFonts.nunito()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _callChild() async {
    final phone = widget.phone ?? '1234567890';
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể thực hiện cuộc gọi')),
        );
      }
    }
  }

  /// TC-14 B4: Format the ISO timestamp from server to a human-readable string.
  String get _formattedTime {
    if (widget.sosTime == null) return '';
    try {
      final dt = DateTime.parse(widget.sosTime!).toLocal();
      return DateFormat('HH:mm  dd/MM/yyyy').format(dt);
    } catch (_) {
      return widget.sosTime!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      appBar: AppBar(
        title: Text('SOS CẢNH BÁO!',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.red.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64),
                const SizedBox(height: 8),
                Text(
                  '${widget.profileName} đang gặp nguy hiểm!',
                  style: GoogleFonts.nunito(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                // TC-14 B4: Show SOS timestamp
                if (_formattedTime.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formattedTime,
                        style: GoogleFonts.nunito(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _playAudio,
                    icon: Icon(_isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill),
                    label: Text(
                      _isPlaying ? 'Tạm dừng ghi âm' : 'Nghe ghi âm 15s',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _callChild,
                  icon: const Icon(Icons.call),
                  label: const Text('Gọi điện cho bé',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (widget.sosId != null && _currentStatus == 'ACTIVE') ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _isUpdating ? null : () => _updateSOSStatus('acknowledge'),
                    icon: _isUpdating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Đã nhận được SOS',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                if (widget.sosId != null && _currentStatus == 'ACKNOWLEDGED') ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _isUpdating ? null : () => _updateSOSStatus('resolve'),
                    icon: _isUpdating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.task_alt),
                    label: const Text('Đã giải quyết xong',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: mapbox.MapWidget(
                key: const ValueKey("sosMapWidget"),
                textureView: true,
                styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
                cameraOptions: mapbox.CameraOptions(
                  center: mapbox.Point(
                      coordinates: mapbox.Position(widget.longitude, widget.latitude)),
                  zoom: 16.0,
                ),
                onMapCreated: (mapbox.MapboxMap mapboxMap) async {
                  _mapboxMap = mapboxMap;
                  // TC-14 B5 + TC-17: CircleAnnotation always renders regardless of sprite
                  _circleManager =
                      await mapboxMap.annotations.createCircleAnnotationManager();
                  await _circleManager!.create(mapbox.CircleAnnotationOptions(
                    geometry: mapbox.Point(
                        coordinates:
                            mapbox.Position(widget.longitude, widget.latitude)),
                    circleRadius: 14.0,
                    circleColor: Colors.red.value,
                    circleStrokeWidth: 3.0,
                    circleStrokeColor: Colors.white.value,
                  ));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
