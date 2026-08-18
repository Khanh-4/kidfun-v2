<!-- Generated: 2026-08-18 (revised) | Source: package.json (root/backend/frontend), mobile/pubspec.yaml | Token estimate: ~750 -->

# Dependencies

## External Services

```
PostgreSQL (Supabase)   Primary datastore. DATABASE_URL (pooled, pgbouncer) + DIRECT_URL
                         (direct, for migrations). Accessed only via Prisma in backend/.
Firebase                Admin SDK (push via FCM) + Firebase Messaging (mobile client).
                         Service account: backend/firebase-service-account.json (gitignored).
Google APIs             OAuth (Sign-In) + YouTube Data API. googleapis package (backend),
                         native Google Sign-In (mobile, in-app account picker).
Groq / OpenAI           AI content analysis (YouTube video safety classification).
                         Both optional — feature degrades gracefully if keys absent;
                         check GET /api/admin/ai-status.
Mapbox                  Maps in mobile app (mapbox_maps_flutter, location_service, map_screen).
```

## Backend (`backend/`)

```
express          web framework
prisma / @prisma/client   ORM (postgresql provider)
socket.io        real-time (family_{userId} rooms)
firebase-admin   FCM push
googleapis       YouTube + OAuth
groq-sdk, openai AI providers
jsonwebtoken     JWT auth (24h expiry)
bcryptjs         password hashing (salt=10)
multer           file upload (SOS audio → /uploads)
nodemailer       password-reset email
express-rate-limit, helmet, cors, morgan   hardening/logging
```

## Frontend (`frontend/parent-dashboard/`, `frontend/child-monitor/`)

```
react 19, react-router-dom 7
@mui/material, @mui/icons-material   (theme: primary indigo #6366f1, secondary pink #f472b6)
axios            REST client + JWT interceptor
socket.io-client real-time client
vite              dev server / build
electron          desktop wrapper (electron/main.cjs, preload.cjs — separate from the Vite build)
```

## Mobile (`mobile/`) — pubspec.yaml, Flutter SDK ^3.11.1

```
flutter_riverpod, riverpod_annotation (+ dev: riverpod_generator, build_runner)   state (code-gen)
go_router                routing
dio                      HTTP client + JWT interceptor
socket_io_client 2.0.3+1 real-time client
firebase_core, firebase_messaging   push notifications
flutter_local_notifications         local notification display (foreground FCM)
google_sign_in           native Google Sign-In (in-app account picker)
flutter_secure_storage   JWT/refresh token storage
shared_preferences       non-sensitive prefs
flutter_dotenv           loads .env (bundled Flutter asset) — API base URL etc.
mapbox_maps_flutter      maps (location feature)
geolocator               GPS / geofence reporting
qr_flutter, mobile_scanner   device-pairing QR generate + scan
device_info_plus         device metadata sent on link/register
record, audioplayers     SOS audio recording + playback
permission_handler       runtime permissions (location, mic, notifications)
path_provider            local file paths (SOS audio storage)
url_launcher              open external links
fl_chart                  charts (reports feature)
google_fonts, flutter_svg, cached_network_image   UI/asset support
intl                       date/number formatting
```

Native Android platform channels (Kotlin, `mobile/android/app/src/main/kotlin/`) — UsageStatsManager,
AccessibilityService, DeviceAdmin — invoked from Dart via `core/services/native_service.dart`.
No Dart package equivalent; this is hand-written platform channel code, not a pub.dev dependency.

## Scheduled Jobs

No `node-cron`-style dependency, but `reportWorker.js` self-schedules: `server.js` calls
`reportWorker.startScheduler()` once at boot, which runs a plain `setInterval` (every 5 min) that
fires `runDailyReports()` at 00:05 and `runWeeklyReports()` on Monday 00:10, both Asia/Ho_Chi_Minh
time. `aiAnalysisWorker.js` has no self-schedule — it only runs on-demand via
`/api/admin/run-ai-analysis`, so an external trigger (cron, Railway/Render scheduled job, etc.) is
still needed for that one in production.

## Related

- [architecture.md](architecture.md) — how these services fit together
- [backend.md](backend.md) — which controllers call which service
