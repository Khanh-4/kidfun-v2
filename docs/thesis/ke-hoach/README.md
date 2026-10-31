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

## Trạng thái nhanh (cập nhật 23/10/2026)

| Task | Nội dung | Trạng thái |
|---|---|---|
| [T0](tasks/T0-quan-ly.md) | Quản lý: phiếu theo dõi tuần, họp GVHD | Đang chạy hằng tuần |
| [T1–T6](tasks/T1-T6-da-xong.md) | Thu thập theo giờ, EDA, đặc trưng, mô phỏng, M1, M2 hai tầng, phản hồi, M3/M4 | Code xong; **chờ test máy thật** |
| [T7](tasks/T7-tich-hop.md) | Tích hợp đầu cuối: tác vụ ban đêm, API kết quả, app phụ huynh | Đang làm: T7.1.1a xong (31/10), kế tiếp T7.1.2 |
| [T8](tasks/T8-kiem-thu-danh-gia.md) | Kiểm thử máy thật, đo pin, đánh giá cuối | Chưa làm (cần T7 và dữ liệu thật) |
| [T9](tasks/T9-bao-cao-demo.md) | Báo cáo, slide, demo | Chưa làm |

Việc tiếp theo: **đọc kết quả test của người test** (`docs/flowtest/`). Có lỗi thì sửa trước, ổn thì bắt đầu T7.

## Quy ước

- **Mã task:** `T7` là task lớn, `T7.2` là nhóm việc, `T7.2.3` là subtask. Commit và PR nên nhắc mã, ví dụ
  `feat(ml): tác vụ ban đêm tính baseline (T7.1)`.
- **Trạng thái subtask:** `- [ ]` chưa làm, `- [x]` xong. Subtask đang chờ người khác thì ghi thêm `(chờ: ...)`.
- **Mỗi subtask phải có tiêu chí xong** đo được: có test, có lệnh chạy được, hoặc có số liệu ghi vào `docs/thesis/`.
- **Cập nhật khi nào:** tick subtask ngay trong PR làm nó; cuối mỗi tuần cập nhật bảng trạng thái ở trên và
  [02-lo-trinh.md](02-lo-trinh.md), rồi thêm mục tuần vào phiếu theo dõi (xem [T0](tasks/T0-quan-ly.md)).
- **Quy trình git:** mỗi nhóm việc một nhánh riêng từ `develop`, một PR. PR có migration Prisma thì **hỏi trước khi
  push**, vì preview Vercel chạy `migrate deploy` thẳng lên DB production.
