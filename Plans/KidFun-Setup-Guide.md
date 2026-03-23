# KidFun V3 — Hướng Dẫn Setup & GitHub Workflow

> Hướng dẫn cho cả nhóm: Khanh (Backend) + Bạn (Frontend)

---

## Phần 1: Setup Môi Trường Dev

### 1.1 Khanh — Backend (WSL Ubuntu + VSCode)

#### Kiểm tra công cụ đã có
```bash
# Trong WSL Ubuntu
node -v          # Cần v18+ (khuyến nghị v20 LTS)
npm -v           # Cần v9+
git --version    # Cần v2.30+
```

#### Cài thêm nếu thiếu
```bash
# Node.js v20 LTS (nếu chưa có hoặc version cũ)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Prisma CLI (global)
npm install -g prisma

# PM2 (cho deploy sau này)
npm install -g pm2
```

#### VSCode Extensions cần thiết (Backend)
```
- Prisma (prisma.prisma) — syntax highlight cho schema.prisma
- ESLint (dbaeumer.vscode-eslint)
- REST Client (humao.rest-client) — test API ngay trong VSCode
- GitLens (eamodio.gitlens) — xem git blame, history
- Thunder Client (rangav.vscode-thunder-client) — Postman alternative
```

#### Cài đặt qua command line
```bash
code --install-extension prisma.prisma
code --install-extension dbaeumer.vscode-eslint
code --install-extension humao.rest-client
code --install-extension eamodio.gitlens
code --install-extension rangav.vscode-thunder-client
```

---

### 1.2 Bạn — Frontend (Flutter + Android)

#### Cài Flutter SDK
```bash
# Trong WSL Ubuntu (nếu bạn cũng dùng WSL)
# HOẶC trên Windows trực tiếp (khuyến nghị cho Flutter)

# Cách 1: Windows (khuyến nghị cho Flutter + Android Studio)
# Download Flutter SDK từ: https://docs.flutter.dev/get-started/install/windows/mobile
# Giải nén vào C:\flutter
# Thêm C:\flutter\bin vào System PATH

# Cách 2: WSL Ubuntu
sudo snap install flutter --classic
flutter doctor
```

#### Cài Android Studio
```
1. Download Android Studio: https://developer.android.com/studio
2. Cài đặt, mở Android Studio
3. SDK Manager → cài Android SDK 34 (Android 14)
4. SDK Manager → SDK Tools → cài:
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
   - Android SDK Platform-Tools
   - Android Emulator (backup, có máy thật rồi)
5. AVD Manager → tạo emulator (backup)
```

#### Kiểm tra Flutter
```bash
flutter doctor -v
# Phải thấy:
# [✓] Flutter
# [✓] Android toolchain
# [✓] Android Studio
# [✓] Connected device (khi cắm Android thật)
```

#### VSCode Extensions cần thiết (Frontend)
```
- Flutter (Dart-Code.flutter)
- Dart (Dart-Code.dart-code)
- Kotlin (fwcd.kotlin)
- GitLens (eamodio.gitlens)
- Error Lens (usernamehw.errorlens)
```

#### Cài đặt qua command line
```bash
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code
code --install-extension fwcd.kotlin
code --install-extension eamodio.gitlens
code --install-extension usernamehw.errorlens
```

---

### 1.3 Cả nhóm — Tài khoản cần tạo

| Dịch vụ | Ai cần | Link | Ghi chú |
|---------|--------|------|---------|
| **Supabase** | Khanh | https://supabase.com | Tạo project → lấy PostgreSQL connection string |
| **Oracle Cloud** | Khanh | https://cloud.oracle.com | Đăng ký Always Free → tạo VM ARM |
| **Firebase** | Cả 2 | https://console.firebase.google.com | Tạo project → enable Cloud Messaging |
| **Google Maps** | Bạn Frontend | https://console.cloud.google.com | Enable Maps SDK for Android → lấy API key |
| **Anthropic** | Khanh | https://console.anthropic.com | Claude API key (cho Sprint 9) |

---

## Phần 2: GitHub Repo Structure

### 2.1 Cấu trúc thư mục V3

Repo `kidfun-v2` hiện tại giữ nguyên code V2 trên branch `main`. 
V3 sẽ phát triển trên branch `develop` với cấu trúc mới:

```
kidfun-v2/
├── backend/                    # ← GIỮ NGUYÊN, Khanh refactor tại đây
│   ├── prisma/
│   │   ├── schema.prisma       # Cập nhật: datasource → PostgreSQL
│   │   └── migrations/
│   ├── src/
│   │   ├── controllers/
│   │   ├── routes/
│   │   ├── middleware/
│   │   ├── services/
│   │   └── server.js
│   ├── .env.example
│   └── package.json
│
├── mobile/                     # ← MỚI, Flutter project
│   ├── lib/
│   │   ├── core/               # Theme, constants, utils, dio client
│   │   ├── features/
│   │   │   ├── auth/           # Login, Register, Forgot Password
│   │   │   ├── profile/        # Profile CRUD
│   │   │   ├── device/         # Device management, QR code
│   │   │   ├── time_limit/     # Time settings, countdown
│   │   │   ├── soft_warning/   # Soft Warning system ★
│   │   │   ├── app_control/    # App blocking, per-app limit
│   │   │   ├── location/       # GPS, geofence, map, SOS
│   │   │   ├── monitoring/     # Notification, call, SMS logs
│   │   │   ├── ai_alerts/      # AI analysis alerts
│   │   │   └── reports/        # Charts, statistics
│   │   ├── shared/             # Shared widgets, models
│   │   └── main.dart
│   ├── android/
│   │   └── app/src/main/kotlin/  # Native Android (Kotlin)
│   ├── ios/                    # iOS (minimal, future work)
│   ├── pubspec.yaml
│   └── README.md
│
├── docs/                       # ← MỚI, tài liệu
│   ├── api-contract.md         # API endpoints cho Frontend tham khảo
│   ├── sprint-plan.md          # Sprint plan
│   └── database-schema.md     # Database schema
│
├── frontend/                   # ← V2 code (giữ nguyên, không sửa)
│   ├── parent-dashboard/
│   └── child-monitor/
│
├── .gitignore
├── CLAUDE.md
└── README.md                   # Cập nhật cho V3
```

---

## Phần 3: Git Branching Strategy

### 3.1 Mô hình nhánh

```
main (V2 stable — KHÔNG AI PUSH TRỰC TIẾP)
  │
  └── develop (V3 development — nhánh tích hợp chính)
        │
        ├── feature/backend/postgresql-migration     (Khanh)
        ├── feature/backend/auth-refactor            (Khanh)
        ├── feature/backend/device-api               (Khanh)
        ├── feature/backend/time-limit-api           (Khanh)
        ├── feature/backend/socket-io                (Khanh)
        ├── feature/backend/location-api             (Khanh)
        ├── feature/backend/ai-pipeline              (Khanh)
        │
        ├── feature/mobile/project-setup             (Bạn)
        ├── feature/mobile/auth-screens              (Bạn)
        ├── feature/mobile/profile-management        (Bạn)
        ├── feature/mobile/device-qr                 (Bạn)
        ├── feature/mobile/time-settings             (Bạn)
        ├── feature/mobile/soft-warning              (Bạn)
        ├── feature/mobile/native-android            (Bạn)
        ├── feature/mobile/gps-map                   (Bạn)
        │
        ├── fix/backend/...                          (bug fixes)
        ├── fix/mobile/...                           (bug fixes)
        │
        └── docs/...                                 (tài liệu)
```

### 3.2 Quy tắc đặt tên branch

```
Tính năng:  feature/<area>/<tên-ngắn-gọn>
Bug fix:    fix/<area>/<mô-tả-bug>
Tài liệu:  docs/<tên-tài-liệu>
Hotfix:     hotfix/<mô-tả>

<area> = backend | mobile | docs
```

**Ví dụ:**
```
feature/backend/postgresql-migration
feature/mobile/auth-screens
fix/backend/jwt-refresh-token
fix/mobile/countdown-timer-bug
docs/api-contract
hotfix/socket-disconnect
```

### 3.3 Quy tắc commit message

```
feat:       Tính năng mới
fix:        Sửa lỗi
refactor:   Tái cấu trúc code (không thay đổi logic)
docs:       Cập nhật tài liệu
style:      Format code, không thay đổi logic
test:       Thêm/sửa test
chore:      Cập nhật config, dependencies
perf:       Tối ưu hiệu năng
```

**Format:** `<type>(<scope>): <mô tả ngắn>`

**Ví dụ:**
```
feat(backend): migrate SQLite to PostgreSQL
feat(mobile): add login screen with JWT auth
fix(backend): handle expired refresh token
refactor(mobile): extract countdown timer widget
docs: update API contract for device endpoints
chore(backend): update prisma to v6
```

---

## Phần 4: Setup GitHub — Từng Bước

### 4.1 Tạo branch develop từ main

```bash
# Clone repo (nếu chưa có)
cd ~
git clone git@github.com:Khanh-4/kidfun-v2.git
cd kidfun-v2

# Tạo branch develop từ main
git checkout main
git pull origin main
git checkout -b develop
git push -u origin develop
```

### 4.2 Invite bạn vào repo

```
GitHub → kidfun-v2 → Settings → Collaborators → Add people
→ Nhập GitHub username của bạn → Invite
→ Bạn accept invitation qua email
```

### 4.3 Setup Branch Protection Rules

#### Bảo vệ branch `main`:
```
GitHub → kidfun-v2 → Settings → Branches → Add branch ruleset

Rule name: Protect main
Target: main

Bật các rule sau:
☑ Restrict creations          — Không ai tạo branch main mới
☑ Restrict updates            — Không ai push trực tiếp
☑ Restrict deletions          — Không ai xóa main
☑ Require a pull request before merging
  ☑ Required approvals: 1     — Cần Khanh approve
  ☑ Dismiss stale pull request approvals when new commits are pushed
☑ Block force pushes          — Cấm force push

Bypass list: KHÔNG AI (kể cả Khanh)
```

#### Bảo vệ branch `develop`:
```
GitHub → Add another ruleset

Rule name: Protect develop
Target: develop

Bật các rule sau:
☑ Restrict deletions          — Không ai xóa develop
☑ Require a pull request before merging
  ☑ Required approvals: 1     — Cần Khanh approve
☑ Block force pushes          — Cấm force push

Bypass list: KHÔNG AI
```

### 4.4 Set default branch thành develop

```
GitHub → kidfun-v2 → Settings → General → Default branch
→ Đổi từ main → develop
→ Update

Lý do: Khi bạn tạo PR, target mặc định sẽ là develop (không phải main)
```

---

## Phần 5: Workflow Làm Việc Hàng Ngày

### 5.1 Quy trình tạo feature mới

```bash
# 1. Luôn bắt đầu từ develop mới nhất
git checkout develop
git pull origin develop

# 2. Tạo feature branch
git checkout -b feature/backend/postgresql-migration

# 3. Code, commit thường xuyên
git add .
git commit -m "feat(backend): update prisma datasource to postgresql"

git add .
git commit -m "feat(backend): add supabase connection string config"

# 4. Push lên GitHub
git push -u origin feature/backend/postgresql-migration

# 5. Tạo Pull Request trên GitHub
#    - Base: develop (KHÔNG PHẢI main)
#    - Compare: feature/backend/postgresql-migration
#    - Ghi mô tả rõ ràng
#    - Assign Khanh review
```

### 5.2 Quy trình Review & Merge (Khanh là reviewer)

```
1. Bạn Frontend tạo PR → target develop
2. Khanh nhận notification
3. Khanh review code:
   - Approve ✅ → Merge (squash merge khuyến nghị)
   - Request changes ❌ → Comment ghi rõ cần sửa gì
4. Sau khi merge → Bạn Frontend xóa feature branch
5. Bạn Frontend pull develop mới nhất trước khi tạo feature tiếp
```

### 5.3 Khanh tự review code của mình

```
Khanh cũng tạo PR cho code của mình (không push thẳng develop).
Lý do: 
- Giữ history sạch
- Có thể tự review lại trước khi merge
- Bạn Frontend cũng có thể xem code backend

Quy trình: Tạo PR → tự review → tự approve → merge
(GitHub cho phép owner approve PR của chính mình)
```

### 5.4 Merge develop → main (chỉ ở milestone)

```bash
# Chỉ merge vào main tại các mốc quan trọng:
# - Sprint 6 (demo giữa kỳ)
# - Sprint 10 (bảo vệ hội đồng)

# Tạo PR: develop → main
# Review kỹ, test đầy đủ
# Merge + tạo release tag

git checkout main
git pull origin main
git tag -a v3.0-sprint6 -m "Sprint 6: Mid-term demo"
git push origin v3.0-sprint6
```

---

## Phần 6: File .gitignore Cập Nhật

```gitignore
# Dependencies
node_modules/
.dart_tool/
.packages

# Environment
.env
.env.local
.env.production

# Build outputs
build/
dist/
dist-electron/
*.apk
*.aab
*.ipa

# IDE
.idea/
.vscode/settings.json
*.swp
*.swo

# Database (local dev)
*.db
*.db-journal

# OS
.DS_Store
Thumbs.db

# Flutter
mobile/.flutter-plugins
mobile/.flutter-plugins-dependencies
mobile/android/.gradle/
mobile/android/local.properties
mobile/ios/Pods/
mobile/ios/.symlinks/

# Firebase
google-services.json
GoogleService-Info.plist

# Prisma
backend/prisma/*.db
```

---

## Phần 7: Checklist Setup Hoàn Tất

### Khanh (Backend)
- [ ] Node.js v20 LTS cài trên WSL
- [ ] VSCode extensions đã cài
- [ ] Git config đã set (name, email)
- [ ] SSH key GitHub đã setup
- [ ] Clone repo, tạo branch develop, push
- [ ] Invite bạn vào repo
- [ ] Setup branch protection (main + develop)
- [ ] Đổi default branch → develop
- [ ] Tạo Supabase project
- [ ] Tạo Oracle Cloud account
- [ ] Tạo Firebase project

### Bạn (Frontend)
- [ ] Flutter SDK đã cài
- [ ] Android Studio + Android SDK đã cài
- [ ] `flutter doctor` passed
- [ ] VSCode extensions đã cài
- [ ] Git config đã set (name, email)
- [ ] SSH key GitHub đã setup
- [ ] Accept invitation repo kidfun-v2
- [ ] Clone repo, checkout develop
- [ ] Android thật kết nối được (`flutter devices`)
- [ ] Tạo Firebase account (cùng project với Khanh)

---

## Phần 8: Lệnh Git Thường Dùng

```bash
# Xem trạng thái
git status
git log --oneline -10

# Chuyển branch
git checkout develop
git checkout -b feature/backend/new-feature

# Cập nhật develop mới nhất
git checkout develop
git pull origin develop

# Rebase feature branch lên develop mới nhất (nếu develop đã thay đổi)
git checkout feature/backend/my-feature
git rebase develop
# Nếu conflict → resolve → git rebase --continue

# Xóa branch local sau khi đã merge
git branch -d feature/backend/old-feature

# Xem tất cả branch
git branch -a

# Stash (lưu tạm khi cần chuyển branch)
git stash
git stash pop
```

---

## Tóm tắt Workflow

```
  ┌─────────────────────────────────────────────┐
  │  1. git checkout develop && git pull         │
  │  2. git checkout -b feature/backend/xxx      │
  │  3. Code + commit thường xuyên               │
  │  4. git push origin feature/backend/xxx      │
  │  5. Tạo PR trên GitHub → target: develop     │
  │  6. Khanh review → Approve → Merge           │
  │  7. Xóa feature branch                       │
  │  8. Lặp lại từ bước 1                        │
  └─────────────────────────────────────────────┘
  
  Milestone (Sprint 6, 10):
  develop → PR → main → tag release
```
