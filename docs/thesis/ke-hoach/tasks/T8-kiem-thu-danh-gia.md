# T8 — Kiểm thử máy thật và đánh giá cuối (tuần KH 8, tuần lịch 6–7)

**Mục tiêu:** có số liệu thật cho RQ4, kiểm tra lại RQ1–RQ5 trên dữ liệu thật đã thu, và kết luận có kiểm định thống kê.

**Điều kiện bắt đầu:** T7 chạy đầu cuối; dữ liệu thật đã tích luỹ ≥ 2 tuần trên máy test.

## T8.1 Độ trễ cảnh báo tầng 1 (RQ4)

- [ ] T8.1.1 Viết kịch bản: dùng máy lúc 0h–2h sáng và tăng đột biến game buổi chiều, ghi giờ bắt đầu chính xác.
- [ ] T8.1.2 Người test chạy ≥ 5 lần mỗi kịch bản trên ≥ 2 dòng máy (chờ: người test).
- [ ] T8.1.3 Tính độ trễ = giờ phụ huynh nhận FCM − giờ bắt đầu bất thường; so với chấm theo lô (sáng hôm sau).
- [ ] T8.1.4 Đếm precision/recall của luật tầng 1 trên các lần chạy.

## T8.2 Tiêu hao pin (RQ4)

- [ ] T8.2.1 Đo 24h bản mốc `5b0a0b0` (đồng bộ 5 phút/lần) và bản mới (gửi theo đợt + tầng 1), cùng máy, cùng kịch
  bản, theo `docs/flowtest/04-do-pin.md` (chờ: người test).
- [ ] T8.2.2 Bảng so sánh: % pin do app, số lần đánh thức, số request mạng.

## T8.3 Đánh giá trên dữ liệu thật

- [ ] T8.3.1 Xuất dữ liệu thật đã ẩn danh từ production (hỏi Khánh trước khi truy vấn production).
- [ ] T8.3.2 Chạy lại M1 trên dữ liệu thật: MAE so với MA7 (biết trước là ít dữ liệu, báo cáo trung thực).
- [ ] T8.3.3 Chạy lại M2 tầng 2 và tầng 1: số cảnh báo/trẻ/tuần, tỷ lệ phụ huynh xác nhận đúng.
- [ ] T8.3.4 RQ5 trên phản hồi thật: số báo nhầm trước và sau khi nới ngưỡng theo phản hồi.

## T8.4 Kiểm định thống kê

- [ ] T8.4.1 Wilcoxon cặp trên sai số theo từng trẻ (XGBoost so với MA7, LSTM so với MA7), báo cáo p-value.
- [ ] T8.4.2 Khoảng tin cậy bootstrap 95% cho MAE và PR-AUC chính.
- [ ] T8.4.3 Cập nhật bảng ở `docs/thesis/07`, `08` (thêm cột khoảng tin cậy).

## T8.5 Câu giải thích

- [ ] T8.5.1 Chọn 20 câu giải thích (cả đúng và sai), làm phiếu khảo sát ngắn.
- [ ] T8.5.2 Nhờ 5–10 phụ huynh chấm mức dễ hiểu 1–5 và đúng/sai.
- [ ] T8.5.3 Tính tỷ lệ câu đúng và điểm trung bình.

## T8.6 Bàn giao

- [ ] T8.6.1 `docs/thesis/11-danh-gia-cuoi.md`: trả lời RQ1–RQ5 kèm số liệu, hạn chế.
- [ ] T8.6.2 Cập nhật [03-rui-ro-va-ton-dong.md](../03-rui-ro-va-ton-dong.md) và [README](../README.md).
