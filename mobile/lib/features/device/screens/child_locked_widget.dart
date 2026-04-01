import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class ChildLockedWidget extends StatefulWidget {
  final VoidCallback onRequestTime;
  final VoidCallback onGoHome;

  const ChildLockedWidget({
    super.key,
    required this.onRequestTime,
    required this.onGoHome,
  });

  @override
  State<ChildLockedWidget> createState() => _ChildLockedWidgetState();
}

class _ChildLockedWidgetState extends State<ChildLockedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late Timer _clockTimer;
  String _currentTime = '';
  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _startClock();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  void _startClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        _currentDate = _formatDate(now);
      });
    }
  }

  String _formatDate(DateTime dt) {
    const weekdays = [
      'chủ nhật', 'thứ hai', 'thứ ba', 'thứ tư',
      'thứ năm', 'thứ sáu', 'thứ bảy',
    ];
    const months = [
      '', 'tháng 1', 'tháng 2', 'tháng 3', 'tháng 4',
      'tháng 5', 'tháng 6', 'tháng 7', 'tháng 8',
      'tháng 9', 'tháng 10', 'tháng 11', 'tháng 12',
    ];
    return '${weekdays[dt.weekday % 7]}, ${dt.day} ${months[dt.month]}';
  }

  String get _countdownStr {
    final now = DateTime.now();
    final tomorrow6am = DateTime(now.year, now.month, now.day + 1, 6, 0, 0);
    final diff = tomorrow6am.difference(now);
    if (diff.isNegative) return '00:00:00';
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.gradientBg(AppColors.lockedGradient),
          child: Stack(
            children: [
              // Background blur decorations
              Positioned(
                top: -64,
                left: -64,
                child: _BlurCircle(
                  size: 256,
                  color: AppColors.indigo500.withOpacity(0.10),
                ),
              ),
              Positioned(
                bottom: -64,
                right: -64,
                child: _BlurCircle(
                  size: 256,
                  color: AppColors.purple500.withOpacity(0.10),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.screenPadding,
                  ),
                  child: Column(
                    children: [
                      _buildClockSection(),
                      _buildLockIconSection(),
                      const SizedBox(height: 24),
                      _buildCountdownCard(),
                      const SizedBox(height: 16),
                      _buildActivitiesCard(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      _buildFooter(),
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

  Widget _buildClockSection() {
    return Column(
      children: [
        const SizedBox(height: 64),
        Text(
          _currentTime,
          style: GoogleFonts.nunito(
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -2,
          ),
        ),
        Text(
          _currentDate,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: Colors.white.withOpacity(0.50),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLockIconSection() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (ctx, child) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.rose500.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.rose500.withOpacity(0.20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.rose500.withOpacity(0.30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 40,
                        color: Color(0xFFFCA5A5), // rose-300
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Đã hết giờ!',
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bạn đã sử dụng hết thời gian được phép hôm nay.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: Colors.white.withOpacity(0.60),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Nghỉ ngơi là điều quan trọng! 😊',
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: Colors.white.withOpacity(0.50),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCountdownCard() {
    return Container(
      width: double.infinity,
      decoration: AppTheme.glassCardSubtle(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          Text(
            'Mở khóa lần tiếp theo',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.white.withOpacity(0.60),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _countdownStr,
            style: GoogleFonts.nunito(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.indigo400,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '06:00 sáng ngày mai',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.white.withOpacity(0.40),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor: const AlwaysStoppedAnimation(AppColors.indigo500),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.20),
            const Color(0xFFF97316).withOpacity(0.20),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(
          color: const Color(0xFFFBBF24).withOpacity(0.30),
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Bạn có thể làm gì bây giờ?',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFDE68A),
            ),
          ),
          const SizedBox(height: 8),
          ...[
            '📚 Đọc sách hoặc làm bài tập',
            '🎨 Vẽ tranh hoặc tô màu',
            '🏃 Vận động, chơi ngoài trời',
            '💤 Nghỉ ngơi và ngủ đủ giấc',
          ].map(
            (s) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: const Color(0xFFFDE68A).withOpacity(0.70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: AppTheme.btnHeightLg,
          child: ElevatedButton.icon(
            onPressed: widget.onRequestTime,
            icon: const Icon(Icons.message_outlined),
            label: Text(
              'Xin thêm giờ từ Bố/Mẹ',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.indigo600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
              ),
              elevation: 8,
              shadowColor: AppColors.slate900.withOpacity(0.50),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: AppTheme.btnHeightSm,
          child: OutlinedButton.icon(
            onPressed: widget.onGoHome,
            icon: Icon(
              Icons.home_outlined,
              color: Colors.white.withOpacity(0.80),
            ),
            label: Text(
              'Về trang chủ',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.80),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.20)),
              backgroundColor: Colors.white.withOpacity(0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, top: 8),
      child: Text(
        'KidShield đang bảo vệ bạn 🛡️',
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: Colors.white.withOpacity(0.20),
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
