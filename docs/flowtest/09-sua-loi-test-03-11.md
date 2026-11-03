# Luồng 09 — Kiểm tra lại 5 lỗi báo cáo ngày 03/11

**Báo cáo gốc:** "Báo cáo các lỗi phát sinh" (03/11) — 5 lỗi: qua ngày vẫn khoá, khởi động lại bị
reset bộ đếm, chặn app không áp dụng, lọc web không áp dụng, vị trí báo "máy bé chưa đăng ký nhận lệnh".

**Nguyên nhân chung (đã sửa trong PR #333):** máy trẻ chưa bao giờ đăng ký nhận lệnh FCM với server,
còn đường Socket.IO cũ đã chết từ khi lên Vercel → mọi lệnh từ phụ huynh xuống máy trẻ không tới.
Ngoài ra app trẻ giữ cờ "đang khoá" từ hôm trước và đếm cả thời gian tắt máy.

**Thay đổi quan trọng cần biết:** ngày mới (hạn mức tổng **và** giới hạn từng app) bắt đầu lúc
**06:00 sáng** giờ VN, không phải 00:00.

Nhánh: `develop` (pull mới nhất). **Phải build lại APK** (có sửa Kotlin), cài lại trên máy trẻ.
Thời gian: ~40 phút + 1 lần kiểm tra sáng hôm sau. Đã liên kết máy trẻ với phụ huynh (Luồng 00).

> Sau mỗi bước, nếu sai: chụp màn hình + ghi giờ, gửi **log Vercel trong vòng 1 giờ** (Vercel chỉ giữ 1 giờ).

## Bước 1 — Máy trẻ đăng ký nhận lệnh (gốc của lỗi 3, 4, 5)

1. Mở app trẻ, chờ màn hình "Đang giám sát".

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 1.1 | Log Vercel | Có dòng `POST /api/child/fcm-token 200` |

## Bước 2 — Vị trí hiện tại

1. App phụ huynh → Vị trí hiện tại → bấm yêu cầu cập nhật vị trí.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 2.1 | Thông báo "Máy của bé chưa đăng ký nhận lệnh" | **Không** còn xuất hiện |
| 2.2 | Log Vercel | `POST /api/profiles/.../location/request 200` (không còn 409), sau đó `POST /api/child/location 201` |
| 2.3 | Bản đồ | Cập nhật vị trí máy trẻ trong ~30 giây |
| 2.4 | Lặp lại khi app trẻ chạy nền (bấm Home trên máy trẻ) | Vẫn cập nhật được |

## Bước 3 — Chặn ứng dụng

1. App phụ huynh → Chặn ứng dụng → chặn 1 app (vd. Chrome).
2. Trên máy trẻ mở app đó. Sau đó bỏ chặn → mở lại.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 3.1 | Mở app bị chặn | Bị chặn ngay, không cần khởi động lại app trẻ |
| 3.2 | Sau khi bỏ chặn | Mở được bình thường |
| 3.3 | Lặp 3.1 khi app trẻ chạy nền | Vẫn bị chặn |

## Bước 4 — Lọc web

1. App phụ huynh → Lọc web → bật chặn 1 danh mục; thêm 1 tên miền (vd. `example.com`).
2. Trên máy trẻ mở trình duyệt vào trang thuộc danh mục / tên miền đó.
3. Tắt danh mục, xoá tên miền → thử lại.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 4.1 | Log Vercel khi phụ huynh lưu | `🌐 [WEBFILTER] policy_update gửi 1/1 token` |
| 4.2 | Log Vercel ngay sau đó | Máy trẻ gọi `GET /api/child/policy` |
| 4.3 | Vào trang bị chặn | Bị chặn, **không cần khởi động lại app trẻ** |
| 4.4 | Sau khi gỡ chặn | Vào được |
| 4.5 | Log Vercel cả buổi test | **Không còn** `GET /socket.io ... 404` |

## Bước 5 — Khởi động lại máy trẻ không làm sai bộ đếm

1. Ghi lại thời gian còn lại trên app trẻ (vd. 2:10:00).
2. Tắt nguồn máy trẻ, **chờ 15 phút**, bật lại, để app tự mở.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 5.1 | Thời gian còn lại sau khi bật | Gần bằng số đã ghi (lệch ≤ 2 phút) — **không** bị trừ 15 phút tắt máy |
| 5.2 | | **Không** nhảy về đầy hạn mức (giới hạn + giờ xin thêm) |
| 5.3 | Đếm tiếp 2–3 phút | Giảm đều, không nhảy số |

## Bước 6 — Giới hạn từng app reset lúc 06:00

1. App phụ huynh → Giới hạn ứng dụng → đặt 1 app = 5 phút.
2. Buổi tối, trên máy trẻ dùng app đó đến khi bị chặn.
3. Mở lại app đó sau 00:00, rồi sau 06:00 sáng.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 6.1 | Dùng hết 5 phút | Bị chặn |
| 6.2 | Sau 00:00 (trước 06:00) | **Vẫn bị chặn** |
| 6.3 | Sau 06:00 | Dùng lại được 5 phút mới |

## Bước 7 — Hết giờ hôm trước, sáng hôm sau tự mở khoá (lỗi 1)

1. Buổi tối, để máy trẻ dùng hết giới hạn → máy bị khoá. **Không** xin thêm giờ.
2. Để máy qua đêm (có thể tắt màn hình), sáng hôm sau kiểm tra.

| # | Kiểm tra | Mong đợi |
|---|----------|----------|
| 7.1 | Sau 00:00, trước 06:00 | **Vẫn khoá** |
| 7.2 | Sau 06:00, mở màn hình + mở app trẻ | Tự mở khoá ngay, đếm hạn mức ngày mới |
| 7.3 | Sau 06:00, không đụng máy | Tự mở khoá trong tối đa 5 phút |
| 7.4 | Tắt máy lúc đang khoá buổi tối → bật lại sau 06:00 | Không khoá, đếm hạn mức mới |

## Báo kết quả

Gửi bảng các mục **#** kèm Đạt/Không đạt. Mục không đạt: ảnh chụp + giờ + log Vercel (trong 1 giờ).
Nếu bước 3 hoặc 5 không đạt, gửi thêm logcat máy trẻ:
`adb logcat -v time | grep -E "flutter|KidFun|AppLimit"`
