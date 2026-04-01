# Bước 2 — RequestTimePage (Xin thêm giờ)

> **Branch:** `feat/ui/request-time-page`  
> **Trạng thái:** ✅ Xong  
> **Phụ thuộc:** Bước 1 (Design Tokens) phải xong trước

---

## Mục tiêu

Tách tính năng "xin thêm giờ" từ dialog đơn giản trong `child_dashboard_screen.dart`  
thành một màn hình riêng đầy đủ theo spec 4.4.

---

## Files cần tạo / sửa

| File | Action |
|------|--------|
| `mobile/lib/features/device/screens/child_request_time_screen.dart` | **TẠO MỚI** |
| `mobile/lib/app.dart` | Thêm route `/child-request-time` |
| `mobile/lib/features/device/screens/child_dashboard_screen.dart` | Sửa nút "Xin thêm giờ" → navigate thay vì showDialog |

---

## Spec tham chiếu: Section 4.4 của `UI/KIDSHIELD_UI_SPEC.md`

---

## Thiết kế màn hình

**Background gradient:** `AppColors.requestTimeGradient` = `[#FB923C → #EC4899 → #F43F5E]`  
**3 trạng thái:** `RequestTimeState.form` | `RequestTimeState.sending` | `RequestTimeState.sent`

### Layout tổng quát
```
Scaffold(
  body: Container(
    decoration: AppTheme.gradientBg(AppColors.requestTimeGradient),
    child: SafeArea(
      child: SingleChildScrollView(  // trạng thái form
        padding: EdgeInsets.all(AppTheme.screenPadding),
        child: ...
      ),
    ),
  ),
)
```

---

## Trạng thái: `form`

### Header
```dart
Row(children: [
  // ← Back button
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
    Text('Xin thêm giờ',
        style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
    Text('Gửi yêu cầu đến Bố/Mẹ',
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.70))),
  ]),
])
```

### Illustration hero
```dart
Column(children: [
  Container(
    width: 96, height: 96,
    decoration: AppTheme.glassCard(radius: 24),
    child: Center(child: Text('🙏', style: TextStyle(fontSize: 48))),
  ),
  SizedBox(height: 16),
  Text('Nhờ Bố/Mẹ giúp!',
      style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
  Text('Hãy chọn lý do và thời gian phù hợp',
      style: GoogleFonts.nunito(fontSize: 14, color: Colors.white.withOpacity(0.70))),
])
```

### Reason Card (Glass card)
```dart
Container(
  decoration: AppTheme.glassCard(),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(children: [
    Text('📋 Lý do xin thêm giờ?',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: Colors.white)),
    SizedBox(height: 12),
    GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.5,
      children: _reasons.map((r) => _ReasonChip(reason: r, ...)).toList(),
    ),
  ]),
)
```

**Danh sách reasons** (6 items):
```dart
final _reasons = [
  {'emoji': '📚', 'label': 'Đang học bài'},
  {'emoji': '🎬', 'label': 'Xem phim chưa xong'},
  {'emoji': '👫', 'label': 'Chơi với bạn bè'},
  {'emoji': '🎉', 'label': 'Cuối tuần / ngày nghỉ'},
  {'emoji': '🎓', 'label': 'Xem video học tập'},
  {'emoji': '✍️', 'label': 'Lý do khác'},
];
```

**ReasonChip widget:**
- Unselected: `bg-white/10 border border-white/20 text-white`
- Selected: `bg-white text-orange-600 border-white shadow-lg`
- Dùng `AnimatedContainer` cho transition

### Time Card (Glass card)
```dart
// 4 nút chọn thời gian, grid 2 cột
final _timeOptions = [
  {'emoji': '⏱', 'label': '15 phút', 'value': 15},
  {'emoji': '⏰', 'label': '30 phút', 'value': 30},
  {'emoji': '🕐', 'label': '1 giờ',   'value': 60},
  {'emoji': '🕑', 'label': '2 giờ',   'value': 120},
];
```

**TimeChip widget:**
- Unselected: `color: Colors.white.withOpacity(0.10), border: Colors.white.withOpacity(0.20)`
- Selected: `color: Colors.white, transform: Matrix4.diagonal3Values(1.05, 1.05, 1)` (scale-105)

### Note Card (Glass card)
```dart
TextField(
  maxLines: 3,
  style: TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: 'Ví dụ: Con đang xem video toán học...',
    hintStyle: TextStyle(color: Colors.white.withOpacity(0.40)),
    filled: true,
    fillColor: Colors.white.withOpacity(0.20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.30)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.30)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.60)),
    ),
  ),
)
```

### Submit Button
```dart
SizedBox(
  width: double.infinity, height: AppTheme.btnHeightLg,
  child: ElevatedButton.icon(
    onPressed: (_selectedReason != null && _selectedMinutes != null) ? _submit : null,
    icon: Icon(Icons.send_rounded),
    label: Text('Gửi yêu cầu cho Bố/Mẹ',
        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFFEA580C), // orange-600
      disabledBackgroundColor: Colors.white.withOpacity(0.50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
      elevation: 8,
    ),
  ),
)
```

### Previous Requests Card (bg-white/10)
- Hiển thị 3 request gần nhất từ API (optional, load từ `ChildRepository`)
- Nếu load lỗi thì ẩn card này
- Badge: Approved = `emerald-400/20 + text-emerald-300`, Rejected = `rose-400/20 + text-rose-300`

---

## Trạng thái: `sending`

```dart
Center(
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    // Spinner vòng tròn
    SizedBox(
      width: 128, height: 128,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          color: Colors.white.withOpacity(0.60),
          strokeWidth: 3,
        ),
        Container(
          width: 108, height: 108,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.send_rounded, size: 48, color: Colors.white),
        ),
      ]),
    ),
    SizedBox(height: 24),
    Text('Đang gửi yêu cầu...',
        style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
    Text('Bố/Mẹ sẽ nhận được thông báo ngay',
        style: GoogleFonts.nunito(fontSize: 14, color: Colors.white.withOpacity(0.70))),
    SizedBox(height: 16),
    // 3 bouncing dots (dùng AnimationController với delays)
    _BouncingDots(),
  ]),
)
```

---

## Trạng thái: `sent`

```dart
Column(children: [
  // Checkmark icon (2 circles)
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
        child: Icon(Icons.check_circle_outline, size: 56, color: Colors.white),
      ),
    ),
  ),
  Text('Đã gửi! 🎉', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
  Text('Yêu cầu xin thêm $_selectedMinutes phút đã được gửi đến Bố/Mẹ...'),

  // Summary card (Glass card)
  Container(
    decoration: AppTheme.glassCard(),
    padding: EdgeInsets.all(AppTheme.cardPadding),
    child: Column(children: [
      Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text('🙏', style: TextStyle(fontSize: 20))),
        ),
        SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Yêu cầu của bạn', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: Colors.white)),
          Text('Đang chờ phê duyệt', style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.60))),
        ]),
        Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.20),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text('Đang chờ',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.amber.shade200)),
        ),
      ]),
      Divider(color: Colors.white.withOpacity(0.10), height: 24),
      _InfoRow('Thời gian xin', '$_selectedMinutes phút'),
      _InfoRow('Lý do', _selectedReasonLabel),
    ]),
  ),

  // Back button
  SizedBox(
    width: double.infinity, height: AppTheme.btnHeightLg,
    child: ElevatedButton(
      onPressed: () => context.go('/child-dashboard'),
      child: Text('Về màn hình chính', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFEA580C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
      ),
    ),
  ),
])
```

---

## Logic gửi request

Dùng socket (không dùng REST) để gửi — giữ logic cũ từ `_sendTimeExtensionRequest`:

```dart
void _submit() {
  if (_selectedReason == null || _selectedMinutes == null) return;
  setState(() => _state = RequestTimeState.sending);

  SocketService.instance.socket.emit('requestTimeExtension', {
    'deviceCode': _deviceCode,
    'requestMinutes': _selectedMinutes,
    'reason': _selectedReasonLabel,
  });

  // Chuyển sang trạng thái sent sau 1.5s (simulate)
  Future.delayed(const Duration(milliseconds: 1500), () {
    if (mounted) setState(() => _state = RequestTimeState.sent);
  });
}
```

---

## Route mới trong `app.dart`

```dart
GoRoute(
  path: '/child-request-time',
  builder: (context, state) => const ChildRequestTimeScreen(),
),
```

---

## Sửa `child_dashboard_screen.dart`

Tìm nút "Xin thêm giờ" (hiện mở `_showRequestDialog()`), thay bằng:
```dart
onPressed: () => context.push('/child-request-time'),
```
Xoá method `_showRequestDialog()` và `_sendTimeExtensionRequest()` khỏi dashboard.  
**Giữ nguyên** `socket.on('timeExtensionResponse', ...)` listener — vẫn cần cập nhật countdown.

---

## Import cần thêm vào file mới

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
```

---

## Commit message

```
feat(mobile/ui): thêm màn hình RequestTimePage (4.4) — 3 states form/sending/sent
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI/Step2-RequestTimePage.md` trong project kidfun-v2.
Tạo branch `feat/ui/request-time-page` từ develop.
Implement toàn bộ theo plan: tạo file mới
`mobile/lib/features/device/screens/child_request_time_screen.dart`,
thêm route `/child-request-time` vào `mobile/lib/app.dart`,
và sửa nút "Xin thêm giờ" trong `child_dashboard_screen.dart` để navigate
thay vì mở dialog.
Spec đầy đủ ở `UI/KIDSHIELD_UI_SPEC.md` section 4.4.
Sau khi xong commit + push + tạo PR về develop.
```
