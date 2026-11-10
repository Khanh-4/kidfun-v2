# Luồng 12 — Xin thêm giờ: kết quả về máy trẻ, không nhận nhầm thông báo (sửa lỗi test 10/11)

**Báo cáo gốc:** "Máy trẻ không nhận được kết quả phê duyệt/từ chối xin thêm giờ và bị nhận nhầm
Push Notification" (10/11).

**Nguyên nhân (đã chẩn đoán từ log Vercel):**
1. Máy trẻ đăng ký token FCM dưới tài khoản phụ huynh → mọi thông báo cho phụ huynh (xin thêm giờ,
   SOS, cảnh báo hết giờ, cảnh báo AI) cũng tới máy trẻ.
2. Duyệt/từ chối chỉ báo máy trẻ qua Socket.IO (không chạy trên Vercel) và kênh Realtime hay rớt:
   phụ huynh duyệt 4 lần, máy trẻ chỉ biết 1 lần.
3. Máy trẻ đã dùng 688 phút trong khi hạn mức 465 phút → duyệt +15 phút vẫn còn 0, máy vẫn khoá.
   Nay: duyệt khi trẻ đã hết giờ = **"+15 phút kể từ lúc duyệt"**.

Nhánh: `develop` (pull mới nhất). **Phải build lại APK** và cài lại trên **cả hai máy**.
Thời gian: ~20 phút. Đã liên kết máy trẻ (Luồng 00). Nên đặt hạn mức hôm nay thấp (vd. 5 phút) để
nhanh hết giờ.

> Sau mỗi bước, nếu sai: chụp màn hình + ghi giờ, gửi **log Vercel trong vòng 1 giờ** và logcat máy trẻ.

## Bước 1 — Máy trẻ không còn nhận thông báo của phụ huynh

1. Chờ máy trẻ hết giờ (màn hình khoá hiện lên).
2. Trên máy trẻ bấm xin thêm 15 phút.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 1.1 | Máy phụ huynh | Có thông báo "⏳ <tên bé> xin thêm giờ" |
| 1.2 | Máy trẻ | **Không** có thông báo "xin thêm giờ" |
| 1.3 | Log Vercel | Dòng `sendEachForMulticast … (total tokens: 1)` (trước đây là 2) |

## Bước 2 — Duyệt khi trẻ đã hết giờ (app trẻ đang mở)

1. App phụ huynh → duyệt yêu cầu ở Bước 1.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 2.1 | Máy trẻ, trong ~5 giây | Pop-up "✅ Được duyệt! Phụ huynh đã cho thêm 15 phút!" |
| 2.2 | Máy trẻ | Màn hình khoá biến mất, đồng hồ đếm ngược chạy lại từ **~15:00** |
| 2.3 | Log Vercel | `Extension APPROVED: … +15min (granted …min …)` và `extension_response APPROVED gửi 1/1 token` |
| 2.4 | Logcat máy trẻ | `[FCM] ⏳ extension_response (foreground): APPROVED` |
| 2.5 | Logcat máy trẻ | `▶️ [SESSION] Mở lại phiên sau khi gỡ khoá` |
| 2.6 | Log Vercel, 2–3 phút sau khi duyệt | Có `POST /api/child/session/heartbeat`, và dòng `getTodayLimit` có `usedMinutes` **tăng dần** (trước đây đứng yên → mở lại app là lại còn nguyên 15 phút) |

## Bước 3 — Từ chối

1. Chờ hết 15 phút (hoặc phụ huynh hạ hạn mức) → máy trẻ khoá lại → xin thêm giờ.
2. App phụ huynh → từ chối.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 3.1 | Máy trẻ | Pop-up "❌ Bị từ chối", vẫn giữ màn hình khoá |
| 3.2 | Log Vercel | `extension_response REJECTED gửi 1/1 token` |

## Bước 4 — Duyệt lúc app trẻ chạy nền

1. Máy trẻ xin thêm giờ, rồi bấm Home (app trẻ chạy nền, **không** vuốt tắt).
2. App phụ huynh → duyệt.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 4.1 | Logcat máy trẻ | `extension_response forwarded to main isolate` rồi `extension_response (background): APPROVED` |
| 4.2 | Mở lại app trẻ | Không còn khoá, đồng hồ còn ~15 phút, có pop-up "Được duyệt" |

## Bước 5 — Thông báo khác vẫn chỉ tới phụ huynh

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 5.1 | Máy trẻ bấm SOS | Máy phụ huynh có thông báo SOS, máy trẻ **không** |
| 5.2 | Cảnh báo sắp hết giờ / hết giờ | Chỉ máy phụ huynh nhận |
| 5.3 | Yêu cầu vị trí, chặn app (Luồng 10) | Vẫn tới máy trẻ như trước |

## Gửi lại

Bảng kết quả từng mục (đạt / không đạt + ảnh), log Vercel và logcat máy trẻ nếu có mục không đạt.
