# Quy Tắc Làm Việc Git — BẮT BUỘC

> **Dán phần này vào cuối mỗi file task để cả hai đều nhớ**

---

## Quy trình cho MỖI task

### Bước 1: Tạo feature branch
```bash
git checkout develop
git pull origin develop
git checkout -b feature/<area>/<tên-task>
```

### Bước 2: Code + commit thường xuyên
```bash
git add -A
git commit -m "feat(backend): mô tả ngắn"
# Commit nhiều lần trong 1 task cũng được
```

### Bước 3: Push + tạo PR
```bash
git push origin feature/<area>/<tên-task>
```
→ Lên GitHub tạo **Pull Request** → **base: develop** → ghi mô tả rõ ràng

### Bước 4: Review + merge
- **Code của bạn Frontend:** Khanh review → approve → merge
- **Code của Khanh:** Tự review → bypass rules → merge

### Bước 5: Xóa branch cũ, bắt đầu task mới
```bash
git checkout develop
git pull origin develop
git branch -d feature/<area>/<tên-task-cũ>
git checkout -b feature/<area>/<tên-task-mới>
```

---

## ⚠️ KHÔNG ĐƯỢC LÀM

- ❌ Push thẳng lên `develop` hoặc `main`
- ❌ Code trực tiếp trên `develop`
- ❌ Merge mà chưa tạo PR
- ❌ Bắt đầu task mới mà chưa merge task cũ

## ✅ PHẢI LÀM

- ✅ Mỗi task = 1 feature branch riêng
- ✅ Mỗi feature branch = 1 PR
- ✅ Pull develop mới nhất TRƯỚC KHI tạo branch mới
- ✅ Commit message theo format: `feat/fix/chore(area): mô tả`

## Quy ước commit message
```
feat(backend): add Socket.IO device events
feat(mobile): implement device list screen
fix(backend): handle null deviceCode in disconnect
fix(mobile): device status not updating real-time
chore(backend): update prisma schema
docs: update API contract
```
