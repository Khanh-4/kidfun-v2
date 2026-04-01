import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/device_provider.dart';
import '../../auth/providers/role_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/socket_service.dart';

enum _LinkState { input, waiting, success }

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  _LinkState _linkState = _LinkState.input;
  bool _isProcessing = false;
  bool _isScanning = false;
  String? _linkedCode;

  final MobileScannerController _controller = MobileScannerController();
  final List<TextEditingController> _codeControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(4, (_) => FocusNode());

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _controller.dispose();
    for (final c in _codeControllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ── Logic (giữ nguyên từ bản cũ) ─────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _processPairingCode(code);
  }

  Future<void> _processPairingCode(String code) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _linkState = _LinkState.waiting;
      _isScanning = false;
    });
    _controller.stop();

    try {
      await ref.read(deviceProvider.notifier).linkDevice(code);

      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final savedDeviceCode = prefs.getString('device_code');
        if (savedDeviceCode != null && savedDeviceCode.isNotEmpty) {
          SocketService.instance.joinDevice(savedDeviceCode);
          print('📡 Scan QR: called joinDevice for code $savedDeviceCode');
        }
        setState(() {
          _linkState = _LinkState.success;
          _linkedCode = code;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _linkState = _LinkState.input;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
        _controller.start();
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool get _isCodeComplete =>
      _codeControllers.every((c) => c.text.isNotEmpty);

  String get _fullCode => _codeControllers.map((c) => c.text).join();

  void _clearCode() {
    for (final c in _codeControllers) c.clear();
    _focusNodes.first.requestFocus();
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final roleState = ref.watch(roleProvider).valueOrNull;
    final isChild = roleState?.role == 'child';

    // QR Scanner overlay
    if (_isScanning) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) setState(() => _isScanning = false);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('Quét mã QR',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.indigo600,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _isScanning = false),
            ),
          ),
          body: Stack(
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Text(
                  'Căn chỉnh mã QR vào trong khung',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !isChild,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.gradientBg(AppColors.linkDeviceGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: Column(
                children: [
                  _buildHeader(isChild),
                  const SizedBox(height: 8),
                  if (_linkState == _LinkState.input) _buildInputState(),
                  if (_linkState == _LinkState.waiting) _buildWaitingState(),
                  if (_linkState == _LinkState.success) _buildSuccessState(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isChild) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          if (!isChild)
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusBtnSm),
                ),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            )
          else
            GestureDetector(
              onTap: () => ref.read(roleProvider.notifier).clearRole(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusBtnSm),
                ),
                child: const Icon(Icons.swap_horiz,
                    color: Colors.white, size: 20),
              ),
            ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Liên kết thiết bị',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'KidShield Child Monitor',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── State: input ──────────────────────────────────────────────────────────

  Widget _buildInputState() {
    return Column(
      children: [
        // Hero icon
        Container(
          width: 96,
          height: 96,
          decoration: AppTheme.glassCard(radius: 24),
          child: const Center(
            child: Text('🔗', style: TextStyle(fontSize: 48)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Liên kết với Phụ huynh',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nhập mã 4 chữ số do phụ huynh cung cấp',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: Colors.white.withOpacity(0.70),
          ),
        ),
        const SizedBox(height: 24),

        // 4-digit input card
        Container(
          decoration: AppTheme.glassCard(),
          padding: const EdgeInsets.all(AppTheme.cardPadding),
          child: Column(
            children: [
              Text(
                'Nhập mã liên kết',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.80),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (i) => _buildDigitBox(i)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: AppTheme.btnHeightLg,
                child: ElevatedButton(
                  onPressed: _isCodeComplete
                      ? () => _processPairingCode(_fullCode)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.indigo700,
                    disabledBackgroundColor: Colors.white.withOpacity(0.40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                    ),
                    elevation: 6,
                  ),
                  child: Text(
                    'Xác nhận liên kết',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã sẽ hết hạn sau 10 phút',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.60),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // QR scan button
        TextButton.icon(
          onPressed: () {
            _controller.start();
            setState(() => _isScanning = true);
          },
          icon: Icon(Icons.qr_code_scanner,
              color: Colors.white.withOpacity(0.70), size: 16),
          label: Text(
            'Hoặc quét mã QR',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.white.withOpacity(0.70),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Steps guide card
        Container(
          decoration: AppTheme.glassCardSubtle(),
          padding: const EdgeInsets.all(AppTheme.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hướng dẫn liên kết:',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.80),
                ),
              ),
              const SizedBox(height: 12),
              ..._steps.map((s) => _buildStep(s)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      width: 56,
      height: 64,
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: '',
          hintText: '·',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.40),
            fontSize: 22,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.20),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
            borderSide:
                BorderSide(color: Colors.white.withOpacity(0.30), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
            borderSide:
                BorderSide(color: Colors.white.withOpacity(0.70), width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }

  static const _steps = [
    {'emoji': '📱', 'title': 'Tải ứng dụng', 'desc': 'Tải KidShield từ App Store hoặc Google Play'},
    {'emoji': '🚀', 'title': 'Mở ứng dụng', 'desc': 'Mở và chọn "Liên kết thiết bị mới"'},
    {'emoji': '🔢', 'title': 'Nhập mã hoặc quét QR', 'desc': 'Nhập mã 4 chữ số từ phụ huynh'},
    {'emoji': '✅', 'title': 'Xác nhận từ phụ huynh', 'desc': 'Phụ huynh nhận thông báo xác nhận'},
  ];

  Widget _buildStep(Map s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(AppTheme.radiusIconSm),
            ),
            child: Center(
              child: Text(
                s['emoji']! as String,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['title']! as String,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                Text(
                  s['desc']! as String,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── State: waiting ────────────────────────────────────────────────────────

  Widget _buildWaitingState() {
    return Column(
      children: [
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (ctx, _) => Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20 * _pulseAnim.value),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.30),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('⏳', style: TextStyle(fontSize: 40)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Đang xử lý...',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Đang liên kết thiết bị, vui lòng chờ...',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: Colors.white.withOpacity(0.70),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: AppTheme.glassCard(),
          padding: const EdgeInsets.all(AppTheme.cardPadding),
          child: Column(
            children: [
              Text(
                'Thiết bị đang liên kết',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.80),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã: ${_linkedCode ?? _fullCode}',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const _BouncingDots(),
            ],
          ),
        ),
      ],
    );
  }

  // ── State: success ────────────────────────────────────────────────────────

  Widget _buildSuccessState() {
    final roleState = ref.read(roleProvider).valueOrNull;

    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: const Color(0xFF34D399).withOpacity(0.30),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withOpacity(0.40),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Liên kết thành công! 🎉',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thiết bị đã được liên kết với tài khoản của Bố/Mẹ',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: Colors.white.withOpacity(0.70),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: AppTheme.glassCard(),
          padding: const EdgeInsets.all(AppTheme.cardPadding),
          child: Column(
            children: [
              _buildInfoRow('Mã liên kết', _linkedCode ?? '—'),
              _buildInfoRow('Trạng thái', 'Đã xác nhận'),
              _buildInfoRow('Chế độ', 'Giám sát bởi phụ huynh'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: AppTheme.btnHeightLg,
          child: ElevatedButton(
            onPressed: () {
              if (roleState?.role == 'child') {
                ref.read(roleProvider.notifier).setLinked(true);
              } else {
                context.pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.indigo700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
              ),
              elevation: 8,
            ),
            child: Text(
              'Bắt đầu sử dụng →',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _clearCode,
          child: Text(
            'Liên kết thiết bị khác',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.white.withOpacity(0.60),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.white.withOpacity(0.70),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _BouncingDots ─────────────────────────────────────────────────────────────

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true);
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.forward();
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _ctrls[i],
          builder: (ctx, _) => Transform.translate(
            offset: Offset(0, -8 * _ctrls[i].value),
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.60),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
