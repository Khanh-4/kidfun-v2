# KidShield UI Upgrade — Parent Screens (Flutter Mobile)

> Nâng cấp UI toàn bộ màn hình phụ huynh trong Flutter mobile app.  
> Design system: dùng lại `AppColors` + `AppTheme` từ Bước 1 (child upgrade).  
> Phong cách: light theme chuyên nghiệp — indigo primary, white cards, Nunito font.

---

## Tiến độ

| Bước | File kế hoạch | Trạng thái | Branch |
|------|--------------|-----------|--------|
| 1 | [Step1-RoleSelection.md](./Step1-RoleSelection.md) | ⬜ Chưa làm | `feat/ui/parent/role-selection` |
| 2 | [Step2-AuthScreens.md](./Step2-AuthScreens.md) | ⬜ Chưa làm | `feat/ui/parent/auth-screens` |
| 3 | [Step3-HomeScreen.md](./Step3-HomeScreen.md) | ⬜ Chưa làm | `feat/ui/parent/home-screen` |
| 4 | [Step4-ProfileScreens.md](./Step4-ProfileScreens.md) | ⬜ Chưa làm | `feat/ui/parent/profile-screens` |
| 5 | [Step5-DeviceScreens.md](./Step5-DeviceScreens.md) | ⬜ Chưa làm | `feat/ui/parent/device-screens` |
| 6 | [Step6-ManagementScreens.md](./Step6-ManagementScreens.md) | ⬜ Chưa làm | `feat/ui/parent/management-screens` |

**Trạng thái:** ⬜ Chưa làm &nbsp;|&nbsp; 🔄 Đang làm &nbsp;|&nbsp; ✅ Xong

---

## File mapping

| Màn hình | File | Bước |
|----------|------|------|
| Chọn vai trò | `auth/screens/role_selection_screen.dart` | 1 |
| Đăng nhập | `auth/screens/login_screen.dart` | 2 |
| Đăng ký | `auth/screens/register_screen.dart` | 2 |
| Quên mật khẩu | `auth/screens/forgot_password_screen.dart` | 2 |
| Trang chủ phụ huynh | `app.dart` → `HomeScreen` | 3 |
| Danh sách hồ sơ | `profile/screens/profile_list_screen.dart` | 4 |
| Tạo hồ sơ | `profile/screens/create_profile_screen.dart` | 4 |
| Sửa hồ sơ | `profile/screens/edit_profile_screen.dart` | 4 |
| Danh sách thiết bị | `device/screens/device_list_screen.dart` | 5 |
| Thêm thiết bị | `device/screens/add_device_screen.dart` | 5 |
| Giới hạn thời gian | `time_limit/screens/time_limit_screen.dart` | 6 |
| Chặn ứng dụng | `profile/screens/app_blocking_screen.dart` | 6 |
| Báo cáo sử dụng | `profile/screens/app_usage_report_screen.dart` | 6 |

---

## Design System (Parent Side)

```
Background:  AppColors.slate50  (#F8FAFC) — nền sáng nhẹ
AppBar:      gradient indigo600 → indigo700
Cards:       white + shadow + border slate200
Primary:     AppColors.indigo600
Font:        Nunito (GoogleFonts)
Radius:      AppTheme.radiusCardMd (16) cho card, AppTheme.radiusBtn (16) cho button
```

### AppBar chuẩn cho tất cả màn hình phụ huynh

```dart
AppBar(
  title: Text('Tiêu đề', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
  flexibleSpace: Container(
    decoration: AppTheme.gradientBg([AppColors.indigo600, AppColors.indigo700]),
  ),
  iconTheme: IconThemeData(color: Colors.white),
  elevation: 0,
)
```

### Card chuẩn

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
    border: Border.all(color: AppColors.slate200),
    boxShadow: [BoxShadow(color: AppColors.slate900.withOpacity(0.06), blurRadius: 8, offset: Offset(0,2))],
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
)
```

---

## Thứ tự thực hiện

```
Bước 1 → Bước 2 → Bước 3 → Bước 4 → Bước 5 → Bước 6
(role)    (auth)   (home)   (profile) (device)  (manage)
```

---

## Cách tiếp tục khi session hết token

1. Mở file `.md` của bước chưa làm
2. Đọc phần **"Prompt để tiếp tục"** ở cuối file đó
3. Paste vào session Claude Code mới
