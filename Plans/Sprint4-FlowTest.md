# KidFun V3 — Sprint 4: Flow Test — FRONTEND

> **Mục tiêu:** Test toàn bộ tính năng Sprint 4 end-to-end trên 2 thiết bị Android
> **Cần:** 2 điện thoại Android (1 Parent + 1 Child) hoặc 1 thật + 1 emulator
> **Backend:** https://kidfun-backend-production.up.railway.app (đã deploy Sprint 4)

---

## Chuẩn bị trước khi test

- [ ] Pull develop mới nhất: `git checkout develop && git pull origin develop`
- [ ] Build app: `flutter run` trên cả 2 thiết bị
- [ ] Mở Railway logs real-time (nhờ Khanh mở) để theo dõi server events
- [ ] Chuẩn bị 2 tài khoản: 1 Parent (đã có profile + device linked), 1 Child (đã link device)

---

## Test 1: Time Settings (Parent)

**Mục tiêu:** Parent đặt giới hạn thời gian cho con

### Bước thực hiện:

1. [ ] Mở app Parent → đăng nhập
2. [ ] Vào profile con → nhấn "Giới hạn thời gian" (hoặc Time Settings)
3. [ ] Thấy 7 ngày trong tuần, mỗi ngày có slider
4. [ ] Kéo slider Thứ 2 → **3 phút** (đặt nhỏ để test nhanh)
5. [ ] Kéo slider các ngày khác tùy ý
6. [ ] Nhấn "Lưu thay đổi"
7. [ ] Thấy SnackBar "Lưu thành công" (hoặc tương tự)

### Kết quả mong đợi:

- [ ] Slider hoạt động mượt, hiển thị đúng "Xh Ym"
- [ ] Lưu thành công, không lỗi
- [ ] Railway logs thấy: `PUT /api/profiles/:id/time-limits 200`

### Lỗi cần báo:

- Slider không kéo được
- Lưu bị lỗi (ghi lại error message)
- Data không đúng sau khi lưu (thoát ra vào lại kiểm tra)

---

## Test 2: Countdown Timer (Child)

**Mục tiêu:** Child mở app → countdown đếm ngược đúng

### Bước thực hiện:

1. [ ] Mở app Child → vào Child Dashboard
2. [ ] Quan sát countdown timer ở giữa màn hình

### Kết quả mong đợi:

- [ ] Countdown hiển thị đúng thời gian còn lại (ví dụ: `00:03:00` nếu đặt 3 phút)
- [ ] Countdown đếm ngược mỗi giây: `00:02:59`, `00:02:58`, ...
- [ ] Railway logs thấy:
  ```
  GET /api/child/today-limit 200
  POST /api/child/session/start 201
  ```
- [ ] Mỗi 60 giây thấy: `POST /api/child/session/heartbeat 200`

### Lỗi cần báo:

- Countdown hiển thị `00:00:00` ngay khi mở (không lấy được remaining time)
- Countdown không đếm ngược
- Countdown hiển thị sai số (so với time limit đã đặt)

---

## Test 3: Soft Warning ★

**Mục tiêu:** Cảnh báo mềm hiện đúng mốc 30/15/5 phút

> **Lưu ý:** Vì đặt 3 phút nên chỉ test được mốc gần 0. Nếu muốn test đầy đủ 3 mốc → đặt time limit 35 phút rồi chờ.
> **Cách test nhanh:** Đặt time limit 2 phút → chờ hết giờ → test TIME_UP.

### Bước thực hiện:

1. [ ] Child đang ở Dashboard, countdown đang chạy
2. [ ] Chờ countdown đến mốc cảnh báo (hoặc test với thời gian ngắn)
3. [ ] Quan sát có hiện dialog cảnh báo không

### Kết quả mong đợi (nếu đặt 35 phút):

- [ ] Còn 30 phút → hiện dialog: "Còn 30 phút" → nhấn "Đã hiểu" → đóng
- [ ] Còn 15 phút → hiện dialog: "Còn 15 phút"
- [ ] Còn 5 phút → hiện dialog: "Còn 5 phút!"
- [ ] Mỗi warning → Railway logs thấy: `POST /api/child/warning 201`
- [ ] Parent nhận push notification cho mỗi warning

### Kết quả mong đợi (nếu đặt 2-3 phút, test nhanh):

- [ ] Có thể không kịp trigger mốc 30/15 (vì time limit < 30 phút)
- [ ] Mốc 5 phút sẽ không trigger nếu limit < 5 phút
- [ ] Quan trọng nhất: test TIME_UP ở Test 4

### Lỗi cần báo:

- Dialog không hiện ở mốc đúng
- Dialog hiện nhiều lần cùng 1 mốc
- Push notification không đến Parent

---

## Test 4: Hết Giờ (TIME_UP)

**Mục tiêu:** Khi countdown = 0 → hiện màn hình khóa

### Bước thực hiện:

1. [ ] Đặt time limit 2 phút (Parent app)
2. [ ] Mở Child app → countdown bắt đầu từ 2:00
3. [ ] Chờ countdown về 0:00

### Kết quả mong đợi:

- [ ] Countdown đến 0:00 → hiện dialog "Hết giờ!"
- [ ] Dialog **KHÔNG THỂ** đóng được (không có nút X, nhấn back không thoát)
- [ ] Railway logs thấy:
  ```
  POST /api/child/warning 201    (type: TIME_UP)
  POST /api/child/session/end 200
  ```
- [ ] Parent nhận push notification "Hết giờ"

### Lỗi cần báo:

- Countdown về 0 nhưng không hiện dialog
- Dialog có thể dismiss được (nhấn back thoát được)
- App crash khi hết giờ

---

## Test 5: Xin Thêm Giờ ★

**Mục tiêu:** Child xin giờ → Parent duyệt → countdown tăng thêm

### Chuẩn bị:

- Đặt time limit 5 phút
- Mở cả 2 app (Parent + Child)

### Bước thực hiện:

1. [ ] **Child:** Mở Dashboard → countdown đang chạy (5:00)
2. [ ] **Child:** Nhấn "Xin thêm giờ"
3. [ ] **Child:** Chọn 15 phút
4. [ ] **Child:** Nhập lý do: "Con đang làm bài tập"
5. [ ] **Child:** Nhấn "Gửi yêu cầu"
6. [ ] **Child:** Thấy thông báo "Đang chờ phản hồi..."
7. [ ] **Parent:** Thấy dialog hiện lên: "Bé An xin thêm 15 phút — Lý do: Con đang làm bài tập"
8. [ ] **Parent:** Nhấn "Duyệt (15 phút)"
9. [ ] **Child:** Thấy dialog "Được duyệt! Phụ huynh đã cho thêm 15 phút!"
10. [ ] **Child:** Countdown tăng thêm 15 phút (từ ~4:xx lên ~19:xx)

### Kết quả mong đợi:

- [ ] Child gửi request thành công
- [ ] Parent nhận dialog trong app real-time (< 3 giây)
- [ ] Parent approve → Child nhận response real-time (< 3 giây)
- [ ] Countdown thực sự tăng thêm đúng số phút
- [ ] Railway logs thấy các Socket.IO events tương ứng

---

## Test 6: Từ Chối Xin Giờ

### Bước thực hiện:

1. [ ] **Child:** Nhấn "Xin thêm giờ" → chọn 30 phút → gửi
2. [ ] **Parent:** Thấy dialog → nhấn "Từ chối"
3. [ ] **Child:** Thấy dialog "Bị từ chối"

### Kết quả mong đợi:

- [ ] Child nhận response "Bị từ chối" real-time
- [ ] Countdown **KHÔNG** thay đổi
- [ ] Không crash, không lỗi

---

## Test 7: Parent Thay Đổi Time Limit Khi Child Đang Dùng

**Mục tiêu:** Parent thay đổi giới hạn → Child countdown cập nhật real-time

### Bước thực hiện:

1. [ ] **Child:** Đang ở Dashboard, countdown hiện 3:00
2. [ ] **Parent:** Vào Time Settings → đổi hôm nay thành 10 phút → Lưu
3. [ ] **Child:** Quan sát countdown

### Kết quả mong đợi:

- [ ] Child countdown cập nhật tăng lên (vì giới hạn mới lớn hơn)
- [ ] Không cần tắt/mở lại app Child
- [ ] Railway logs thấy `timeLimitUpdated` event

---

## Test 8: Tắt/Mở Lại App (Persistence)

### Bước thực hiện:

1. [ ] **Child:** Đang ở Dashboard, countdown hiện 3:00
2. [ ] **Child:** Nhấn Home (minimize app) → đợi 30 giây
3. [ ] **Child:** Mở lại app

### Kết quả mong đợi:

- [ ] Countdown tiếp tục đúng (trừ đi 30 giây đã trôi qua)
- [ ] Không reset về giá trị ban đầu
- [ ] Session cũ kết thúc, session mới bắt đầu
- [ ] Railway logs thấy:
  ```
  POST /api/child/session/end 200     (khi minimize)
  POST /api/child/session/start 201   (khi mở lại)
  ```

---

## Test 9: Push Notification (Parent Không Mở App)

### Bước thực hiện:

1. [ ] **Parent:** Đóng app hoàn toàn (force close)
2. [ ] **Child:** Nhấn "Xin thêm giờ" → gửi request
3. [ ] **Parent:** Quan sát notification bar

### Kết quả mong đợi:

- [ ] Parent nhận push notification: "Bé An xin thêm 15 phút"
- [ ] Nhấn notification → mở app
- [ ] (Tùy chọn) App mở vào screen xử lý request

### Lỗi cần báo:

- Không nhận push notification
- Notification hiện nhưng nội dung sai
- Nhấn notification nhưng app không mở đúng screen

---

## Test 10: Edge Cases

### 10.1: Time limit = 0 phút

1. [ ] **Parent:** Đặt hôm nay = 0 phút → Lưu
2. [ ] **Child:** Mở app

- Mong đợi: Hiện "Hết giờ!" ngay lập tức

### 10.2: Không có time limit cho hôm nay

1. [ ] **Parent:** Không đặt time limit (hoặc isActive = false)
2. [ ] **Child:** Mở app

- Mong đợi: Countdown hiện 0:00 hoặc thông báo "Không có giới hạn hôm nay"

### 10.3: Mất mạng giữa chừng

1. [ ] **Child:** Đang countdown → tắt WiFi/4G
2. [ ] Đợi 10 giây → bật lại mạng

- Mong đợi: Countdown vẫn chạy (local timer), khi có mạng lại → heartbeat sync lại từ server

### 10.4: Xin giờ 2 lần liên tiếp

1. [ ] **Child:** Xin thêm giờ → Parent duyệt
2. [ ] **Child:** Xin thêm giờ lần 2

- Mong đợi: Cả 2 lần đều hoạt động bình thường

---

## Bảng tổng hợp kết quả test

| # | Test Case | Kết quả | Ghi chú |
|---|-----------|---------|---------|
| 1 | Time Settings (Parent) | ⬜ Pass / ⬜ Fail | |
| 2 | Countdown Timer (Child) | ⬜ Pass / ⬜ Fail | |
| 3 | Soft Warning (30/15/5 phút) | ⬜ Pass / ⬜ Fail | |
| 4 | Hết giờ (TIME_UP) | ⬜ Pass / ⬜ Fail | |
| 5 | Xin thêm giờ (Approve) | ⬜ Pass / ⬜ Fail | |
| 6 | Từ chối xin giờ (Reject) | ⬜ Pass / ⬜ Fail | |
| 7 | Thay đổi time limit real-time | ⬜ Pass / ⬜ Fail | |
| 8 | Tắt/mở lại app | ⬜ Pass / ⬜ Fail | |
| 9 | Push notification | ⬜ Pass / ⬜ Fail | |
| 10.1 | Time limit = 0 | ⬜ Pass / ⬜ Fail | |
| 10.2 | Không có time limit | ⬜ Pass / ⬜ Fail | |
| 10.3 | Mất mạng giữa chừng | ⬜ Pass / ⬜ Fail | |
| 10.4 | Xin giờ 2 lần | ⬜ Pass / ⬜ Fail | |

---

## Khi gặp lỗi — cách báo cho Khanh

Mỗi bug cần ghi rõ:

1. **Test case nào:** ví dụ "Test 5, bước 7"
2. **Triệu chứng:** ví dụ "Parent không thấy dialog"
3. **Flutter console log:** copy log lỗi nếu có
4. **Railway log:** nhờ Khanh check server log tại thời điểm lỗi
5. **Screenshot/video:** nếu có

Format báo bug:
```
Bug: [Test X, Bước Y]
Triệu chứng: ...
Expected: ...
Actual: ...
Flutter log: ...
```
