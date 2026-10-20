# 00 — Chuẩn bị (làm một lần)

## 1. Lấy code

Lần đầu:
```
git clone https://github.com/Khanh-4/kidfun-v2.git
cd kidfun-v2
git checkout develop
```

Các lần sau (trước mỗi đợt test):
```
cd kidfun-v2
git checkout develop
git pull
git rev-parse --short HEAD      # ghi mã này vào phần Ghi chép của từng file
```

## 2. Đặt 5 file cấu hình (không có trên git)

Khanh gửi riêng file `kidfun-test-files.zip`. Giải nén **vào thư mục gốc `kidfun-v2/`** sao cho có đủ:

| File | Dùng cho |
|---|---|
| `mobile/.env` | khoá bản đồ (Mapbox) |
| `mobile/android/app/google-services.json` | Firebase (đăng nhập, thông báo) |
| `mobile/android/app/debug.keystore` | ký bản debug (thiếu là build lỗi, đăng nhập Google lỗi) |
| `mobile/android/key.properties` | ký bản release (chỉ cần cho luồng 04) |
| `mobile/android/kidfun-release.keystore` | ký bản release (chỉ cần cho luồng 04) |

Không commit các file này. `git status` không được hiện chúng (đã có trong `.gitignore`).

## 3. Chạy app bằng Android Studio

1. Android Studio → **Open** → chọn thư mục `kidfun-v2/mobile`.
2. Lần đầu: chờ Gradle sync xong; nếu được hỏi thì chạy `flutter pub get` (Terminal trong Android Studio, ở `mobile/`).
3. Cắm **máy trẻ** (bật Tuỳ chọn nhà phát triển → Gỡ lỗi USB), chọn máy trên thanh công cụ, bấm **Run ▶**.
4. **Máy phụ huynh**: dùng máy thứ hai, hoặc tạo emulator (Device Manager → Create Device) rồi Run lần nữa lên emulator.

## 4. Liên kết máy trẻ

1. Trên máy phụ huynh: đăng nhập tài khoản phụ huynh, tạo một **hồ sơ trẻ dành riêng để test** (đặt tên dễ nhận,
   vd "Bé Test").
2. Lấy mã ghép đôi, nhập trên máy trẻ, cấp **đủ quyền** khi app hỏi: Truy cập dữ liệu sử dụng, Trợ năng,
   Quản trị thiết bị, Thông báo.
3. Báo cho Khanh **tên hồ sơ** và **giờ liên kết** (Khanh dùng để tra dữ liệu trên server).

## 5. Xem log (Logcat)

Android Studio → tab **Logcat** (dưới cùng) → chọn máy trẻ → ô lọc gõ:
```
tag:HourlyUsageWorker | tag:Tier1Client
```
Khi báo lỗi, copy đoạn log quanh thời điểm lỗi (chuột phải → Copy) và dán vào mẫu báo lỗi.

Nếu muốn dùng dòng lệnh (Windows PowerShell):
```
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" logcat -s HourlyUsageWorker Tier1Client
```

## Kiểm tra nhanh

- [ ] App chạy được trên máy trẻ và máy phụ huynh, đăng nhập được.
- [ ] Liên kết máy trẻ thành công, máy phụ huynh thấy máy trẻ "đang trực tuyến".
- [ ] Logcat lọc được theo tag ở mục 5.

## Ghi chép

| Mục | Giá trị |
|---|---|
| Mã commit | |
| Máy trẻ (mẫu / Android) | |
| Máy phụ huynh (máy thật hay emulator) | |
| Tên hồ sơ trẻ test / giờ liên kết | |
