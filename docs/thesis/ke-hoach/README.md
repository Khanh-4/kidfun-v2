# Kế hoạch đồ án chuyên ngành — Đề tài 01

Thư mục này là **kế hoạch sống** của đồ án: đề tài là gì, đã làm tới đâu, còn gì phải làm, và làm tiếp theo hướng nào.
Kết quả thực nghiệm chi tiết **không chép lại ở đây**: chúng nằm ở `docs/thesis/01–09` và chỉ được dẫn link.

## Mục lục

| File | Nội dung |
|---|---|
| [01-tong-quan-de-tai.md](01-tong-quan-de-tai.md) | Tên đề tài, mục tiêu, 5 câu hỏi nghiên cứu, 4 module, kiến trúc hai tầng, dữ liệu, phạm vi |
| [02-lo-trinh.md](02-lo-trinh.md) | Lộ trình 9 tuần: kế hoạch gốc, tiến độ thực tế, lịch các tuần còn lại |
| [03-rui-ro-va-ton-dong.md](03-rui-ro-va-ton-dong.md) | Rủi ro, việc đang chờ, câu hỏi chưa chốt |
| [04-huong-phat-trien.md](04-huong-phat-trien.md) | Việc mở rộng nếu dư thời gian và hướng phát triển sau đồ án |
| [tasks/](tasks/) | Danh sách task lớn, mỗi task chia thành các subtask có tiêu chí "xong" |

## Trạng thái nhanh (cập nhật 20/11/2026)

| Task | Nội dung | Trạng thái |
|---|---|---|
| [T0](tasks/T0-quan-ly.md) | Quản lý: phiếu theo dõi tuần, họp GVHD | Đang chạy hằng tuần (tuần 5 xong, #364; tuần 6 chưa) |
| [T1–T6](tasks/T1-T6-da-xong.md) | Thu thập theo giờ, EDA, đặc trưng, mô phỏng, M1, M2 hai tầng, phản hồi, M3/M4 | Code xong; flowtest 10, 11, 13, 15, 16 PASS trên máy thật; flowtest 17 B1–B5 PASS (20/11) |
| [T7](tasks/T7-tich-hop.md) | Tích hợp đầu cuối | **Xong**. Bàn giao: [10-tich-hop.md](../10-tich-hop.md) |
| [T8](tasks/T8-kiem-thu-danh-gia.md) | Kiểm thử máy thật, đo pin, đánh giá cuối | T8.4 xong (kèm LiveLab, kết luận ghi chiều); **công cụ T8.3 sẵn** (`models.real_eval`); **phiếu T8.5.1 sẵn** (`ml/reports/t85_survey.md`); T8.1–T8.2 chờ flowtest 14 |
| [T9](tasks/T9-bao-cao-demo.md) | Báo cáo, slide, demo | **T9.3.2 xong** (tài khoản demo, [demo-bao-ve.md](../demo-bao-ve.md)); báo cáo chưa viết |

Thay đổi lớn ngày 16/11 (chi tiết: mục "Bổ sung 16/11" trong [07](../07-ket-qua-m1-hoan-chinh.md), [08](../08-ket-qua-m2-tang2.md)):
M1 đổi nhãn "vượt giới hạn" → **"dùng hết giờ"** (ROC-AUC 0,726 → 0,854, ngưỡng cảnh báo 0,8), Platt + kẹp, bỏ
`history_days`; thêm bộ dữ liệu **LiveLab**; mô phỏng sinh GeofenceEvent (nhóm vị trí không giúp); làm sạch nhãn
`binge_day` (recall DBSCAN 0,27 → 0,49).

Thay đổi 17–20/11 (chỉ app trẻ, phần ghi nhật ký YouTube — nguồn dữ liệu cho M3/M4 và màn phụ huynh):
Shorts ghi đủ tiêu đề + `@người đăng` (#379); bỏ trang Playables, ký tự vô hình (#380); `@handle` video thường bị ký
tự bidi che (#381); backfill kênh video dài từ cây, chặn nhận nhầm Shorts, bỏ trang Downloads (#382); không tách một
video thành 2 dòng theo câu phụ đề khi xem toàn màn hình, bỏ nhãn "Suggested video" (#383). Các dòng rác trên prod đã
dọn (có sao lưu ngoài repo). `thesis-nightly` chạy đều mỗi đêm với gói `xgb_rel+xgb_hit_platt@2026-11-16`, không lỗi.

Việc tiếp theo (theo thứ tự, cập nhật 20/11):
1. **Build APK trẻ** từ `develop` (≥ `7833dbf`, có #383), gửi người test **flowtest 17 Bước 6** (video dài + phụ đề +
   toàn màn hình, màn gợi ý); nhắc điền mục "Ghi chép" (commit, máy, bản YouTube). Flowtest 14 đang đo pin thì đo
   xong mới cài APK mới.
2. Gửi phiếu khảo sát T8.5 cho 5–10 phụ huynh; nhập câu trả lời rồi `python -m models.survey --score`.
3. ~23/11 (dữ liệu thật đủ 7 ngày): **hỏi Khanh** rồi chạy `python -m models.real_eval --url … --save-pages` (T8.3).
4. Khi flowtest 14 có file đầu tiên: viết script phân tích độ trễ / pin (T8.1.3–T8.1.4, T8.2.2).
5. Sau khi flowtest 14 đo xong: refactor `childController.js` → `sessionService` (roadmap V2 giai đoạn B).
6. Cuối tuần 6 (22/11): phiếu theo dõi tuần 6 (T0).
7. Tuần 8–9: **T9.1** viết báo cáo; T9.3.3–T9.3.4 quay video dự phòng, chạy thử demo.

Flowtest 16 mục 1.3 và 1.7 (ghép lại / xoá thiết bị) cố ý chưa test để không cắt chuỗi dữ liệu liên tục của máy trẻ;
làm sau khi T8.3 lấy xong dữ liệu.

Dữ liệu thật: trẻ thật bắt đầu tháng 10–11 (mùa ít dùng hết giờ trên mô phỏng) nên có thể ít cảnh báo M1 — đúng thiết
kế, xem lại ở T8.3. Nhắc nhóm test để máy trẻ chạy liên tục và nhập ngày sinh cho bé.

## Quy ước

- **Mã task:** `T7` là task lớn, `T7.2` là nhóm việc, `T7.2.3` là subtask. Commit và PR nên nhắc mã, ví dụ
  `feat(ml): tác vụ ban đêm tính baseline (T7.1)`.
- **Trạng thái subtask:** `- [ ]` chưa làm, `- [x]` xong. Subtask đang chờ người khác thì ghi thêm `(chờ: ...)`.
- **Mỗi subtask phải có tiêu chí xong** đo được: có test, có lệnh chạy được, hoặc có số liệu ghi vào `docs/thesis/`.
- **Cập nhật khi nào:** tick subtask ngay trong PR làm nó; cuối mỗi tuần cập nhật bảng trạng thái ở trên và
  [02-lo-trinh.md](02-lo-trinh.md), rồi thêm mục tuần vào phiếu theo dõi (xem [T0](tasks/T0-quan-ly.md)).
- **Quy trình git:** mỗi nhóm việc một nhánh riêng từ `develop`, một PR. PR có migration Prisma thì **hỏi trước khi
  push**, vì preview Vercel chạy `migrate deploy` thẳng lên DB production.
