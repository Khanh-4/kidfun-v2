# Luồng 08 — YouTube Activity: log lên app phụ huynh + thu thập cây giao diện YouTube

**Báo cáo gốc:** "YouTube Activity không ghi nhận tiêu đề video / tên kênh dù đã bật Hỗ trợ tiếp cận"
(Luồng 03 – Bước 1, mục 11 YouTube tổng quan và mục 12 YouTube nhật ký).

**Kết quả điều tra (DB production, 02/11):** máy test **có** gửi lên 6 video, **tiêu đề đúng**, nhưng
**tên kênh luôn trống**. Lý do bạn không thấy video là app chỉ gửi log khi đã **rời YouTube / chuyển video**,
và trước đây phải chờ thêm **tối đa 5 phút**.

**Bản mới (PR #331, đã có trên `develop`):**
- Log được gửi **mỗi 1 phút** (trước đây là 5 phút), và gửi **ngay** khi mở lại app trẻ.
- Không còn mất log nếu video kết thúc đúng lúc app đang gửi.
- Lọc nhật ký theo ngày dùng giờ Việt Nam (video xem lúc 00:00–06:59 không còn rơi sang ngày hôm trước).

**Chưa sửa:** tên kênh vẫn trống. Bước 3 thu thập dữ liệu để sửa lỗi này.

Nhánh: `develop` (pull mới nhất) — thời gian ~20 phút. Máy ảo cần có app YouTube (image có Google Play).
Hỗ trợ tiếp cận của KidFun phải **đang bật** (xem Luồng 07).

## Bước 1 — Video hiện ở app phụ huynh sau khi mở lại app trẻ

1. `git pull` nhánh `develop`, Run app trẻ lại (không cần gỡ).
2. Trên máy trẻ: mở YouTube, xem một video thường **ít nhất 15 giây**.
3. Bấm **Home**, rồi mở app **KidFun**.
4. Đợi khoảng 10 giây, mở app phụ huynh → hồ sơ của bé → **YouTube**.

- [ ] Mục **YouTube nhật ký** có video vừa xem, tiêu đề đúng, thời lượng xấp xỉ thời gian đã xem.
- [ ] Mục **YouTube tổng quan**: số video và số phút tăng lên tương ứng.
- [ ] (Biết trước) Tên kênh trống / hiện "Unknown" — **không cần báo lỗi**, đây là lỗi đang sửa.

## Bước 2 — Video vẫn lên khi trẻ chuyển sang app khác

5. Mở YouTube, xem video **khác** ≥ 15 giây.
6. Chuyển sang một app bất kỳ **không phải KidFun** (ví dụ Cài đặt, Chrome). **Không** mở KidFun.
7. Đợi **1–2 phút**, kiểm tra app phụ huynh.

- [ ] Video thứ hai hiện trong nhật ký.
- [ ] Video xem dưới 10 giây **không** được ghi (đúng thiết kế) — thử một video, thoát ngay sau ~5 giây.

## Bước 3 — Thu thập cây giao diện YouTube (để sửa tên kênh)

8. Mở YouTube, phát một video thường. **Chạm vào màn hình** cho hiện các nút điều khiển, rồi ngay lập tức chạy
   trên máy tính (terminal của Android Studio):
   ```bash
   adb shell uiautomator dump /sdcard/yt_video.xml && adb pull /sdcard/yt_video.xml
   ```
9. Mở một video **Shorts**, đợi nó chạy, rồi chạy:
   ```bash
   adb shell uiautomator dump /sdcard/yt_shorts.xml && adb pull /sdcard/yt_shorts.xml
   ```
10. Ghi lại log của bộ theo dõi YouTube trong lúc xem một video ~30 giây rồi bấm Home:
    ```bash
    adb logcat -c
    # xem video ~30 giây, bấm Home
    adb logcat -d -s YouTubeTracker > yt_log.txt
    ```
11. Xem phiên bản YouTube: Cài đặt → Ứng dụng → YouTube → (cuộn xuống cuối) **Phiên bản**.

- [ ] Gửi lại 3 file `yt_video.xml`, `yt_shorts.xml`, `yt_log.txt` + phiên bản YouTube.
      Nếu lệnh `uiautomator dump` báo lỗi "could not get idle state", chạy lại vài lần hoặc tạm dừng video rồi chạy.

## Ghi chép

- Mã commit: `git rev-parse --short HEAD` → (phải là `da7f415` hoặc mới hơn)
- Máy / Android:
- Phiên bản YouTube:
- Bước không đạt (dùng mẫu báo lỗi trong README):
