# KidFun V3 — Sprint 4 BUGFIX Round 3 — BACKEND (Khanh)

> **Dựa trên:** Test results lần 3 + Railway logs
> **Bugs:** 2 bugs backend

---

## Bug 1 (CRITICAL): Child nhận sai time limit — luôn hiện 2 giờ

### Triệu chứng

- Parent set time limit 5 phút cho profile "Archi" (profileId: 13)
- Child mở app → countdown hiện **2:00:00** (2 giờ = default) thay vì **00:05:00**
- Logs: `PUT /api/profiles/13/time-limits 200` → lưu thành công
- Logs: `GET /api/child/today-limit?deviceCode=BE4B.251210.005 200` → trả 200 nhưng data có thể sai

### Debug cần làm

**Bước 1:** Test API trực tiếp để xem response:

```bash
curl "https://kidfun-backend-production.up.railway.app/api/child/today-limit?deviceCode=BE4B.251210.005"
```

Kiểm tra response:
- `profileId` có đúng là 13 không?
- `limitMinutes` có đúng là 5 không?
- `remainingMinutes` có đúng không?
- `dayOfWeek` có khớp với ngày hôm nay không?

**Bước 2:** Nếu `profileId` sai (không phải 13) → device link với profile khác. Kiểm tra:

```bash
# Xem device 48 link với profile nào
curl "https://kidfun-backend-production.up.railway.app/api/devices" \
  -H "Authorization: Bearer <token>"
```

**Bước 3:** Nếu `dayOfWeek` không khớp → Parent set time limit cho ngày khác, không phải hôm nay.

### Nguyên nhân có thể

Mở file `childController.js`, hàm `getTodayLimit`:

```javascript
const today = new Date().getDay(); // 0 = Sunday
const todayLimit = device.profile.timeLimits.find(tl => tl.dayOfWeek === today);
```

**Vấn đề timezone:** `new Date().getDay()` trả ngày theo UTC trên server Railway. Nếu Việt Nam là Thứ 2 (dayOfWeek=1) nhưng UTC vẫn là Chủ nhật (dayOfWeek=0) → lấy sai time limit.

### Fix

**Branch:** `fix/backend/timezone-today-limit`

```bash
git checkout develop && git pull origin develop
git checkout -b fix/backend/timezone-today-limit
```

File sửa: `backend/src/controllers/childController.js` (hàm `getTodayLimit`)

```javascript
// ❌ CŨ: dùng UTC → sai timezone cho VN
const today = new Date().getDay();

// ✅ MỚI: dùng timezone Việt Nam (UTC+7)
const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
const today = vnNow.getDay();
```

**Áp dụng tương tự** cho tất cả chỗ tính `startOfDay` (đầu ngày):

```javascript
// ❌ CŨ:
const startOfDay = new Date();
startOfDay.setHours(0, 0, 0, 0);

// ✅ MỚI: đầu ngày theo timezone VN
const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
const startOfDay = new Date(vnNow);
startOfDay.setHours(0, 0, 0, 0);
```

**Áp dụng cho cả `heartbeat`** trong `sessionController.js` — nếu cũng có `new Date().getDay()` hoặc `setHours(0,0,0,0)`.

### Nếu không phải timezone

Nếu test API trực tiếp cho thấy `limitMinutes` đúng (= 5) nhưng Child vẫn hiện 2 giờ → bug ở frontend (Child không parse response đúng). Thêm log vào API:

```javascript
console.log(`📊 getTodayLimit: deviceCode=${deviceCode}, profileId=${device.profile.id}, today=${today}, limitMinutes=${limitMinutes}, remainingMinutes=${remainingMinutes}`);
```

### Commit & Push

```bash
git add -A
git commit -m "fix(backend): use Vietnam timezone for today-limit calculation"
git push origin fix/backend/timezone-today-limit
```
→ PR → develop → merge → deploy

---

## Bug 2: Remaining time làm tròn theo phút

> Giống Bug E từ Round 2 — chưa fix.

### Fix

**Gộp vào branch trên** hoặc tạo branch riêng:

File sửa: `backend/src/controllers/childController.js` (hàm `getTodayLimit`)

```javascript
// Tính bằng giây thay vì phút
const usedSeconds = sessions.reduce((total, s) => {
  const end = s.endTime || new Date();
  return total + (end - s.startTime) / 1000;
}, 0);
const limitSeconds = (todayLimit?.limitMinutes || 0) * 60;
const remainingSeconds = Math.max(0, Math.round(limitSeconds - usedSeconds));

return sendSuccess(res, {
  // ... các field khác giữ nguyên ...
  remainingMinutes: Math.round(remainingSeconds / 60),
  remainingSeconds: remainingSeconds,   // ★ THÊM
});
```

File sửa: `backend/src/controllers/sessionController.js` (hàm `heartbeat`)

Tương tự — thêm `remainingSeconds` vào response.

### Commit & Push

```bash
git add -A
git commit -m "fix(backend): add remainingSeconds to API, fix timezone calculation"
git push origin fix/backend/timezone-today-limit
```
→ PR → develop → merge → deploy

---

## Test sau khi fix

```bash
# 1. Verify timezone
curl "https://kidfun-backend-production.up.railway.app/api/child/today-limit?deviceCode=BE4B.251210.005"

# Response phải có:
# - dayOfWeek đúng ngày hôm nay (VN timezone)
# - limitMinutes đúng = giá trị Parent đã set
# - remainingSeconds xuất hiện
```

- [ ] `dayOfWeek` đúng ngày hôm nay (Việt Nam)
- [ ] `limitMinutes` đúng giá trị Parent đã set
- [ ] `remainingSeconds` có trong response
- [ ] Child hiện countdown đúng sau khi frontend update

---

## Checklist

| # | Task | Status |
|---|------|--------|
| 1 | Test API `today-limit` trực tiếp → xem response | ⬜ |
| 2 | Fix timezone `Asia/Ho_Chi_Minh` trong getTodayLimit | ⬜ |
| 3 | Fix timezone trong heartbeat (nếu có) | ⬜ |
| 4 | Thêm `remainingSeconds` vào getTodayLimit response | ⬜ |
| 5 | Thêm `remainingSeconds` vào heartbeat response | ⬜ |
| 6 | Thêm console.log debug cho getTodayLimit | ⬜ |
| 7 | Deploy Railway | ⬜ |
| 8 | Test API response đúng | ⬜ |
| 9 | Nhắn Frontend test lại | ⬜ |
