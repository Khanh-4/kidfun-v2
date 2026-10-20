# 04 — Đo pin: bản cũ (mốc) và bản mới

**Mục đích:** so mức tiêu hao pin của app trẻ **trước** và **sau** khi thêm bộ thu thập theo giờ + luật tầng 1
(câu hỏi nghiên cứu RQ4 của đồ án). Làm **2 lần đo**, mỗi lần 24 giờ, **cùng máy, cùng kịch bản, cùng điều kiện mạng**.

| Lần đo | Mã commit cần build | Ghi chú |
|---|---|---|
| A — mốc (bản cũ) | `5b0a0b0` | trước PR #303: chưa có bộ thu thập theo giờ, chưa có luật tầng 1 |
| B — bản mới | `develop` mới nhất | đủ bộ thu thập theo giờ + luật tầng 1 |

Các bước đo chi tiết (lệnh `adb`, kịch bản sử dụng, file cần gửi) ở
[docs/thesis/04-huong-dan-do-pin.md](../thesis/04-huong-dan-do-pin.md). File này chỉ thêm phần **chọn đúng bản code**
cho từng lần đo.

## Lần đo A — bản cũ (mốc)

1. Lấy đúng bản code cũ:
   ```
   cd kidfun-v2
   git fetch
   git checkout 5b0a0b0
   git rev-parse --short HEAD        # phải in 5b0a0b0
   ```
   Git báo "detached HEAD" là bình thường. 5 file cấu hình (00-chuan-bi.md mục 2) vẫn giữ nguyên.
2. Build và cài **bản release** (không dùng nút Run của Android Studio):
   ```
   cd mobile
   flutter pub get
   flutter build apk --release
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```
3. Mở app, liên kết với "Bé Test", cấp đủ quyền. **Không** tắt tối ưu pin cho app.
4. Làm đúng **Bước 1 → Bước 4** trong docs/thesis/04-huong-dan-do-pin.md (24 giờ). Đặt tên file gửi lại có chữ `A`:
   `kidfun_batterystats_A.txt`, `full_batterystats_A.txt`, `bugreport_pin_A.zip`.
5. Xong thì quay lại nhánh chính:
   ```
   cd kidfun-v2
   git checkout develop
   ```

## Lần đo B — bản mới

1. `git checkout develop && git pull`, ghi mã commit (`git rev-parse --short HEAD`).
2. Gỡ app cũ trên máy (`adb uninstall com.kidfun.mobile`) rồi build + cài bản release như bước 2 ở trên.
3. Liên kết lại "Bé Test", cấp đủ quyền, **mở app KidFun một lần** (để lên lịch thu thập theo giờ).
4. Làm đúng Bước 1 → Bước 4 như lần A. Đặt tên file có chữ `B`.

## Kiểm tra trước khi gửi

- [ ] Lần A build đúng commit `5b0a0b0`; lần B build từ `develop` (đã ghi mã).
- [ ] Cả hai lần đều là bản **release**, cài bằng `adb install`, rút cáp suốt thời gian đo.
- [ ] Cả hai lần cùng máy, cùng kịch bản (1 giờ YouTube, 30 phút game, 30 phút web/mạng xã hội), Wi-Fi bật suốt.
- [ ] Đủ 6 file (3 file × 2 lần) + bảng ghi chép dưới đây.

## Ghi chép

| Mục | Lần A (mốc) | Lần B (mới) |
|---|---|---|
| Mã commit | 5b0a0b0 | |
| Mẫu máy / phiên bản Android | | |
| Giờ bắt đầu / pin lúc bắt đầu (%) | | |
| Giờ kết thúc / pin lúc kết thúc (%) | | |
| Số giờ đo thực tế | | |
| Có làm đúng kịch bản không? Khác gì | | |
| Wi-Fi bật suốt? Có lúc mất mạng? | | |
| Có cắm sạc / khởi động lại giữa chừng? | | |
