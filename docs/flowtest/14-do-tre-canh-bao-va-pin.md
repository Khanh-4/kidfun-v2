# Luồng 14 — Đo độ trễ cảnh báo tầng 1 và đo pin (đồ án, T8.1 + T8.2)

**Mục đích:** lấy số liệu thật cho câu hỏi nghiên cứu RQ4: cảnh báo trên máy trẻ (tầng 1) đến tay phụ huynh **nhanh
hơn bao nhiêu** so với chấm theo lô ban đêm, báo **đúng / sai** bao nhiêu lần, và app trẻ **tốn pin hơn bao nhiêu**
so với bản cũ.

Luồng này **không kiểm tra tính năng mới**, chỉ đo. Mỗi lần chạy phải ghi **giờ chính xác tới phút** vào bảng ở cuối
file. Phần A đo độ trễ, phần B đo pin. **Không** làm hai phần cùng lúc trên cùng máy.

| Phần | Nội dung | Thời gian | Cần |
|---|---|---|---|
| A1 | Dùng máy lúc 0h–2h sáng (luật khuya) | 3 đêm × ~40 phút mỗi máy | ≥ 2 máy trẻ khác dòng |
| A2 | Chơi game đột biến buổi chiều (luật tăng đột biến) | 3 buổi chiều × ~3 giờ mỗi máy | Khánh nạp mức thường ngày giả |
| B | Đo pin 24 giờ: bản cũ (mốc) và bản mới | 2 × 24 giờ | 1 máy, bản release |

Nhánh: **`develop`** mới nhất, bản **release** (`flutter build apk --release`). Ghi mã commit (`git rev-parse --short HEAD`).

## Quy tắc chung cho phần A

1. **Máy trẻ chỉ dùng theo kịch bản** trong những ngày đo. Có người khác dùng máy ngoài kịch bản thì ghi lại giờ đó,
   nếu không Khánh sẽ đếm nhầm thành báo sai.
2. **Đồng hồ:** điện thoại để giờ tự động (theo mạng). Giờ bắt đầu = phút đầu tiên mở game hoặc video.
3. **Phụ huynh không bấm "Được phép"** trong suốt phần A, vì nút này nới ngưỡng và làm sai các lần đo sau. Muốn phản
   hồi thì chỉ bấm "Đúng là bất thường".
4. Máy trẻ **có mạng** (Wi-Fi), **không** tắt tối ưu pin (để như người dùng thật). Máy phụ huynh để app **chạy nền**.
5. Giờ nhận = giờ hiện trên thông báo ở máy phụ huynh. Kéo thanh thông báo xuống để xem, hoặc chụp màn hình.
6. Mỗi lần chạy phải nằm gọn trong **một giờ đồng hồ** (vd 0:05–0:20). Luật chấm theo từng giờ, và mỗi giờ chỉ báo
   một lần.

Theo thiết kế, máy trẻ kiểm tra luật **30 phút một lần**. Luật khuya cần ≥ 10 phút trong một giờ, nên độ trễ dự kiến
khoảng **10–40 phút**. Luật tăng đột biến cần ≥ 20 phút, nên dự kiến **20–50 phút**. Quá 60 phút vẫn ghi lại, đó là
số liệu cần đo (Android có thể hoãn tác vụ nền khi màn hình tắt).

## A1 — Luật khuya: dùng máy lúc 0h–2h sáng

Mỗi đêm có **2 lần chạy** ở hai giờ khác nhau. Làm **3 đêm** trên **mỗi máy**, tổng ≥ 6 lần mỗi máy.

| Lần | Dùng máy | Sau đó |
|---|---|---|
| Đêm X – lần 1 | **00:05 → 00:20** chơi game hoặc xem YouTube liên tục 15 phút | Tắt màn hình, để máy yên |
| Đêm X – lần 2 | **01:35 → 01:50** dùng liên tục 15 phút | Tắt màn hình, để máy yên tới 02:45 |
| Đối chứng (1 trong 3 đêm) | **22:15 → 22:20** chỉ dùng **5 phút** | Không được báo (dưới ngưỡng 10 phút) |

**Mong đợi**
- [ ] Mỗi lần chạy có đúng **1** thông báo "Cảnh báo sử dụng của <tên bé>", nội dung đúng giờ ("lúc 0h", "lúc 1h"),
      đúng loại app.
- [ ] Lần đối chứng **không** có thông báo.
- [ ] Không nhận thông báo cho giờ không có lần chạy.

> Nếu bé test **thường** thức khuya (mức thường ngày của giờ đó > 3 phút) thì luật khuya sẽ không báo. Đây là thiết kế,
> không phải lỗi. Khánh sẽ kiểm tra mức thường ngày trước đêm đầu tiên (phần "Dành cho Khánh").

## A2 — Luật tăng đột biến: chơi game buổi chiều

**Trước mỗi buổi:** nhắn Khánh "bắt đầu A2 hôm nay" + tên hồ sơ + **tên game sẽ chơi**, **trước 08:00 sáng**.
Dùng cùng một game cho mọi lần chạy. Khánh nạp mức thường ngày giả:
lúc 15h, 16h, 17h bé thường chỉ chơi game khoảng 2 phút. Máy trẻ tự tải lại mức thường ngày trong vòng 6 giờ, nên tới
15h là đã có. **Không** gỡ liên kết máy trẻ.

Mỗi buổi chiều có 2 lần chạy và 1 lần đối chứng. Làm **3 buổi** trên **mỗi máy**.

| Lần | Dùng máy | Mong đợi |
|---|---|---|
| Lần 1 | **15:05 → 15:35** chơi **một game** liên tục 30 phút | Có thông báo "chơi game lúc 15h gấp … lần" |
| Đối chứng | **16:05 → 16:15** chơi game **10 phút** | **Không** báo (dưới 20 phút) |
| Lần 2 | **17:05 → 17:35** chơi game liên tục 30 phút | Có thông báo cho lúc 17h |

**Mong đợi**
- [ ] Lần 1 và lần 2 mỗi lần có đúng 1 thông báo, câu kiểu "Bé chơi game lúc 15h gấp … lần so với bình thường
      (… phút, thường khoảng 2 phút)".
- [ ] Lần đối chứng không có thông báo.

## B — Đo pin: bản cũ (mốc) và bản mới

Làm theo [04-do-pin.md](04-do-pin.md) (chọn đúng bản code) và
[docs/thesis/04-huong-dan-do-pin.md](../thesis/04-huong-dan-do-pin.md) (các bước đo 24 giờ). Có hai bổ sung so
với hướng dẫn đó:

1. **Thêm 3 lệnh ở Bước 3 (kết thúc)**, chạy ngay sau các lệnh cũ. Đặt tên file có chữ `A` hoặc `B`:
   ```
   adb shell dumpsys netstats detail > netstats_A.txt
   adb shell dumpsys jobscheduler > jobscheduler_A.txt
   adb shell dumpsys alarm > alarm_A.txt
   ```
   Các file này dùng để đếm **số lần đánh thức máy** và **số request mạng** của app (T8.2.2).
2. **Không làm phần A trong 24 giờ đo pin.** Máy chỉ dùng theo kịch bản pin (1 giờ YouTube, 30 phút game, 30 phút web).

- [ ] Đủ 2 lần đo (A = `5b0a0b0`, B = `develop`), cùng máy, cùng kịch bản.
- [ ] Mỗi lần đủ 6 file: 3 file của hướng dẫn cũ + `netstats`, `jobscheduler`, `alarm`.

## Ghi chép — phần A (mỗi lần chạy một dòng)

| Máy | Ngày | Lần (A1-0h / A1-1h / A1-đối chứng / A2-15h / A2-16h đối chứng / A2-17h) | Giờ bắt đầu | Giờ kết thúc | Có thông báo? | Giờ nhận thông báo | Nội dung thông báo (chép nguyên văn) |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
| | | | | | | | |
| | | | | | | | |

Máy dùng: (mẫu máy, Android, mã commit) — máy 1: …; máy 2: …
Giờ máy bị dùng ngoài kịch bản (nếu có): …

## Ghi chép — phần B

Dùng bảng "Ghi chép" trong [04-do-pin.md](04-do-pin.md), thêm một dòng: "Đủ file netstats / jobscheduler / alarm?".

---

### Dành cho Khánh

**Trước A1: kiểm tra mức thường ngày của giờ khuya.** Lấy `deviceCode` của máy trẻ (bảng `Device`):

```bash
curl -s "https://kidfun-backend.vercel.app/api/child/behavior-baseline?deviceCode=<CODE>" | python3 -c '
import json, sys, collections
b = json.load(sys.stdin)["data"]["baseline"]
tot = collections.Counter()
for e in (b or {}).get("baseline", []):
    if e["hour"] <= 5 or e["hour"] >= 22:
        tot[(e["dayType"], e["hour"])] += e["mean"]
print("baseline = null" if b is None else dict(tot) or "không có ô khuya nào (tổng = 0)")'
```

Giờ nào `total > 3` thì luật khuya không báo ở giờ đó. Khi đó đổi lần chạy A1 sang giờ khác trong 0h–5h.
`baseline` là `null` thì luật khuya vẫn chạy, nhưng chỉ trong 0h–5h.

**Trước mỗi buổi A2 (sau khi `thesis-nightly` của đêm trước đã chạy xong**, vì tác vụ ban đêm ghi đè mức thường ngày):

```bash
curl -s "https://kidfun-backend.vercel.app/api/child/behavior-baseline?deviceCode=<CODE>" | python3 -c '
import csv, json, sys, datetime as dt
PID, HOURS = <ID>, (15, 16, 17)
b = json.load(sys.stdin)["data"]["baseline"]
if b is None:  # bé chưa có mức thường ngày: dựng khung như ml/tier1/rules.py::build_baseline
    tomorrow = (dt.datetime.utcnow() + dt.timedelta(hours=7)).date() + dt.timedelta(days=1)
    b = {"profileId": PID, "validUntil": f"{tomorrow}T00:00:00+07:00", "nightWindow": ["22:00", "06:00"],
         "baseline": [], "categories": {}, "dayTypes": {},
         "rules": {"nightMinMinutes": 10, "nightUsualMaxMinutes": 3.0, "spikeRatio": 3.0, "spikeMinMinutes": 20}}
if not b.get("categories"):  # thiếu thì máy trẻ coi mọi app là "other" và luật game không bao giờ báo
    b["categories"] = {r["packageName"]: r["category"] for r in csv.DictReader(open("ml/config/app_categories.csv"))}
b["baseline"] = [e for e in b["baseline"] if not (e["cat"] == "game" and e["hour"] in HOURS)] + [
    {"dayType": d, "hour": h, "cat": "game", "mean": 2, "std": 1} for h in HOURS for d in ("school", "weekend", "off")]
print(json.dumps({"baselines": [{"profileId": PID, "payload": b, "validUntil": b["validUntil"]}]}))' > /tmp/baseline_a2.json

curl -s -X PUT https://kidfun-backend.vercel.app/api/cron/behavior-baselines \
  -H "Authorization: Bearer $CRON_SECRET" -H 'Content-Type: application/json' -d @/tmp/baseline_a2.json
```

Chạy lệnh từ **thư mục gốc repo** (đoạn script đọc `ml/config/app_categories.csv`). Game người test chơi phải có
`packageName` trong file đó với nhóm `game`. Chưa có thì hỏi tên gói (Cài đặt → Ứng dụng) rồi thêm vào csv trước
buổi A2, nếu không máy trẻ xếp game vào nhóm `other` và sẽ không báo.

**Tính kết quả (T8.1.3, T8.1.4):**
- Độ trễ tầng 1 = giờ nhận thông báo − giờ bắt đầu. Đối chiếu với `BehaviorAlert.createdAt` / `notifiedAt`
  (`source = 'TIER1'`, `slotStart` = ô giờ) để tách hai đoạn: máy trẻ phát hiện (createdAt − bắt đầu) và FCM tới
  phụ huynh (giờ nhận − notifiedAt).
- Độ trễ chấm theo lô = giờ bắt đầu lần chạy `thesis-nightly` kế tiếp (tab Actions) − giờ bắt đầu. Đây là mức sớm
  nhất phụ huynh có thể biết nếu chỉ có tầng 2.
- Precision / recall: lần chạy có thông báo = TP; lần chạy không có = FN; thông báo ở giờ không có lần chạy hoặc ở lần
  đối chứng = FP (trừ các giờ người test đã ghi là dùng ngoài kịch bản).

**Rủi ro của phần B:** bản mốc `5b0a0b0` còn dùng Socket.IO, mà server hiện tại đã bỏ Socket.IO (PR #333). App cũ
có thể kết nối lại liên tục, làm pin của bản mốc tốn hơn thực tế, tức là lợi cho bản mới. Khi phân tích, đếm số
lần kết nối lại trong `bugreport` / `netstats` của lần A và ghi vào hạn chế (`docs/thesis/11`).
