# KidFun V3 — Sprint 2 API Reference

> **Server:** https://kidfun-backend-production.up.railway.app
> **Auth:** Gửi header `Authorization: Bearer <token>`
> **Response format:** `{ success: true/false, data/message, code }`

---

## Auth API

### POST /api/auth/register
```json
// Request
{ "email": "user@example.com", "password": "123456", "fullName": "Nguyen Van A" }

// Response 201
{ "success": true, "data": { "token": "...", "refreshToken": "...", "user": { "id", "email", "fullName", "phoneNumber", "createdAt" } } }
```

### POST /api/auth/login
```json
// Request
{ "email": "user@example.com", "password": "123456" }

// Response 200
{ "success": true, "data": { "token": "...", "refreshToken": "...", "user": { "id", "email", "fullName", "phoneNumber" } } }
```

### POST /api/auth/refresh-token
```json
// Request (KHÔNG cần Authorization header)
{ "refreshToken": "..." }

// Response 200
{ "success": true, "data": { "token": "...", "refreshToken": "..." } }
```

### POST /api/auth/logout
```
Authorization: Bearer <token>

// Response 200
{ "success": true, "data": { "message": "Logged out" } }
```

### POST /api/auth/forgot-password
```json
// Request
{ "email": "user@example.com" }

// Response 200
{ "success": true, "data": { "message": "Nếu email tồn tại, chúng tôi đã gửi hướng dẫn đặt lại mật khẩu." } }
```

---

## Profile API (cần Auth)

### GET /api/profiles
```json
// Response 200
{ "success": true, "data": [ { "id", "profileName", "dateOfBirth", "avatarUrl", "isActive", "timeLimits": [...], "_count": { "usageLogs", "warnings" } } ] }
```

### POST /api/profiles
```json
// Request
{ "profileName": "Bé An", "dateOfBirth": "2015-06-15" }

// Response 201
{ "success": true, "data": { "profile": { ... } } }
```

### GET /api/profiles/:id
### PUT /api/profiles/:id
### DELETE /api/profiles/:id
### PUT /api/profiles/:id/time-limits
```json
// Request
{ "timeLimits": [ { "dayOfWeek": 0, "dailyLimitMinutes": 150 }, ... ] }
```

---

## Device API (cần Auth)

### GET /api/devices
### POST /api/devices
### GET /api/devices/:id
### PUT /api/devices/:id
### DELETE /api/devices/:id
### POST /api/devices/link (KHÔNG cần Auth)
```json
// Request
{ "deviceCode": "ABC12345" }
```

---

## FCM Token API (cần Auth)

### POST /api/fcm-tokens/register
```json
// Request
{ "token": "fcm_token_string", "platform": "ANDROID", "deviceId": 1 }

// Response 200
{ "success": true, "data": { "message": "Token registered" } }
```

### DELETE /api/fcm-tokens/unregister
```json
// Request
{ "token": "fcm_token_string" }

// Response 200
{ "success": true, "data": { "message": "Token removed" } }
```

---

## Error Format
```json
{ "success": false, "message": "Mô tả lỗi", "code": "ERROR_CODE" }
```

**Error codes:** `EMAIL_EXISTS`, `INVALID_CREDENTIALS`, `MISSING_TOKEN`, `TOKEN_EXPIRED`, `INVALID_TOKEN`, `NOT_FOUND`, `DUPLICATE`, `INVALID_INPUT`, `INTERNAL_ERROR`, `FORBIDDEN`

---

## Notes
- Access token hết hạn sau 24h
- Refresh token hết hạn sau 7d
- Khi access token hết hạn, gọi `/api/auth/refresh-token` để lấy token mới
- Platform cho FCM: `ANDROID` hoặc `IOS`
