# Hướng dẫn đo pin làm mốc (cho người test)

> Mục đích: đo mức tiêu hao pin của app KidFun trên máy trẻ **trước** khi đổi sang gửi dữ liệu theo đợt
> (tuần 6), để có số so sánh cho câu hỏi nghiên cứu RQ4. Lần đo sau (tuần 8) làm **y hệt** các bước dưới đây.

## Chuẩn bị (một lần)

1. **Máy:** dùng đúng một chiếc điện thoại Android làm máy trẻ cho cả lần đo này và lần đo sau.
2. **Bản app — phải là bản RELEASE:** bản debug của Flutter chạy chế độ JIT nên tốn pin hơn hẳn, đo sẽ sai.
   Trong thư mục `mobile/` (nhánh `develop` mới nhất, đã có 5 file bí mật):
   ```
   git rev-parse --short HEAD
   flutter build apk --release
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```
   Ghi lại mã commit in ra ở lệnh đầu.
3. **Liên kết:** mở app, liên kết máy với **một hồ sơ trẻ dùng để test**, cấp đủ quyền như khi dùng thật
   (Truy cập dữ liệu sử dụng, Trợ năng, Quản trị thiết bị, Thông báo). **Không** tự tắt chế độ tối ưu pin cho app
   — để như người dùng bình thường.
4. **Lệnh `adb`:** Android Studio đã kèm sẵn. Trên Windows mở PowerShell và dùng đường dẫn đầy đủ (hoặc thêm thư mục này vào PATH):
   ```
   & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
   ```
   Bên dưới viết tắt là `adb`. Bật **Tuỳ chọn nhà phát triển → Gỡ lỗi USB** trên điện thoại.

## Các bước đo (24 giờ)

### Bước 1 — Bắt đầu (cắm cáp USB)
Sạc máy lên **≥ 90%**, cắm cáp USB vào máy tính, rồi chạy:
```
adb devices
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell dumpsys batterystats --reset
adb shell dumpsys battery
```
- `adb devices` phải thấy máy ở trạng thái `device`.
- Lệnh `--reset` xoá số liệu pin cũ để bắt đầu đếm từ 0.
- Ghi lại **giờ bắt đầu** và dòng `level:` (phần trăm pin) của lệnh cuối vào bảng ở cuối trang.

### Bước 2 — Rút cáp, dùng máy theo kịch bản cố định
**Rút cáp USB ngay** (Android chỉ đếm số liệu pin khi máy không sạc). Không cắm sạc trong 24 giờ.

Kịch bản sử dụng (giữ giống nhau ở cả hai lần đo):

| Việc | Thời lượng |
|---|---|
| Xem YouTube | 1 giờ |
| Chơi một game bất kỳ | 30 phút |
| Lướt web / mạng xã hội | 30 phút |
| Còn lại | để máy nghỉ, màn hình tắt, Wi-Fi bật suốt |

Nếu pin xuống dưới **15%** trước khi đủ 24 giờ thì dừng sớm và ghi số giờ thực tế.

### Bước 3 — Kết thúc (cắm cáp lại và chạy lệnh NGAY)
Cắm cáp USB lại và chạy ngay (máy bắt đầu sạc từ lúc cắm, số liệu chỉ tính đến thời điểm đó):
```
adb shell dumpsys battery
adb shell dumpsys batterystats com.kidfun.mobile > kidfun_batterystats.txt
adb shell dumpsys batterystats > full_batterystats.txt
adb bugreport bugreport_pin_moc.zip
```
- Ghi **giờ kết thúc** và `level:` của lệnh đầu.
- Lệnh `bugreport` mất 1–3 phút, file khoảng vài chục MB — dùng để xem bằng công cụ Battery Historian của Google.

### Bước 4 — Gửi lại
Gửi cho Khanh: 3 file (`kidfun_batterystats.txt`, `full_batterystats.txt`, `bugreport_pin_moc.zip`) + bảng dưới đây.

## Bảng ghi chép

| Mục | Giá trị |
|---|---|
| Mẫu máy / phiên bản Android | |
| Mã commit của bản app | |
| Giờ bắt đầu / pin lúc bắt đầu (%) | |
| Giờ kết thúc / pin lúc kết thúc (%) | |
| Số giờ đo thực tế | |
| Có làm đúng kịch bản không? Nếu khác thì khác gì | |
| Wi-Fi bật suốt? Có lúc nào mất mạng? | |
| Có cắm sạc giữa chừng không? | |

## Lưu ý
- **Không** gỡ/cài lại app, không đổi cài đặt tối ưu pin, không khởi động lại máy trong 24 giờ (nếu lỡ thì ghi lại).
- Không chạy app bằng nút Run/Debug của Android Studio trong lúc đo; cài bản release bằng `adb install` như ở trên rồi rút cáp.
- Lần đo sau phải dùng **cùng máy, cùng kịch bản, cùng điều kiện mạng** thì mới so sánh được.
