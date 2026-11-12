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

## Trạng thái nhanh (cập nhật 12/11/2026)

| Task | Nội dung | Trạng thái |
|---|---|---|
| [T0](tasks/T0-quan-ly.md) | Quản lý: phiếu theo dõi tuần, họp GVHD | Đang chạy hằng tuần |
| [T1–T6](tasks/T1-T6-da-xong.md) | Thu thập theo giờ, EDA, đặc trưng, mô phỏng, M1, M2 hai tầng, phản hồi, M3/M4 | Code xong; **chờ test máy thật** |
| [T7](tasks/T7-tich-hop.md) | Tích hợp đầu cuối: tác vụ ban đêm, API kết quả, app phụ huynh | **Xong code T7.1–T7.6** (05–11/11); chờ flowtest 11 + 13 trên máy thật. Bàn giao: [10-tich-hop.md](../10-tich-hop.md) |
| [T8](tasks/T8-kiem-thu-danh-gia.md) | Kiểm thử máy thật, đo pin, đánh giá cuối | **T8.4 xong** (12/11, kiểm định trên mô phỏng + dữ liệu công khai); T8.1–T8.3, T8.5 chờ máy thật / dữ liệu thật |
| [T9](tasks/T9-bao-cao-demo.md) | Báo cáo, slide, demo | Chưa làm |

Việc tiếp theo (theo thứ tự, cập nhật 12/11):
1. **Build APK phụ huynh** (#359, #360), gửi người test: flowtest 13 (test lại), 05 bước 5, 10 (test lại) và
   [flowtest 14](../../flowtest/14-do-tre-canh-bao-va-pin.md).
2. **Phiếu theo dõi tuần 5** (T0.1); hỏi GVHD hình thức báo cáo và lịch bảo vệ (T0.2).
3. Chọn bản mốc đo pin (xem [03](03-rui-ro-va-ton-dong.md), rủi ro Socket.IO).
4. Tuần 6: **T8.1, T8.2** theo flowtest 14. Tuần 7: **T8.3, T8.5** trên dữ liệu thật, chạy lại T8.4. Tuần 8–9: **T9**.

Dữ liệu thật: tác vụ ban đêm 12/11 mới tính được cho 1 trẻ (đủ 7 ngày), K-Means chưa chia nhóm (cần ≥ 6 trẻ).
Nhắc nhóm test để máy trẻ chạy liên tục và nhập ngày sinh cho bé.

## Quy ước

- **Mã task:** `T7` là task lớn, `T7.2` là nhóm việc, `T7.2.3` là subtask. Commit và PR nên nhắc mã, ví dụ
  `feat(ml): tác vụ ban đêm tính baseline (T7.1)`.
- **Trạng thái subtask:** `- [ ]` chưa làm, `- [x]` xong. Subtask đang chờ người khác thì ghi thêm `(chờ: ...)`.
- **Mỗi subtask phải có tiêu chí xong** đo được: có test, có lệnh chạy được, hoặc có số liệu ghi vào `docs/thesis/`.
- **Cập nhật khi nào:** tick subtask ngay trong PR làm nó; cuối mỗi tuần cập nhật bảng trạng thái ở trên và
  [02-lo-trinh.md](02-lo-trinh.md), rồi thêm mục tuần vào phiếu theo dõi (xem [T0](tasks/T0-quan-ly.md)).
- **Quy trình git:** mỗi nhóm việc một nhánh riêng từ `develop`, một PR. PR có migration Prisma thì **hỏi trước khi
  push**, vì preview Vercel chạy `migrate deploy` thẳng lên DB production.
