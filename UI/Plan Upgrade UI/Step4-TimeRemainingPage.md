# Bước 4 — TimeRemainingPage (Child Dashboard)

> **Branch:** `feat/ui/time-remaining-page`  
> **Trạng thái:** ✅ Xong  
> **Phụ thuộc:** Bước 1, 2, 3 phải xong trước

---

## Mục tiêu

Redesign toàn bộ UI của `child_dashboard_screen.dart` theo spec 4.2.  
**Giữ nguyên 100% logic** (socket, countdown timer, heartbeat, session, NativeService).  
Chỉ thay đổi phần `build()` và các widget helper.

---

## File cần sửa

| File | Action |
|------|--------|
| `mobile/lib/features/device/screens/child_dashboard_screen.dart` | Redesign `build()` + widget helpers |

---

## Spec tham chiếu: Section 4.2 của `UI/KIDSHIELD_UI_SPEC.md`

---

## Background

```dart
Container(
  decoration: AppTheme.gradientBg(AppColors.timeRemainingGradient),
  // gradient: #7C3AED → #4F46E5 → #1D4ED8
)
```

---

## Cấu trúc `build()` mới

```dart
@override
Widget build(BuildContext context) {
  if (_isLoading) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBg(AppColors.timeRemainingGradient),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }

  // Locked state → ChildLockedWidget (Bước 3)
  if (_isTimeUp) {
    return ChildLockedWidget(
      onRequestTime: () => context.push('/child-request-time'),
      onGoHome: () => setState(() => _isTimeUp = false),
    );
  }

  return Scaffold(
    body: Container(
      decoration: AppTheme.gradientBg(AppColors.timeRemainingGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                         MediaQuery.of(context).padding.top -
                         MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
              child: Column(children: [
                _buildTopBar(),
                _buildProfileRow(),
                SizedBox(height: 8),
                _buildCircularProgress(),
                SizedBox(height: 16),
                _buildStatusMessage(),
                SizedBox(height: 16),
                _buildAppUsageCard(),
                SizedBox(height: 16),
                _buildActionButtons(),
                SizedBox(height: 24),
                _buildFooterStars(),
                SizedBox(height: 16),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}
```

---

## Top Bar

```dart
Widget _buildTopBar() {
  return Padding(
    padding: EdgeInsets.only(top: 16, bottom: 4),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(AppTheme.radiusIconSm),
        ),
        child: Icon(Icons.shield_outlined, color: Colors.white, size: 18),
      ),
      SizedBox(width: 8),
      Text('KidShield',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
      Spacer(),
      AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (ctx, _) => Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: Color(0xFF34D399), // emerald-400
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      SizedBox(width: 6),
      Text('Đang giám sát',
          style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.80))),
    ]),
  );
}
```

---

## Profile Row

```dart
Widget _buildProfileRow() {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        ),
        child: Center(child: Text('👦', style: TextStyle(fontSize: 24))),
      ),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Xin chào!',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
        Text(_deviceCode ?? 'Thiết bị',
            style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.60))),
      ])),
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(AppTheme.radiusIconSm),
        ),
        child: Icon(Icons.notifications_none_outlined, color: Colors.white, size: 20),
      ),
    ]),
  );
}
```

---

## Circular Progress (CustomPaint)

Dùng `CustomPainter` để vẽ SVG-like circular progress.

```dart
Widget _buildCircularProgress() {
  final totalSeconds = _currentTotalLimitMinutes * 60;
  final percent = totalSeconds > 0
      ? (1.0 - (_remainingSeconds / totalSeconds)).clamp(0.0, 1.0)
      : 0.0;
  final isWarning = _remainingSeconds < 30 * 60;

  return Center(
    child: SizedBox(
      width: 220, height: 220,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: Size(220, 220),
          painter: _CircularProgressPainter(
            percent: percent,
            trackColor: Colors.white.withOpacity(0.20),
            fillColor: isWarning ? const Color(0xFFF97316) : Colors.white,
            strokeWidth: 18,
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Thời gian còn lại',
              style: GoogleFonts.nunito(fontSize: 11, color: Colors.white.withOpacity(0.60))),
          Text(
            _formatTimeDisplay(_remainingSeconds),
            style: GoogleFonts.nunito(
              fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white,
            ),
          ),
          Text(
            '/ ${_currentTotalLimitMinutes ~/ 60}h${_currentTotalLimitMinutes % 60 > 0 ? " ${_currentTotalLimitMinutes % 60}m" : ""} hôm nay',
            style: GoogleFonts.nunito(fontSize: 11, color: Colors.white.withOpacity(0.60)),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isWarning
                  ? Color(0xFFF97316).withOpacity(0.30)
                  : Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              'Đã dùng: ${_formatTimeDisplay((_currentTotalLimitMinutes * 60) - _remainingSeconds)}',
              style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: isWarning ? Color(0xFFFFEDD5) : Colors.white,
              ),
            ),
          ),
        ]),
      ]),
    ),
  );
}

// Helper: format seconds → "1h25m" hoặc "25m30s"
String _formatTimeDisplay(int seconds) {
  if (seconds < 0) seconds = 0;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '${h}h${m.toString().padLeft(2,'0')}m';
  if (m > 0) return '${m}m${s.toString().padLeft(2,'0')}s';
  return '${s}s';
}
```

### `_CircularProgressPainter`

```dart
class _CircularProgressPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  const _CircularProgressPainter({
    required this.percent,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // -90 deg
    final sweepAngle = 2 * math.pi * percent;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, 2 * math.pi, false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Fill
    if (percent > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false,
        Paint()
          ..color = fillColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.percent != percent || old.fillColor != fillColor;
}
```

Thêm `import 'dart:math' as math;` ở đầu file.

---

## Status Message

```dart
Widget _buildStatusMessage() {
  final isWarning = _remainingSeconds > 0 && _remainingSeconds < 30 * 60;
  final remainMins = _remainingSeconds ~/ 60;

  return Container(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: isWarning
          ? Color(0xFFF97316).withOpacity(0.20)
          : Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
      border: Border.all(
        color: isWarning
            ? Color(0xFFFED7AA).withOpacity(0.30)  // orange-200/30
            : Colors.white.withOpacity(0.20),
      ),
    ),
    child: Column(children: [
      Text(
        isWarning ? '⚠️ Sắp hết giờ!' : '🌟 Đang dùng tốt!',
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w600, fontSize: 14,
          color: isWarning ? Color(0xFFFED7AA) : Colors.white,
        ),
      ),
      Text(
        isWarning
            ? 'Còn $remainMins phút, hãy chuẩn bị dừng lại nhé'
            : 'Tiếp tục giữ thói quen tốt bạn nhé!',
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: isWarning
              ? Color(0xFFFED7AA).withOpacity(0.70)
              : Colors.white.withOpacity(0.60),
        ),
      ),
    ]),
  );
}
```

---

## App Usage Card (Glass card)

```dart
Widget _buildAppUsageCard() {
  // Hiển thị static demo data (app usage thực tế chưa có API trả về per-app)
  final apps = [
    {'emoji': '▶️', 'name': 'YouTube',   'used': 45, 'max': 60,  'color': Color(0xFFEF4444), 'blocked': false},
    {'emoji': '🎮', 'name': 'Roblox',    'used': 30, 'max': 45,  'color': Color(0xFFF97316), 'blocked': false},
    {'emoji': '📚', 'name': 'Khan Acad', 'used': 20, 'max': 120, 'color': Color(0xFF10B981), 'blocked': false},
    {'emoji': '🎵', 'name': 'TikTok',    'used': 0,  'max': 0,   'color': Color(0xFFEF4444), 'blocked': true},
  ];

  return Container(
    decoration: AppTheme.glassCard(),
    padding: EdgeInsets.all(AppTheme.cardPadding),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ứng dụng hôm nay',
          style: GoogleFonts.nunito(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.80),
          )),
      SizedBox(height: 12),
      ...apps.map((app) => _buildAppRow(app)).toList(),
    ]),
  );
}

Widget _buildAppRow(Map app) {
  final blocked = app['blocked'] as bool;
  final used = app['used'] as int;
  final max = app['max'] as int;
  final color = app['color'] as Color;
  final progress = max > 0 ? (used / max).clamp(0.0, 1.0) : 0.0;
  final isOver = progress > 0.9;

  return Opacity(
    opacity: blocked ? 0.50 : 1.0,
    child: Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(children: [
          Text(app['emoji'] as String, style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Expanded(
            child: Text(app['name'] as String,
                style: GoogleFonts.nunito(fontSize: 13, color: Colors.white)),
          ),
          blocked
              ? Row(children: [
                  Icon(Icons.lock_outline, size: 12, color: Color(0xFFFCA5A5)),
                  SizedBox(width: 4),
                  Text('Bị chặn',
                      style: GoogleFonts.nunito(fontSize: 11, color: Color(0xFFFCA5A5))),
                ])
              : Text('${used}/${max}ph',
                  style: GoogleFonts.nunito(
                    fontSize: 11, color: Colors.white.withOpacity(0.60),
                  )),
        ]),
        if (!blocked) ...[
          SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.20),
              valueColor: AlwaysStoppedAnimation(isOver ? Color(0xFFF97316) : color),
              minHeight: 6,
            ),
          ),
        ],
      ]),
    ),
  );
}
```

---

## Action Buttons (grid 2 cột)

```dart
Widget _buildActionButtons() {
  return Row(children: [
    // Nút "Xin thêm giờ" (ghost)
    Expanded(
      child: GestureDetector(
        onTap: () => context.push('/child-request-time'),
        child: Container(
          height: AppTheme.btnHeightLg,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time_outlined, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Xin thêm giờ',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white,
                  )),
            ]),
          ),
        ),
      ),
    ),
    SizedBox(width: AppTheme.gap),
    // Nút "Trang chủ" (primary white)
    Expanded(
      child: GestureDetector(
        onTap: () {},  // trang chủ (không có action cụ thể cho trẻ)
        child: Container(
          height: AppTheme.btnHeightLg,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
            boxShadow: [BoxShadow(
              color: AppColors.slate900.withOpacity(0.20),
              blurRadius: 12, offset: Offset(0, 4),
            )],
          ),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.home_outlined, color: AppColors.indigo700, size: 18),
              SizedBox(width: 6),
              Text('Trang chủ',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: AppColors.indigo700,
                  )),
            ]),
          ),
        ),
      ),
    ),
  ]);
}
```

---

## Footer Stars

```dart
Widget _buildFooterStars() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(5, (_) =>
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.star, size: 16, color: Colors.white.withOpacity(0.30)),
      ),
    ),
  );
}
```

---

## Giữ nguyên các method logic sau

KHÔNG xóa bất kỳ method nào sau đây:
- `_initializeDashboard()`
- `_initSession()`
- `_startCountdown()`
- `_fetchAndApplyNewLimit()`
- `_setupSocketListeners()`
- `_heartbeat()`
- `_syncBlockedApps()`
- `_checkSoftWarning()`
- `_checkAndRequestPermissions()`
- `_onTimeUp()` → sửa để set flag `_isTimeUp = true` thay vì showDialog
- `_saveEndTime()`
- `didChangeAppLifecycleState()`

---

## Soft warning dialogs

Giữ nguyên `_showWarningDialog()` — vẫn dùng `showDialog` bình thường cho 30m/15m/5m warnings.  
Chỉ đổi `_isTimeUpDialogShowing` → `_isTimeUp` (rename flag toàn file).

---

## Commit message

```
feat(mobile/ui): redesign ChildDashboardScreen theo KidShield spec 4.2
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI/Step4-TimeRemainingPage.md` trong project kidfun-v2.
Tạo branch `feat/ui/time-remaining-page` từ develop (sau khi đã merge bước 1, 2, 3).
Redesign phần `build()` của `child_dashboard_screen.dart` theo plan.
QUAN TRỌNG: Không xóa bất kỳ logic nào (timer, socket, session, heartbeat).
Chỉ thay đổi UI — tất cả các method _init*, _start*, _fetch*, _setup*, _heartbeat*
phải được giữ nguyên.
Spec đầy đủ ở `UI/KIDSHIELD_UI_SPEC.md` section 4.2.
Sau khi xong commit + push + tạo PR về develop.
```
