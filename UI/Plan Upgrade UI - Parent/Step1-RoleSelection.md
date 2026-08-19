# Bước 1 — Role Selection Screen

> **Branch:** `feat/ui/parent/role-selection`  
> **Trạng thái:** ⬜ Chưa làm  
> **File:** `mobile/lib/features/auth/screens/role_selection_screen.dart`

---

## Mục tiêu

Redesign màn hình chọn vai trò (Phụ huynh / Trẻ em) — màn hình đầu tiên người dùng thấy.  
Dùng gradient `linkDeviceGradient` làm nền, 2 role card nổi bật, branding KidShield.

---

## Thiết kế mới

### Background
```dart
Container(
  decoration: AppTheme.gradientBg(AppColors.linkDeviceGradient),
  // #6366F1 → #9333EA → #EC4899
)
```

### Branding section (top)
```dart
Column(children: [
  SizedBox(height: 64),
  Container(
    width: 80, height: 80,
    decoration: AppTheme.glassCard(radius: 20),
    child: Center(child: Icon(Icons.shield_outlined, size: 44, color: Colors.white)),
  ),
  SizedBox(height: 16),
  Text('KidShield',
      style: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
  Text('Bảo vệ con yêu của bạn',
      style: GoogleFonts.nunito(fontSize: 14, color: Colors.white.withOpacity(0.70))),
  SizedBox(height: 48),
])
```

### Role cards (2 cards dọc)

```dart
// Card Phụ huynh — white solid
GestureDetector(
  onTap: () => ref.read(roleProvider.notifier).setRole('parent'),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: Offset(0,8))],
    ),
    padding: EdgeInsets.all(AppTheme.cardPadding),
    child: Row(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: AppColors.indigo600.withOpacity(0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        ),
        child: Icon(Icons.supervisor_account_outlined, size: 32, color: AppColors.indigo600),
      ),
      SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tôi là Phụ huynh',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800)),
        Text('Quản lý thời gian và nội dung của con',
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
      ])),
      Icon(Icons.chevron_right, color: AppColors.slate400),
    ]),
  ),
),

SizedBox(height: 16),

// Card Thiết bị con — glass
GestureDetector(
  onTap: () => ref.read(roleProvider.notifier).setRole('child'),
  child: Container(
    decoration: AppTheme.glassCard(),
    padding: EdgeInsets.all(AppTheme.cardPadding),
    child: Row(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        ),
        child: Icon(Icons.phone_android_outlined, size: 32, color: Colors.white),
      ),
      SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Thiết bị của con',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('Kết nối thiết bị này với tài khoản phụ huynh',
            style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.70))),
      ])),
      Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.60)),
    ]),
  ),
),
```

### Footer
```dart
Padding(
  padding: EdgeInsets.only(top: 32, bottom: 24),
  child: Text('KidShield — Bảo vệ thế hệ tương lai 🛡️',
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.40))),
)
```

---

## Commit message

```
feat(mobile/ui): redesign RoleSelectionScreen — gradient bg, 2 role cards
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI - Parent/Step1-RoleSelection.md`.
Tạo branch `feat/ui/parent/role-selection` từ develop.
Redesign `mobile/lib/features/auth/screens/role_selection_screen.dart` theo plan.
Giữ nguyên logic setRole(). Chỉ thay đổi UI.
Commit + push + PR về develop.
```
