# Luồng 16 — Hồi quy sau đợt thay đổi 16/11 (gỡ Socket.IO + nhãn "dùng hết giờ")

Cần **APK mới cho cả máy trẻ lẫn máy phụ huynh** build từ `develop` (từ commit `1abb3ef` trở đi). Làm cùng buổi với
[Luồng 15](15-youtube-ten-kenh-handle.md) (YouTube @handle) vì dùng chung APK máy trẻ. Thời gian ~30 phút.

> **Nếu đang đo pin ở [Luồng 14](14-do-tre-canh-bao-va-pin.md) phần B:** đo xong lần đo đang chạy rồi mới cài APK mới —
> cài bản khác giữa chừng làm sai số đo. Phần A (độ trễ cảnh báo) làm tiếp bằng APK mới được.

## Bước 1 — Gỡ Socket.IO không làm hỏng luồng cũ (PR #366)

App không còn thư viện Socket.IO (đã không chạy từ PR #333). Các chỗ từng gọi nó: đăng nhập/đăng xuất phụ huynh, ghép
nối máy trẻ, app ra nền/vào lại, gỡ liên kết. Mỗi mục chỉ cần chạy như bình thường:

| # | Làm | Mong đợi |
|---|---|---|
| 1.1 | Máy phụ huynh: đăng xuất rồi đăng nhập lại | Vào được trang chủ, danh sách bé hiện đủ; không văng app |
| 1.2 | Máy phụ huynh: tắt hẳn app (vuốt khỏi đa nhiệm), mở lại | Vẫn đăng nhập, dữ liệu tải lại bình thường |
| 1.3 | Máy trẻ: gỡ liên kết (nếu cần) rồi **quét QR ghép nối lại** | Ghép thành công, vào màn đồng hồ đếm ngược |
| 1.4 | Máy trẻ: bấm Home 2 phút rồi mở lại KidFun | Đồng hồ chạy đúng, không văng, không đòi ghép lại |
| 1.5 | Máy phụ huynh: đổi giới hạn hôm nay của bé | Máy trẻ cập nhật trong ~10 giây (như trước) |
| 1.6 | Máy phụ huynh: bấm **yêu cầu vị trí** của bé | Vị trí mới hiện trên bản đồ (đi qua FCM, không qua Socket.IO) |
| 1.7 | Máy phụ huynh: **Xoá thiết bị** của bé | Máy trẻ tự về màn ghép nối trong ~1 phút |

- [ ] Logcat máy trẻ/phụ huynh **không** còn dòng nào bắt đầu bằng `[SOCKET]` (trước đây in liên tục).
- [ ] Không có lỗi đỏ mới trong Logcat khi làm 1.1–1.7.

## Bước 2 — Thẻ "Ngày mai" ghi "Khả năng dùng hết giờ" (PR #372)

Từ 16/11, M1 không đoán "vượt giới hạn" nữa (máy bị chặn khi hết giờ nên "vượt" chỉ xảy ra khi xin thêm giờ được
duyệt) mà đoán **"dùng hết giờ"** (dùng tới sát giới hạn, trong vòng 5 phút). Server chỉ tạo cảnh báo khi khả năng
**≥ 80%** (trước là 60%).

Khánh gửi 2 dự đoán thử (lệnh ở cuối file), cho 2 bé khác nhau:

| # | Dự đoán thử | Mong đợi trên màn AI Insights của bé đó |
|---|---|---|
| 2.1 | bé A: 95 phút, giới hạn 120, khả năng **0,72** | Dòng **"Khả năng dùng hết giờ: 72%"** màu **vàng/cam**; **không** có thông báo đẩy mới |
| 2.2 | bé B: 115 phút, giới hạn 120, khả năng **0,85** | **"Khả năng dùng hết giờ: 85%"** màu **đỏ**; có **thông báo đẩy** |
| 2.3 | Mở thông báo của 2.2 | Câu dạng: "Dự đoán ngày …: bé dùng khoảng 1 giờ 55 phút, **85% khả năng dùng hết giờ (giới hạn 2 giờ)**." — không còn chữ "vượt giới hạn" |
| 2.4 | Bé có khả năng dưới 50% (nếu có sẵn, hoặc Khánh gửi 0,3) | Màu **xanh** |

- [ ] Không còn chỗ nào trên màn AI Insights ghi "Khả năng vượt giới hạn".

## Bước 3 — Sáng hôm sau: tác vụ ban đêm chạy gói mới (Khánh kiểm tra log)

- [ ] Log `thesis-nightly` có `dự đoán M1 (xgb_rel+xgb_hit_platt@2026-11-16)`, không có `BundleError`.
- [ ] Số trẻ "đã tính" ở M1 không ít hơn hôm trước (trẻ không dùng máy cả ngày nhưng hôm trước có dùng vẫn được dự đoán).
- [ ] Ghi lại số "cảnh báo mới" của M1 (có thể vẫn ít: trẻ thật bắt đầu tháng 10–11, mùa ít dùng hết giờ — đúng thiết kế).

## Dành cho Khánh — gửi dự đoán thử

Xoá cảnh báo thử sau khi test nếu cần. `modelVersion` đặt `flowtest-16` để phân biệt.

```bash
TOMORROW=$(TZ=Asia/Ho_Chi_Minh date -d tomorrow +%F)
curl -s -X POST https://kidfun-backend.vercel.app/api/cron/behavior-results \
  -H "Authorization: Bearer $CRON_SECRET" -H 'Content-Type: application/json' \
  -d "{\"modelVersion\":\"flowtest-16\",\"predictions\":[
       {\"profileId\":<ID_BE_A>,\"date\":\"$TOMORROW\",\"predictedMinutes\":95,\"pOverLimit\":0.72,\"limitMinutes\":120},
       {\"profileId\":<ID_BE_B>,\"date\":\"$TOMORROW\",\"predictedMinutes\":115,\"pOverLimit\":0.85,\"limitMinutes\":120}]}"
```

Kết quả mong đợi: `"predictions":2,"alertsCreated":1` (chỉ bé B).

## Ghi chép

- Mã commit APK: `git rev-parse --short HEAD` →
- Máy / Android (trẻ, phụ huynh):
- Bước không đạt (dùng mẫu báo lỗi trong README):
