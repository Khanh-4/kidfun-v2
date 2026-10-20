# 02 — Cảnh báo dùng máy bất thường ngay trên máy trẻ (PR #313, #315)

**Tính năng:** sau mỗi lần thu thập (30 phút/lần), app trẻ tự kiểm tra **luật tầng 1**. Nếu bất thường, app gửi cảnh
báo lên server, server gửi **thông báo** cho phụ huynh, ví dụ:

> **Cảnh báo sử dụng của Bé Test** — Bé chơi game lúc 1h trong 25 phút — giờ này bé thường đã ngủ.

Hiện server **chưa có "mức thường ngày"** của trẻ (tác vụ tính hằng đêm làm ở tuần 7), nên app chỉ dùng **luật khuya**
và chỉ trong khung **0h–6h sáng**: trong **một giờ** (vd 1:00–1:59) dùng máy tổng cộng ≥ 10 phút thì báo.
Luật "tăng đột biến" chỉ test được bằng bước 5 (tuỳ chọn).

**Cần:**
- Đã làm [00-chuan-bi.md](00-chuan-bi.md); máy trẻ đã liên kết (nếu vừa làm luồng 01 bước 3 thì liên kết lại);
  máy trẻ đã mở app KidFun ít nhất một lần.
- Máy phụ huynh **đã đăng nhập và cho phép nhận thông báo**. Khi chờ thông báo, để app phụ huynh **ở nền** (bấm Home):
  app phụ huynh chưa có màn hình riêng cho loại thông báo mới này (làm ở tuần 7), nên nếu app đang mở có thể không
  hiện banner.

## Bước 1 — Dùng máy lúc 22h–23h: KHÔNG được báo

1. Khoảng **22:15**, trên máy trẻ chơi một game hoặc xem YouTube khoảng **20 phút**.
2. Chờ tới khoảng **23:30**.

**Kết quả mong đợi**
- [ ] Máy phụ huynh **không** nhận thông báo "Cảnh báo sử dụng".
- [ ] Logcat (tag `Tier1Client`) **không** có dòng `Gửi … cảnh báo tầng 1`.

## Bước 2 — Dùng máy sau nửa đêm: PHẢI báo

1. Trong **cùng một giờ** sau nửa đêm (vd **1:05–1:25**), trên máy trẻ chơi game hoặc xem YouTube liên tục khoảng
   **15–20 phút**. Ghi lại giờ bắt đầu.
2. Để máy trẻ ở đó (màn hình tắt cũng được, nhưng **có mạng**), chờ tối đa **40 phút**.

**Kết quả mong đợi**
- [ ] Máy phụ huynh nhận thông báo tiêu đề **"Cảnh báo sử dụng của <tên bé>"**; nội dung đúng giờ (vd "lúc 1h"),
      đúng loại app (chơi game / xem video…), số phút gần đúng.
- [ ] Logcat máy trẻ có dòng `Gửi 1 cảnh báo tầng 1, HTTP 200`.
- [ ] Logcat **không** có dòng `Luật tầng 1 lỗi`.
- [ ] Ghi thời gian từ lúc bắt đầu dùng máy tới lúc nhận thông báo vào bảng (dùng cho câu hỏi nghiên cứu về độ trễ).

## Bước 3 — Dùng tiếp trong cùng giờ: KHÔNG báo lần 2

1. Ngay sau khi nhận thông báo ở bước 2, **vẫn trong cùng giờ đó** (vd trước 2:00), dùng thêm khoảng 10 phút.
2. Chờ tối đa 40 phút.

**Kết quả mong đợi**
- [ ] **Không** nhận thông báo thứ hai cho cùng giờ đó.
- [ ] Nếu đã sang **giờ mới** (vd 2:xx) mà trong giờ mới vẫn dùng ≥ 10 phút thì **được phép** có thông báo mới cho giờ
      mới — ghi lại có hay không.

## Bước 4 — Gỡ liên kết thì không còn cảnh báo

1. Gỡ liên kết máy trẻ trên máy phụ huynh.
2. Trong khung 0h–6h (đêm đó hoặc đêm sau) dùng máy trẻ ≥ 15 phút trong một giờ, chờ 40 phút.

**Kết quả mong đợi**
- [ ] Không có thông báo "Cảnh báo sử dụng" nào.

## Bước 5 (tuỳ chọn) — Luật "tăng đột biến"

Bước này cần Khanh nạp một "mức thường ngày" giả cho hồ sơ test (cần khoá `CRON_SECRET` của server).

1. Báo Khanh **giờ** bạn sẽ test (vd 20h hôm nay) và **tên hồ sơ**. Khanh nạp mức thường ngày giả: ở giờ đó bé thường
   chỉ xem video khoảng 2 phút.
2. Gỡ liên kết rồi liên kết lại máy trẻ (để app tải mức thường ngày mới ngay, không phải chờ 6 giờ).
3. Trong giờ đã hẹn, xem YouTube liên tục **≥ 20 phút**, chờ tối đa 40 phút.

**Kết quả mong đợi**
- [ ] Phụ huynh nhận thông báo kiểu "Bé xem video lúc 20h gấp … lần so với bình thường (… phút, thường khoảng 2 phút)."

## Ghi chép

| Mục | Giá trị |
|---|---|
| Mã commit | |
| Bước 1: giờ dùng máy, có thông báo không | |
| Bước 2: giờ bắt đầu dùng → giờ nhận thông báo (độ trễ, phút) | |
| Bước 2: nội dung thông báo (chép nguyên văn) | |
| Bước 3: có thông báo lần 2 trong cùng giờ không | |
| Bước 4: kết quả | |
| Bước 5 (nếu làm): nội dung thông báo | |
