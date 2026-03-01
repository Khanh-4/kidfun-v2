# kidfun-v2

## Chạy trên nhiều thiết bị (LAN)

KidFun V2 hỗ trợ chạy Backend, Parent Dashboard, và Child Monitor trên các thiết bị khác nhau trong cùng mạng LAN.

### Bước 1: Tìm IP LAN của máy chạy Backend

```bash
# Sử dụng script tiện ích
npm run lan:ip

# Hoặc thủ công:
# Windows:  ipconfig
# Linux:    ip addr show | grep "inet "
# macOS:    ifconfig | grep "inet "
```

### Bước 2: Cấu hình Backend (Máy A - ví dụ IP: 192.168.1.100)

Backend mặc định đã listen trên `0.0.0.0` (tất cả network interfaces).

Cập nhật file `backend/.env`:

```env
# Cho phép CORS từ các thiết bị trong LAN
SOCKET_CORS_ORIGIN=http://localhost:3000,http://localhost:3002,http://192.168.1.100:3000,http://192.168.1.100:3002
```

Mở firewall port 3001:

```bash
# Windows (PowerShell as Admin):
netsh advfirewall firewall add rule name="KidFun Backend" dir=in action=allow protocol=TCP localport=3001

# Linux (ufw):
sudo ufw allow 3001/tcp

# Linux (firewalld):
sudo firewall-cmd --add-port=3001/tcp --permanent && sudo firewall-cmd --reload
```

### Bước 3: Cấu hình Frontend (Máy B - Child Monitor)

Tạo file `frontend/child-monitor/.env`:

```env
VITE_API_URL=http://192.168.1.100:3001
VITE_SOCKET_URL=http://192.168.1.100:3001
```

### Bước 4: Khởi chạy

```bash
# Máy A (Backend + Parent Dashboard):
npm run dev

# Máy B (Child Monitor):
cd frontend/child-monitor
npm run dev -- --host    # --host cho phép truy cập từ LAN
```

### Electron App

Để chạy Electron Child Monitor kết nối đến máy khác:

```bash
# Cách 1: Dùng biến môi trường
API_URL=http://192.168.1.100:3001 npm run electron:dev

# Cách 2: Tạo file electron-config.json trong frontend/child-monitor/
```

```json
{
  "apiUrl": "http://192.168.1.100:3001"
}
```

### Ví dụ cấu hình hoàn chỉnh

| Thiết bị | Vai trò | IP | Cấu hình |
|----------|---------|-----|----------|
| Máy A | Backend + Parent Dashboard | 192.168.1.100 | Chạy `npm run dev`, mở port 3001 |
| Máy B | Child Monitor | 192.168.1.101 | `.env`: `VITE_API_URL=http://192.168.1.100:3001` |
| Điện thoại | Child Monitor (web) | - | Truy cập `http://192.168.1.101:3002` |
