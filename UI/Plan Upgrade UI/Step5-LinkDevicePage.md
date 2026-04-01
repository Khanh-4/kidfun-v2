# Bước 5 — LinkDevicePage (Liên kết thiết bị)

> **Branch:** `feat/ui/link-device-page`  
> **Trạng thái:** ✅ Xong  
> **Phụ thuộc:** Bước 1 (Design Tokens) phải xong trước

---

## Mục tiêu

Redesign màn hình liên kết thiết bị cho trẻ em theo spec 4.1.  
Màn hình hiện tại: `scan_qr_screen.dart` (quét QR code để link device).  
Spec thêm input 4 số và 3 states: `input` → `waiting` → `success`.

---

## Files cần sửa

| File | Action |
|------|--------|
| `mobile/lib/features/device/screens/scan_qr_screen.dart` | Redesign UI, giữ logic QR scan + link |

---

## Spec tham chiếu: Section 4.1 của `UI/KIDSHIELD_UI_SPEC.md`

---

## Background

```dart
Container(
  decoration: AppTheme.gradientBg(AppColors.linkDeviceGradient),
  // gradient: #6366F1 → #9333EA → #EC4899
)
```

---

## 3 trạng thái

```dart
enum LinkDeviceState { input, waiting, success }

LinkDeviceState _state = LinkDeviceState.input;
```

---

## Header (dùng chung)

```dart
Widget _buildHeader() {
  return Padding(
    padding: EdgeInsets.only(top: 8, bottom: 16),
    child: Row(children: [
      GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(AppTheme.radiusBtnSm),
          ),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Liên kết thiết bị',
            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('KidShield Child Monitor',
            style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.70))),
      ]),
    ]),
  );
}
```

---

## State: `input` — Nhập mã 4 chữ số

### Hero icon
```dart
Container(
  width: 96, height: 96,
  decoration: AppTheme.glassCard(radius: 24),
  child: Center(child: Text('🔗', style: TextStyle(fontSize: 48))),
),
Text('Liên kết với Phụ huynh',
    style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
Text('Nhập mã 4 chữ số do phụ huynh cung cấp',
    style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.70))),
```

### 4-digit code input card (Glass card)

```dart
// State variables
final List<TextEditingController> _codeControllers = List.generate(4, (_) => TextEditingController());
final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

// Widget
Container(
  decoration: AppTheme.glassCard(),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(children: [
    Text('Nhập mã liên kết',
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.80))),
    SizedBox(height: 16),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (i) => _buildDigitBox(i)),
    ),
    SizedBox(height: 20),
    SizedBox(
      width: double.infinity, height: AppTheme.btnHeightLg,
      child: ElevatedButton(
        onPressed: _isCodeComplete ? _submitCode : null,
        child: Text('Xác nhận liên kết',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.indigo700,
          disabledBackgroundColor: Colors.white.withOpacity(0.50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
          elevation: 6,
        ),
      ),
    ),
    SizedBox(height: 8),
    Text('Mã sẽ hết hạn sau 10 phút',
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(fontSize: 11, color: Colors.white.withOpacity(0.60))),
  ]),
)
```

### Digit box

```dart
Widget _buildDigitBox(int index) {
  return SizedBox(
    width: 56, height: 64,
    child: TextField(
      controller: _codeControllers[index],
      focusNode: _focusNodes[index],
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
      keyboardType: TextInputType.number,
      maxLength: 1,
      decoration: InputDecoration(
        counterText: '',
        hintText: '·',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 22),
        filled: true,
        fillColor: Colors.white.withOpacity(0.20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.30), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.70), width: 2),
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

bool get _isCodeComplete =>
    _codeControllers.every((c) => c.text.isNotEmpty);

String get _fullCode =>
    _codeControllers.map((c) => c.text).join();
```

### Steps card (bg-white/10)

```dart
Container(
  decoration: AppTheme.glassCardSubtle(),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Hướng dẫn liên kết:',
        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.80))),
    SizedBox(height: 12),
    ..._steps.map((s) => _buildStep(s)),
  ]),
)

final _steps = [
  {'emoji': '📱', 'title': 'Tải ứng dụng', 'desc': 'Tải KidShield từ App Store hoặc Google Play'},
  {'emoji': '🚀', 'title': 'Mở ứng dụng', 'desc': 'Mở và chọn "Liên kết thiết bị mới"'},
  {'emoji': '🔢', 'title': 'Nhập mã hoặc quét QR', 'desc': 'Nhập mã 4 chữ số từ phụ huynh'},
  {'emoji': '✅', 'title': 'Xác nhận từ phụ huynh', 'desc': 'Phụ huynh nhận thông báo xác nhận'},
];

Widget _buildStep(Map s) {
  return Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(AppTheme.radiusIconSm),
        ),
        child: Center(child: Text(s['emoji']!, style: TextStyle(fontSize: 16))),
      ),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s['title']!,
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.white)),
        Text(s['desc']!,
            style: GoogleFonts.nunito(
              fontSize: 11, color: Colors.white.withOpacity(0.60),
            )),
      ])),
    ]),
  );
}
```

### Submit logic

```dart
Future<void> _submitCode() async {
  setState(() => _state = LinkDeviceState.waiting);
  // Gọi API link device với _fullCode (dùng lại logic từ scan_qr_screen hiện tại)
  // Nếu thành công → setState(() => _state = LinkDeviceState.success);
  // Nếu lỗi → setState(() { _state = LinkDeviceState.input; _showError(); });
  await _processPairingCode(_fullCode);
}
```

Giữ nguyên method `_processPairingCode(String code)` từ `scan_qr_screen.dart` hiện tại  
(gọi `DeviceProvider.linkDevice(code)` → lưu `SharedPreferences` → `SocketService.joinDevice()`).

---

## State: `waiting`

```dart
// Pulsing icon
AnimatedBuilder(
  animation: _pulseAnim,
  builder: (ctx, _) => Container(
    width: 112, height: 112,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.20 * _pulseAnim.value),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.30),
          shape: BoxShape.circle,
        ),
        child: Center(child: Text('⏳', style: TextStyle(fontSize: 40))),
      ),
    ),
  ),
),

Text('Đang chờ xác nhận...',
    style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
Text('Phụ huynh đang xem xét yêu cầu...',
    style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.70))),

// Info card
Container(
  decoration: AppTheme.glassCard(),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(children: [
    Text('Thiết bị đang liên kết',
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.80))),
    Text('Mã: $_fullCode',
        style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
    SizedBox(height: 12),
    // 3 bouncing dots
    _BouncingDots(),
  ]),
),
```

---

## State: `success`

```dart
// Icon checkmark (2 circles màu emerald)
Container(
  width: 112, height: 112,
  decoration: BoxDecoration(
    color: Color(0xFF34D399).withOpacity(0.30), // emerald-400/30
    shape: BoxShape.circle,
  ),
  child: Center(
    child: Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Color(0xFF34D399).withOpacity(0.40),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.white),
    ),
  ),
),

Text('Liên kết thành công! 🎉',
    style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
Text('Thiết bị đã được liên kết với tài khoản của Bố/Mẹ',
    style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.70))),

// Info card (Glass card)
Container(
  decoration: AppTheme.glassCard(),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(children: [
    _InfoRow('Trẻ em',        profileName),
    _InfoRow('Thiết bị',      deviceName),
    _InfoRow('Giới hạn/ngày', dailyLimit),
  ]),
),

// Nút "Bắt đầu sử dụng →"
SizedBox(
  width: double.infinity, height: AppTheme.btnHeightLg,
  child: ElevatedButton(
    onPressed: () => context.go('/child-dashboard'),
    child: Text('Bắt đầu sử dụng →',
        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.indigo700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
      elevation: 8,
    ),
  ),
),
```

---

## Widget helper `_BouncingDots`

```dart
class _BouncingDots extends StatefulWidget {
  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots> with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(vsync: this, duration: Duration(milliseconds: 600))
        ..repeat(reverse: true);
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
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
      AnimatedBuilder(
        animation: _ctrls[i],
        builder: (ctx, _) => Transform.translate(
          offset: Offset(0, -8 * _ctrls[i].value),
          child: Container(
            width: 10, height: 10,
            margin: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.60),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ));
  }
}
```

---

## Widget helper `_InfoRow`

```dart
Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.70))),
      Text(value, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
    ]),
  );
}
```

---

## QR Scan button (giữ lại từ code cũ)

Thêm nút "Quét mã QR" ở dưới input card — navigate sang `ScanQrScreen` hoặc mở camera modal:
```dart
TextButton.icon(
  onPressed: () => context.push('/devices/scan'),
  icon: Icon(Icons.qr_code_scanner, color: Colors.white.withOpacity(0.70), size: 16),
  label: Text('Hoặc quét mã QR',
      style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.70))),
),
```

---

## Commit message

```
feat(mobile/ui): redesign ScanQrScreen → LinkDevicePage theo KidShield spec 4.1
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI/Step5-LinkDevicePage.md` trong project kidfun-v2.
Tạo branch `feat/ui/link-device-page` từ develop.
Redesign `mobile/lib/features/device/screens/scan_qr_screen.dart`
theo plan — thêm 3 states (input/waiting/success), 4-digit input boxes,
giữ nguyên logic `_processPairingCode()` và QR scanner.
Spec đầy đủ ở `UI/KIDSHIELD_UI_SPEC.md` section 4.1.
Sau khi xong commit + push + tạo PR về develop.
```
