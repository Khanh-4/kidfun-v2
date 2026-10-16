# Đồ án chuyên ngành — Tuần 1: EDA bộ dữ liệu LSApp và hệ quả cho thiết kế

> Số liệu chi tiết: `ml/reports/lsapp_eda.md` (sinh lại bằng `ml/eda/lsapp_eda.py`, xem `ml/README.md`).
> Ngày chạy: 16/10/2026. Nguồn dữ liệu: https://github.com/aliannejadi/LSApp

## 1. Số liệu chính

| Chỉ số | Giá trị |
|---|---|
| Người tham gia / app / dòng sự kiện | 292 / 87 / 3,66 triệu |
| Khoảng thời gian **toàn bộ nghiên cứu** | 09/2017 → 05/2018 (≈ 8 tháng) |
| Số ngày có dữ liệu **mỗi người** | trung vị **5**, trung bình 10,1, tối đa 126 |
| Người có ≥ 14 ngày dữ liệu (dùng được cho M1) | **67–69** (≥ 28 ngày: 20) |
| Phiên dùng app (Opened→Closed) | 565.929 phiên, trung vị 7 giây |
| Thời gian dùng / ngày | ≈ 157 phút, ngày thường và cuối tuần gần như bằng nhau (+1%) |
| Tự tương quan chuỗi theo ngày (trung vị) | trễ 1 ngày 0,06; trễ 7 ngày 0,04 |
| MAE mô hình cơ sở (walk-forward, 853 lượt) | naive 113 phút; seasonal naive 119 phút; **MA7 90 phút** |

## 2. Phát hiện và hệ quả

### 2.1. "8 tháng" là thời gian thu thập của cả nghiên cứu, không phải của mỗi người
PDF mô tả (bản 2, mục 2.1) ghi "LSApp: 292 người dùng, 8 tháng" — dễ hiểu nhầm là mỗi người có 8 tháng dữ liệu.
Thực tế trung vị chỉ **5 ngày/người**. → **Sửa PDF**: "thu thập trong khoảng 8 tháng; mỗi người trung vị 5 ngày, 67 người có từ 14 ngày trở lên".

### 2.2. M1 không thể huấn luyện mô hình riêng cho từng người trên LSApp
- Chỉ ~67 người đủ 14 ngày, tổng 853 lượt dự đoán hợp lệ → đủ để **so sánh** các mô hình, không đủ để huấn luyện LSTM riêng từng người.
- Hướng làm: **một mô hình chung (global) cho mọi người**, đặc trưng chuẩn hoá theo mức trung bình của chính người đó (vd tỷ lệ so với trung bình 7 ngày gần nhất). Đây cũng là cách phù hợp với KidFun, nơi trẻ mới liên kết chưa có lịch sử.
- Mốc sai số cần vượt: **MA7 ≈ 90 phút** trên mức trung bình ≈ 157 phút/ngày (≈ 57%) — hành vi người lớn biến động rất mạnh giữa các ngày.

### 2.3. Người lớn trong LSApp KHÔNG có chu kỳ tuần
Cuối tuần chỉ hơn ngày thường 1%, tự tương quan trễ 7 ngày ≈ 0 → seasonal naive còn kém naive.
Ngược lại, khảo sát trẻ em Việt Nam [10 trong PDF] cho thấy tỷ lệ dùng 3–4 giờ/ngày tăng từ ~1% (ngày thường) lên 7–9% (cuối tuần).
→ LSApp **không dùng để kiểm chứng tính chu kỳ tuần**; chu kỳ tuần/lịch học phải đến từ **bộ sinh dữ liệu mô phỏng** (hiệu chỉnh theo khảo sát) và dữ liệu thật KidFun. Đây là một luận điểm tốt cho mục "Tính mới" (bộ sinh theo bối cảnh trẻ em VN).

### 2.4. Không biết múi giờ của dấu thời gian → đặc trưng "giờ trong ngày" trên LSApp không tin được
- 37,9% thời gian dùng rơi vào 22:00–06:00 theo giờ ghi trong dữ liệu; giờ ít dùng nhất là 9h, nhiều nhất 20h.
- Nếu dấu thời gian là **UTC** và người tham gia chủ yếu ở Mỹ (UTC−5), thì giờ địa phương thấp nhất ≈ 4h sáng, cao nhất ≈ 15h — hợp lý hơn nhiều. README của bộ dữ liệu không nêu múi giờ → **đây chỉ là giả thuyết**, ghi vào hạn chế.
- → Đánh giá **phát hiện dùng máy lúc khuya (M2, tầng 1)** không dựa trên LSApp; dùng dữ liệu mô phỏng có nhãn + dữ liệu thật KidFun (bảng `AppUsageHourly` lưu giờ UTC rõ ràng, đổi sang giờ VN khi phân tích).
- LSApp vẫn dùng được cho các đặc trưng **không phụ thuộc múi giờ**: tổng theo ngày (ranh giới ngày có thể lệch vài giờ — chấp nhận và nêu rõ), số phiên, độ dài phiên, cơ cấu app.

### 2.5. Phiên rất ngắn
Trung vị 7 giây/phiên (LSApp ghi cả những lần mở/đóng chớp nhoáng khi chuyển app). Đặc trưng "số lần mở" (`launchCount`) trên KidFun đã gộp lần mở lại trong 2 giây; khi so sánh hai nguồn cần lọc phiên < 2–3 giây cho thống nhất.

## 3. Việc cần làm tiếp theo từ EDA
1. Sửa câu mô tả LSApp trong PDF (mục 2.1) theo 2.1 ở trên.
2. Thiết kế M1 theo hướng **mô hình chung, đặc trưng tương đối theo từng người** (2.2).
3. Đưa "chu kỳ tuần / lịch học" thành tham số trọng tâm của bộ sinh dữ liệu mô phỏng (2.3).
4. EDA StudentLife (48 SV, 10 tuần — dài hơn, có thể kiểm tra chu kỳ tuần ở sinh viên) trước khi chốt bộ đặc trưng.
