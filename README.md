# KidFun V2 — Hệ thống quản lý thời gian sử dụng thiết bị cho trẻ em

> Smart Parental Control System with Soft Warning Technology

Hệ thống kiểm soát thời gian sử dụng thiết bị thông minh, giúp phụ huynh quản lý và giám sát hoạt
động của trẻ em trên thiết bị di động. Dùng công nghệ cảnh báo mềm (Soft Warning) để nhắc trẻ trước
khi hết giờ, kết hợp real-time giữa app phụ huynh và app trẻ em, cùng phân tích nội dung bằng AI.

Đây là monorepo gồm 4 app chạy trên 1 backend chung: **backend API**, **parent-dashboard** và
**child-monitor** (2 web app React, đóng gói thêm bản Electron desktop), và **mobile app Flutter**
(dùng chung 1 codebase cho cả vai trò phụ huynh và trẻ em) — **app mobile hiện là trọng tâm phát
triển chính của dự án.**

## Apps trong monorepo

| App | Path | Công nghệ | Vai trò |
|-----|------|-----------|---------|
| **Backend** | `backend/` | Express + Prisma + PostgreSQL (Supabase) + Socket.IO | API cho toàn bộ hệ thống |
| **Mobile** | `mobile/` | Flutter 3.x + Riverpod + go_router | App chính — dùng cho cả Phụ huynh và Trẻ em |
| **Parent Dashboard** | `frontend/parent-dashboard/` | React 19 + Vite + MUI (+ Electron) | Web/desktop cho Phụ huynh |
| **Child Monitor** | `frontend/child-monitor/` | React 19 + Vite + MUI (+ Electron) | Web/desktop cho Trẻ em |

## Tính năng chính

- **Auth:** đăng ký/đăng nhập (email hoặc Google Sign-In native trên mobile), quên mật khẩu qua email/OTP, JWT 24h
- **Quản lý hồ sơ & thiết bị:** nhiều hồ sơ con, liên kết thiết bị qua QR code hoặc mã ghép nối (`deviceCode`, không cần auth)
- **Giới hạn thời gian:** theo từng ngày trong tuần, giảm dần (gradual reduction), giới hạn riêng theo từng app
- **Chặn nội dung:** chặn website/domain tùy chỉnh, chặn app, chặn theo danh mục web (WebCategory) kèm override theo domain
- **School Mode:** lịch học tự động theo từng ngày, danh sách app được phép dùng trong giờ học, override thủ công
- **Vị trí & an toàn:** theo dõi vị trí, geofence (khu vực an toàn) với sự kiện enter/exit, nút SOS kèm ghi âm
- **YouTube AI Safety:** theo dõi video đã xem, phân tích nội dung bằng Groq/OpenAI, cảnh báo mức độ nguy hiểm (1-5), tự động/thủ công chặn video
- **Báo cáo:** snapshot báo cáo ngày/tuần, lịch sử hoạt động chi tiết
- **Xin thêm giờ real-time:** trẻ gửi yêu cầu → phụ huynh duyệt/từ chối qua Socket.IO
- **Push notification:** FCM cho các sự kiện khi thiết bị offline (SOS, geofence, cảnh báo AI, hết giờ)
- **Thực thi trên thiết bị (Android):** chặn app qua AccessibilityService, theo dõi usage qua UsageStatsManager, khóa thiết bị qua DeviceAdmin

## Tech Stack

| Layer | Công nghệ |
|-------|-----------|
| **Backend** | Node.js, Express, Prisma ORM, **PostgreSQL (Supabase)**, Socket.IO, JWT, bcryptjs, Nodemailer, Firebase Admin, googleapis, Groq SDK, OpenAI SDK |
| **Mobile** | Flutter 3.x, Riverpod (code-gen), go_router, Dio, Firebase Messaging, socket_io_client, Mapbox, geolocator, flutter_secure_storage |
| **Parent Dashboard / Child Monitor** | React 19, Vite, Material-UI v7, React Router v7, Axios, Socket.IO Client |
| **Desktop packaging** | Electron (per-app `electron/main.cjs`, output to `dist-electron/`) |
| **Testing** | Jest + Supertest (backend), Playwright (`tests/`, E2E for the web apps), `flutter test` (mobile) |

## Cấu trúc thư mục

```
kidfun-v2/
├── backend/
│   ├── prisma/
│   │   ├── schema.prisma          # 32 models — xem docs/CODEMAPS/data.md
│   │   └── migrations/
│   ├── src/
│   │   ├── controllers/           # 23 file, per-domain business logic
│   │   ├── routes/                # 12 file route
│   │   ├── middleware/            # auth, validation, upload, error handling
│   │   ├── services/              # socketService, aiService, fcmService, firebaseService, ...
│   │   ├── workers/                # aiAnalysisWorker, reportWorker (self-scheduled)
│   │   └── server.js
│   ├── firebase-service-account.json   # KHÔNG commit — lấy từ Firebase Console
│   └── .env.example
├── frontend/
│   ├── parent-dashboard/          # port 5173 (Vite default) + Electron
│   ├── child-monitor/             # port 5174 + Electron
│   └── shared/                    # components/hooks/utils dùng chung 2 app trên
├── mobile/                        # Flutter app — trọng tâm phát triển hiện tại
│   ├── lib/
│   │   ├── core/                  # network (dio_client, socket_service), services, storage, theme
│   │   ├── features/              # auth, device, location, profile, reports, time_limit, youtube
│   │   └── shared/                # models, widgets dùng chung
│   └── android/app/src/main/kotlin/com/kidfun/mobile/   # native enforcement layer
├── tests/                         # Playwright E2E cho web app
├── scripts/get-lan-ip.js
├── docs/CODEMAPS/                 # tài liệu kiến trúc chi tiết (architecture, backend, frontend, data, dependencies)
├── CLAUDE.md                      # context cho AI assistant (gitignored, không commit)
└── package.json                   # monorepo root scripts
```

> Chi tiết đầy đủ hơn (từng route, từng model, từng service bên ngoài) nằm trong
> [`docs/CODEMAPS/`](docs/CODEMAPS/architecture.md) — README này chỉ tóm tắt.

## Yêu cầu hệ thống

- **Node.js** 18+ (khuyến nghị 20 LTS), **npm** 9+
- **Flutter SDK** ^3.11.1 (cho mobile)
- **PostgreSQL** — khuyến nghị dùng [Supabase](https://supabase.com) (free tier đủ dùng cho dev)
- **Android Studio** hoặc thiết bị Android thật (cho mobile — enforcement layer chỉ có native code cho Android, chưa hỗ trợ iOS)
- **Git** 2.30+

## Cài đặt — Backend + Web apps

### 1. Clone & cài dependencies

```bash
git clone https://github.com/Khanh-4/kidfun-v2.git
cd kidfun-v2
npm run install:all
```

### 2. Cấu hình môi trường backend

```bash
cp backend/.env.example backend/.env
```

Chỉnh `backend/.env`:

```env
# Database — tạo project trên supabase.com, lấy 2 connection string này trong Project Settings > Database
DATABASE_URL="postgresql://postgres.[project-ref]:[PASSWORD]@aws-x-region.pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://postgres.[project-ref]:[PASSWORD]@aws-x-region.pooler.supabase.com:5432/postgres"

JWT_SECRET=your-super-secret-jwt-key
JWT_EXPIRES_IN=24h

PORT=3001
HOST=0.0.0.0

# SMTP cho quên mật khẩu (Gmail App Password)
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-16-char-app-password

# CORS cho dev — Vite mặc định 5173/5174
SOCKET_CORS_ORIGIN=http://localhost:5173,http://localhost:5174

# Optional — AI content analysis (bỏ qua nếu chưa cần, feature tự degrade, check GET /api/admin/ai-status)
GROQ_API_KEY=
OPENAI_API_KEY=
```

Đặt file `backend/firebase-service-account.json` (lấy từ Firebase Console → Project Settings →
Service Accounts → Generate new private key) — cần cho push notification (FCM).

### 3. Khởi tạo database

```bash
npm run db:setup
```

### 4. Chạy dev

```bash
npm run dev              # Backend (3001) + Parent Dashboard (5173)
npm run dev:backend      # Chỉ backend
npm run dev:parent       # Chỉ Parent Dashboard
npm run dev:child        # Chỉ Child Monitor (5174)
```

### 5. Build Electron desktop app

```bash
cd frontend/parent-dashboard && npm run electron:build
cd ../child-monitor && npm run electron:build
```

## Cài đặt — Mobile (Flutter)

```bash
cd mobile
flutter pub get
```

**Firebase:** đặt `google-services.json` (lấy từ Firebase Console) vào `mobile/android/app/` —
file này bị gitignore, không có sẵn khi clone.

**Mapbox:** tạo file `mobile/.env`:

```env
MAPBOX_PUBLIC_TOKEN=your-mapbox-public-token
```

**API base URL — LƯU Ý: đây KHÔNG phải biến môi trường.** `.env` ở trên chỉ dùng cho Mapbox token.
Base URL của API được **hardcode** trong `mobile/lib/core/constants/api_constants.dart`
(`ApiConstants.baseUrl`), mặc định trỏ tới backend production trên Railway. Để chạy với backend
local, sửa trực tiếp file này:

```dart
// mobile/lib/core/constants/api_constants.dart
static const String baseUrl = 'https://kidfun-backend-production.up.railway.app'; // mặc định

// Comment dòng trên, mở 1 trong 2 dòng dưới tùy thiết bị test:
// static const String baseUrl = 'http://10.0.2.2:3001';        // Android emulator
// static const String baseUrl = 'http://192.168.x.x:3001';     // thiết bị thật, dùng IP từ `npm run lan:ip`
```

Sau khi sửa, chạy:

```bash
flutter run
```

Nếu chỉnh sửa provider có annotation `@riverpod`, chạy lại code-gen:

```bash
dart run build_runner build     # hoặc: watch
```

## Kiểm thử

```bash
npm run test:backend            # Jest (backend)
npm run test:frontend           # Jest (parent-dashboard)
cd tests && npm test            # Playwright E2E (web apps) — cần `npx playwright install` lần đầu
cd mobile && flutter test       # Unit/widget test (mobile)
```

## Troubleshooting

**Lỗi kết nối database:** kiểm tra `DATABASE_URL`/`DIRECT_URL` trỏ đúng project Supabase, sau đó
`cd backend && npx prisma migrate reset && npx prisma generate`.

**Mobile không gọi được API local:** đây gần như luôn là do `ApiConstants.baseUrl` (xem phần Mobile
ở trên) vẫn đang trỏ tới Railway production thay vì local/LAN — không phải lỗi CORS hay `.env`.

**AI features (YouTube analysis) không chạy:** `GROQ_API_KEY`/`OPENAI_API_KEY` thiếu trong
`backend/.env` — kiểm tra `GET /api/admin/ai-status`. Tính năng tự degrade gracefully, không lỗi cứng.

**FCM push không nhận được:** kiểm tra `backend/firebase-service-account.json` tồn tại (backend) và
`google-services.json` nằm đúng `mobile/android/app/` (mobile).

**Lỗi Electron build trên WSL2:** cần `sudo apt install wine64` để build NSIS installer;
`dist-electron/win-unpacked/` vẫn chạy được như portable app không cần installer.

## Scripts (root `package.json`)

```bash
npm run dev              # Backend + Parent Dashboard
npm run dev:backend      # Backend only (port 3001)
npm run dev:parent       # Parent Dashboard only (port 5173)
npm run dev:child        # Child Monitor only (port 5174)
npm run lan:ip           # In IP LAN — dùng để test mobile/thiết bị thật trên cùng mạng

npm run db:migrate       # Chạy Prisma migration
npm run db:seed          # Seed dữ liệu mẫu
npm run db:studio        # Mở Prisma Studio GUI
npm run db:reset         # Reset database

npm run build            # Build backend + cả 2 web app
npm run test:backend     # Jest (backend)
npm run test:frontend    # Jest (parent-dashboard)
npm run lint / lint:fix  # ESLint

npm run install:all      # Cài toàn bộ dependencies (root + backend + 2 web app)
```

## Quy trình Git

Xem [CLAUDE.md](CLAUDE.md) (local, không commit) — mỗi task = 1 feature branch riêng từ `develop`,
commit theo `feat/fix/chore(area): mô tả`, không push thẳng lên `develop`/`main`.

## License

MIT License — xem [LICENSE](LICENSE)

## Tác giả

**Nhóm 60 - HUTECH** — Dự án môn học tại Đại học Công nghệ TP.HCM (HUTECH)
