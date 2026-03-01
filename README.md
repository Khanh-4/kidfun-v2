# KidFun V2.0 - Hệ thống quản lý thời gian sử dụng thiết bị cho trẻ em

> Smart Parental Control System with Soft Warning Technology

Hệ thống kiểm soát thời gian sử dụng thiết bị thông minh, giúp phụ huynh quản lý và giám sát hoạt động của trẻ em trên các thiết bị điện tử. Sử dụng công nghệ cảnh báo mềm (Soft Warning) để nhắc nhở trẻ trước khi hết thời gian, kết hợp giao tiếp real-time giữa thiết bị của phụ huynh và trẻ em.

## Tính năng chính

### Parent Dashboard (Dành cho Phụ huynh)
- Đăng ký / Đăng nhập / Quên mật khẩu (gửi email)
- Quản lý hồ sơ con (tạo, sửa, xóa nhiều hồ sơ)
- Quản lý thiết bị (tạo mã kết nối, gán thiết bị cho hồ sơ con)
- Cài đặt giới hạn thời gian theo từng ngày (Thứ 2 - Chủ nhật)
- Chặn website / ứng dụng theo hồ sơ
- Nhận thông báo xin thêm giờ real-time từ trẻ
- Duyệt / từ chối yêu cầu thêm giờ
- Xem lịch sử hoạt động chi tiết
- Báo cáo thống kê sử dụng (biểu đồ)
- Đa ngôn ngữ: Tiếng Việt / English
- Ứng dụng Desktop (Electron)

### Child Monitor (Dành cho Trẻ em)
- Liên kết thiết bị bằng mã kết nối
- Hiển thị thời gian còn lại (đếm ngược real-time)
- Cảnh báo mềm: thông báo ở mốc 30 phút, 15 phút, 5 phút
- Xin thêm giờ sử dụng (gửi lý do cho phụ huynh)
- Màn hình khóa fullscreen khi hết giờ (kiosk mode)
- Chặn website qua hosts file (cần quyền Administrator)
- Phím thoát khẩn cấp: `Ctrl+Shift+Alt+Q`
- Ứng dụng Desktop (Electron)

### Real-time Communication
- Socket.IO cho giao tiếp 2 chiều giữa Parent và Child
- Cập nhật tức thì khi thay đổi giới hạn thời gian
- Cập nhật tức thì khi thay đổi danh sách chặn website
- Thông báo khi thiết bị bị xóa

## Tech Stack

| Layer | Công nghệ |
|-------|-----------|
| **Backend** | Node.js, Express.js, Prisma ORM, SQLite, Socket.IO, JWT, bcryptjs, Nodemailer |
| **Parent Dashboard** | React 19, Vite, Material-UI v7, React Router v7, Recharts, i18next, Axios |
| **Child Monitor** | React 19, Vite, Material-UI v7, Axios, Socket.IO Client |
| **Desktop App** | Electron 40, electron-builder |
| **Dev Tools** | Nodemon, ESLint, Jest, Supertest, Concurrently |

## Cấu trúc thư mục

```
kidfun-v2/
├── backend/                          # Backend API Server
│   ├── prisma/
│   │   ├── schema.prisma             # Database schema (10 models)
│   │   └── migrations/               # Migration history
│   ├── src/
│   │   ├── controllers/              # Business logic
│   │   │   ├── authController.js     # Đăng ký, đăng nhập, quên MK
│   │   │   ├── profileController.js  # Quản lý hồ sơ con
│   │   │   ├── deviceController.js   # Quản lý thiết bị
│   │   │   ├── childController.js    # API cho Child Monitor
│   │   │   ├── blockedSiteController.js
│   │   │   └── monitoringController.js
│   │   ├── routes/                   # API endpoints
│   │   ├── middleware/               # Auth, validation, error handling
│   │   ├── services/                 # Socket.IO, Email service
│   │   └── server.js                 # Entry point
│   ├── .env.example
│   └── package.json
├── frontend/
│   ├── parent-dashboard/             # Parent Dashboard (port 5173)
│   │   ├── src/
│   │   │   ├── pages/                # 13 page components
│   │   │   ├── components/           # UI components theo feature
│   │   │   ├── services/             # API, Socket, Auth services
│   │   │   └── locales/              # en.json, vi.json
│   │   ├── electron/                 # Electron main process
│   │   └── package.json
│   └── child-monitor/                # Child Monitor (port 5174)
│       ├── src/
│       │   ├── pages/                # LinkDevice, ChildDashboard
│       │   ├── components/           # LockScreen
│       │   └── services/             # API, Socket services
│       ├── electron/                 # Electron + hostsManager
│       └── package.json
├── scripts/
│   └── get-lan-ip.js                 # Tiện ích tìm IP LAN
├── tests/                            # E2E & integration tests
├── package.json                      # Monorepo root
├── CLAUDE.md                         # AI assistant context
└── README.md
```

## Yêu cầu hệ thống

- **Node.js** 18+ (khuyến nghị 20 LTS)
- **npm** 9+
- **Windows 10/11** (cho Electron app và chặn website qua hosts file)
- **Git** 2.30+

## Hướng dẫn cài đặt

### Bước 1: Clone repository

```bash
git clone https://github.com/Khanh-4/kidfun-v2.git
cd kidfun-v2
```

### Bước 2: Cài đặt dependencies

```bash
npm run install:all
```

Hoặc cài thủ công:

```bash
npm install
cd backend && npm install
cd ../frontend/parent-dashboard && npm install
cd ../child-monitor && npm install
cd ../../..
```

### Bước 3: Cấu hình môi trường

```bash
cp backend/.env.example backend/.env
```

Chỉnh sửa file `backend/.env`:

```env
# Database (SQLite - không cần cài đặt thêm)
DATABASE_URL="file:./dev.db"

# JWT - thay đổi secret key cho production
JWT_SECRET=your-super-secret-jwt-key
JWT_EXPIRES_IN=24h

# Server
PORT=3001
HOST=0.0.0.0

# SMTP - cho tính năng quên mật khẩu (Gmail App Password)
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-16-char-app-password

# CORS - thêm IP LAN nếu chạy nhiều thiết bị
SOCKET_CORS_ORIGIN=http://localhost:5173,http://localhost:5174
```

> **Lấy Gmail App Password:** Google Account > Security > 2-Step Verification > App passwords > Tạo mật khẩu ứng dụng

### Bước 4: Khởi tạo database

```bash
cd backend
npx prisma migrate dev
npx prisma generate
```

### Bước 5: Chạy ứng dụng (Development)

```bash
# Terminal 1 - Backend (port 3001)
npm run dev:backend

# Terminal 2 - Parent Dashboard (port 5173)
npm run dev:parent

# Terminal 3 - Child Monitor (port 5174)
npm run dev:child
```

Hoặc chạy Backend + Parent Dashboard cùng lúc:

```bash
npm run dev
```

### Bước 6: Build Electron App (Production)

```bash
# Build Parent Dashboard
cd frontend/parent-dashboard
npm run electron:build

# Build Child Monitor
cd ../child-monitor
npm run electron:build
```

Output: `dist-electron/win-unpacked/` - copy thư mục này sang máy Windows và chạy trực tiếp.

## Hướng dẫn sử dụng

### Dành cho Phụ huynh (Parent Dashboard)

1. **Đăng ký tài khoản** tại trang Register
2. **Đăng nhập** với email và mật khẩu
3. **Tạo hồ sơ con** tại mục Profiles (nhập tên, ngày sinh)
4. **Tạo thiết bị** tại mục Devices:
   - Nhấn "Thêm thiết bị" → nhập tên thiết bị
   - Hệ thống tạo **mã kết nối** (device code)
   - Gán thiết bị cho hồ sơ con
5. **Cài đặt giới hạn thời gian** tại Time Settings:
   - Chọn hồ sơ con
   - Thiết lập thời gian cho từng ngày (Thứ 2 - Chủ nhật)
6. **Chặn website** tại Blocked Sites:
   - Chọn hồ sơ con
   - Thêm domain cần chặn (vd: facebook.com, tiktok.com)
7. **Xem báo cáo** tại Reports: biểu đồ thời gian sử dụng theo ngày/tuần
8. **Nhận thông báo** khi trẻ xin thêm giờ → Duyệt hoặc Từ chối

### Dành cho Trẻ em (Child Monitor)

1. **Nhập mã kết nối** từ Parent Dashboard
2. **Sử dụng thiết bị** - màn hình hiển thị thời gian còn lại
3. Nhận **cảnh báo mềm** ở mốc 30, 15, 5 phút
4. **Xin thêm giờ** - nhập lý do và gửi cho phụ huynh
5. Khi hết giờ → **màn hình khóa fullscreen**
6. Phím thoát khẩn cấp (cho demo): `Ctrl+Shift+Alt+Q`

## Chạy trên nhiều thiết bị (LAN)

### Bước 1: Tìm IP LAN

```bash
npm run lan:ip
```

Hoặc thủ công:
- **Windows:** `ipconfig` → IPv4 Address
- **Linux/macOS:** `ip addr show` hoặc `ifconfig`

### Bước 2: Cấu hình Backend (Máy chạy server)

Backend mặc định listen trên `0.0.0.0` (tất cả interfaces). Cập nhật `backend/.env`:

```env
SOCKET_CORS_ORIGIN=http://localhost:5173,http://localhost:5174,http://192.168.1.100:5173,http://192.168.1.100:5174
```

### Bước 3: Mở firewall port 3001

```bash
# Windows (PowerShell as Admin)
netsh advfirewall firewall add rule name="KidFun Backend" dir=in action=allow protocol=TCP localport=3001

# Linux (ufw)
sudo ufw allow 3001/tcp
```

### Bước 4: Cấu hình Child Monitor (Máy của trẻ)

Tạo file `frontend/child-monitor/.env`:

```env
VITE_API_URL=http://192.168.1.100:3001
VITE_SOCKET_URL=http://192.168.1.100:3001
```

### Bước 5: Khởi chạy

```bash
# Máy A (Backend + Parent Dashboard)
npm run dev

# Máy B (Child Monitor)
cd frontend/child-monitor
npm run dev -- --host
```

### Ví dụ cấu hình hoàn chỉnh

| Thiết bị | Vai trò | IP | Cấu hình |
|----------|---------|-----|----------|
| Máy A | Backend + Parent Dashboard | 192.168.1.100 | Chạy `npm run dev`, mở port 3001 |
| Máy B | Child Monitor | 192.168.1.101 | `.env`: `VITE_API_URL=http://192.168.1.100:3001` |

### Port Forwarding (WSL2 → Windows)

Nếu chạy backend trong WSL2, cần forward port:

```powershell
# PowerShell as Admin
netsh interface portproxy add v4tov4 listenport=3001 listenaddress=0.0.0.0 connectport=3001 connectaddress=$(wsl hostname -I)
```

## API Endpoints

### Authentication (`/api/auth`)

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|--------|
| POST | `/register` | No | Đăng ký tài khoản |
| POST | `/login` | No | Đăng nhập (trả về JWT) |
| POST | `/forgot-password` | No | Gửi email đặt lại mật khẩu |
| POST | `/reset-password` | No | Đặt lại mật khẩu với token |
| PUT | `/profile` | JWT | Cập nhật thông tin tài khoản |
| PUT | `/change-password` | JWT | Đổi mật khẩu |

### Profiles (`/api/profiles`)

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|--------|
| GET | `/` | JWT | Danh sách hồ sơ con |
| POST | `/` | JWT | Tạo hồ sơ con mới |
| GET | `/:id` | JWT | Chi tiết hồ sơ |
| PUT | `/:id` | JWT | Cập nhật hồ sơ |
| DELETE | `/:id` | JWT | Xóa hồ sơ |
| PUT | `/:id/time-limits` | JWT | Cập nhật giới hạn thời gian |

### Devices (`/api/devices`)

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|--------|
| GET | `/` | JWT | Danh sách thiết bị |
| POST | `/` | JWT | Tạo thiết bị mới |
| POST | `/link` | No | Liên kết thiết bị (dùng deviceCode) |
| PUT | `/:id` | JWT | Cập nhật thiết bị |
| DELETE | `/:id` | JWT | Xóa thiết bị |

### Blocked Sites (`/api/blocked-sites`)

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|--------|
| GET | `/:profileId` | JWT | Danh sách website bị chặn |
| POST | `/` | JWT | Thêm website/app cần chặn |
| DELETE | `/:id` | JWT | Xóa khỏi danh sách chặn |

### Monitoring (`/api/monitoring`)

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|--------|
| GET | `/reports/:profileId` | JWT | Báo cáo sử dụng |
| GET | `/activity-history/:profileId` | JWT | Lịch sử hoạt động |
| GET | `/warnings/:profileId` | JWT | Danh sách cảnh báo |

### Child API (`/api/child`) - Public, dùng header `X-Device-Code`

| Method | Endpoint | Mô tả |
|--------|----------|--------|
| GET | `/status` | Thông tin thời gian, profile, session |
| POST | `/session/start` | Bắt đầu session mới |
| POST | `/session/heartbeat` | Heartbeat mỗi 60 giây |
| POST | `/session/end` | Kết thúc session |
| POST | `/bonus` | Lưu bonus khi Parent duyệt thêm giờ |
| POST | `/warnings` | Ghi log cảnh báo |
| GET | `/blocked-sites` | Lấy danh sách website bị chặn |

### Health Check

| Method | Endpoint | Mô tả |
|--------|----------|--------|
| GET | `/api/health` | Kiểm tra server hoạt động |

## Socket.IO Events

```
Parent Dashboard                  Backend                    Child Monitor
       |                            |                            |
       |--- joinFamily(userId) ---->|<---- joinFamily(userId) ---|
       |                            |                            |
       |                            |<-- requestTimeExtension ---|
       |<-- timeExtensionRequest ---|                            |
       |                            |                            |
       |--- respondTimeExtension -->|                            |
       |                            |--- timeExtensionResponse ->|
       |                            |                            |
       |--- removeDevice --------->|--- deviceRemoved --------->|
       |                            |                            |
       |  (update time limit API)   |--- timeLimitUpdated ------>|
       |  (update blocked sites)    |--- blockedSitesUpdated --->|
```

| Event | Hướng | Mô tả |
|-------|-------|--------|
| `joinFamily` | Client → Server | Tham gia room `family_{userId}` |
| `requestTimeExtension` | Child → Server | Xin thêm giờ |
| `timeExtensionRequest` | Server → Parent | Chuyển yêu cầu đến phụ huynh |
| `respondTimeExtension` | Parent → Server | Phản hồi yêu cầu |
| `timeExtensionResponse` | Server → Child | Chuyển kết quả đến trẻ |
| `removeDevice` | Parent → Server | Xóa thiết bị |
| `deviceRemoved` | Server → Child | Thông báo thiết bị bị xóa |
| `timeLimitUpdated` | Server → Child | Cập nhật giới hạn thời gian |
| `blockedSitesUpdated` | Server → Child | Cập nhật danh sách chặn |

## Database Schema

10 models (Prisma + SQLite):

| Model | Mô tả | Quan hệ |
|-------|--------|---------|
| **User** | Tài khoản phụ huynh | → Profiles, Devices, Notifications |
| **Profile** | Hồ sơ trẻ em | → TimeLimits, BlockedWebsites, UsageLogs, Warnings |
| **Device** | Thiết bị đã đăng ký | → Sessions, Applications |
| **TimeLimit** | Giới hạn thời gian theo ngày | Unique: [profileId, dayOfWeek] |
| **BlockedWebsite** | Website/app bị chặn | blockType: website \| app |
| **Application** | Ứng dụng trên thiết bị | isBlocked, timeLimitMinutes |
| **UsageLog** | Log hoạt động | startTime, endTime, durationSeconds |
| **Warning** | Cảnh báo đã gửi | warningType, userResponse |
| **Notification** | Thông báo cho phụ huynh | type, isRead |
| **Session** | Phiên sử dụng | status: ACTIVE/COMPLETED, bonusMinutes |

## Troubleshooting

### Lỗi CORS khi kết nối LAN
- Kiểm tra `SOCKET_CORS_ORIGIN` trong `backend/.env` đã thêm IP LAN
- Hoặc đặt `origin: "*"` trong development mode (đã cấu hình mặc định)

### Lỗi kết nối database
```bash
cd backend
npx prisma migrate reset   # Reset và tạo lại database
npx prisma generate         # Tạo lại Prisma client
```

### Lỗi Electron build trên WSL2
- Cần cài `wine64` để tạo NSIS installer: `sudo apt install wine64`
- Thư mục `win-unpacked/` vẫn sử dụng được như portable app

### Lỗi chặn website không hoạt động
- Child Monitor cần chạy với **quyền Administrator** (Run as Administrator)
- Kiểm tra file `C:\Windows\System32\drivers\etc\hosts` có section `# KidFun-Block-Start`

### Socket.IO không kết nối qua LAN
- Kiểm tra firewall port 3001 đã mở
- Kiểm tra IP trong `.env` của frontend đúng với IP máy chạy backend
- Xem log Console (F12) để debug: `[SocketService]`, `[ParentSocket]`

### Lỗi 401 Unauthorized ở Child Monitor
- Child Monitor dùng `X-Device-Code` header, không dùng JWT
- Các API child phải gọi qua `/api/child/*` (public routes)

## Scripts

```bash
npm run dev              # Backend + Parent Dashboard
npm run dev:backend      # Backend only (port 3001)
npm run dev:parent       # Parent Dashboard only (port 5173)
npm run dev:child        # Child Monitor only (port 5174)

npm run db:migrate       # Chạy Prisma migration
npm run db:seed          # Seed dữ liệu mẫu
npm run db:studio        # Mở Prisma Studio GUI
npm run db:reset         # Reset database

npm run test:backend     # Chạy Jest tests
npm run build            # Build tất cả
npm run lint             # Kiểm tra ESLint
npm run lint:fix         # Tự động fix ESLint

npm run lan:ip           # Hiển thị IP LAN + hướng dẫn cấu hình
npm run install:all      # Cài đặt tất cả dependencies
```

## Đóng góp

1. Fork repository
2. Tạo branch: `git checkout -b feature/ten-tinh-nang`
3. Commit: `git commit -m "feat: Mô tả tính năng"`
4. Push: `git push origin feature/ten-tinh-nang`
5. Tạo Pull Request

### Quy ước commit message
- `feat:` Tính năng mới
- `fix:` Sửa lỗi
- `docs:` Cập nhật tài liệu
- `refactor:` Tái cấu trúc code
- `security:` Bảo mật

## License

MIT License - xem file [LICENSE](LICENSE)

## Tác giả

**Nhom 60 - HUTECH**
- Dự án môn học tại Đại học Công nghệ TP.HCM (HUTECH)
- KidFun V2.0 - Smart Parental Control System with Soft Warning Technology
