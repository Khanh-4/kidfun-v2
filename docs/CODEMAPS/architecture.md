<!-- Generated: 2026-08-18 | Files scanned: ~335 | Token estimate: ~750 -->

# Architecture

KidFun v2 — smart parental control system with soft-warning technology. Monorepo, 4 runnable apps sharing one backend.

## Apps

```
backend/                    Express + Prisma + Socket.IO API        (port 3001)
frontend/parent-dashboard/  React 19 + Vite + MUI, Electron-wrapped (port 3000)
frontend/child-monitor/     React 19 + Vite + MUI, Electron-wrapped (port 3002)
frontend/shared/            Shared components/hooks/utils/constants across the two React apps
mobile/                     Flutter 3.x (Riverpod + go_router + Dio), parent + child roles
```

`frontend/parent-dashboard` and `frontend/child-monitor` each ship both as a Vite web build and an
Electron desktop app (`electron/main.cjs`, `electron/preload.cjs`, `dist-electron/`).

## Data Flow

```
Mobile (child device)  ─┐
Child Monitor (web)     ├─ Dio/Axios (JWT) ──▶ Express API ──▶ Prisma ──▶ PostgreSQL (Supabase)
Parent Dashboard        ─┘                         │
                                                    ├─▶ Firebase Admin (FCM push, offline devices)
                                                    ├─▶ Google APIs (YouTube data, OAuth)
                                                    └─▶ Groq / OpenAI (AI content analysis)

All 3 clients ⇄ Socket.IO ⇄ backend, joined into room `family_{userId}`
  (real-time: time-extension requests, device online/offline, geofence & SOS alerts, location)
```

## Service Boundaries

- **backend** is the single source of truth — all clients talk to it over REST (JWT auth) and Socket.IO. No client talks to Postgres, Firebase, or the AI providers directly.
- **mobile** additionally talks to Android platform channels (`native_service`) for on-device enforcement (UsageStatsManager, AccessibilityService, DeviceAdmin) — this is local-only, not part of the backend API.
- **workers/** (`aiAnalysisWorker.js`, `reportWorker.js`) run inside the backend process, triggered via `/api/admin/run-*` endpoints (no separate scheduler process yet — see [dependencies.md](dependencies.md)).

## Auth

JWT (24h expiry), issued by `backend/src/controllers/authController.js`. `middleware/auth.js` exposes
`authenticate` (verifies JWT) and `authorizeParent`. Google Sign-In is native on mobile (in-app
account picker); web apps use Google OAuth redirect flow (`authController.loginWithGoogle`).
Passwords hashed with bcryptjs (salt=10).

## Related

- [backend.md](backend.md) — routes, middleware, controller→service map
- [frontend.md](frontend.md) — page tree for both React apps + mobile feature layout
- [data.md](data.md) — Prisma schema (32 models)
- [dependencies.md](dependencies.md) — external services and integrations
