# 06 — Chẩn đoán: vì sao server không nhận dữ liệu dùng app

**Vấn đề (2026-10-31):** trên production **không có dòng dữ liệu dùng app nào** từ máy trẻ — cả luồng gửi theo
ngày (5 phút/lần, bảng `AppUsageLog`, 0 dòng trong 14 ngày) lẫn luồng theo giờ (`AppUsageHourly`, 0 dòng từ
trước tới nay). Server đã kiểm tra là nhận bình thường, nên lỗi nằm ở **phía máy trẻ không gửi lên**. Luồng này
chỉ để thu log tìm chỗ nó dừng — **chưa cần đạt/không đạt**, chỉ cần gửi đủ log.

**Cần:** đã làm xong [00-chuan-bi.md](00-chuan-bi.md), máy trẻ (máy ảo được) đã liên kết, bản **debug** build từ
`develop` mới nhất. Khoảng **20 phút**, máy ảo phải **chạy liên tục** suốt bài test (không tắt/ngủ giữa chừng).

> ⏱ Làm xong thì **báo Khanh ngay trong vòng 1 giờ** — log server (Vercel) chỉ giữ 1 giờ, quá giờ là mất bằng chứng.

## Bước 1 — Ghi lại môi trường

```
git rev-parse --short HEAD
adb devices
adb shell getprop ro.build.version.release
```

- [ ] Ghi mã commit, tên máy ảo, bản Android vào bảng **Ghi chép**.

## Bước 2 — Kiểm tra quyền Usage Access

```
adb shell cmd appops get com.kidfun.mobile GET_USAGE_STATS
adb shell dumpsys usagestats | grep -c "package=com.android.chrome"
```

**Kết quả mong đợi**
- [ ] Dòng đầu có `allow` (nếu là `default` / `ignore` / `deny` → ghi lại, đó có thể chính là nguyên nhân).
- [ ] Dòng thứ hai ra một số **> 0** (Android có ghi sự kiện dùng app trên máy ảo này).

## Bước 3 — Bật log rồi tạo dữ liệu

1. Mở một terminal, chạy lệnh sau và **để nó chạy suốt bài test**, lưu ra file:
   ```
   adb logcat -c
   adb logcat -s HourlyUsageWorker WM-WorkerWrapper WM-SystemJobScheduler flutter > log-06.txt
   ```
2. Trên máy trẻ mở app KidFun, vào **màn hình chính của trẻ** (dashboard). Ghi giờ.
3. Mở **Chrome** ~2 phút, rồi **Settings** ~2 phút, rồi quay lại KidFun. Ghi giờ.
4. Để KidFun mở ở dashboard, chờ **ít nhất 8 phút** (luồng theo ngày chạy 5 phút/lần).

## Bước 4 — Xem lịch chạy nền

Ở một terminal khác:

```
adb shell dumpsys jobscheduler | grep -B2 -A8 com.kidfun.mobile > jobs-06.txt
```

Rồi dừng lệnh logcat ở bước 3 (Ctrl+C). Ghi giờ kết thúc.

**Kết quả mong đợi** (chỉ để đối chiếu, không đạt cũng không sao — cứ gửi file)
- [ ] `log-06.txt` có dòng chứa `HOURLY` hoặc `HourlyUsageWorker` hoặc `usage`.
- [ ] `jobs-06.txt` không rỗng (có lịch chạy nền của KidFun).
- [ ] `log-06.txt` **không** có dòng `Lên lịch thất bại`, `thất bại`, `từ chối`, `Exception`.

## Gửi cho Khanh

1. Hai file `log-06.txt` và `jobs-06.txt`.
2. Output của bước 1 và bước 2 (copy cả lệnh lẫn kết quả).
3. Bảng **Ghi chép** dưới đây.

## Ghi chép

| Mục | Giá trị |
|---|---|
| Mã commit | |
| Máy ảo / Android | |
| Bước 2: kết quả appops (`allow`/…) | |
| Bước 2: số sự kiện Chrome | |
| Bước 3: giờ mở dashboard | |
| Bước 3: giờ dùng Chrome / Settings | |
| Bước 4: giờ kết thúc | |
| Ghi chú khác | |
