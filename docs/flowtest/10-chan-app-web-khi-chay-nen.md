# Luồng 10 — Chặn app / lọc web khi app trẻ đang chạy nền (sửa lỗi test 05/11)

**Báo cáo gốc:** "Báo cáo các lỗi phát sinh" (05/11), Luồng 09 Bước 1 mục 3 và 6: chặn app và
lọc web không có tác dụng, trẻ vẫn dùng app/web bình thường.

**Nguyên nhân thật (đọc từ `logs_screen.txt`):** nhận diện và khoá không hề chạy, vì máy trẻ
**chưa bao giờ nhận được danh sách chặn**:
- Lúc mở app, log ghi `Synced 0 blocked apps` / `Synced 0 blocked domains`, tức danh sách còn rỗng.
- Phụ huynh thêm app/web bị chặn → server gửi push FCM → app trẻ đang chạy nền nên văng
  `NoSuchMethodError: No top-level getter '_firebaseMessagingBackgroundHandler'` (xuất hiện 14 lần trong log).
  PR #333 vô tình làm lệch annotation `@pragma('vm:entry-point')` khỏi hàm xử lý push nền.
- Phần chặn native (`performGlobalAction(HOME)` qua Accessibility) đã có sẵn, nên KHÔNG cần
  overlay/SYSTEM_ALERT_WINDOW như báo cáo đề xuất. Danh sách rỗng thì không có gì để chặn.

**Đã sửa:** annotation đặt lại đúng chỗ, có test chặn tái phát. Thêm lưới an toàn: app trẻ tự lấy lại
danh sách chặn mỗi lần quay lại app và mỗi 5 phút, nên dù lỡ push thì chậm nhất ~5 phút vẫn chặn được.

Nhánh: **`develop`** (pull mới nhất — đã gồm PR #334 sửa lỗi này và #335 tăng tốc backend). **Build lại APK**,
cài lại trên máy trẻ. Bật đủ quyền: Accessibility (KidFun), Usage Access, Thông báo. Thời gian: ~25 phút + để máy
chạy nhiều ngày (Bước 6).

> **Trước khi bắt đầu:** nhắn Khánh "bắt đầu test luồng 10" kèm giờ bắt đầu. Server chỉ giữ log 1 giờ — Khánh cần
> đọc log trong lúc bạn test để đo tốc độ API (Bước 5).

## Bước 1 — Push nền không còn văng lỗi

1. Mở app trẻ, chờ dashboard hiện, rồi bấm Home (app chạy nền).
2. Trên máy phụ huynh: chặn 1 app có trên máy trẻ (vd. Chrome hoặc Calculator).
3. Xem Logcat máy trẻ (lọc `flutter`):
   - [ ] **KHÔNG** còn dòng `No top-level getter '_firebaseMessagingBackgroundHandler'`
   - [ ] Có dòng `[FCM] 🚫 Updated blocked apps in background: 1 packages`

## Bước 2 — Chặn app

1. Máy trẻ mở app vừa bị chặn.
   - [ ] Bị đẩy về màn hình chính ngay (trong ~1 giây)
   - [ ] Mở lại nhiều lần đều bị đẩy về
2. Phụ huynh bỏ chặn app đó, chờ ~10 giây.
   - [ ] Máy trẻ mở app bình thường

## Bước 3 — Lọc web

1. App trẻ chạy nền. Phụ huynh thêm tên miền cấm (vd. `facebook.com`) hoặc bật một danh mục.
2. Logcat máy trẻ:
   - [ ] Có `[FCM] 🌐 Policy synced after policy_update`, không có lỗi `NoSuchMethodError`
3. Máy trẻ mở **Chrome**, gõ `facebook.com`.
   - [ ] Có thông báo "🚫 Trang web bị chặn" **và** Chrome bị đẩy về màn hình chính

## Bước 4 — Lưới an toàn (không có push)

1. Bật chế độ máy bay trên máy trẻ. Phụ huynh chặn thêm 1 app khác.
2. Tắt chế độ máy bay trên máy trẻ, mở KidFun một lần rồi bấm Home.
   - [ ] Log có `Synced 1 blocked apps` (hoặc số tương ứng) ngay sau `App resumed`
   - [ ] Mở app đó thì bị đẩy về màn hình chính

## Bước 5 — Tốc độ phản hồi (backend đã chuyển sang máy chủ Sydney, PR #335)

Không cần làm gì thêm ngoài dùng app bình thường trong lúc test Bước 1–4; Khánh đo trên log server.
Ghi lại cảm nhận:
1. Máy trẻ: mở KidFun → màn đồng hồ đếm ngược hiện số phút còn lại sau khoảng bao lâu?
   - [ ] Dưới ~2 giây   - [ ] 2–5 giây   - [ ] Trên 5 giây (ghi số giây: ___)
2. Máy phụ huynh: mở trang chi tiết của bé → dữ liệu hiện sau khoảng bao lâu? (ghi số giây: ___)

## Bước 6 — Để máy trẻ thu dữ liệu cho đồ án (7–14 ngày)

Tác vụ ban đêm của đồ án (21:05 mỗi tối) chỉ tính mức thường ngày và dự đoán cho trẻ có **≥ 7 ngày** dữ liệu
(phát hiện bất thường tầng 2 cần **≥ 14 ngày**). Hiện chưa trẻ nào đủ.
1. Giữ app KidFun trên máy trẻ **đã liên kết, đã cấp Usage Access**, không gỡ cài đặt, không xoá dữ liệu app.
2. Tắt tối ưu pin cho KidFun (Cài đặt → Pin → KidFun → Không hạn chế) để app không bị hệ thống tắt.
3. Dùng máy như bình thường (YouTube, game, học…) mỗi ngày.
   - [ ] Đã để máy chạy liên tục, ghi ngày bắt đầu: ___
   - [ ] Báo Khánh nếu phải gỡ app / đổi máy / reset (dữ liệu sẽ bắt đầu lại từ đầu)

## Gửi lại

- Tick từng ô ở trên (Bước 6 báo ngày bắt đầu là đủ, không cần chờ hết 14 ngày). Ô nào fail thì gửi kèm **toàn bộ** Logcat (lọc `flutter` + `AppBlocker`)
  từ lúc phụ huynh bấm chặn đến lúc mở app/web.
- Nếu vẫn thấy "thông báo nhưng không chặn": chụp màn hình thông báo đó, ghi rõ tiêu đề và
  máy nào hiện (máy trẻ hay máy phụ huynh).
