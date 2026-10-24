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

## Bước 3 — Test lại 2 lỗi đã sửa (báo cáo Task 3, 2026-10-24)

Cần **build lại app phụ huynh từ nhánh mới** — bản cũ vẫn còn lỗi. Phần backend tự lên Vercel khi PR được merge
(trước đó thông báo SOS có thể chưa tự biến mất ở mục 3.3 khi app chạy nền — ghi chú lại nếu gặp).

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 3.1 | Máy trẻ bấm **SOS**, máy phụ huynh **đang mở app** → pop-up SOS hiện → bấm **Đã nhận được** ngay trên pop-up | pop-up đóng, hiện "Đã xác nhận SOS"; vào **Lịch sử SOS** thấy trạng thái "Đã nhận" | [ ] |
| 3.2 | Sau 3.1: thoát app ra màn hình chính rồi mở lại app 2–3 lần | pop-up SOS **không** hiện lại | [ ] |
| 3.3 | Sau 3.1: kéo thanh thông báo của điện thoại xuống | **không còn** thông báo SOS vừa xử lý | [ ] |
| 3.4 | SOS mới → trên pop-up bấm **Xem chi tiết** | màn hình SOS có nút **Đã nhận được SOS**; bấm → đổi thành nút **Đã giải quyết xong**; bấm tiếp → báo "Đã giải quyết SOS"; thông báo trên thanh trạng thái biến mất | [ ] |
| 3.5 | SOS mới khi app phụ huynh **chạy nền / đã tắt** → bấm vào thông báo đẩy | mở màn hình SOS **có** nút Đã nhận / Đã giải quyết, bấm được | [ ] |
| 3.6 | Bản đồ vị trí → **chạm vào bên trong** 1 vùng an toàn đã tạo | hiện pop-up có tên vùng, nút **Sửa** và **Xoá** | [ ] |
| 3.7 | Chọn **Sửa** → đổi tên + kéo bán kính → **Lưu** | vòng tròn trên bản đồ đổi kích thước; chạm lại thấy tên/bán kính mới | [ ] |
| 3.8 | Chạm vùng → **Xoá** → hộp xác nhận → **Xóa** | vùng biến mất khỏi bản đồ | [ ] |
| 3.9 | Đang ở chế độ **thêm vùng** (nút ➕ góc trên) → chạm vào vùng cũ | **không** hiện pop-up Sửa/Xoá, chỉ đặt tâm vùng mới như trước | [ ] |
| 3.10 | Máy trẻ **mở app** KidFun. Máy phụ huynh: bản đồ vị trí → bấm nút **🎯 góc dưới phải** | nút xoay ngắn, hiện "Đã gửi yêu cầu, đang chờ máy của bé gửi vị trí..."; trong ~20 giây chấm vị trí của bé **nhảy tới vị trí mới** | [ ] |
| 3.11 | Như 3.10 nhưng máy trẻ **đang ở màn hình chính / tắt màn hình** (app chạy nền) | vị trí vẫn cập nhật trong ~20 giây; máy trẻ **không** hiện thông báo nào | [ ] |
| 3.12 | Như 3.10 nhưng trên emulator đổi vị trí giả (Extended controls → Location) trước khi bấm | chấm vị trí nhảy đúng tới tọa độ vừa đặt | [ ] |
| 3.13 | Hồ sơ **chưa liên kết máy** nào → bấm nút 🎯 | báo đỏ "Chưa có thiết bị nào liên kết với hồ sơ này" | [ ] |

Mục 3.10–3.13 cần **build lại cả app máy trẻ** (máy trẻ phải có code nhận lệnh mới) và backend bản mới đã lên
Vercel. Máy trẻ cần quyền vị trí **"Luôn cho phép"** thì 3.11 mới đạt.

## Ghi chép

| Mục | Giá trị |
|---|---|
| Mã commit | |
| Màn hình / thao tác lỗi (số thứ tự + mô tả) | |
| Ghi chú khác | |
