import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';

class SOSAlertScreen extends StatefulWidget {
  final String profileName;
  final double latitude;
  final double longitude;
  final String? audioUrl;
  final String? phone;

  const SOSAlertScreen({
    super.key,
    required this.profileName,
    required this.latitude,
    required this.longitude,
    this.audioUrl,
    this.phone,
  });

  @override
  State<SOSAlertScreen> createState() => _SOSAlertScreenState();
}

class _SOSAlertScreenState extends State<SOSAlertScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;

  @override
  void initState() {
    super.initState();
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

  Future<void> _callChild() async {
    final phone = widget.phone ?? '1234567890'; // Placeholder
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      appBar: AppBar(
        title: Text('SOS CẢNH BÁO!', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.white)),
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
                  style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _playAudio,
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                    label: Text(_isPlaying ? 'Tạm dừng ghi âm' : 'Nghe ghi âm 15s', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  label: const Text('Gọi điện cho bé', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: MapWidget(
                key: const ValueKey("sosMapWidget"),
                textureView: true,
                styleUri: MapboxStyles.STREETS,
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(widget.longitude, widget.latitude)),
                  zoom: 16.0,
                ),
                onMapCreated: (MapboxMap mapboxMap) async {
                  _mapboxMap = mapboxMap;
                  _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                  await _annotationManager!.create(PointAnnotationOptions(
                    geometry: Point(coordinates: Position(widget.longitude, widget.latitude)),
                    iconImage: 'marker-15',
                  ));
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
