# Đồ án chuyên ngành — Tuần 1: EDA bộ dữ liệu StudentLife và so sánh với LSApp

> Số liệu chi tiết: `ml/reports/studentlife_eda.md` (sinh lại bằng `ml/eda/studentlife_eda.py`).
> Nguồn: bản RDS trên Zenodo (record 3529253, CC-BY-4.0) của dataset gốc https://studentlife.cs.dartmouth.edu
> — trang gốc không truy cập được ngày 16/10/2026.

## 1. Dữ liệu thật sự có gì

| Bảng | Nội dung thật | Hệ quả |
|---|---|---|
| `other/app_usage` | **Ảnh chụp** danh sách task đang chạy, đúng **20 phút/lần** (200.767 ảnh) | Không đo được số phút dùng app; chỉ biết app trên cùng tại thời điểm chụp |
| `sensing/phonelock` | Chỉ các lần khoá máy **≥ 60 phút** (9.275 lần) | Không suy ra thời gian màn hình chính xác; dùng tốt làm tín hiệu **ngủ/nghỉ** |

- 40% ảnh chụp có app trên cùng là **app thu thập dữ liệu của nghiên cứu** (`paco`), cộng launcher/hệ thống/khoá máy dài → **84,8% ảnh chụp bị loại**.
- "Chỉ số hoạt động" (ảnh chụp còn lại × 20 phút) ≈ 220 phút/ngày — **thiên cao** (khoảng tắt màn hình ngắn < 60 phút vẫn bị tính), chỉ dùng để so sánh tương đối (ngày thường/cuối tuần, theo giờ), **không** dùng như số phút thật.
- Điểm mạnh so với LSApp: **mỗi người trung vị 60 ngày hợp lệ** (min 22, max 90) và dấu thời gian Unix + địa điểm biết trước → đổi chính xác sang giờ địa phương (America/New_York).
- PDF mô tả trước đây ghi StudentLife có "khoá/mở màn hình và lịch sử dùng ứng dụng" — chưa chính xác, **đã sửa ở PDF bản 2.1**.

## 2. Kết quả chính và so sánh với LSApp

| Chỉ số | LSApp (người lớn) | StudentLife (sinh viên) |
|---|---|---|
| Ngày dữ liệu / người (trung vị) | 5 | **60** |
| Múi giờ dấu thời gian | không rõ | rõ (America/New_York) |
| Cuối tuần so với ngày thường | +1% | **−7%** (chỉ số hoạt động) |
| Tự tương quan trễ 7 ngày (trung vị) | 0,04 | **0,16** |
| Tự tương quan trễ 1 ngày (trung vị) | 0,06 | 0,20 |
| Tỷ lệ hoạt động trong 22:00–06:00 | 37,9% (giờ không rõ múi) | **29,3%** (giờ địa phương thật) |
| Giờ đi ngủ ước lượng (trung vị) | — | 01:48 đêm thường; **02:18** đêm thứ Sáu/thứ Bảy |
| Mô hình cơ sở tốt nhất | MA7 | MA7 (seasonal naive vẫn kém nhất) |

## 3. Hệ quả cho thiết kế

1. **Chu kỳ tuần có thật nhưng yếu ở sinh viên** (trễ 7 ngày 0,16; đi ngủ muộn hơn ~30 phút đêm cuối tuần) và gần như không có ở người lớn. Trẻ em có lịch học cố định nên kỳ vọng chu kỳ mạnh hơn (khảo sát VN: tỷ lệ dùng 3–4 giờ/ngày từ ~1% lên 7–9% cuối tuần). → Bộ sinh dữ liệu mô phỏng phải **tham số hoá rõ độ mạnh chu kỳ tuần**, và thực nghiệm M1 nên chạy ở nhiều mức (yếu như StudentLife → mạnh như kỳ vọng ở trẻ) để thấy khi nào đặc trưng "thứ trong tuần" có ích.
2. **Seasonal naive (bằng cùng thứ tuần trước) thua MA7 trên cả hai bộ** → đúng như lo ngại "mô hình phức tạp chưa chắc hơn mô hình đơn giản" (RQ1). MA7 là mốc cần vượt.
3. **Dùng máy lúc khuya là chuyện phổ biến ở sinh viên** (29% hoạt động trong 22:00–06:00, đi ngủ quanh 2 giờ sáng). Với trẻ em, ngưỡng "khuya" của tầng 1 phải theo **cài đặt của phụ huynh** hoặc giờ ngủ thường lệ của chính trẻ, không dùng một ngưỡng chung lấy từ dữ liệu người lớn/sinh viên.
4. **Tín hiệu khoá máy dài ≈ giờ ngủ** là đặc trưng đáng thêm cho M2: "trẻ mở máy giữa khoảng ngủ thường lệ" là một kiểu bất thường dễ giải thích cho phụ huynh. App KidFun có thể suy ra từ sự kiện `SCREEN_NON_INTERACTIVE` đã thu (khoảng tắt màn hình dài nhất trong đêm).
5. Không có bộ công khai nào đo được **số phút dùng thật theo giờ** cho đúng đối tượng trẻ em → càng khẳng định giá trị của bộ thu thập theo giờ trong KidFun và bộ sinh mô phỏng.
