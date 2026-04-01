# KidShield UI Upgrade — Mobile Flutter

> Tài liệu kế hoạch nâng cấp UI toàn bộ màn hình mobile (Flutter).  
> Spec gốc: `UI/KIDSHIELD_UI_SPEC.md`  
> Nếu session Claude Code hết token → mở file bước tiếp theo, copy prompt vào session mới.

---

## Tổng quan

Nâng cấp 4 màn hình child + design tokens cho mobile Flutter app.  
Spec chỉ mô tả **Child Pages** cho mobile (Section 4). Parent screens (Section 5-14) là React web dashboard — không implement ở đây.

---

## Tiến độ

| Bước | File kế hoạch | Trạng thái | Branch |
|------|--------------|-----------|--------|
| 1 | [Step1-Design-Tokens.md](./Step1-Design-Tokens.md) | ✅ Xong | `feat/ui/design-tokens` |
| 2 | [Step2-RequestTimePage.md](./Step2-RequestTimePage.md) | ⬜ Chưa làm | `feat/ui/request-time-page` |
| 3 | [Step3-LockedPage.md](./Step3-LockedPage.md) | ⬜ Chưa làm | `feat/ui/locked-page` |
| 4 | [Step4-TimeRemainingPage.md](./Step4-TimeRemainingPage.md) | ⬜ Chưa làm | `feat/ui/time-remaining-page` |
| 5 | [Step5-LinkDevicePage.md](./Step5-LinkDevicePage.md) | ⬜ Chưa làm | `feat/ui/link-device-page` |

**Trạng thái:** ⬜ Chưa làm &nbsp;|&nbsp; 🔄 Đang làm &nbsp;|&nbsp; ✅ Xong

---

## File mapping — Hiện tại vs Sau khi upgrade

| Màn hình | File hiện tại | File sau upgrade | Ghi chú |
|----------|--------------|-----------------|---------|
| Design tokens | `app_colors.dart` + `app_theme.dart` | Sửa 2 file này | Bước 1 |
| TimeRemainingPage (child dashboard) | `child_dashboard_screen.dart` | Sửa file này | Bước 4 |
| LockedPage | Nằm trong `child_dashboard_screen.dart` | Tạo `child_locked_screen.dart` mới | Bước 3 |
| RequestTimePage | Dialog trong `child_dashboard_screen.dart` | Tạo `child_request_time_screen.dart` mới | Bước 2 |
| LinkDevicePage | `scan_qr_screen.dart` | Sửa file này | Bước 5 |
| Routes | `app.dart` | Thêm routes mới | Ở các bước 2, 3 |

---

## Quy trình cho MỖI bước

```bash
# 1. Tạo branch từ develop
git checkout develop && git pull origin develop
git checkout -b feat/ui/<tên-bước>

# 2. Implement theo file kế hoạch

# 3. Commit + push + PR về develop
git add <files>
git commit -m "feat(mobile/ui): <mô tả>"
git push origin feat/ui/<tên-bước>
```

---

## Thứ tự thực hiện

```
Bước 1 → Bước 2 → Bước 3 → Bước 4 → Bước 5
(tokens)  (request) (locked)  (dashboard) (link)
```

Bước 1 PHẢI làm trước vì các bước sau dùng màu từ `AppColors`.  
Bước 2 và 3 nên làm trước bước 4 vì dashboard sẽ navigate sang chúng.

---

## Cách tiếp tục khi session hết token

1. Mở file `.md` của bước chưa làm
2. Đọc phần **"Prompt để tiếp tục"** ở cuối file đó
3. Paste prompt vào session Claude Code mới

---

## Tech stack mobile

- Flutter + Dart
- Riverpod (state management)
- go_router (navigation)
- google_fonts (Nunito)
- `BackdropFilter` cho glass effect
- `CustomPaint` cho circular progress
- `AnimationController` cho pulse/bounce animations
