# Luồng 17 — YouTube Shorts: ghi tiêu đề và @người đăng

**Báo cáo gốc (17/11, Luồng 15, Bước 3):** khi bé xem YouTube Shorts, app trẻ không ghi được gì: không có
tiêu đề, không có `@người đăng`. Video thường thì vẫn ghi được.

**Nguyên nhân:** app trẻ nhận ra màn Shorts bằng một danh sách mã giao diện (view ID) đoán từ trước. YouTube
bản hiện nay **không có mã nào** trong danh sách đó, nên app không biết đang ở Shorts và bỏ qua toàn bộ.

**Bản sửa (nhánh `fix/youtube-shorts-tracking`):**
- Nhận ra màn Shorts bằng mã giao diện thật (`reel_recycler`, `reel_player_page_container`, `reel_watch_player`,
  `reel_watch_fragment_root`). Mã này lấy từ 2 bản dump giao diện thật của người khác, khớp nhau.
- Chỉ đọc chữ của **Short đang ở giữa màn hình**. YouTube tải sẵn Short trước/sau nên không lấy nhầm @ của chúng.
  Chỉ đọc vùng **dưới, bên trái**, không đọc cột lượt thích / Share / Save bên phải.
- Dòng chữ chỉ có `@tên` (ví dụ `@hismathakmal4231`) là người đăng. Dòng chữ ngay dưới, sau khi bỏ nút
  **Subscribe / Đăng ký**, là tiêu đề. Dấu `...` ở cuối tiêu đề bị cắt được bỏ đi.
- Short không có chú thích thì tiêu đề ghi là `YouTube Shorts (@tên)`.
- Lướt sang Short khác: Short cũ được lưu (nếu xem ≥ 10 giây) và Short mới bắt đầu tính giờ.
- Nếu app thấy màn Shorts nhưng không tìm ra `@tên`, logcat in dòng `🩻 Shorts: no @handle found, visible texts=[…]`
  (tối đa 20 giây một lần). **Dòng này là thứ Khanh cần nhất nếu bước nào không đạt.**

Thời gian: ~15 phút. Chỉ cần **APK máy trẻ** mới (backend không đổi). Hỗ trợ tiếp cận của KidFun phải đang bật.

## Bước 1 — Một Short

1. Pull nhánh, Run lại app trẻ (không cần gỡ).
2. Mở terminal: `adb logcat -c` rồi `adb logcat -s YouTubeTracker`.
3. Trên máy trẻ mở YouTube → tab **Shorts**, để một Short chạy **≥ 20 giây** (không lướt).

- [ ] Log có dòng `▶️ Started (content): <tiêu đề> | @<tên>` (hoặc `▶️ Started:` / `▶️ Re-detected (retry):`).
- [ ] `@<tên>` khớp chữ `@…` ở góc dưới bên trái màn hình.
- [ ] `<tiêu đề>` khớp dòng chữ ngay dưới `@…` (có thể ngắn hơn nếu trên màn hình bị cắt bằng `...`),
      **không** phải "Subscribe", "Share", số lượt thích.

## Bước 2 — Lướt nhiều Short

4. Lướt lên sang Short tiếp theo, xem ~15 giây. Lặp lại 3 lần (tổng 4 Short).

- [ ] Mỗi lần lướt có 1 dòng `⏹️ Stopping: …` của Short cũ rồi `▶️ Started (navigation): … | @<tên mới>`.
- [ ] Không có Short nào bị ghi `@<tên>` của Short **khác** (so với màn hình lúc xem).

5. Bấm Home, mở KidFun, đợi ~10 giây, mở app phụ huynh → hồ sơ bé → **YouTube**.

- [ ] **YouTube nhật ký**: có các Short vừa xem, đúng tiêu đề và `@<tên>`.
- [ ] **YouTube tổng quan**: thống kê theo kênh có các `@<tên>` đó.

## Bước 3 — Hồi quy video thường (không được hỏng)

6. Mở một video thường, xem ≥ 30 giây, mở phần bình luận có @tên người khác.

- [ ] Vẫn đạt như Luồng 15 Bước 1–2: `▶️ Started … | @<handle kênh>`, không lấy @ trong bình luận.

## Ghi chép

- Mã commit: `git rev-parse --short HEAD` →
- Máy / Android:
- Phiên bản YouTube (Cài đặt › Ứng dụng › YouTube):
- Nếu có bước không đạt: gửi `adb logcat -d -s YouTubeTracker > yt_shorts_log.txt` (cần cả dòng `🩻 Shorts…`
  nếu có), và chạy lúc **đang mở Short**:
  `adb shell uiautomator dump /sdcard/yt_shorts.xml && adb pull /sdcard/yt_shorts.xml`.
