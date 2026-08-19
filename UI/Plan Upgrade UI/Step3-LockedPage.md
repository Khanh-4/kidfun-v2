# Bước 3 — LockedPage (Màn hình khóa)

> **Branch:** `feat/ui/locked-page`  
> **Trạng thái:** ✅ Xong  
> **Phụ thuộc:** Bước 1 (Design Tokens) phải xong trước

---

## Mục tiêu

Tách màn hình "hết giờ / bị khóa" từ dialog/overlay trong `child_dashboard_screen.dart`  
thành một `Widget` riêng đầy đủ theo spec 4.3.  
**Không tạo route mới** — hiển thị bằng cách replace toàn bộ body của `child_dashboard_screen.dart`  
khi `_isTimeUpDialogShowing = true` (giữ nguyên logic native lock hiện tại).

---

## Files cần tạo / sửa

| File | Action |
|------|--------|
| `mobile/lib/features/device/screens/child_locked_widget.dart` | **TẠO MỚI** — Widget, không phải Screen |
| `mobile/lib/features/device/screens/child_dashboard_screen.dart` | Dùng `ChildLockedWidget` thay thế dialog `_onTimeUp` |

---

## Spec tham chiếu: Section 4.3 của `UI/KIDSHIELD_UI_SPEC.md`

---

## Thiết kế Widget

**Background gradient:** `AppColors.lockedGradient` = `[#0F172A → #1E293B → #1E1B4B]`

### Cấu trúc `ChildLockedWidget`

```dart
class ChildLockedWidget extends StatefulWidget {
  final VoidCallback onRequestTime;   // navigate to /child-request-time
  final VoidCallback onGoHome;        // context.go('/child-dashboard') → chỉ tắt lock state
  const ChildLockedWidget({
    super.key,
    required this.onRequestTime,
    required this.onGoHome,
  });
}
```

### Scaffold wrapper

```dart
Scaffold(
  body: Container(
    decoration: AppTheme.gradientBg(AppColors.lockedGradient),
    child: Stack(children: [
      // Background blur decorations
      _BackgroundDecorations(),
      SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          child: Column(children: [
            _ClockSection(),
            _LockIconSection(),
            _CountdownCard(),
            _ActivitiesCard(),
            _ActionButtons(),
            _Footer(),
          ]),
        ),
      ),
    ]),
  ),
)
```

### Background decorations

```dart
// 2 blur circles
Positioned(
  top: -64, left: -64,
  child: Container(
    width: 256, height: 256,
    decoration: BoxDecoration(
      color: AppColors.indigo500.withOpacity(0.10),
      shape: BoxShape.circle,
    ),
  ),
),
Positioned(
  bottom: -64, right: -64,
  child: Container(
    width: 256, height: 256,
    decoration: BoxDecoration(
      color: AppColors.purple500.withOpacity(0.10),
      shape: BoxShape.circle,
    ),
  ),
),
// Dùng BackdropFilter blur-3xl trên mỗi circle:
// ImageFilter.blur(sigmaX: 48, sigmaY: 48)
```

### Clock section

```dart
Column(children: [
  SizedBox(height: 64),
  Text(
    _currentTime,  // cập nhật mỗi giây via Timer
    style: GoogleFonts.nunito(
      fontSize: 64, fontWeight: FontWeight.w800,
      color: Colors.white, letterSpacing: -2,
    ),
  ),
  Text(
    _currentDate,  // "thứ hai, 17 tháng 3"
    style: GoogleFonts.nunito(
      fontSize: 14, color: Colors.white.withOpacity(0.50),
    ),
  ),
  SizedBox(height: 32),
])
```

**Timer logic trong State:**
```dart
late Timer _clockTimer;
String _currentTime = '';
String _currentDate = '';

void _startClock() {
  _updateClock();
  _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
}

void _updateClock() {
  final now = DateTime.now();
  setState(() {
    _currentTime = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    _currentDate = _formatDate(now);
  });
}
```

### Lock Icon (3 vòng tròn pulsing + AnimationController)

```dart
// Dùng AnimationController repeat reverse để pulse
late AnimationController _pulseCtrl;
late Animation<double> _pulseAnim;

// initState:
_pulseCtrl = AnimationController(vsync: this, duration: Duration(seconds: 2))..repeat(reverse: true);
_pulseAnim = Tween(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

// Widget:
AnimatedBuilder(
  animation: _pulseAnim,
  builder: (ctx, child) => Transform.scale(
    scale: _pulseAnim.value,
    child: Container(
      width: 160, height: 160,
      decoration: BoxDecoration(
        color: AppColors.rose500.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 112, height: 112,
          decoration: BoxDecoration(
            color: AppColors.rose500.withOpacity(0.20),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.rose500.withOpacity(0.30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline_rounded, size: 40, color: Color(0xFFFCA5A5)), // rose-300
            ),
          ),
        ),
      ),
    ),
  ),
),
```

**Text dưới icon:**
```dart
Text('Đã hết giờ!',
    style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
Text('Bạn đã sử dụng hết thời gian được phép hôm nay.',
    style: GoogleFonts.nunito(fontSize: 14, color: Colors.white.withOpacity(0.60))),
Text('Nghỉ ngơi là điều quan trọng! 😊',
    style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.50))),
```

### Countdown Card

```dart
// bg-white/10 backdrop-blur border border-white/20 rounded-3xl px-8 py-5
Container(
  decoration: AppTheme.glassCardSubtle(),
  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
  child: Column(children: [
    Text('Mở khóa lần tiếp theo',
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.60))),
    SizedBox(height: 8),
    Text(
      _countdownStr,  // "HH:MM:SS" đếm ngược đến 06:00 sáng hôm sau
      style: GoogleFonts.nunito(
        fontSize: 36, fontWeight: FontWeight.w800,
        color: AppColors.indigo400, letterSpacing: 4,
      ),
    ),
    Text('06:00 sáng ngày mai',
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.40))),
    SizedBox(height: 12),
    // Progress bar 100% (luôn full vì đã hết giờ)
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: 1.0,
        backgroundColor: Colors.white.withOpacity(0.10),
        valueColor: AlwaysStoppedAnimation(AppColors.indigo500),
        minHeight: 6,
      ),
    ),
  ]),
)
```

**Countdown logic:**
```dart
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
```

### Activities Card

```dart
// bg-gradient amber-500/20 → orange-500/20, border amber-400/30
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [
      Color(0xFFF59E0B).withOpacity(0.20),
      Color(0xFFF97316).withOpacity(0.20),
    ]),
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
    border: Border.all(color: Color(0xFFFBBF24).withOpacity(0.30)),
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('💡 Bạn có thể làm gì bây giờ?',
        style: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: Color(0xFFFDE68A), // amber-200
        )),
    SizedBox(height: 8),
    ...[ '📚 Đọc sách hoặc làm bài tập',
         '🎨 Vẽ tranh hoặc tô màu',
         '🏃 Vận động, chơi ngoài trời',
         '💤 Nghỉ ngơi và ngủ đủ giấc',
    ].map((s) => Padding(
      padding: EdgeInsets.only(top: 4),
      child: Text(s,
          style: GoogleFonts.nunito(
            fontSize: 12, color: Color(0xFFFDE68A).withOpacity(0.70),
          )),
    )),
  ]),
)
```

### Action Buttons

```dart
// Nút 1: Xin thêm giờ từ Bố/Mẹ
SizedBox(
  width: double.infinity, height: AppTheme.btnHeightLg,
  child: ElevatedButton.icon(
    onPressed: widget.onRequestTime,
    icon: Icon(Icons.message_outlined),
    label: Text('Xin thêm giờ từ Bố/Mẹ',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.indigo600,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
      elevation: 8,
      shadowColor: AppColors.slate900.withOpacity(0.50),
    ),
  ),
),
SizedBox(height: 12),
// Nút 2: Về trang chủ
SizedBox(
  width: double.infinity, height: AppTheme.btnHeightSm,
  child: OutlinedButton.icon(
    onPressed: widget.onGoHome,
    icon: Icon(Icons.home_outlined, color: Colors.white.withOpacity(0.80)),
    label: Text('Về trang chủ',
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.80),
        )),
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: Colors.white.withOpacity(0.20)),
      backgroundColor: Colors.white.withOpacity(0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
    ),
  ),
),
```

### Footer

```dart
Padding(
  padding: EdgeInsets.only(bottom: 32, top: 8),
  child: Text('KidShield đang bảo vệ bạn 🛡️',
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(
        fontSize: 12, color: Colors.white.withOpacity(0.20),
      )),
)
```

---

## Tích hợp vào `child_dashboard_screen.dart`

### Hiện tại (cần sửa)

Tìm method `_onTimeUp()` và toàn bộ logic show dialog hết giờ. Thay vì `showDialog`, đặt flag `_isTimeUpShowing = true` và render `ChildLockedWidget` trong `build()`.

### Cách tích hợp trong `build()`

```dart
@override
Widget build(BuildContext context) {
  if (_isLoading) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  // Màn hình khóa — hiển thị thay vì toàn bộ dashboard
  if (_isTimeUp) {
    return ChildLockedWidget(
      onRequestTime: () => context.push('/child-request-time'),
      onGoHome: () {
        // Chỉ dismiss locked state nếu đã có thêm thời gian
        // (nút "về trang chủ" cho phép exit nếu limit đã thay đổi)
        setState(() => _isTimeUp = false);
      },
    );
  }

  // ... dashboard bình thường
}
```

**Rename flag:** `_isTimeUpDialogShowing` → `_isTimeUp` để rõ nghĩa hơn  
(update tất cả references trong file)

---

## Commit message

```
feat(mobile/ui): thêm ChildLockedWidget theo spec 4.3 — clock, pulsing lock, countdown
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI/Step3-LockedPage.md` trong project kidfun-v2.
Tạo branch `feat/ui/locked-page` từ develop.
Implement toàn bộ theo plan: tạo file mới
`mobile/lib/features/device/screens/child_locked_widget.dart`
và cập nhật `child_dashboard_screen.dart` để dùng widget này
thay cho dialog hết giờ hiện tại.
Spec đầy đủ ở `UI/KIDSHIELD_UI_SPEC.md` section 4.3.
Sau khi xong commit + push + tạo PR về develop.
```
