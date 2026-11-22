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

## Bước 4 — Playables và ký tự lạ (bản sửa 17/11 tối)

7. Trên YouTube mở mục **Playables** (trò chơi), lướt ~30 giây. Xem thêm 1 Short có hashtag (`#…`).

- [ ] App phụ huynh **không** có dòng nào tên "Playables" / "Trò chơi" trong YouTube nhật ký.
- [ ] Tiêu đề Short có hashtag hiện bình thường, không có khoảng trắng thừa hay ô vuông lạ sau `#tag`.

## Bước 5 — @người đăng video thường + ký tự điều khiển (bản sửa 19/11)

8. Mở video thường có dòng `@<tên> … likes … views … ago` ngay dưới tiêu đề (vd. kênh `@thesamurice`),
   xem ≥ 30 giây (có thể chờ dòng `@<tên>` hiện trễ vài giây).
9. Xem 1 Short có nhiều hashtag, rồi quay lại video thường ở bước 8.

- [ ] Logcat có `▶️ Started … | @thesamurice` **hoặc** `🏷️ Channel backfilled (tree): @thesamurice …`
      (bản 19/11 tối: thử lại sau ~2,5 s / 6 s / 15 s và mỗi lần màn hình đổi).
- [ ] Xem 1 video ở chế độ **toàn màn hình** rồi thoát ra màn dọc ≥ 5 giây → kênh vẫn được điền.
- [ ] Mở trang **Tải xuống / Downloads** → không có dòng "Downloads" trong YouTube nhật ký.
- [ ] App phụ huynh: YouTube nhật ký + tổng quan hiện `@thesamurice`, **không** trống / "Unknown".
- [ ] Không có dòng nhật ký nào chỉ toàn ký hiệu/ô vuông, và một video không bị tách thành 2 dòng.
- [ ] Nếu vẫn trống: gửi logcat, cần dòng `🩻 Video: no @handle …` (ký tự ẩn hiện dạng `⁨`).

## Bước 6 — Video dài toàn màn hình có phụ đề + "Suggested video" (bản sửa 20/11)

Lỗi prod 20/11: một video dài bị tách thành 2 dòng, dòng sau mang tiêu đề là **câu phụ đề** và kênh
trống; thêm một dòng tiêu đề "Suggested video".

10. Mở video thường dài ≥ 5 phút, **bật phụ đề (CC)**, chuyển **toàn màn hình**, chạm màn hình vài lần
    cho thanh điều khiển hiện ra, xem ≥ 3 phút.
11. Để video chạy đến hết (hoặc tua gần cuối) cho màn **video gợi ý / tự phát tiếp** hiện ra ≥ 20 giây.

- [ ] Logcat có thể có `🌲 Title from tree scan: <câu phụ đề>` nhưng **không** có `⏹️ Stopping` /
      `▶️ Started (navigation)` mới cho tới khi thật sự sang video khác.
- [ ] App phụ huynh: video ở bước 10 chỉ có **1 dòng**, đúng tiêu đề + `@kênh`, thời lượng ≈ thời gian xem.
- [ ] **Không** có dòng nào tên "Suggested video" / "Video đề xuất".
- [ ] Khi tự phát tiếp sang video mới (hoặc bấm video gợi ý) → có dòng mới đúng tiêu đề video đó.
- [ ] Nếu không đạt: gửi `adb logcat -d -s YouTubeTracker`, và chạy `uiautomator dump` lúc đang toàn màn hình.

**Bước 6b — Video bắt đầu ngay ở toàn màn hình (bản sửa 20/11 chiều).**

12. Đang toàn màn hình có CC, để video tự phát tiếp sang video mới (hoặc xoay ngang máy rồi mới mở video).
    Xem ≥ 1 phút **không chạm**, sau đó chạm màn hình cho thanh điều khiển hiện ra, rồi thoát toàn màn hình.

- [ ] Logcat **không** có `🌲 Title from tree scan: <câu phụ đề>` (node phụ đề đã bị loại khỏi quét cây).
- [ ] Nếu phiên lỡ bắt đầu bằng tên tạm, khi tiêu đề thật hiện ra phải có `✏️ Title adopted: … → <tiêu đề thật>`,
      **không** có `⏹️ Stopping` + `▶️ Started` mới.
- [ ] App phụ huynh: video đó **1 dòng**, đúng tiêu đề, không có dòng nào là câu phụ đề.
- [ ] (bản sửa #386) Phụ huynh chặn 1 video; trên máy trẻ mở video đó khi máy **đang xoay ngang** / tự phát tiếp ở
      toàn màn hình, chạm cho thanh điều khiển hiện → video **bị chặn** (thông báo + về màn Home).
- [ ] Bắt buộc gửi kèm lúc đang toàn màn hình + CC + thanh điều khiển đang hiện:
      `adb shell uiautomator dump /sdcard/yt_full.xml && adb pull /sdcard/yt_full.xml`
      (để Khanh xác nhận mã giao diện của phụ đề và tiêu đề toàn màn hình).

## Bước 7 — Toàn màn hình từ giây 0, tự phát bài kế (bản sửa 22/11, MediaSession)

Báo cáo 22/11: mở thẳng / tự phát tiếp ở toàn màn hình **không chạm** → không ghi tên video và @người đăng
(thanh điều khiển ẩn nên cây giao diện không có tiêu đề). Bản sửa đọc tên video từ **MediaSession** của YouTube
(cái hiện ở trình phát nhạc trên thanh thông báo), không phụ thuộc giao diện. Cần quyền mới **Truy cập thông báo**.

13. Cài APK mới. Mở app trẻ → pop-up "còn thiếu quyền" có dòng **Truy cập thông báo** → **Mở Cài đặt** → bật KidFun
    → quay lại app.
    - [ ] Pop-up không còn dòng này. Logcat có `🎵 MediaSession watcher started`.
14. Mở 1 video thường, xoay ngang / bấm toàn màn hình **ngay**, rồi **không chạm** màn hình. Để video chạy hết và
    tự phát sang **ít nhất 2 bài kế** (chọn video ngắn 2–4 phút cho đỡ chờ). Sau đó thoát toàn màn hình, về Home.
    - [ ] Logcat: mỗi bài có `🎵 Media metadata: <tiêu đề> | <tên kênh> | <giây>s` và `▶️ Started (media): …`;
          khi sang bài mới có `⏹️ Stopping: <bài trước>` (không có `Started` nào mang câu phụ đề).
    - [ ] App phụ huynh: **mỗi bài 1 dòng**, đúng tiêu đề, thời lượng gần đúng thời gian xem từng bài
          (không dồn hết vào bài đầu).
    - [ ] Kênh: bài nào đã thoát về màn dọc thì là `@tên`; bài chỉ xem ở toàn màn hình có thể là **tên hiển thị**
          của kênh (vd. `KÊNH MẪU`, không có @) — đây là đúng thiết kế.
15. Khi đang toàn màn hình, bấm tạm dừng 1 phút rồi phát tiếp.
    - [ ] Logcat có `⏸️ Paused` / `▶️ Resumed`; thời lượng bài đó **không** tính 1 phút tạm dừng.
16. Có quảng cáo chen giữa (nếu gặp): ghi lại dòng `🎵 Media metadata` lúc quảng cáo chạy.
    - [ ] Gửi kèm dòng đó (Khanh cần biết YouTube công bố gì khi chạy quảng cáo; chưa lọc).
17. Hồi quy Shorts: lướt 3 Shorts như Bước 1–3.
    - [ ] Vẫn đủ @handle + tiêu đề, mỗi Short 1 dòng (MediaSession không được chen vào Shorts).
18. Tắt "Truy cập thông báo" của KidFun, lặp lại bước 14 với 1 video.
    - [ ] App không lỗi; quay về cách cũ (chỉ ghi được khi chạm màn hình hoặc thoát toàn màn hình).

Gửi kèm: `adb logcat -d -s YouTubeTracker > yt_media_log.txt` và `adb shell dumpsys media_session` chạy lúc đang
phát toàn màn hình.

## Ghi chép

- Mã commit (**bắt buộc**): `git rev-parse --short HEAD` →
- Máy / Android:
- Phiên bản YouTube (Cài đặt › Ứng dụng › YouTube):
- Nếu có bước không đạt: gửi `adb logcat -d -s YouTubeTracker > yt_shorts_log.txt` (cần cả dòng `🩻 Shorts…`
  nếu có), và chạy lúc **đang mở Short**:
  `adb shell uiautomator dump /sdcard/yt_shorts.xml && adb pull /sdcard/yt_shorts.xml`.
