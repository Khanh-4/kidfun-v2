# Demo buổi bảo vệ — tài khoản có sẵn dữ liệu (T9.3.2)

Dữ liệu demo nằm trong **DB test cục bộ** (`backend/.env.test`), không vào production. App phụ huynh nối vào
backend chạy trên laptop.

## 1. Dựng dữ liệu và bật backend

```bash
bash ml/e2e/run_demo.sh            # ~1 phút; giữ chạy suốt buổi demo, Ctrl+C để tắt
bash ml/e2e/run_demo.sh --cleanup  # xoá tài khoản demo khỏi DB test
```

Script làm: mô phỏng 28 ngày → nạp 2 bé demo + 6 bé nền → bật backend `0.0.0.0:3001` → chạy tác vụ ban đêm thật
(baseline, dự đoán M1, cảnh báo M2, nhóm thói quen M3 + gợi ý M4). Đăng nhập: `demo.baove@kidfun.test` /
`demo1234` (đổi bằng biến `DEMO_EMAIL`, `DEMO_PASSWORD`). Chạy lại script sẽ dựng lại dữ liệu theo ngày hôm đó.

| Bé | Hiện gì trên app |
|---|---|
| **An** (11–14 tuổi) | Cảnh báo M2 hôm qua kèm giải thích ("dùng một ứng dụng mới trong 9 giờ 30 phút") → bấm "Đúng là bất thường" / "Được phép"; heatmap 4 tuần; nhóm thói quen + gợi ý |
| **Minh** (11–14 tuổi) | Thẻ "Ngày mai": dự đoán + khả năng dùng hết giờ (thử 16/11: 116 phút / giới hạn 105, 74%); heatmap; nhóm thói quen |
| 6 bé nền | Ở tài khoản khác, chỉ để K-Means có đủ ≥ 6 trẻ và chia được 3 nhóm |

## 2. Build APK phụ huynh trỏ vào laptop

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://<IP-mà-điện-thoại-thấy>:3001
```

Không truyền `--dart-define` thì app vẫn trỏ production như cũ.

## 3. Mạng

- Điện thoại và laptop cùng một mạng Wi-Fi (phát từ điện thoại cũng được).
- **WSL2**: IP do `run_demo.sh` in ra là IP ảo của WSL, điện thoại không thấy. Trên Windows (PowerShell quyền
  admin), chuyển cổng từ Windows vào WSL rồi dùng IP Wi-Fi của Windows (`ipconfig`) cho `API_BASE_URL`:

  ```powershell
  netsh interface portproxy add v4tov4 listenport=3001 listenaddress=0.0.0.0 connectport=3001 connectaddress=<IP-WSL>
  New-NetFirewallRule -DisplayName "KidFun demo 3001" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow
  ```

  Dọn sau buổi demo: `netsh interface portproxy delete v4tov4 listenport=3001 listenaddress=0.0.0.0`.

## 4. Giới hạn — chuẩn bị video dự phòng (T9.3.3)

- Màn đọc qua REST (AI Insights, cảnh báo, dự đoán, heatmap, báo cáo) chạy đầy đủ — đã kiểm bằng API 16/11.
- Realtime (Supabase) gắn với DB production nên **không** cập nhật tức thời cho dữ liệu demo — kéo xuống để làm mới.
- Thông báo đẩy: chưa thử với backend demo. Phần "phụ huynh nhận thông báo" trong kịch bản T9.3.1 nên quay sẵn
  bằng app thật.
- **Cảnh báo M1 không chắc có trong ngày demo.** Kể cả với nhãn "dùng hết giờ" (#372), thử 16/11 Minh được
  p = 0,74 (< ngưỡng 0,8); trong 40 trẻ mô phỏng chỉ ~4% số ngày đạt p ≥ 0,8 với trẻ có lịch sử ngắn (xem tồn đọng
  `history_days`). Demo thẻ "Ngày mai" (số phút + khả năng dùng hết giờ) và cảnh báo M2 của An; cảnh báo M1 dùng
  video dự phòng.
