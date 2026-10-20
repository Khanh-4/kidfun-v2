# 03 — App phụ huynh vẫn chạy đúng sau sửa lỗi phân quyền (PR #314)

**Thay đổi:** server giờ kiểm tra "hồ sơ trẻ này có phải con của tài khoản đang đăng nhập không" ở **mọi** màn hình
xem/sửa dữ liệu của trẻ (trước đây đổi số trên đường dẫn là xem được con nhà khác). Phần chặn người lạ đã có test tự
động. Luồng này kiểm tra điều ngược lại: **chủ thật vẫn dùng mọi màn hình bình thường**, không bị báo "không tìm thấy".

**Cần:** máy phụ huynh đăng nhập đúng tài khoản sở hữu "Bé Test", máy trẻ đã liên kết và dùng máy được ít nhất vài
giờ (để các màn hình có dữ liệu).

**Dấu hiệu lỗi cần báo ngay:** màn hình trắng/xoay mãi, thông báo "Profile not found", "Không tìm thấy", "Lỗi 404",
hoặc danh sách rỗng trong khi trước đây có dữ liệu.

## Bước 1 — Mở lần lượt các màn hình của "Bé Test"

Từ danh sách hồ sơ → chọn "Bé Test" → mở từng mục:

| # | Màn hình | Mong đợi | Đạt |
|---|---|---|---|
| 1 | Sửa hồ sơ | hiện đúng tên, ngày sinh | [ ] |
| 2 | Giới hạn thời gian | hiện giới hạn từng ngày; **sửa 1 ngày → Lưu → mở lại thấy giá trị mới** | [ ] |
| 3 | Chặn ứng dụng | hiện danh sách app; chặn 1 app rồi bỏ chặn được | [ ] |
| 4 | Giới hạn theo app | hiện danh sách; thêm rồi xoá 1 giới hạn được | [ ] |
| 5 | Chế độ đi học (lịch học) | hiện lịch; lưu được | [ ] |
| 6 | Lọc web | hiện danh mục; bật/tắt 1 danh mục được; thêm/xoá 1 tên miền được | [ ] |
| 7 | Báo cáo dùng app (ngày / tuần) | có số liệu | [ ] |
| 8 | Vị trí hiện tại (bản đồ) | hiện vị trí máy trẻ | [ ] |
| 9 | Lịch sử vị trí | có điểm / đường đi | [ ] |
| 10 | Lịch sử SOS | mở được (rỗng cũng được nếu chưa có SOS) | [ ] |
| 11 | YouTube — tổng quan | mở được, có số liệu nếu máy trẻ đã xem YouTube | [ ] |
| 12 | YouTube — nhật ký | danh sách video đã xem | [ ] |
| 13 | Cảnh báo AI | mở được (rỗng cũng được) | [ ] |
| 14 | Báo cáo | báo cáo ngày / tuần mở được | [ ] |
| 15 | Lịch sử hoạt động | mở được | [ ] |

## Bước 2 — Các thao tác sửa/xoá theo từng mục

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 1 | Vùng an toàn: **tạo** 1 vùng mới trên bản đồ | tạo được, hiện trên bản đồ | [ ] |
| 2 | Vùng an toàn: **sửa** tên / bán kính vùng vừa tạo | lưu được | [ ] |
| 3 | Vùng an toàn: **xoá** vùng vừa tạo | xoá được, biến mất khỏi bản đồ | [ ] |
| 4 | Máy trẻ bấm **SOS** → máy phụ huynh mở cảnh báo SOS → bấm **Đã nhận** rồi **Đã xử lý** | cả hai nút chạy, trạng thái đổi | [ ] |
| 5 | YouTube nhật ký: **chặn** 1 video rồi **bỏ chặn** | cả hai chạy | [ ] |
| 6 | Cảnh báo AI (nếu có): mở 1 cảnh báo → **đánh dấu đã đọc** | hết chấm "chưa đọc" | [ ] |
| 7 | Máy trẻ **xin thêm giờ** → phụ huynh **duyệt** (một lần) và **từ chối** (một lần khác) | máy trẻ nhận đúng kết quả | [ ] |

## Ghi chép

| Mục | Giá trị |
|---|---|
| Mã commit | |
| Màn hình / thao tác lỗi (số thứ tự + mô tả) | |
| Ghi chú khác | |
