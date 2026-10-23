# T0 — Quản lý đồ án (lặp lại mỗi tuần)

## T0.1 Phiếu theo dõi tiến độ (cuối mỗi tuần)

- [ ] T0.1.1 Thêm dòng tuần vào "Nhật ký tuần" ở [02-lo-trinh.md](../02-lo-trinh.md).
- [ ] T0.1.2 Thêm mục `N` vào `WEEKS` trong `BAO CAO DO AN CHUYEN NGANH/phieu_theo_doi.py`: ngày dạng
  `"dd/mm/yyyy\n–\ndd/mm/yyyy"`, 5–8 gạch đầu dòng ngắn, dòng cuối là "Tồn đọng".
- [ ] T0.1.3 Chạy `python3 phieu_theo_doi.py N` (cần Word trên Windows) → `PhieuTheoDoiTuanN.pdf`; xem PDF không vỡ bảng.
- [ ] T0.1.4 PR riêng `docs/phieu-theo-doi-tuanN`.

Đã nộp: tuần 1 (PR #307), tuần 2 (PR #317).

## T0.2 Làm việc với GVHD

- [ ] T0.2.1 Hỏi hình thức báo cáo cuối: báo cáo thường hay dạng bài báo, số trang, mẫu của khoa.
- [ ] T0.2.2 Hỏi lịch nộp bản nháp, lịch bảo vệ (để chốt mốc T9).
- [ ] T0.2.3 Báo GVHD tiến độ đi trước 4 tuần; hỏi có muốn thêm phần mở rộng nào ở
  [04-huong-phat-trien.md](../04-huong-phat-trien.md) không.

## T0.3 Phối hợp người test

- [ ] T0.3.1 Mỗi lần có tính năng mới trên app: cập nhật `docs/flowtest/`, push, gửi checklist cho người test.
- [ ] T0.3.2 Nhận kết quả (ảnh chụp, logcat, số đo pin) → ghi lỗi thành subtask mới trong task tương ứng.

## T0.4 Giữ kế hoạch này luôn đúng

- [ ] T0.4.1 Cuối tuần: cập nhật bảng trạng thái ở [README](../README.md), tick subtask đã xong.
- [ ] T0.4.2 Có rủi ro hoặc tồn đọng mới → ghi vào [03-rui-ro-va-ton-dong.md](../03-rui-ro-va-ton-dong.md).
