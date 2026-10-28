# 2026-10-28 — Đồng hồ đếm ngược app trẻ: "Đã dùng" lệch, server ngừng đếm sau 00:00

**Trạng thái:** ĐÃ SỬA — PR #321 (merge `0b47e0f`), người test xác nhận 2026-10-29 bằng `docs/flowtest/05-dong-ho-dem-nguoc.md`.

## Triệu chứng (báo cáo của người test)

1. Phụ huynh đổi hạn mức hoặc duyệt xin thêm giờ → "Đã dùng" trên app trẻ thay đổi theo, đồng hồ lệch dần qua mỗi lần đổi.
2. Tắt màn hình lúc đang mở app trẻ vẫn bị trừ giờ; ra Home / chuyển app thì như "ngưng đếm".

## Bằng chứng (log Vercel, thiết bị `CP31.260623.012`, profile 20, test 23:59 → 00:30 giờ VN)

- Cùng một response `GET /api/child/today-limit` có `limitMinutes` mới nhưng `remainingSeconds` cũ:
  `limitMinutes=245` mà `remainingSeconds=18282` (≈ 305 phút — hạn mức trước đó).
- Mỗi lần phụ huynh lưu hạn mức có **7–8 request `today-limit` gần như cùng lúc**, mỗi cái 2–8 giây.
- Phiên tạo lúc 23:59:37 VN; sau 00:00 **mọi `POST /api/child/session/resume` đều 404** và **không còn heartbeat nào** sau lần pause đầu tiên.

## Nguyên nhân gốc

| # | Nguyên nhân | Hậu quả |
|---|---|---|
| 1 | `calcRemaining()` cache kết quả 30s **trong bộ nhớ**. Vercel chạy nhiều instance; `clearCache()` lúc lưu hạn mức chỉ xoá instance xử lý request đó. | Instance khác trả `remainingSeconds` cũ ghép với `limitMinutes` mới. App tính `Đã dùng = limitMinutes*60 − remainingSeconds` → nhảy sai, có lúc âm. |
| 2 | Lưu hạn mức sửa 7 hàng `TimeLimit` (7 ngày) → Supabase Realtime bắn 7 event → app gọi `_fetchAndApplyNewLimit()` 7 lần. | Response về không theo thứ tự; app áp cái về sau cùng, có thể là số cũ. |
| 3 | Qua 00:00 VN, `calcRemaining()` đóng phiên bắt đầu từ hôm trước. `resumeSession` không thấy phiên ACTIVE → 404. Nhánh lỗi resume ở app không bật lại heartbeat. | Không UsageLog mới nào được mở → server ngừng đếm hẳn. App tính lại từ `_endTime` cũ nên thời gian tắt màn hình bị trừ. Khi phụ huynh đổi hạn mức, app lấy số server (đứng yên) → "Đã dùng" tụt. |

Ghi chú: người test hay test quanh 00:00 giờ VN (24/10, 25/10, 28/10) — lỗi nào "khó hiểu" thì nghĩ tới mốc ngày trước.

## Cách sửa (PR #321)

- `backend/src/controllers/childController.js`
  - `calcRemaining()`: bỏ cache; trả thêm `usedSeconds`.
  - `getTodayLimit`: `remainingSeconds = max(0, limitMinutes*60 − usedSeconds)` — luôn khớp với `limitMinutes` trả về (kể cả khi bật giảm dần).
  - `resumeSession`: không còn phiên ACTIVE thì tạo phiên mới thay vì 404.
- `mobile/lib/features/device/screens/child_dashboard_screen.dart`
  - `_onRealtimeTimeLimitUpdated`: debounce 1.5s (`_limitRefetchDebounce`).
  - `_fetchAndApplyNewLimit`: số thứ tự `_limitFetchSeq`, bỏ response của lần gọi cũ.
  - `_resumeFromScreenOn` nhánh `catch`: gọi lại `_startHeartbeat()`.

## Kiểm tra lại khi nghi tái phát

1. Chạy `docs/flowtest/05-dong-ho-dem-nguoc.md` (bước 4 phải test qua 00:00).
2. Kéo log Vercel **trong vòng 1 giờ** (gói Hobby chỉ giữ 1 giờ):
   - query `getTodayLimit: deviceCode` → kiểm tra `limitMinutes*60 − remainingSeconds ≈ usedMinutes*60`.
   - query `/api/child/session` → `resume` phải 200, heartbeat đều 60s sau mỗi `pause/resume`.
3. Logcat app trẻ lọc `📊|💓|SCREEN|PAUSE|RESUME|Realtime`: mỗi lần lưu hạn mức chỉ 1 dòng `📊 [_fetchAndApplyNewLimit]`.

## Đừng làm lại

- **Đừng thêm cache in-memory** cho số liệu thời gian (hoặc bất cứ thứ gì cần nhất quán giữa các request) trên Vercel — mỗi instance một bản. Cần cache thì dùng store dùng chung.
- Đừng để app tự tính "Đã dùng" từ hai số lấy ở hai thời điểm khác nhau.
- Mọi nhánh lỗi dừng heartbeat/pause phải có đường bật lại.

## Còn treo (chưa sửa, không do PR #321)

- `POST /api/child/session/end` trả **400** (thấy lúc 17:27 và 18:33 UTC ngày 28/10) — có thể app gửi thiếu `sessionId` hợp lệ khi hết giờ (`_onTimeUp`). Chưa thấy ảnh hưởng vì `startSession` tự đóng phiên cũ.
- `GET /api/cron/daily-reports` **timeout 60s** (17:53 UTC ngày 28/10) — báo cáo ngày có thể không được tạo.
- Các `clearCache('remaining_…')` trong `profileController.js`, `extensionController.js`, `childController.js` giờ không còn tác dụng (không còn gì để xoá) — có thể dọn.
