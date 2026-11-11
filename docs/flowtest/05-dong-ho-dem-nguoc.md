# 05 — Đồng hồ đếm ngược app trẻ (test lại sau PR fix/child-countdown-sync)

Kiểm tra 3 lỗi chốt từ log Vercel ngày 28/10:
cache 30s trả `remainingSeconds` cũ kèm hạn mức mới, 7 lần gọi `today-limit` song song mỗi lần lưu,
và `session/resume` trả 404 sau 00:00 giờ VN khiến server ngừng đếm.

Cần: APK build từ nhánh `fix/child-countdown-sync`, 1 máy trẻ + app phụ huynh, logcat lọc
`📊|💓|SCREEN|PAUSE|RESUME|Realtime`.

## Bước 1 — Đổi hạn mức không làm lệch "Đã dùng"

| # | Thao tác | Mong đợi |
|---|----------|----------|
| 1.1 | Dùng máy trẻ ~5 phút, ghi lại "Đã dùng" | Ví dụ `Đã dùng: 0:05:xx` |
| 1.2 | Phụ huynh tăng hạn mức hôm nay +30 phút, lưu | Trong ~3s: "/ Xh hôm nay" tăng 30p, đồng hồ còn lại tăng ~30p, **"Đã dùng" giữ nguyên (±5s)** |
| 1.3 | Giảm hạn mức −45 phút, lưu | "Đã dùng" vẫn giữ nguyên, đồng hồ còn lại giảm ~45p |
| 1.4 | Lặp 1.2–1.3 thêm 3 lần liên tiếp | "Đã dùng" không trôi qua các lần đổi |
| 1.5 | Trẻ xin thêm 15p, phụ huynh duyệt | Còn lại +15p, "Đã dùng" giữ nguyên |
| 1.6 | Logcat sau mỗi lần lưu | Chỉ **1** dòng `📊 [_fetchAndApplyNewLimit] limitDelta=...` (trước đây 7–8 dòng) |

## Bước 2 — Tắt màn hình thì ngưng đếm

| # | Thao tác | Mong đợi |
|---|----------|----------|
| 2.1 | Đang mở app trẻ, ghi số còn lại, tắt màn hình 2 phút | Logcat có `📱 [SCREEN OFF]` |
| 2.2 | Mở khoá lại | `📱 [SCREEN ON]`, **không** có `❌ [RESUME]`; số còn lại ≈ số ở 2.1 (lệch ≤ 10s) |

## Bước 3 — Ra khỏi app (Home / đa nhiệm / app khác) vẫn đếm

| # | Thao tác | Mong đợi |
|---|----------|----------|
| 3.1 | Ghi số còn lại, bấm Home, mở YouTube xem 5 phút (không tắt màn hình) | — |
| 3.2 | Quay lại app trẻ | Số còn lại giảm ~5 phút |
| 3.3 | Phụ huynh mở chi tiết thiết bị | Thời gian đã dùng cũng tăng ~5 phút |

Nếu 3.2 hoặc 3.3 sai: gửi logcat đoạn từ lúc bấm Home tới lúc quay lại.

## Bước 4 — Qua 00:00 giờ VN (quan trọng)

| # | Thao tác | Mong đợi |
|---|----------|----------|
| 4.1 | Mở app trẻ lúc ~23:55, để chạy qua 00:00 | — |
| 4.2 | Lúc ~00:05 tắt màn hình 1 phút rồi mở lại | Không có `❌ [RESUME]`; tiếp tục có `💓 [HEARTBEAT]` mỗi 60s |
| 4.3 | Lúc ~00:15 phụ huynh xem thời gian đã dùng hôm nay | Tăng đều theo thời gian dùng thật từ 00:00, không đứng ở vài phút |

Báo kết quả trong vòng 1 giờ sau khi test để còn kéo được log Vercel (gói Hobby chỉ giữ 1 giờ).

## Bước 5 — Hạn mức 0 phút / giảm dần: heartbeat không làm nhảy đồng hồ (PR #351, báo cáo 11/11)

Lỗi cũ: phụ huynh đặt hạn mức **0 phút** rồi duyệt thêm giờ → `today-limit` trả đúng (vd 158s) nhưng mỗi heartbeat
trả ~7298s (server đọc 0 thành 120 phút) → đồng hồ nhảy lên ~2 tiếng. Cần APK máy trẻ bất kỳ từ `develop` (bản sửa
chỉ ở server). Logcat lọc `📊|💓|HEARTBEAT|Drift`.

| # | Thao tác | Mong đợi |
|---|----------|----------|
| 5.1 | Phụ huynh đặt hạn mức **hôm nay = 0 phút**, lưu | Máy trẻ khoá (hết giờ) |
| 5.2 | Trẻ xin thêm 15 phút, phụ huynh duyệt | Máy trẻ mở, đồng hồ còn ~15 phút |
| 5.3 | Để app trẻ chạy ≥ 3 phút (≥ 3 lần heartbeat) | Logcat: `💓 [HEARTBEAT] ping successful. server=Ns` với N ≈ số giây còn lại trên màn hình (lệch ≤ 60s); **không** có dòng `Drift … detected` với số lớn hàng nghìn giây |
| 5.4 | Nhìn đồng hồ trong suốt 5.3 | Giảm đều, không nhảy lên ~2 tiếng |

Ghi lại giờ làm 5.3 để Khánh kéo log Vercel (`getTodayLimit` phải khớp heartbeat). Trường hợp "giảm dần" cũng
được sửa cùng PR nhưng app mobile chưa có nút bật giảm dần → chỉ kiểm bằng unit test `backend/tests/unit/dailyLimit.test.js`.

