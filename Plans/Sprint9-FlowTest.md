# KidFun V3 — Sprint 9 Flow Test

> **Sprint:** YouTube Monitoring, AI Safety & Reports
> **Scope:** YouTube tracking qua AccessibilityService + Gemini AI analysis + Daily/Weekly Reports + Activity History
> **Phụ thuộc:** AccessibilityService từ Sprint 5+8, UsageStats, Socket.IO, FCM
> **AI Provider:** Google Gemini 2.5 Flash (free tier)

---

## Chuẩn bị trước khi test

- [ ] Build và cài APK mới lên **thiết bị thật** (emulator không đọc được YouTube UI đầy đủ)
- [ ] Backend đã deploy Railway, `GEMINI_API_KEY` đã set (hoặc chưa — test được cả 2 trường hợp)
- [ ] Parent app đã đăng nhập, có profile con + thiết bị đã link
- [ ] Child device đã cấp: UsageStats, Accessibility, Device Admin, Notification
- [ ] YouTube app đã cài trên Child device (version gần đây)
- [ ] Có sẵn data từ Sprint 4-8 để Reports có nội dung hiển thị

---

## Flow 1: YouTube Tracker — Đọc Video Info

**Mục tiêu:** AccessibilityService đọc được title + channel từ YouTube UI

### 1a: Video đầu tiên

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 1a.1 | Child mở YouTube app | AccessibilityService active |
| 1a.2 | Chọn 1 video bất kỳ (ví dụ Cocomelon) | Video bắt đầu play |
| 1a.3 | Logcat filter `YouTubeTracker` | `▶️ Started: <title> | <channel>` |
| 1a.4 | Title đọc được không null, length > 3 | ✅ |
| 1a.5 | Channel đọc được (có thể null nếu version YouTube ẩn) | ⚠️ Chấp nhận null |

### 1b: Title quá ngắn hoặc generic

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 1b.1 | Quay về home YouTube | Tracker **KHÔNG** log "YouTube" hoặc "Trang chủ" |
| 1b.2 | Logcat | Skip, không có log mới |

### 1c: Version YouTube khác

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 1c.1 | Test trên Android 10 với YouTube version cũ | Resource IDs có thể khác |
| 1c.2 | Nếu không đọc được | Update `TITLE_VIEW_IDS` + `CHANNEL_VIEW_IDS` trong `YouTubeTracker.kt` |

### Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Fix |
|-------------|-------------|-----|
| Title null/rỗng | Resource ID thay đổi | Chạy `adb shell uiautomator dump` để tìm đúng ID mới |
| Title = "YouTube" (tên app) | Đọc nhầm node app name | Thêm filter length + blacklist |
| Tracker không fire | `rootInActiveWindow` null | Check `canRetrieveWindowContent="true"` trong accessibility_service_config.xml |

---

## Flow 2: YouTube Tracker — Watch Duration

### 2a: Video > 10 giây

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2a.1 | Bắt đầu xem video Cocomelon | `currentVideo.startedAt` = now |
| 2a.2 | Xem 15 giây → quay về home | `stopCurrentVideo()` gọi |
| 2a.3 | Logcat | `📺 Video done: Cocomelon (15s)` |
| 2a.4 | `YouTubeTracker.pendingLogs.size` | 1 |

### 2b: Video < 10 giây (skip)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2b.1 | Mở video, chỉ xem 3 giây → tắt | **KHÔNG** log (skip) |
| 2b.2 | pendingLogs.size | Không tăng |

### 2c: Chuyển video liên tục

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2c.1 | Xem video A (30s) → next video B | Log video A (30s) |
| 2c.2 | Xem video B (20s) → quay về home | Log video B (20s) |
| 2c.3 | pendingLogs | 2 records |

### 2d: Rời YouTube

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2d.1 | Đang xem video → chuyển sang app khác (Zalo, Chrome) | `handleYouTubeEvent` không fire, tracker detect package khác → stop |
| 2d.2 | Logcat | Video done với duration đã tính |

### 2e: Screen off

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2e.1 | Đang xem video → khóa màn hình | `ACTION_SCREEN_OFF` broadcast → `stopCurrentVideo()` |
| 2e.2 | Log saved với duration chính xác | ✅ |

### 2f: Force close YouTube

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2f.1 | Đang xem → swipe YouTube khỏi recent apps | Tracker detect (accessibility event cho launcher) |
| 2f.2 | Video được save | ✅ |

---

## Flow 3: Batch Upload & Sync

### 3a: Upload pending logs

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3a.1 | Xem 3-5 videos khác nhau trong 5 phút | pendingLogs có 3-5 items |
| 3a.2 | Đợi đến mốc upload (mỗi 5 phút) | `YouTubeService._uploadPending` fire |
| 3a.3 | Logcat | `✅ [YOUTUBE] Uploaded X logs` |
| 3a.4 | Backend: check DB `YouTubeLog` | Records xuất hiện |
| 3a.5 | `pendingLogs` sau upload | Empty (đã clear) |
| 3a.6 | Railway logs | `📺 [YOUTUBE] Saved X logs for profile Y` |

### 3b: Network fail → retry

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3b.1 | Tắt WiFi/4G → đợi upload time | Upload fail |
| 3b.2 | pendingLogs không clear (vì fail) | ✅ |
| 3b.3 | Bật lại mạng → đợi lần upload tiếp | Upload thành công, clear pending |

### 3c: Dedup

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3c.1 | Upload 1 log, xong → upload lại cùng log | Backend xử lý idempotent (không duplicate) |

### 3d: Sync blocked videos

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3d.1 | Parent manual block 1 video | Backend emit `blockedVideosUpdated` |
| 3d.2 | Child nhận Socket.IO → `_syncBlockedVideos` fire | `✅ [YOUTUBE] Synced X blocked videos` |
| 3d.3 | Kotlin: `YouTubeTracker.blockedVideos` cập nhật | ✅ |

---

## Flow 4: AI Analysis (Backend Worker)

### 4a: AI chạy khi có API key

**Điều kiện:** `GEMINI_API_KEY` đã set trong Railway Variables

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4a.1 | Đợi 10 phút sau khi có logs mới | Worker tự fire |
| 4a.2 | Hoặc: trigger manual `POST /api/admin/run-ai-analysis` | Worker fire ngay |
| 4a.3 | Railway logs | `🤖 [AI WORKER] Analyzing N videos...` |
| 4a.4 | Mỗi request sleep 4.5s | Đảm bảo < 15 RPM |
| 4a.5 | Mỗi log update: `isAnalyzed=true, dangerLevel, category, aiSummary` | DB cập nhật |
| 4a.6 | Logcat worker cuối | `✅ [AI WORKER] Batch done` |

### 4b: AI chạy KHÔNG có API key (safe mode)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4b.1 | Chưa set `GEMINI_API_KEY` | Worker skip, không crash |
| 4b.2 | Railway logs | `⏭️ [AI WORKER] GEMINI_API_KEY not set, skip batch` |
| 4b.3 | Logs vẫn lưu DB | `isAnalyzed = false` |
| 4b.4 | Parent UI vẫn xem dashboard được (không có danger level cho video mới) | ✅ |

### 4c: Rate limit exceeded

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4c.1 | Upload 100 videos liên tục | Worker analyze batch 10 items/lần |
| 4c.2 | Nếu hit 429 error | Fallback return `{dangerLevel: 1, category: 'SAFE'}`, không crash |

### 4d: Thumbnail không có

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4d.1 | Log không có `thumbnailUrl` | Worker analyze text-only |
| 4d.2 | Vẫn có kết quả dangerLevel | ✅ (chỉ kém chính xác hơn vision) |

### 4e: Classify videos thực tế

Test với videos mẫu:

| Video thật | Expected dangerLevel | Expected category |
|-----------|---------------------|-------------------|
| Cocomelon - Wheels on the Bus | 1 | SAFE |
| Kids song compilation | 1 | SAFE |
| MrBeast challenge | 1-2 | SAFE |
| Squid Game Episode | 4-5 | VIOLENCE |
| Fortnite gameplay | 2-3 | SAFE hoặc VIOLENCE |
| ELSAGATE fake Elsa cartoon | 4-5 | DISTURBING |
| Explicit music video | 3-4 | SEXUAL |

**Note:** AI không hoàn hảo. Có thể false positive/negative vài case. Acceptable cho đồ án.

---

## Flow 5: AI Alert & Auto-Block

### 5a: Danger level >= 4 trigger alert

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 5a.1 | AI analyze video với dangerLevel = 4 | `handleDangerousVideo` fire |
| 5a.2 | DB: AIAlert record tạo | ✅ |
| 5a.3 | DB: BlockedVideo record tạo | ✅ |
| 5a.4 | DB: YouTubeLog.isBlocked = true | ✅ |
| 5a.5 | Socket.IO: Parent room nhận `aiAlert` event | ✅ |
| 5a.6 | Socket.IO: Child device room nhận `blockedVideosUpdated` | ✅ |
| 5a.7 | FCM push notification đến Parent | ✅ |

### 5b: Danger level < 4 (không alert)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 5b.1 | Video dangerLevel = 3 | Chỉ lưu `dangerLevel, category, aiSummary` |
| 5b.2 | **KHÔNG** tạo AIAlert | ✅ |
| 5b.3 | **KHÔNG** push notification | ✅ |
| 5b.4 | Video vẫn xem được | ✅ |

### 5c: Parent UI nhận real-time alert

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 5c.1 | Parent app đang mở khi có alert | Dialog `AIAlertDialog` hiện ngay |
| 5c.2 | Dialog có: icon warning, dangerLevel, category, videoTitle, channel, aiSummary | ✅ |
| 5c.3 | 2 nút: "Đóng" và "Xem chi tiết" | ✅ |
| 5c.4 | Text "Video đã được tự động chặn" | ✅ |
| 5c.5 | Barrier dismissible = false (phải bấm nút) | ✅ |

### 5d: Parent UI background (push notification)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 5d.1 | Parent app trong background | FCM push notification hiện trên status bar |
| 5d.2 | Title: "⚠️ Cảnh báo nội dung nguy hiểm" | ✅ |
| 5d.3 | Body: tên profile + video title + summary | ✅ |
| 5d.4 | Tap notification | Mở app → navigate đến AI Alerts screen |

### 5e: Child bị chặn video ngay lập tức

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 5e.1 | Ngay sau AI alert, Child app nhận `blockedVideosUpdated` | Sync blocked list |
| 5e.2 | Nếu Child đang xem video đó | Kick về Home ngay |
| 5e.3 | Nếu Child cố mở lại video | Bị chặn |
| 5e.4 | Notification "🚫 Video bị chặn" hiển thị | ✅ |

---

## Flow 6: Parent Dashboard YouTube

### 6a: Load dashboard lần đầu

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6a.1 | Parent: Profile → "YouTube Activity" | Mở dashboard |
| 6a.2 | Chọn "7 ngày" | API `GET /api/profiles/:id/youtube/dashboard?days=7` |
| 6a.3 | Loading spinner → data hiện | ✅ |

### 6b: Summary cards

| # | Item | Verify |
|---|------|--------|
| 6b.1 | Total videos | Đúng số trong DB 7 ngày gần đây |
| 6b.2 | Total watch time | Sum duration đúng |
| 6b.3 | Alerts count (unread) | Đúng số |

### 6c: Danger level chart

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6c.1 | Horizontal bar chart 5 levels | Render đúng |
| 6c.2 | Count mỗi level khớp với DB | ✅ |
| 6c.3 | "Chưa phân tích" category hiển thị nếu có | ✅ |

### 6d: Top channels

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6d.1 | List top 10 channels | Sorted by watch time desc |
| 6d.2 | Mỗi channel: name, count, watch time | Chính xác |

### 6e: Categories summary

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6e.1 | Grid với icons cho mỗi category (BULLY, SEXUAL, DRUG, VIOLENCE, SELF_HARM, DISTURBING) | ✅ |
| 6e.2 | Color code: SAFE=xanh, 3=cam, 4-5=đỏ | ✅ |

### 6f: Recent alerts

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6f.1 | List 5 alerts gần nhất | Cards |
| 6f.2 | Tap → navigate chi tiết | ✅ |

### 6g: Daily activity chart

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6g.1 | Bar chart 7 ngày | Render |
| 6g.2 | Count video mỗi ngày đúng | ✅ |

### 6h: Empty state

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6h.1 | Profile mới, chưa có YouTube data | Hiện "Chưa có dữ liệu" |

---

## Flow 7: Drill-down Logs + Manual Block

### 7a: Filter by date

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7a.1 | Parent: Dashboard → "Xem tất cả videos" | Logs screen mở |
| 7a.2 | DatePicker: chọn hôm qua | API `?date=YYYY-MM-DD` |
| 7a.3 | Chỉ hiện videos ngày đó | ✅ |

### 7b: Filter by danger

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7b.1 | Slider: minDanger = 3 | API `?minDanger=3` |
| 7b.2 | Chỉ hiện videos có dangerLevel >= 3 | ✅ |

### 7c: Filter by channel

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7c.1 | Dropdown chọn "Cocomelon" | API `?channel=Cocomelon` |
| 7c.2 | Chỉ hiện Cocomelon videos | ✅ |

### 7d: Manual block 1 video

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7d.1 | Parent tap video → "Chặn video này" | Confirm dialog |
| 7d.2 | Confirm → API `POST /api/profiles/:id/blocked-videos` | 201 |
| 7d.3 | Video trong UI có badge "Đã chặn" | ✅ |
| 7d.4 | Socket emit `blockedVideosUpdated` | ✅ |
| 7d.5 | Child sync → `YouTubeTracker.blockedVideos` cập nhật | ✅ |
| 7d.6 | Child mở video đó | Bị chặn, kick về Home |

### 7e: Manual unblock

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7e.1 | Parent: "Bỏ chặn" video | DELETE `/api/blocked-videos/:id` |
| 7e.2 | Child sync | blockedVideos giảm 1 |
| 7e.3 | Child mở lại | Vào bình thường |

### 7f: Pagination

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7f.1 | Scroll đến cuối list 20 items | Auto load page 2 |
| 7f.2 | Loading indicator dưới cùng | ✅ |

---

## Flow 8: AI Alert Center

### 8a: Badge unread

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 8a.1 | Có 3 alerts chưa đọc | Badge "3" trên Home icon |
| 8a.2 | Parent vào Alert Center | API `GET /api/profiles/:id/ai-alerts?unread=true` |

### 8b: Tab switcher

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 8b.1 | Tab "Chưa đọc" / "Tất cả" | Switch được |
| 8b.2 | List alert cards (newest first) | ✅ |

### 8c: Alert detail

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 8c.1 | Tap alert → detail screen | Hiện video info, AI summary, timestamp |
| 8c.2 | Mark as read tự động | PUT `/api/ai-alerts/:id/read` |
| 8c.3 | Badge giảm 1 | ✅ |

### 8d: Link sang drill-down

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 8d.1 | Alert detail có nút "Xem trong lịch sử" | Navigate sang Logs screen, filter video đó |

---

## Flow 9: Reports — Daily Tab

### 9a: Mở Reports Screen

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9a.1 | Parent Home → "📊 Báo cáo" | Reports Screen mở |
| 9a.2 | TabBar "Hôm nay" / "Tuần này" | ✅ |
| 9a.3 | Default tab: "Hôm nay" | ✅ |

### 9b: Daily summary cards

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9b.1 | 4 cards: Screen time, Apps count, YouTube, Alerts | ✅ |
| 9b.2 | Số liệu khớp với dashboard khác | ✅ |
| 9b.3 | Format duration đẹp (ví dụ "2h 35m") | ✅ |

### 9c: Top Apps Pie Chart

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9c.1 | Pie chart với 5 top apps | Render đúng tỷ lệ |
| 9c.2 | Legend bên dưới | Match với pie slices |
| 9c.3 | Duration mỗi app đúng | ✅ |

### 9d: YouTube Danger Levels

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9d.1 | 5 horizontal bars cho 5 levels | Render |
| 9d.2 | Colors: green → red theo mức độ | ✅ |
| 9d.3 | Count + percentage đúng | ✅ |

### 9e: Location Section

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9e.1 | List geofence events trong ngày | Sorted theo thời gian |
| 9e.2 | Icon ENTER (xanh) / EXIT (cam) | ✅ |
| 9e.3 | Timestamp đúng format (HH:MM) | ✅ |

### 9f: Alerts Section

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9f.1 | Hiển thị nếu có: AI alerts, SOS, time extensions | ✅ |
| 9f.2 | Hide cards không có data | ✅ |

### 9g: Date Picker

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9g.1 | Tap date picker → chọn ngày hôm qua | API reload với `?date=YYYY-MM-DD` |
| 9g.2 | Data cập nhật theo ngày chọn | ✅ |
| 9g.3 | Label "Hôm nay" đổi thành "DD/MM/YYYY" | ✅ |

### 9h: Empty Day

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9h.1 | Chọn ngày không có data | Hiện empty state / 0 values |
| 9h.2 | Không crash | ✅ |

### 9i: Cache vs Realtime

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 9i.1 | Hôm nay: load chậm hơn (realtime compute) | ~500ms-1s |
| 9i.2 | Ngày cũ (đã có snapshot): load nhanh | ~200-300ms |

---

## Flow 10: Reports — Weekly Tab

### 10a: Tuần này

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 10a.1 | Tap tab "Tuần này" | API `GET /reports/weekly` |
| 10a.2 | Week picker default = tuần hiện tại (T2 → CN) | ✅ |

### 10b: Summary tuần

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 10b.1 | Cards tổng 7 ngày (screen time, YouTube, alerts...) | ✅ |
| 10b.2 | Numbers lớn hơn daily (vì cộng 7 ngày) | ✅ |

### 10c: Bar chart 7 ngày

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 10c.1 | Bar chart với 7 bars (T2-CN) | Render |
| 10c.2 | Height = screen time mỗi ngày | Proportional |
| 10c.3 | Loading delay ~2-5s (vì phải fetch 7 daily reports) | ⚠️ Acceptable |
| 10c.4 | Skeleton / loading indicator | ✅ |

### 10d: Week Picker

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 10d.1 | Chọn tuần trước | API `?weekStart=YYYY-MM-DD` (T2) |
| 10d.2 | Data reload | ✅ |

### 10e: Cron-generated report

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 10e.1 | Sau T2 00:10 VN → cron tạo report tuần vừa qua | Railway logs |
| 10e.2 | Parent xem tuần đó → load nhanh từ cache | ✅ |

---

## Flow 11: Activity History Timeline

### 11a: Timeline chronologically

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 11a.1 | Parent: "Lịch sử hoạt động" | Screen mở |
| 11a.2 | List events newest first | ✅ |
| 11a.3 | Mỗi item: icon + title + timestamp | ✅ |

### 11b: 6 loại events hiển thị

| Type | Icon | Color | Verify |
|------|------|-------|--------|
| SOS | warning | Red dark | ⬜ |
| AI_ALERT | psychology | Red | ⬜ |
| GEOFENCE_ENTER | login | Green | ⬜ |
| GEOFENCE_EXIT | logout | Orange | ⬜ |
| TIME_EXTENSION | access_time | Blue | ⬜ |
| WARNING | notifications | Yellow dark | ⬜ |
| SESSION_START/END | play/stop | Blue/Grey | ⬜ |

### 11c: Date picker

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 11c.1 | Đổi ngày | Timeline reload |
| 11c.2 | Ngày không có activity | Empty state |

### 11d: Pull-to-refresh

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 11d.1 | Kéo xuống từ đỉnh | Refresh indicator |
| 11d.2 | Reload data | ✅ |

---

## Flow 12: Cron Jobs Hoạt Động

### 12a: Daily Report Cron

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 12a.1 | Đến 00:05 VN (hoặc manual trigger) | Worker chạy |
| 12a.2 | Railway logs | `📊 [REPORT] Generating daily reports for N profiles` |
| 12a.3 | Report cho ngày hôm qua (yesterday) | Được tạo trong DB |
| 12a.4 | Bảng ReportSnapshot có record mới type=DAILY | ✅ |

### 12b: Weekly Report Cron

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 12b.1 | Đến T2 00:10 VN | Weekly worker fire |
| 12b.2 | Railway logs | `📊 [REPORT] Generating weekly reports` |
| 12b.3 | Report cho tuần vừa kết thúc (previous Monday) | Tạo trong DB |
| 12b.4 | Bảng ReportSnapshot có record type=WEEKLY | ✅ |

### 12c: AI Worker Cron

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 12c.1 | Sau khi có unanalyzed logs, đợi 10 phút | Worker fire |
| 12c.2 | Batch 10 items/lần | ✅ |
| 12c.3 | Sleep 4.5s giữa requests | Không vượt 15 RPM |
| 12c.4 | Nếu pending > 10 → lần sau tiếp tục | ✅ |

### 12d: Manual Trigger (Dev)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 12d.1 | `POST /api/admin/run-ai-analysis` | 200 |
| 12d.2 | `POST /api/admin/run-daily-reports` | 200 |
| 12d.3 | `POST /api/admin/run-weekly-reports` | 200 |

### 12e: Timezone

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 12e.1 | Railway có timezone UTC, nhưng cron check VN | Dùng `toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' })` |
| 12e.2 | Không chạy sai giờ | ✅ |

---

## Flow 13: Edge Cases & Lỗi

### 13a: Child không có YouTube app

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 13a.1 | Thiết bị không cài YouTube | Tracker không fire, không lỗi |
| 13a.2 | pendingLogs empty mãi mãi | ✅ |

### 13b: Restart Child device

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 13b.1 | Reboot thiết bị | ForegroundService restart |
| 13b.2 | YouTubeTracker state lost (pendingLogs = []) | Acceptable (đã upload trước đó) |
| 13b.3 | Sau đó xem video mới → track như bình thường | ✅ |

### 13c: Kill app

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 13c.1 | Swipe Kid app khỏi recent | Service vẫn chạy (foreground) |
| 13c.2 | Reopen app → tracker resume | ✅ |

### 13d: Gemini quota exceeded

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 13d.1 | Vượt 1500 RPD | API trả 429 |
| 13d.2 | Worker catch error, fallback SAFE | Không crash |
| 13d.3 | Logs stay unanalyzed | Tomorrow worker tries again |

### 13e: Network slow khi upload

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 13e.1 | Slow 3G network | Upload có thể timeout |
| 13e.2 | pendingLogs không clear | Retry next cycle |

### 13f: YouTube Shorts

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 13f.1 | Xem YouTube Shorts (swipe lên/xuống) | Title có thể thay đổi quá nhanh |
| 13f.2 | Tracker có thể miss một số shorts | Acceptable |
| 13f.3 | Shorts > 10s vẫn log được | ✅ |

### 13g: Block 1 video → 2 videos cùng tên (false positive)

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 13g.1 | 2 videos cùng title "Funny Cats" từ 2 channels | Block title sẽ block cả 2 |
| 13g.2 | Parent có thể unblock nếu muốn giữ 1 | ⚠️ Limitation |

### 13h: Report với profile mới

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 13h.1 | Profile mới tạo, chưa có data | Report hiện 0 values, không crash |

---

## Flow 14: Privacy Check

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 14a | Check DB YouTubeLog | Chỉ lưu title, channel, duration, dangerLevel, category, summary |
| 14b | **KHÔNG** lưu transcript, comments, search query | ✅ |
| 14c | Check DB không có SMS, Call logs | ✅ (Sprint 9 không làm) |
| 14d | AI Summary ngắn gọn, không leak thông tin | ✅ |
| 14e | Thumbnail URL là public Google static, không lưu image | ✅ |

---

## Flow 15: Performance

| # | Metric | Target |
|---|--------|--------|
| 15a | Battery drain 24h với tracker active | < 5% tăng so với không tracker |
| 15b | Dashboard load time (7 ngày) | < 1.5s |
| 15c | Daily report (hôm nay realtime) | < 1s |
| 15d | Daily report (cache) | < 500ms |
| 15e | Weekly report (7 daily reports parallel) | < 3s |
| 15f | Activity history (100 events) | < 800ms |
| 15g | AI Worker 1 video | ~5-8s (including 4.5s sleep) |
| 15h | Batch 10 videos | ~50-80s |

---

## Bảng tổng hợp kết quả test

| # | Flow | Kết quả | Ghi chú |
|---|------|---------|---------|
| 1 | YouTube Tracker - Đọc info | ⬜ Pass / ⬜ Fail | |
| 2 | YouTube Tracker - Watch duration | ⬜ Pass / ⬜ Fail | |
| 3 | Batch Upload & Sync | ⬜ Pass / ⬜ Fail | |
| 4 | AI Analysis Worker | ⬜ Pass / ⬜ Fail | |
| 5 | AI Alert & Auto-Block | ⬜ Pass / ⬜ Fail | |
| 6 | Parent Dashboard YouTube | ⬜ Pass / ⬜ Fail | |
| 7 | Drill-down Logs + Manual Block | ⬜ Pass / ⬜ Fail | |
| 8 | AI Alert Center | ⬜ Pass / ⬜ Fail | |
| 9 | Reports - Daily Tab | ⬜ Pass / ⬜ Fail | |
| 10 | Reports - Weekly Tab | ⬜ Pass / ⬜ Fail | |
| 11 | Activity History Timeline | ⬜ Pass / ⬜ Fail | |
| 12 | Cron Jobs | ⬜ Pass / ⬜ Fail | |
| 13 | Edge Cases | ⬜ Pass / ⬜ Fail | |
| 14 | Privacy Check | ⬜ Pass / ⬜ Fail | |
| 15 | Performance | ⬜ Pass / ⬜ Fail | |

---

## Checklist cuối Sprint 9

### Phần A: YouTube + AI

| # | Hạng mục | ✅ |
|---|----------|----|
| A1 | YouTubeTracker đọc title + channel từ YouTube UI | ⬜ |
| A2 | Watch duration tracking (skip < 10s) | ⬜ |
| A3 | Auto stop khi rời YouTube / screen off | ⬜ |
| A4 | Batch upload mỗi 5 phút | ⬜ |
| A5 | Sync blocked videos mỗi 2 phút + Socket.IO | ⬜ |
| A6 | Gemini AI integration + safe mode (no key) | ⬜ |
| A7 | AI Worker batch mỗi 10 phút | ⬜ |
| A8 | Auto alert + block khi dangerLevel >= 4 | ⬜ |
| A9 | Push notification AI Alert | ⬜ |
| A10 | Parent Dashboard YouTube với charts | ⬜ |
| A11 | Drill-down logs với filter | ⬜ |
| A12 | Manual block/unblock | ⬜ |
| A13 | AI Alert Dialog + Alert Center | ⬜ |

### Phần B: Reports

| # | Hạng mục | ✅ |
|---|----------|----|
| B1 | ReportSnapshot model + migration | ⬜ |
| B2 | Aggregation service (gộp Sprint 5-9 data) | ⬜ |
| B3 | Cron daily + weekly (timezone VN) | ⬜ |
| B4 | Report API với cache fallback | ⬜ |
| B5 | Activity history API (6 loại events) | ⬜ |
| B6 | Reports Screen với TabBar | ⬜ |
| B7 | Daily Tab (cards + charts) | ⬜ |
| B8 | Weekly Tab (7-day bar chart) | ⬜ |
| B9 | Activity History timeline | ⬜ |
| B10 | Navigation entry vào Parent Home | ⬜ |

### Phần C: Chất lượng

| # | Hạng mục | ✅ |
|---|----------|----|
| C1 | Privacy compliance (no transcript/comments) | ⬜ |
| C2 | Performance targets đạt | ⬜ |
| C3 | Edge cases không crash | ⬜ |
| C4 | Survive reboot / offline / kill app | ⬜ |

---

## Lỗi thường gặp & Cách xử lý

| Lỗi | Nguyên nhân | Fix |
|-----|-------------|-----|
| Tracker không đọc được title | YouTube version mới, resource IDs đổi | Chạy `adb shell uiautomator dump` tìm IDs mới, update `YouTubeTracker.kt` |
| pendingLogs không upload | Upload error, không retry | Check network, logs. Bug: thêm retry logic |
| AI Worker không chạy | GEMINI_API_KEY chưa set / `isRunning` stuck = true | Railway Variables check, restart service |
| Push notification không đến | FCM token expired | Parent re-login để refresh FCM token |
| Dashboard chart trống | Data chưa analyzed (level null) | Đợi AI worker run hoặc manual trigger |
| Weekly tab load chậm | 7 parallel API calls | Acceptable < 5s. Tối ưu: backend trả 7-day bulk |
| Report sai timezone | Cron check UTC thay VN | Dùng `toLocaleString(..., {timeZone: 'Asia/Ho_Chi_Minh'})` |
| Activity history thiếu events | Query thiếu 1 model | Add missing query trong controller |
| YouTube Shorts miss | Event stream quá nhanh | Accept limitation |
| Gemini 429 | Vượt rate limit | Sleep 4.5s giữa requests, fallback SAFE |

---

## Khi gặp lỗi — cách báo cho Khanh

Format báo bug:

```
Bug: [Flow X, Bước Y.Z]
Triệu chứng: ...
Expected: ...
Actual: ...
Flutter log: ...
Kotlin log (logcat filter YouTubeTracker hoặc YouTubeService): ...
Railway log: ...
Gemini response (nếu AI bug): ...
```
