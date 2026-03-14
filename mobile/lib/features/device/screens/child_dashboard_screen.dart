import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/providers/role_provider.dart';
import '../../../core/network/socket_service.dart';

class ChildDashboardScreen extends ConsumerStatefulWidget {
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasToken = false;
  bool _isSocketConnected = false;
  String? _deviceCode;
  Timer? _connectionCheckTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the connection indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('device_token');
    final deviceCode = prefs.getString('device_code');

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() {
        _hasToken = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _hasToken = true;
      _deviceCode = deviceCode;
      _isLoading = false;
    });

    // Connect Socket.IO (idempotent — won't duplicate if already connected)
    if (deviceCode != null && deviceCode.isNotEmpty) {
      SocketService.instance.connectAsChild(deviceCode);
    }

    // Poll socket connection status every 3 seconds
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _isSocketConnected = SocketService.instance.isConnected;
        });
      }
    });

    // Initial check
    setState(() => _isSocketConnected = SocketService.instance.isConnected);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasToken) {
      return _buildRelinkScreen();
    }

    return _buildDashboard();
  }

  Widget _buildRelinkScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.link_off, size: 100, color: Colors.white70),
                  const SizedBox(height: 24),
                  Text(
                    'Chưa liên kết thiết bị',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vui lòng liên kết thiết bị với tài khoản phụ huynh trước khi tiếp tục.',
                    style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(roleProvider.notifier).setLinked(false),
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: Text('Quét mã QR', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF667EEA),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return PopScope(
      canPop: false, // Child cannot go back
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                      _buildTimeCard(),
                      const SizedBox(height: 24),
                      _buildConnectionStatus(),
                      const SizedBox(height: 24),
                      _buildRequestMoreTimeButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // App name
          Expanded(
            child: Text(
              'KidFun 🌟',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // Connection indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isSocketConnected ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _isSocketConnected ? Colors.greenAccent : Colors.red.shade300,
                    shape: BoxShape.circle,
                    boxShadow: _isSocketConnected
                        ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.7), blurRadius: 8, spreadRadius: 2)]
                        : [],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            _isSocketConnected ? 'Đã kết nối máy chủ' : 'Mất kết nối máy chủ',
            style: GoogleFonts.nunito(
              color: _isSocketConnected ? Colors.greenAccent : Colors.red.shade200,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF42E695), Color(0xFF3BB2B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF42E695).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          const Text('👦', style: TextStyle(fontSize: 60)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào!',
                  style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  'Hôm nay vui không? 😊',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Text(
            '⏳ Thời gian còn lại',
            style: GoogleFonts.nunito(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '2:30:00',
            style: GoogleFonts.nunito(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF667EEA),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '(Cập nhật ở Sprint 4)',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isSocketConnected
            ? Colors.green.shade50
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSocketConnected ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (ctx, child) {
              return Transform.scale(
                scale: _isSocketConnected ? _pulseAnimation.value : 1.0,
                child: Icon(
                  _isSocketConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isSocketConnected ? Colors.green : Colors.red,
                  size: 32,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSocketConnected ? '🟢 Đã kết nối với máy chủ' : '🔴 Mất kết nối',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isSocketConnected ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                Text(
                  _isSocketConnected
                      ? 'Phụ huynh có thể theo dõi hoạt động của bạn'
                      : 'Đang cố gắng kết nối lại...',
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (!_isSocketConnected)
            IconButton(
              onPressed: () {
                if (_deviceCode != null) {
                  SocketService.instance.connectAsChild(_deviceCode!);
                }
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Kết nối lại',
            ),
        ],
      ),
    );
  }

  Widget _buildRequestMoreTimeButton() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⏳ Tính năng xin thêm giờ sẽ có ở Sprint 4!',
              style: GoogleFonts.nunito(fontSize: 15),
            ),
            backgroundColor: const Color(0xFF667EEA),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9966), Color(0xFFFF5E62)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFF5E62).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🙋', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Text(
                'Xin thêm giờ',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
