# Đồ án chuyên ngành — Tuần 6 (phần thực nghiệm): luật tầng 1, vòng phản hồi, M3, M4

> Số liệu: `ml/reports/m2_feedback.md`, `ml/reports/m3_m4.md`. Phần chạy trên hệ thống thật (bảng, API, app trẻ) nằm
> ở hai PR riêng của tuần 6.

## 1. Luật tầng 1 (bản tham chiếu `ml/tier1/rules.py`)

- **JSON mức thường ngày** server gửi xuống máy trẻ (đặc tả 05 mục 2.3): trung vị **9,1 KB**, lớn nhất 16 KB / trẻ.
  Đủ nhỏ để tải mỗi ngày một lần.
- **Luật:**
  - **khuya:** trong khung 22h–6h, dùng ≥ 10 phút, **và trẻ thường không dùng máy giờ đó** (mức thường ngày ≤ 3 phút);
  - **tăng đột biến:** một nhóm app ≥ 3 lần mức thường ngày cùng giờ, cùng loại ngày, và ≥ 20 phút.
- `ml/tier1/test_vectors.json` là bộ ca kiểm thử dùng chung. Bản Kotlin trên app trẻ phải cho đúng kết quả như bản
  Python.

**Phát hiện quan trọng:** luật khuya ban đầu dùng khung **22h cố định**. Với khung này, 92% cảnh báo là báo nhầm, và
97% số báo nhầm rơi vào 22–23h ở trẻ 11–17 tuổi (các em quen ngủ lúc 23h). Khi cá nhân hoá (chỉ báo khi trẻ thường
không dùng máy giờ đó), tỷ lệ báo nhầm giảm còn **42%** mà recall giữ nguyên.

## 2. Vòng phản hồi của phụ huynh (RQ5)

Cách mô phỏng:

- Tầng 1 chạy trên dữ liệu mô phỏng từ 02/03/2026 (26 tuần). Mức thường ngày được tính lại mỗi tuần.
- "Phụ huynh mô phỏng" trả lời 70% số cảnh báo: cảnh báo đúng thì bấm "đúng là bất thường", sai thì bấm "được phép";
  có xác suất bấm nhầm.
- Khi phụ huynh bấm "được phép", ngưỡng của đúng loại ngày (+ nhóm app) được nới (đột biến × 1,25, khuya × 1,5),
  tối đa 2 lần.

| Chính sách | Báo nhầm 4 tuần đầu | Báo nhầm 4 tuần cuối | Cảnh báo / trẻ / tuần (cuối) | Recall |
|---|---|---|---|---|
| Khung khuya cố định | 93% | 92% | 2,02 | 0,83 |
| Khung khuya cố định + phản hồi | 92% | 88% | 1,30 | 0,82 |
| Khuya cá nhân hoá | 42% | 72% | 0,59 | 0,83 |
| **Khuya cá nhân hoá + phản hồi (nhiễu 0%)** | 41% | **51%** | **0,33** | 0,82 |
| Khuya cá nhân hoá + phản hồi (nhiễu 10%) | 41% | 50% | 0,32 | 0,82 |
| Khuya cá nhân hoá + phản hồi (nhiễu 20%) | 41% | 50% | 0,32 | 0,82 |

- **Trả lời RQ5: có.** Phản hồi giảm số cảnh báo khoảng 45% (0,59 → 0,33 / trẻ / tuần) và giảm báo nhầm ở cuối giai
  đoạn (72% → 51%). Recall chỉ mất khoảng 1 điểm (0,83 → 0,82).
- **Không nhạy với việc phụ huynh bấm nhầm** (0–20%), vì mỗi loại ngày + nhóm app chỉ được nới tối đa 2 lần. Một vài lần
  bấm nhầm không làm ngưỡng nới quá đà.
- **Báo nhầm tăng về cuối giai đoạn khi không có phản hồi** (42% → 72%). Đó là mùa hè: ngày nghỉ dài làm thói quen đổi,
  mà mức thường ngày "ngày nghỉ" lúc đầu hè còn ít dữ liệu. Vòng phản hồi giúp hệ thống tự thích nghi với thay đổi này.
- Khung cố định + phản hồi vẫn báo nhầm 88%: phản hồi không thay được việc thiết kế luật đúng ngay từ đầu.

## 3. M3 — nhóm thói quen (K-Means, gọn)

- Mỗi trẻ được biểu diễn bằng 56 chiều: phân bố 24 giờ (ngày học / ngày không học), cơ cấu 5 nhóm app, tỷ lệ dùng khuya,
  tỷ lệ cuối tuần / ngày học, và mức dùng. Dữ liệu năm học, trước 01/06/2026.
- Chọn k = 3 theo silhouette. Silhouette chỉ **0,24**, nghĩa là các nhóm không tách biệt rõ. Độ khớp với nhóm tuổi:
  ARI = 0,34.

| Nhóm | Số trẻ | Đặc điểm nổi bật | Phút/ngày | Nhóm tuổi phổ biến |
|---|---|---|---|---|
| 0 | 33 | hầu như không dùng khuya, ít mạng xã hội | 134 | 6–10 |
| 1 | 32 | hầu như không dùng khuya, dùng ít | 143 | 3–5 |
| 2 | 35 | hay dùng khuya, nghiêng về mạng xã hội | 402 | 15–17 |

Nhận xét: dữ liệu mô phỏng thực chất có 2 kiểu rõ rệt (trẻ nhỏ dùng vừa phải, trẻ lớn dùng nhiều + khuya + mạng xã
hội), nên nhóm 0 và nhóm 1 khá giống nhau. Vai trò của M3 trong ứng dụng: hiển thị heatmap thứ × giờ
(`ml/reports/m3_heatmaps.png`) và cho phụ huynh biết con mình thuộc nhóm thói quen nào. Không dùng M3 để ra quyết định.

## 4. M4 — gợi ý cho phụ huynh (hệ luật, gọn)

Tính trên 28 ngày trước 15/05/2026: **49/100 trẻ** có ít nhất một gợi ý.

| Luật | Số trẻ | Ví dụ câu |
|---|---|---|
| Giảm dần | 20 | "Bé chạm giới hạn 3 giờ 45 phút ở 50% ngày đi học và xin thêm giờ khoảng 4 lần/tuần. Có thể nâng giới hạn ngày đi học lên 4 giờ rồi bật chế độ giảm dần về 3 giờ 45 phút trong 4 tuần…" |
| Đặt giới hạn | 18 | "Bé chưa có giới hạn thời gian. Có thể bắt đầu bằng mức hiện tại (7 giờ 45 phút ngày đi học) rồi giảm dần 10% mỗi tuần." |
| WHO (3–5 tuổi) | 10 | "Bé đang dùng khoảng 1 giờ 45 phút/ngày. WHO khuyến nghị trẻ 2–4 tuổi dùng màn hình không quá 1 giờ/ngày…" |
| Giới hạn game | 3 | "Game chiếm 51% thời gian dùng máy. Có thể đặt giới hạn riêng cho game…" |
| Giờ ngủ | 0 | (trẻ ≤ 10 tuổi: sau 22h; trẻ 11+ tuổi: sau nửa đêm, ≥ 3 đêm/tuần) |

- Luật "giảm dần" dùng tính năng `TimeLimit.isGradual` sẵn có của KidFun: gợi ý đi kèm một hành động phụ huynh làm được
  ngay trong app.
- **Đã sửa trong tuần:**
  - Ban đầu gợi ý "đặt giới hạn bằng mức đang dùng", nhưng mức dùng đã bị chính giới hạn chặn lại nên câu thành vô
    nghĩa ("đặt 3h45 rồi giảm về 3h45"). Nay mức xuất phát = giới hạn + số phút bé hay xin thêm.
  - Luật giờ ngủ ban đầu coi 22h là khuya với mọi tuổi, nên báo cho 39 trẻ. Nay trẻ từ 11 tuổi chỉ tính dùng máy sau
    nửa đêm.
- Hạn chế: mốc WHO chỉ dành cho trẻ 2–4 tuổi, nên áp gần đúng cho nhóm 3–5. Với các nhóm tuổi khác, gợi ý dựa trên
  thói quen của chính trẻ, không đưa ra con số chuẩn bên ngoài chưa kiểm chứng.
