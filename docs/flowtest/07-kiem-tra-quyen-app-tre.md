# Luồng 07 — App trẻ tự rà soát quyền còn thiếu

**Sửa lỗi:** báo cáo "app trẻ không hiện pop-up yêu cầu cấp quyền còn thiếu sau khi cài đặt/cập nhật"
(máy ảo Android 17, thiếu Accessibility, đang ở **màn ghép nối**).

**Nguyên nhân thật:** chỉ màn hình trẻ (sau khi ghép nối) mới kiểm tra quyền; màn ghép nối không kiểm tra gì.
Ngoài ra màn hình trẻ bỏ sót: vị trí/thông báo bị "từ chối vĩnh viễn", vị trí chạy ngầm, GPS tắt.

**Bản mới:** cả màn ghép nối lẫn màn hình trẻ hiện **một pop-up "KidFun còn thiếu N quyền"** liệt kê mọi quyền
thiếu; mỗi quyền có nút **Cấp quyền** (hộp thoại hệ thống) hoặc **Mở Cài đặt**. Kiểm tra lại mỗi lần mở app và
mỗi lần quay lại app từ Cài đặt.

Nhánh: `fix/child-permission-audit` — thời gian ~30 phút. Máy ảo dùng được.

## Bước 1 — Màn ghép nối (đúng kịch bản lỗi)

1. Gỡ app trẻ, cài lại từ nhánh này (Run trong Android Studio), chọn vai trò **Con** → tới màn ghép nối.

- [ ] Pop-up "KidFun còn thiếu N quyền" hiện ngay, liệt kê các quyền chưa cấp (ít nhất: Đọc dữ liệu sử dụng,
      Hỗ trợ tiếp cận, Vị trí; Android 13+ thêm Thông báo).
- [ ] Có nút **Để sau**; bấm thì pop-up đóng, vẫn ghép nối được bình thường.
- [ ] Bấm **Mở Cài đặt** cạnh "Hỗ trợ tiếp cận" → mở đúng màn Hỗ trợ tiếp cận. Bật KidFun rồi quay lại app
      → pop-up hiện lại **không còn** dòng Hỗ trợ tiếp cận.
- [ ] Bấm **Cấp quyền** cạnh "Vị trí" → hiện hộp thoại hệ thống; cho phép → pop-up tự cập nhật, chuyển sang hỏi
      "Vị trí chạy ngầm".
- [ ] Cấp đủ hết → không còn pop-up.

## Bước 2 — Quyền bị thu hồi sau khi đã ghép nối

2. Ghép nối xong, đang ở màn hình trẻ. Vào Cài đặt → Hỗ trợ tiếp cận → **tắt** KidFun. Quay lại app.

- [ ] Pop-up hiện, chỉ có dòng Hỗ trợ tiếp cận. **Không** có nút "Để sau", bấm nút Back cũng không đóng.
- [ ] Bật lại → quay lại app → pop-up biến mất.

3. Cập nhật app đè (bấm Run lại trong Android Studio, **không** gỡ) khi đang thiếu một quyền.

- [ ] Mở app → pop-up hiện đúng quyền đang thiếu.

## Bước 3 — Các lỗ hổng cũ

4. Cài đặt app → Quyền → Vị trí → **Không cho phép** (bấm từ chối 2 lần cho tới khi Android không hỏi nữa).
   - [ ] Pop-up có dòng "Vị trí", nút ghi **Mở Cài đặt** → mở trang thông tin app KidFun.
5. Cấp vị trí ở mức **Chỉ khi đang dùng ứng dụng**.
   - [ ] Pop-up có dòng "Vị trí chạy ngầm ("Luôn cho phép")".
6. Tắt định vị (kéo thanh thông báo → tắt Vị trí/GPS), quay lại app.
   - [ ] Pop-up có dòng "Bật định vị (GPS)", nút mở màn cài đặt Vị trí.
7. (Android 13+) Tắt quyền Thông báo của KidFun trong Cài đặt.
   - [ ] Pop-up có dòng "Thông báo".

## Ghi chép

- Mã commit: `git rev-parse --short HEAD` →
- Máy / Android:
- Bước không đạt (dùng mẫu báo lỗi trong README):
