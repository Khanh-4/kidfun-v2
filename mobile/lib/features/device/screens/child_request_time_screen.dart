import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_theme.dart';

enum _RequestState { form, sending, sent }

class ChildRequestTimeScreen extends StatefulWidget {
  const ChildRequestTimeScreen({super.key});

  @override
  State<ChildRequestTimeScreen> createState() => _ChildRequestTimeScreenState();
}

class _ChildRequestTimeScreenState extends State<ChildRequestTimeScreen>
    with TickerProviderStateMixin {
  _RequestState _state = _RequestState.form;
  String? _deviceCode;

  // Form selections
  int? _selectedReasonIndex;
  int? _selectedMinutes;
  final _noteController = TextEditingController();

  // Animations
  late AnimationController _pulseCtrl;

  // ── Data ────────────────────────────────────────────────────────────
  static const _reasons = [
    {'emoji': '📚', 'label': 'Đang học bài'},
    {'emoji': '🎬', 'label': 'Xem phim chưa xong'},
    {'emoji': '👫', 'label': 'Chơi với bạn bè'},
    {'emoji': '🎉', 'label': 'Cuối tuần / ngày nghỉ'},
    {'emoji': '🎓', 'label': 'Xem video học tập'},
    {'emoji': '✍️', 'label': 'Lý do khác'},
  ];

  static const _timeOptions = [
    {'emoji': '⏱', 'label': '15 phút', 'value': 15},
    {'emoji': '⏰', 'label': '30 phút', 'value': 30},
    {'emoji': '🕐', 'label': '1 giờ',   'value': 60},
    {'emoji': '🕑', 'label': '2 giờ',   'value': 120},
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadDeviceCode();
  }

  Future<void> _loadDeviceCode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _deviceCode = prefs.getString('device_code'));
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Submit ───────────────────────────────────────────────────────────
  bool get _canSubmit =>
      _selectedReasonIndex != null && _selectedMinutes != null;

  String get _selectedReasonLabel =>
      _selectedReasonIndex != null
          ? _reasons[_selectedReasonIndex!]['label']!
          : '';

  void _submit() {
    if (!_canSubmit || _deviceCode == null) return;

    setState(() => _state = _RequestState.sending);

    SocketService.instance.socket.emit('requestTimeExtension', {
      'deviceCode': _deviceCode,
      'requestMinutes': _selectedMinutes,
      'reason': _selectedReasonLabel +
          (_noteController.text.trim().isNotEmpty
              ? ': ${_noteController.text.trim()}'
              : ''),
    });

    // Chuyển sang trạng thái sent sau 1.5 giây
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _state = _RequestState.sent);
    });
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBg(AppColors.requestTimeGradient),
        child: SafeArea(
          child: switch (_state) {
            _RequestState.form    => _buildForm(),
            _RequestState.sending => _buildSending(),
            _RequestState.sent    => _buildSent(),
          },
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding, 8, AppTheme.screenPadding, 16),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(AppTheme.radiusBtnSm),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xin thêm giờ',
              style: GoogleFonts.nunito(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Gửi yêu cầu đến Bố/Mẹ',
              style: GoogleFonts.nunito(
                fontSize: 12, color: Colors.white.withOpacity(0.70))),
        ]),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STATE: FORM
  // ════════════════════════════════════════════════════════════════════
  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          child: Column(children: [
            // ── Hero ──────────────────────────────────────────────────
            Container(
              width: 96, height: 96,
              decoration: AppTheme.glassCard(radius: 24),
              child: const Center(
                child: Text('🙏', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Nhờ Bố/Mẹ giúp!',
                style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Hãy chọn lý do và thời gian phù hợp',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13, color: Colors.white.withOpacity(0.70))),
            const SizedBox(height: 20),

            // ── Reason Card ───────────────────────────────────────────
            _GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📋 Lý do xin thêm giờ?',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: _reasons.length,
                  itemBuilder: (ctx, i) => _ReasonChip(
                    emoji: _reasons[i]['emoji']!,
                    label: _reasons[i]['label']!,
                    selected: _selectedReasonIndex == i,
                    onTap: () => setState(() => _selectedReasonIndex = i),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Time Card ─────────────────────────────────────────────
            _GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('⏱ Muốn xin thêm bao lâu?',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: _timeOptions.length,
                  itemBuilder: (ctx, i) {
                    final opt = _timeOptions[i];
                    final val = opt['value'] as int;
                    return _TimeChip(
                      emoji: opt['emoji']! as String,
                      label: opt['label']! as String,
                      selected: _selectedMinutes == val,
                      onTap: () => setState(() => _selectedMinutes = val),
                    );
                  },
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Note Card ─────────────────────────────────────────────
            _GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💬 Lời nhắn cho Bố/Mẹ (tùy chọn)',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: GoogleFonts.nunito(
                    color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Con đang xem video toán học...',
                    hintStyle: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.40), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusCardMd),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.30)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusCardMd),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.60), width: 1.5),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Submit button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: AppTheme.btnHeightLg,
              child: ElevatedButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text('Gửi yêu cầu cho Bố/Mẹ',
                    style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFEA580C),
                  disabledBackgroundColor: Colors.white.withOpacity(0.40),
                  disabledForegroundColor: Colors.white.withOpacity(0.60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.30),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STATE: SENDING
  // ════════════════════════════════════════════════════════════════════
  Widget _buildSending() {
    return Column(children: [
      _buildHeader(),
      Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinner
              SizedBox(
                width: 128, height: 128,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 128, height: 128,
                    child: CircularProgressIndicator(
                      color: Colors.white.withOpacity(0.50),
                      strokeWidth: 3,
                    ),
                  ),
                  Container(
                    width: 104, height: 104,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        size: 44, color: Colors.white),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              Text('Đang gửi yêu cầu...',
                  style: GoogleFonts.nunito(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              const SizedBox(height: 8),
              Text('Bố/Mẹ sẽ nhận được thông báo ngay',
                  style: GoogleFonts.nunito(
                    fontSize: 14, color: Colors.white.withOpacity(0.70))),
              const SizedBox(height: 20),
              const _BouncingDots(),
            ],
          ),
        ),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════
  // STATE: SENT
  // ════════════════════════════════════════════════════════════════════
  Widget _buildSent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          child: Column(children: [
            // ── Checkmark icon ────────────────────────────────────────
            Container(
              width: 128, height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      size: 56, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Đã gửi! 🎉',
                style: GoogleFonts.nunito(
                  fontSize: 24, fontWeight: FontWeight.w700,
                  color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Yêu cầu xin thêm $_selectedMinutes phút đã được\ngửi đến Bố/Mẹ. Hãy chờ một chút nhé!',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13, color: Colors.white.withOpacity(0.70)),
            ),
            const SizedBox(height: 20),

            // ── Summary card ──────────────────────────────────────────
            _GlassCard(
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('🙏', style: TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Yêu cầu của bạn',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('Đang chờ phê duyệt',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.60))),
                  ]),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.20),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text('Đang chờ',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: const Color(0xFFFDE68A))),
                  ),
                ]),
                Divider(
                    color: Colors.white.withOpacity(0.15), height: 24),
                _InfoRow('Thời gian xin', '$_selectedMinutes phút'),
                const SizedBox(height: 4),
                _InfoRow('Lý do', _selectedReasonLabel),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Tip card ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
              ),
              child: Text(
                '💡 Mẹo nhỏ: Trong khi chờ, bạn có thể đọc sách hoặc nghỉ ngơi!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13, color: Colors.white.withOpacity(0.60)),
              ),
            ),
            const SizedBox(height: 16),

            // ── Back button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: AppTheme.btnHeightLg,
              child: ElevatedButton(
                onPressed: () => context.go('/child-dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFEA580C),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusBtn)),
                  elevation: 6,
                ),
                child: Text('Về màn hình chính',
                    style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.glassCard(),
      child: child,
    );
  }
}

class _ReasonChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ReasonChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withOpacity(0.20),
            width: 2,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? const Color(0xFFEA580C)
                      : Colors.white,
                )),
          ),
        ]),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TimeChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: selected
            ? (Matrix4.identity()..scale(1.05))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withOpacity(0.20),
            width: 2,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFFEA580C)
                    : Colors.white,
              )),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
              fontSize: 13, color: Colors.white.withOpacity(0.60))),
        Text(value,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
      ],
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 0, end: -10).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => AnimatedBuilder(
        animation: _anims[i],
        builder: (ctx, _) => Transform.translate(
          offset: Offset(0, _anims[i].value),
          child: Container(
            width: 10, height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.60),
              shape: BoxShape.circle,
            ),
          ),
        ),
      )),
    );
  }
}
