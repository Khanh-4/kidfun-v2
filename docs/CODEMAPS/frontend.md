<!-- Generated: 2026-08-18 (revised) | Files scanned: frontend/ + mobile/lib + mobile/android/.../kotlin (~135 files) | Token estimate: ~1050 -->

# Frontend

## Parent Dashboard (`frontend/parent-dashboard/`, port 3000)

React 19 + Vite + MUI. Also builds as an Electron desktop app (`electron/main.cjs` +
`electron/preload.cjs` → `dist-electron/`).

```
src/pages/          Account, ActivityHistory, BlockedSites, Dashboard, Devices,
                     ForgotPassword, Login, Notifications, Profiles, Register,
                     Reports, ResetPassword, TimeSettings
src/components/      Auth/  Dashboard/  Devices/  Layout/  Profiles/  Reports/  TimeManagement/
src/services/api.js          Axios instance, JWT interceptor, base URL http://localhost:3001/api
src/services/socketService.js Socket.IO client singleton (joins family_{userId})
```

## Child Monitor (`frontend/child-monitor/`, port 3002)

React 19 + Vite + MUI. Also Electron-wrapped (same pattern as parent-dashboard). Much smaller
surface — this is the on-screen soft-warning overlay, not a full management UI.

```
src/pages/       ChildDashboard, LinkDevice
src/components/  (child-specific UI, large fonts / rounded corners per theme convention)
```

## Shared (`frontend/shared/`)

`components/`, `constants/`, `hooks/`, `utils/` — code shared between parent-dashboard and
child-monitor (both are separate Vite apps, not a single build, so this is manually imported
via relative path, not an npm workspace package).

## Mobile (`mobile/lib/`)

Flutter 3.x, Riverpod (code-gen) + go_router + Dio + Firebase Messaging + Socket.IO client +
Mapbox. Single app used by both parent (control) and child (monitored device) roles.

```
main.dart / app.dart   Bootstrap, ProviderScope, go_router config, theme (app.dart is large, ~800 lines)

core/network/dio_client.dart     Dio + JWT interceptor, base URL from .env asset (flutter_dotenv)
core/network/socket_service.dart Socket.IO client (joins family_{userId} room) — lives under
                                  network/, not services/
core/services/  notification_service (FCM + flutter_local_notifications), location_service
                (geolocator + geofence reporting), native_service (Android platform channel,
                MethodChannel calls: getAppUsage, getInstalledApps, ...), policy_service
                (syncs Sprint-8 policies via GET /api/child/policy, re-synced on socket events
                blockedDomainsUpdated/appTimeLimitUpdated/schoolScheduleUpdated), youtube_service,
                app_lifecycle_service
core/storage/secure_storage.dart  JWT/refresh token (flutter_secure_storage); shared_preferences
                                   for non-sensitive prefs

shared/models/    device_model, profile_model, time_limit_model, user_model
shared/widgets/    time_extension_listener (listens for timeExtensionResponse socket event)

features/<name>/data/        repositories
features/<name>/providers/   Riverpod providers (@riverpod code-gen)
features/<name>/screens/     UI screens
  (note: actual layout is data/providers/screens, not domain/presentation as CLAUDE.md's
   architecture note states)

features/auth/screens/     login, register, forgot_password, role_selection
features/device/screens/   device_list, add_device, scan_qr (mobile_scanner + qr_flutter pairing),
                            child_dashboard, child_locked_widget, child_request_time
features/profile/screens/  profile_list, create_profile, edit_profile, app_blocking,
                            per_app_limit, app_usage_report, school_mode, web_filter
features/time_limit/screens/  time_limit_screen
features/location/screens/    map, location_history, sos_alert, sos_history (record/audioplayers
                               for SOS audio)
features/reports/screens/     reports (fl_chart), activity_history
features/youtube/screens/     youtube_dashboard, youtube_logs, ai_alerts

android/app/src/main/kotlin/com/kidfun/mobile/
  MainActivity.kt                     MethodChannel registration (native_service bridge)
  helpers/UsageStatsHelper.kt         UsageStatsManager wrapper
  helpers/BlockNotificationHelper.kt  system notification when an app/site is blocked
  receivers/BootReceiver.kt           restart enforcement services on device boot
  receivers/KidFunDeviceAdminReceiver.kt : DeviceAdminReceiver  (device-admin policy hooks)
  services/AppBlockerService.kt       : AccessibilityService  (foreground-app detection → blocking)
  services/AppLimitChecker.kt         per-app time-limit enforcement loop
  services/KidFunService.kt           : Service  (background usage-tracking foreground service)
  services/SchoolModeChecker.kt       school-mode schedule enforcement
  services/YouTubeTracker.kt          YouTube-in-app watch tracking (feeds YouTubeLog)
```

After editing any `@riverpod`-annotated provider: `dart run build_runner build` (or `watch`).

## Related

- [architecture.md](architecture.md) — how these apps connect to the backend
