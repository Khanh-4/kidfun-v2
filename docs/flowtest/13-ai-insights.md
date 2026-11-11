# Flowtest 13 — Màn AI Insights (đồ án chuyên ngành, T7.5)

**Cần:** APK phụ huynh build từ `develop` sau PR T7.5. Một hồ sơ trẻ **đã có** máy trẻ chạy KidFun vài ngày
(để có heatmap) và một hồ sơ **mới** (để xem trạng thái rỗng).

## Bước 1 — Mở màn

| # | Làm | Mong đợi |
|---|---|---|
| 1.1 | Danh sách hồ sơ → bấm biểu tượng biểu đồ tím (tooltip "AI Insights") cạnh nút cảnh báo hành vi | Mở màn "AI Insights · <tên bé>" |
| 1.2 | Kéo xuống để làm mới | Không lỗi, dữ liệu tải lại |
| 1.3 | Tắt mạng rồi mở lại màn | Hiện "Không tải được dữ liệu…" + nút **Thử lại**; bật mạng, bấm Thử lại → tải được |

## Bước 2 — Trạng thái rỗng (hồ sơ mới / chưa đủ 7 ngày)

| # | Làm | Mong đợi |
|---|---|---|
| 2.1 | Mở AI Insights của hồ sơ chưa có dữ liệu | Thẻ "Ngày mai": "Cần thêm 7 ngày dữ liệu… (đã có 0/7 ngày)"; "Thói quen theo giờ": "Chưa có dữ liệu sử dụng theo giờ." |
| 2.2 | Hồ sơ có máy trẻ chạy được 2–6 ngày | "Cần thêm N ngày" với N = 7 − số ngày đã có; heatmap có vài ô tô màu |

## Bước 3 — Heatmap

| # | Làm | Mong đợi |
|---|---|---|
| 3.1 | Hồ sơ có dữ liệu: nhìn lưới 7 hàng (T2…CN) × 24 cột | Ô đậm ở đúng khung giờ bé hay dùng (giờ VN), ô xám = không dùng |
| 3.2 | Nhấn giữ một ô tô màu | Hiện "T? Xh: N phút" |
| 3.3 | Đọc dòng chú thích dưới lưới | "Trung bình mỗi tuần trong 4 tuần gần nhất · ô đậm nhất ≈ N phút/giờ" |

## Bước 4 — Thẻ "Ngày mai" (Khánh gửi dự đoán thử, xem cuối file)

| # | Làm | Mong đợi |
|---|---|---|
| 4.1 | Sau khi Khánh gửi dự đoán, làm mới màn | Thẻ hiện "1 giờ 35 phút / giới hạn 2 giờ", "Khả năng vượt giới hạn: 72%" màu đỏ, câu giải thích bắt đầu "[Thử nghiệm]" |
| 4.2 | Hồ sơ đủ ≥ 7 ngày nhưng chưa có dự đoán | "Dự đoán cho ngày mai sẽ có sau khi hệ thống phân tích lúc 21:00 tối nay." |

**Gửi kết quả:** bảng ✅/❌ theo mã bước, kèm ảnh chụp màn hình bước 2.1, 3.1, 4.1.

---

### Dành cho Khánh — gửi dự đoán thử

`pOverLimit` 0,72 ≥ 0,6 nên server cũng tạo thêm một cảnh báo M1 kèm thông báo (xoá sau khi test nếu cần):

```bash
TOMORROW=$(TZ=Asia/Ho_Chi_Minh date -d tomorrow +%F)
curl -s -X POST https://kidfun-backend.vercel.app/api/cron/behavior-results \
  -H "Authorization: Bearer $CRON_SECRET" -H 'Content-Type: application/json' \
  -d "{\"modelVersion\":\"flowtest-13\",\"predictions\":[{\"profileId\":<ID>,\"date\":\"$TOMORROW\",
       \"predictedMinutes\":95,\"pOverLimit\":0.72,\"limitMinutes\":120,
       \"message\":\"[Thử nghiệm] Ngày mai bé có thể dùng khoảng 1 giờ 35 phút, nhiều nhất vào buổi tối.\"}]}"
```

Tác vụ ban đêm thật sẽ ghi đè dòng này (cùng `profileId` + ngày) khi bé đủ 7 ngày dữ liệu.
