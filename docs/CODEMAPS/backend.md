<!-- Generated: 2026-08-18 | Files scanned: backend/src (~60 files) | Token estimate: ~950 -->

# Backend

Express app entry: `backend/src/server.js`. Mounts helmet, cors, morgan, `express-rate-limit`
(global `/api/` limiter + stricter `authLimiter` on `/api/auth/login` and `/api/auth/register`),
static `/uploads`, Socket.IO. `trust proxy = 1` (Railway/Render/Heroku).

## Middleware Chain

```
helmet → cors → morgan('dev') → express.json()
  → apiLimiter (all /api/*)
  → authLimiter (only /api/auth/login, /api/auth/register)
  → [route-level] authenticate (JWT) / authorizeParent
  → controller
  → errorHandler (final)
```

`middleware/auth.js` — `authenticate`, `authorizeParent`
`middleware/validation.js` — express-validator wrapper
`middleware/uploadMiddleware.js` — multer (SOS audio uploads)
`middleware/responseHandler.js` — consistent response envelope
`middleware/errorHandler.js` — final error handler

## Routes (mounted in server.js)

```
/api/auth              → authRoutes            (public: register/login/google/forgot/reset; authenticated: logout/profile/change-password)
/api/profiles          → profileRoutes          (CRUD + nested: time-limits, warnings, extension-requests, app-usage,
                                                   blocked-apps, location, geofences, sos, app-time-limits, school-schedule,
                                                   blocked-categories, custom-blocked-domains, youtube, ai-alerts, reports, activity-history)
/api/devices            → deviceRoutes           (link, generate-pairing-code, CRUD, status)
/api/monitoring         → monitoringRoutes       (usage, warnings, reports, activity-history — by profileId)
/api/blocked-sites      → blockedSiteRoutes      (CRUD by profileId)
/api/child              → childRoutes            (child-device-facing: status, session lifecycle, bonus, warnings,
                                                   extension-request, blocked-sites/apps/domains/videos, app-usage sync,
                                                   school-mode, policy, youtube-logs, location, sos)
/api/fcm-tokens         → fcmRoutes              (register/unregister push token, authenticated)
/api/extension-requests → extensionRequestRoutes (pending list, approve — parent-facing)
/api/geofences          → geofenceRoutes         (update/delete, authenticated)
/api/sos                → sosRoutes              (acknowledge/resolve, authenticated)
/api/web-categories     → webFilteringRoutes     (GET category list)
/api                    → youtubeRoutes          (unblock video, mark AI alert read — authenticated)

/api/admin/ai-status         → inline in server.js, authenticated
/api/admin/run-ai-analysis   → inline, authenticated → triggers workers/aiAnalysisWorker.js
/api/admin/run-daily-reports → inline, authenticated → triggers workers/reportWorker.js
/api/admin/run-weekly-reports→ inline, authenticated → triggers workers/reportWorker.js
```

Notably, `/api/devices/link` and most of `/api/child/*` are **unauthenticated by design** — the
child device authenticates implicitly via its unique `deviceCode`, not a JWT.

## Controllers → Services

`backend/src/controllers/` (23 files) hold per-domain business logic and call into
`backend/src/services/`:

```
aiAlertController, monitoringController        → aiService.js       (Groq/OpenAI analysis)
fcmController, sosController, geofenceController → fcmService.js, firebaseService.js (push fanout)
reportController                                → reportService.js  (daily/weekly snapshot generation)
geofenceController                               → geofenceService.js (enter/exit detection)
authController                                   → emailService.js  (reset-password email)
all controllers touching Socket.IO events        → socketService.js (see below)
monitoringController (dashboards)                → cacheService.js
```

`backend/src/controllers/` full list: activityHistory, aiAlert, appTimeLimit, appUsage, auth,
blockedApp, blockedSite, child, childPolicy, device, extension, fcm, geofence, location,
monitoring, profile, report, schoolSchedule, session, sos, timeLimit, warning, webFiltering,
youtube.

## Socket.IO (`services/socketService.js`)

All clients join room `family_{userId}` via `joinFamily`; device clients also join
`device_{deviceCode}` via `joinDevice`.

```
Client → Server          Server → Client (room-scoped)
─────────────────────    ──────────────────────────────
ping                      pong
joinFamily                roomJoined
joinDevice                deviceError
heartbeat                 —
requestTimeExtension  →   timeExtensionRequest   (family room)
respondTimeExtension  →   timeExtensionResponse  (device room)
requestLocation       →   locationRequested      (device room)
removeDevice          →   deviceRemoved
disconnect            →   deviceOffline, device_status_changed (family room)
—                         deviceOnline, device_status_changed  (on joinDevice)
```

## Workers (`backend/src/workers/`)

- `aiAnalysisWorker.js` — scans unanalyzed `YouTubeLog` rows, calls `aiService`, writes `AIAlert` / `BlockedVideo`. Triggered via `/api/admin/run-ai-analysis`.
- `reportWorker.js` — builds `ReportSnapshot` rows (DAILY/WEEKLY). Triggered via `/api/admin/run-daily-reports` / `run-weekly-reports`.
- No cron scheduler wired in-process yet — these are invoked externally (see [dependencies.md](dependencies.md)).

## Related

- [data.md](data.md) — Prisma models referenced by these controllers
- [architecture.md](architecture.md) — where this fits in the overall system
