# Luồng 15 — YouTube: ghi tên kênh dạng @handle (giao diện YouTube mới)

**Báo cáo gốc (16/11):** giao diện YouTube mới không còn hiện tên kênh. Ngay dưới tiêu đề video chỉ có
một dòng gộp, ví dụ `@PhêPhim 26K likes 1.7M views 5y ago more`. Vì vậy mục **YouTube tổng quan** và
**YouTube nhật ký** (Luồng 03, Bước 1, mục 11–12) không có tên kênh.

**Bản sửa (nhánh `fix/youtube-channel-handle`):**
- App trẻ tìm chuỗi bắt đầu bằng `@` ở **dòng đầu tiên có @ nằm sau tiêu đề video** và chỉ lấy phần
  `@PhêPhim` (bỏ `26K likes 1.7M views 5y ago more`). Bình luận có @tên người khác ở phía dưới
  không bị lấy nhầm.
- YouTube bản cũ vẫn có tên kênh riêng thì app vẫn đọc tên đó như trước.
- Dòng @handle thường tải xong **sau** tiêu đề. Nếu lúc bắt đầu video chưa thấy, app sẽ điền tên kênh vào
  video đang xem ở lần quét kế tiếp (khoảng 2 giây); thời lượng xem không bị tính lại từ đầu.

Thời gian: ~15 phút. Chỉ cần **APK máy trẻ** mới (backend không đổi). Hỗ trợ tiếp cận của KidFun phải đang bật.

## Bước 1 — Video thường

1. Pull nhánh, Run lại app trẻ (không cần gỡ).
2. Mở terminal: `adb logcat -c` rồi `adb logcat -s YouTubeTracker`.
3. Trên máy trẻ mở YouTube, phát một video thường (ví dụ của kênh @PhêPhim), xem **≥ 30 giây**.

- [ ] Log có dòng `▶️ Started … | @<handle>`, **hoặc** `▶️ Started … | null` rồi vài giây sau có
      `🏷️ Channel backfilled: @<handle> …`.
- [ ] `@<handle>` trong log **khớp** chuỗi @ dưới tiêu đề trên màn hình, **không** kèm "likes / views / ago / more".

4. Bấm Home, mở KidFun, đợi ~10 giây, mở app phụ huynh → hồ sơ bé → **YouTube**.

- [ ] **YouTube nhật ký**: video vừa xem có tên kênh `@<handle>` (không còn trống / "Unknown").
- [ ] **YouTube tổng quan**: phần thống kê theo kênh có `@<handle>`.

## Bước 2 — Không lấy nhầm @ trong bình luận

5. Mở một video có bình luận chứa @tên người khác. Cuộn xuống mở phần bình luận rồi xem tiếp ≥ 30 giây.

- [ ] Tên kênh ghi nhận vẫn là @handle của kênh (dưới tiêu đề), không phải @tên trong bình luận.

## Bước 3 — Shorts (ghi lại kết quả, không chặn merge)

6. Xem một video Shorts ≥ 15 giây, rồi bấm Home.

- [ ] Ghi lại tên kênh trong log / app phụ huynh: `@handle` / tên thường / trống.

## Ghi chép

- Mã commit: `git rev-parse --short HEAD` →
- Máy / Android:
- Phiên bản YouTube:
- Nếu có bước không đạt: gửi `adb logcat -d -s YouTubeTracker > yt_log.txt` và
  `adb shell uiautomator dump /sdcard/yt_video.xml && adb pull /sdcard/yt_video.xml` (chạy lúc đang mở video).
