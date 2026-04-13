# KidFun V3 — Sprint 8 Flow Test

> **Sprint:** Web Filtering, School Mode & Per-app Limits
> **Cơ chế:** AccessibilityService mở rộng (đọc URL browser), UsageStats per-app, School Mode enforcement
> **Ngày tạo:** 2026-04

---

## Chuẩn bị trước khi test

- [ ] Build và cài APK mới lên **thiết bị thật** (emulator không hỗ trợ đầy đủ)
- [ ] Đã hoàn thành permissions từ Sprint 5: UsageStats, Accessibility, Device Admin
- [ ] Backend đã seed web categories (5 categories)
- [ ] Parent app đã có profile con + thiết bị đã link
- [ ] Thiết bị Child có cài sẵn: Chrome/Firefox, YouTube, TikTok, Instagram, Zoom
- [ ] Test trong nhiều giờ khác nhau để verify School Mode theo lịch

---

## Flow 1: Per-app Time Limit — CRUD từ Parent

**Mục tiêu:** Parent thêm/sửa/xóa giới hạn thời gian cho từng app

### 1a: Thêm giới hạn YouTube

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 1a.1 | Parent: Profile → "Giới hạn từng ứng dụng" | Màn hình mở, list trống (lần đầu) |
| 1a.2 | Bấm "Thêm giới hạn" → chọn YouTube từ list app usage | Dialog chọn limit hiện ra |
| 1a.3 | Nhập 30 phút → Lưu | Toast "Đã lưu", YouTube xuất hiện trong list |
| 1a.4 | Backend: `POST /api/profiles/13/app-time-limits` 201 | Data lưu vào DB |
| 1a.5 | Child device: Logcat trong vòng 3 giây | `[POLICY] Synced — apps=1` |

### 1b: Sửa limit

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 1b.1 | Parent: tap YouTube → slider chỉnh từ 30 → 60 phút | UI update |
| 1b.2 | Backend: `POST /api/profiles/13/app-time-limits` (upsert) | Giá trị mới |
| 1b.3 | Child sync | Logcat: `[POLICY] Synced` |

### 1c: Xóa limit

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 1c.1 | Parent: swipe-to-delete hoặc nút xóa | Confirm dialog |
| 1c.2 | Confirm → YouTube biến mất khỏi list | Backend DELETE 200 |
| 1c.3 | Child sync | `limits.size = 0` |

---

## Flow 2: Per-app Time Limit — Enforcement

**Mục tiêu:** Child dùng quá limit → cảnh báo → bị chặn

### Chuẩn bị

- Parent đặt YouTube limit = 6 phút (để test nhanh)
- Child đã sync policy

### 2a: Warning 5 phút

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2a.1 | Child: mở YouTube → dùng đến phút thứ 1 (còn 5 phút) | `AppLimitChecker.checkStatus` return "WARNING" |
| 2a.2 | Notification xuất hiện trên status bar | "⚠️ YouTube còn 5 phút" |
| 2a.3 | Child tiếp tục dùng thêm 2 phút | Không hiện warning lần 2 (chỉ 1 lần) |
| 2a.4 | Logcat | `warnedApps.contains("com.google.android.youtube") = true` |

### 2b: BLOCKED khi hết giờ

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2b.1 | Child dùng tiếp đến đủ 6 phút | `checkStatus` return "BLOCKED" |
| 2b.2 | Khi chuyển sang YouTube mới | Notification "⏰ YouTube đã hết giờ hôm nay" |
| 2b.3 | App bị đẩy về Home Screen ngay | Thao tác bị chặn |
| 2b.4 | Thử mở lại YouTube | Bị chặn lần nữa |

### 2c: App khác vẫn hoạt động bình thường

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2c.1 | Child mở TikTok (chưa có limit) | Mở được bình thường |
| 2c.2 | Child mở Chrome, Zalo,... | Tất cả vẫn bình thường |

### 2d: Reset lúc nửa đêm

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2d.1 | Đổi ngày trên server (hoặc đợi nửa đêm) | `usedSeconds` = 0 |
| 2d.2 | Child sync policy | `remainingSeconds` = fulllimit |
| 2d.3 | Mở YouTube | Vào bình thường |

---

## Flow 3: Web Filtering — Categories

**Mục tiêu:** Parent bật category → Child bị chặn URL trong browser

### 3a: Lấy danh sách categories

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3a.1 | Parent: Profile → "Chặn trang web" → tab "Danh mục" | 5 categories hiện ra |
| 3a.2 | Mỗi category có: icon, tên, số domain, toggle | Hiển thị đúng |
| 3a.3 | Backend: `GET /api/web-categories` 200 | Trả 5 categories + domains |

### 3b: Bật category "Người lớn"

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3b.1 | Parent: toggle "Người lớn" ON | Toggle xanh |
| 3b.2 | Backend: `POST /api/profiles/13/blocked-categories` 201 | Lưu DB |
| 3b.3 | Child device: Logcat | `blockedDomains` tăng thêm 8 domains |
| 3b.4 | Child: mở Chrome → gõ `pornhub.com` → Enter | Trang **KHÔNG load**, app đẩy về Home |
| 3b.5 | Notification xuất hiện | "🚫 Trang web bị chặn — pornhub.com" |
| 3b.6 | Logcat trong AccessibilityService | `🚫 Blocked URL: pornhub.com` |

### 3c: Test subdomain matching

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3c.1 | Child gõ `m.pornhub.com` hoặc `vn.pornhub.com` | Cũng bị chặn (subdomain match) |
| 3c.2 | Child gõ `pornhubNOT.com` (unrelated) | Không bị chặn |

### 3d: Expandable domain list

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3d.1 | Parent: tap vào category "Người lớn" để expand | Hiện 8 domains |
| 3d.2 | Hiển thị mỗi domain có toggle "Cho phép" riêng | UI chính xác |

### 3e: Override whitelist 1 domain

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3e.1 | Parent: trong Social Media category, "Cho phép" `facebook.com` | Toggle domain đổi trạng thái |
| 3e.2 | Backend: `POST /api/profiles/13/blocked-categories/:id/override` 201 | Lưu override |
| 3e.3 | Child sync | Logcat: `blockedDomains` không chứa facebook.com |
| 3e.4 | Child gõ `facebook.com` → Enter | Vào được |
| 3e.5 | Child gõ `instagram.com` (vẫn trong category) | Bị chặn |

### 3f: Tắt category

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3f.1 | Parent: toggle "Người lớn" OFF | Toggle xám |
| 3f.2 | Child sync | `blockedDomains` giảm 8 domains |
| 3f.3 | Child gõ domain trước đây bị chặn | Vào được |

---

## Flow 4: Web Filtering — Custom Domains

### 4a: Thêm custom domain

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4a.1 | Parent: Web Filtering → tab "Tùy chỉnh" | Tab hiện, list trống (lần đầu) |
| 4a.2 | Nhập `badsite.example.com` → Lưu | Domain xuất hiện trong list |
| 4a.3 | Backend: `POST /api/profiles/13/custom-blocked-domains` 201 | DB lưu |
| 4a.4 | Child sync | Domain thêm vào `blockedDomains` |
| 4a.5 | Child: Chrome gõ `badsite.example.com` | Bị chặn |

### 4b: Xóa custom domain

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4b.1 | Parent: swipe-to-delete domain | Confirm dialog |
| 4b.2 | Confirm → domain biến mất | Backend DELETE 200 |
| 4b.3 | Child sync + mở domain | Vào được |

---

## Flow 5: Web Filtering — Multi-Browser

**Mục tiêu:** Chặn URL trên nhiều browser khác nhau

| # | Browser | Bước test | Kết quả |
|---|---------|-----------|---------|
| 5.1 | Chrome | Gõ `pornhub.com` | Bị chặn ⬜ |
| 5.2 | Firefox | Gõ `pornhub.com` | Bị chặn ⬜ |
| 5.3 | Samsung Internet | Gõ `pornhub.com` | Bị chặn ⬜ |
| 5.4 | Edge | Gõ `pornhub.com` | Bị chặn ⬜ |
| 5.5 | Brave | Gõ `pornhub.com` | Bị chặn ⬜ |
| 5.6 | Opera | Gõ `pornhub.com` | Bị chặn ⬜ |

**Lưu ý:** Nếu có browser bị miss, kiểm tra `BROWSER_PACKAGES` trong `AppBlockerService.kt`.

---

## Flow 6: School Mode — Setup

### 6a: Cài đặt template

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6a.1 | Parent: Profile → "Chế độ học tập" | Màn hình mở |
| 6a.2 | Toggle "Bật" ON | Expand settings |
| 6a.3 | Template: 07:00 - 11:30 (T2-T6) | UI time picker chính xác |
| 6a.4 | Thêm day override: CN và T7 tắt | Override hiển thị |
| 6a.5 | Allowed apps: thêm Zoom, Google Classroom, Gmail | List 3 apps |
| 6a.6 | Lưu → Backend `PUT /api/profiles/13/school-schedule` 200 | DB đầy đủ schedule + overrides + allowedApps |

### 6b: Child sync

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6b.1 | Child device logcat | `📚 Active=<depends_on_time>` |
| 6b.2 | API `GET /api/child/school-mode?deviceCode=XXX` | Trả isActive đúng theo giờ hiện tại |

---

## Flow 7: School Mode — Enforcement Theo Lịch

> **Lưu ý:** Cần test trong 2 khung giờ khác nhau (trong giờ học và ngoài giờ học)

### 7a: Trong giờ học (ví dụ 8:00 T3)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7a.1 | Child: mở Zoom | ✅ Mở được (trong whitelist) |
| 7a.2 | Child: mở Gmail | ✅ Mở được |
| 7a.3 | Child: mở YouTube | ❌ Bị chặn + notification "📚 Đang trong giờ học" |
| 7a.4 | Child: mở TikTok | ❌ Bị chặn |
| 7a.5 | Child: mở KidFun | ✅ Mở được (always allowed) |

### 7b: Ngoài giờ học (ví dụ 13:00 T3)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7b.1 | Child: mở YouTube | ✅ Mở bình thường |
| 7b.2 | Child: mở TikTok | ✅ Mở bình thường |
| 7b.3 | Logcat Child | `SchoolModeChecker.isActive = false` |

### 7c: Ngày trong override (ví dụ CN)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7c.1 | Test lúc 9:00 Chủ Nhật | School Mode KHÔNG active (CN bị tắt override) |
| 7c.2 | Mở mọi app | Đều bình thường |

---

## Flow 8: School Mode — Manual Override

### 8a: Tắt tạm 1 giờ

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 8a.1 | Trong giờ học (School Mode active) | YouTube đang bị chặn |
| 8a.2 | Parent: Settings → "Tắt tạm 1 giờ" | Confirm dialog |
| 8a.3 | Confirm | Backend `POST /school-schedule/override` 200 |
| 8a.4 | Child sync | `SchoolModeChecker.isActive = false` |
| 8a.5 | Child mở YouTube | ✅ Mở được |
| 8a.6 | Đợi 1 giờ (hoặc mock thời gian) | Override hết hạn |
| 8a.7 | Child sync | `isActive` trở lại theo lịch |

### 8b: Bật tạm 1 giờ (ngoài giờ học)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 8b.1 | Ngoài giờ học (12:00 T3) | School Mode inactive |
| 8b.2 | Parent bấm "Bật tạm 1 giờ" | Override FORCE_ON |
| 8b.3 | Child mở YouTube | ❌ Bị chặn (School Mode ép active) |
| 8b.4 | Child mở Zoom | ✅ Mở được |

### 8c: Clear override

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 8c.1 | Parent: nút "Bỏ tạm" / CLEAR | Override xóa |
| 8c.2 | Child sync | Trở lại theo lịch |

---

## Flow 9: Real-time Sync (Socket.IO)

**Mục tiêu:** Khi Parent thay đổi, Child cập nhật ngay (< 3 giây)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9.1 | Child đang sử dụng, Parent thêm blocked domain | Socket emit `blockedDomainsUpdated` |
| 9.2 | Child logcat trong 3 giây | `[POLICY] Synced` |
| 9.3 | Child mở domain mới bị chặn | Bị chặn NGAY (không cần restart app) |
| 9.4 | Parent đổi per-app limit YouTube từ 30→60 phút | Socket emit `appTimeLimitUpdated` |
| 9.5 | Child logcat | Re-sync + cập nhật limits |
| 9.6 | Parent bật School Mode | Socket emit `schoolScheduleUpdated` |
| 9.7 | Child sync → School Mode active ngay | ✅ |

---

## Flow 10: Combined Policy — Tất cả cùng hoạt động

**Mục tiêu:** Per-app + Web + School Mode hoạt động cùng lúc, không xung đột

### Kịch bản phức hợp:

- Parent cài đủ cả 3:
  - Per-app: YouTube 30 phút
  - Web: chặn "Người lớn" category + custom "badsite.com"
  - School Mode: T2-T6 07:00-11:30, allowed apps: Zoom, Classroom

### 10a: Trong giờ học

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 10a.1 | Mở YouTube | ❌ Chặn (School Mode ưu tiên) |
| 10a.2 | Mở Zoom | ✅ Được phép |
| 10a.3 | Chrome gõ `pornhub.com` trong Zoom/Chrome | ❌ Chặn (School + Web đều chặn) |

### 10b: Ngoài giờ học

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 10b.1 | Mở YouTube (chưa đủ limit) | ✅ Mở được |
| 10b.2 | Mở YouTube sau khi đủ 30 phút | ❌ Chặn (per-app limit) |
| 10b.3 | Mở Chrome → pornhub.com | ❌ Chặn (web filter) |
| 10b.4 | Mở Chrome → google.com | ✅ Mở được |
| 10b.5 | Mở TikTok (không có limit, không trong blocklist) | ✅ Mở được |

---

## Flow 11: Edge Cases

### 11a: App + Web đồng thời

| # | Case | Expected |
|---|------|----------|
| 11a.1 | Chrome đang bật, đang ở tab `pornhub.com`, Parent bật category | Socket → Child sync → kick về Home ngay khi next event |

### 11b: Sync khi offline

| # | Case | Expected |
|---|------|----------|
| 11b.1 | Child mất mạng | Policy cũ vẫn enforce (cached in Kotlin memory) |
| 11b.2 | Mạng trở lại | Sync lại policy mới nhất |

### 11c: Khôi phục sau restart

| # | Case | Expected |
|---|------|----------|
| 11c.1 | Kill app + reboot thiết bị | ForegroundService start → PolicyService auto-sync |
| 11c.2 | Policy enforce đầy đủ sau reboot | ✅ Các rule vẫn active |

### 11d: Override edge

| # | Case | Expected |
|---|------|----------|
| 11d.1 | Domain có trong category override + trong custom blocked | Custom blocked wins (vẫn bị chặn) |
| 11d.2 | App có per-app limit + trong School Mode allowed | School Mode ưu tiên: trong giờ học OK, ngoài giờ thì tính per-app |

### 11e: Subdomain matching đúng

| # | Input chặn | Input test | Expected |
|---|-----------|------------|----------|
| 11e.1 | `facebook.com` | `m.facebook.com` | ❌ Chặn |
| 11e.2 | `facebook.com` | `facebook.com.vn` | ❌ Chặn (cẩn thận edge này) |
| 11e.3 | `facebook.com` | `myfacebook.com` | ✅ KHÔNG chặn |

---

## Flow 12: Performance & UX

| # | Case | Expected |
|---|------|----------|
| 12.1 | Battery drain sau 24h dùng Child | Không tăng đáng kể so với Sprint 5 |
| 12.2 | App lag khi AccessibilityService active | Không cảm nhận được lag |
| 12.3 | Notification không spam | Chỉ warn 1 lần/app/ngày, block notification có throttle |
| 12.4 | Parent UI responsive | Mọi thao tác < 1 giây |

---

## Lỗi thường gặp & Cách xử lý

| Lỗi | Nguyên nhân | Fix |
|-----|-------------|-----|
| URL không bị đọc từ Chrome | Resource ID đổi version mới | Update `urlBarIds` trong AppBlockerService |
| Chặn không có notification | Channel chưa được tạo | Call `ensureChannel()` trước khi `notify()` |
| Per-app limit warning nhiều lần | `warnedApps` không reset nửa đêm | Thêm logic reset daily |
| School Mode không active theo lịch | Timezone sai | Dùng `Asia/Ho_Chi_Minh` |
| Sync chậm | PolicyService interval 2 phút | Lắng nghe Socket.IO để sync ngay |
| Override hết hạn không tự clear | Backend chưa check `overrideUntil` | Thêm check `< new Date()` → null |
| Custom domain trùng category | Dedup ở backend | Dùng `Set` khi tính `blockedDomains` |

---

## Bảng tổng hợp kết quả test

| # | Flow | Kết quả | Ghi chú |
|---|------|---------|---------|
| 1 | Per-app Limit CRUD | ⬜ Pass / ⬜ Fail | |
| 2 | Per-app Enforcement (warning + block) | ⬜ Pass / ⬜ Fail | |
| 3 | Web Categories (toggle + override) | ⬜ Pass / ⬜ Fail | |
| 4 | Web Custom Domains | ⬜ Pass / ⬜ Fail | |
| 5 | Multi-Browser | ⬜ Pass / ⬜ Fail | |
| 6 | School Mode Setup | ⬜ Pass / ⬜ Fail | |
| 7 | School Mode Enforcement | ⬜ Pass / ⬜ Fail | |
| 8 | Manual Override | ⬜ Pass / ⬜ Fail | |
| 9 | Real-time Sync Socket.IO | ⬜ Pass / ⬜ Fail | |
| 10 | Combined Policy | ⬜ Pass / ⬜ Fail | |
| 11 | Edge Cases | ⬜ Pass / ⬜ Fail | |
| 12 | Performance & UX | ⬜ Pass / ⬜ Fail | |

---

## Checklist cuối Sprint 8

| # | Hạng mục | ✅ |
|---|----------|----|
| 1 | AccessibilityService đọc URL từ 6 browsers | ⬜ |
| 2 | Domain matching (exact + subdomain) chính xác | ⬜ |
| 3 | Per-app warning 5 phút (1 lần/ngày) | ⬜ |
| 4 | Per-app block + notification | ⬜ |
| 5 | Web Filter categories hoạt động | ⬜ |
| 6 | Web Filter override whitelist | ⬜ |
| 7 | Custom blocked domains | ⬜ |
| 8 | School Mode theo lịch (template + overrides) | ⬜ |
| 9 | School Mode whitelist apps | ⬜ |
| 10 | Manual override với thời hạn | ⬜ |
| 11 | Policy sync real-time (< 3s) | ⬜ |
| 12 | Combined policy không xung đột | ⬜ |
| 13 | Survive reboot / offline / kill app | ⬜ |

---

## Khi gặp lỗi — cách báo cho Khanh

Format báo bug:

```
Bug: [Flow X, Bước Y]
Triệu chứng: ...
Expected: ...
Actual: ...
Flutter log: ...
Kotlin log (logcat): ...
Railway log: ...
```
