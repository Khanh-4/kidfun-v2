<!-- Generated: 2026-08-18 | Source: backend/prisma/schema.prisma | Token estimate: ~900 -->

# Data Model

**Provider: PostgreSQL (Supabase, via `DATABASE_URL` + pooled `DIRECT_URL`).**
CLAUDE.md's "SQLite" note is stale — `schema.prisma` and `backend/.env.example` both confirm
Postgres/Supabase is what's actually wired up. 32 models, all `Int @id @default(autoincrement())`.

## Core

```
User (email unique, googleId unique, passwordHash?, resetToken/OTP fields)
  ├─ 1:N Profile
  ├─ 1:N Device
  ├─ 1:N Notification
  └─ 1:N FCMToken

Profile (userId → User, cascade delete)
  └─ fan-out point: nearly every other domain model FKs to profileId, cascade delete

Device (userId → User, profileId → Profile SetNull; deviceCode unique, pairingCode unique)
  └─ fan-out: Application, Session, FCMToken, UsageSession, TimeExtensionRequest,
     AppUsageLog, LocationLog, SOSAlert, YouTubeLog

Session (deviceId → Device)         — legacy/simple session record (totalMinutes, bonusMinutes)
FCMToken (userId → User, deviceId? → Device SetNull; token unique; platform ANDROID|IOS)
```

## Time & Usage

```
TimeLimit            @@unique([profileId, dayOfWeek]) — dailyLimitMinutes, gradual reduction fields
UsageSession          profileId + deviceId, startTime/endTime/isActive
UsageLog              profileId, appName/websiteUrl, activityType
TimeExtensionRequest  profileId + deviceId, status PENDING|APPROVED|REJECTED
AppTimeLimit          @@unique([profileId, packageName]) — per-app daily limit (Sprint 8)
AppUsageLog           @@unique([profileId, deviceId, packageName, date]) — daily usage rollup
Application           deviceId → Device, isBlocked/timeLimitMinutes (legacy desktop app model)
BlockedApp             @@unique([profileId, packageName]) — mobile app blocking
```

## Content Filtering

```
BlockedWebsite         profileId, blockType/blockValue
WebCategory            name unique, displayName — 1:N WebCategoryDomain, 1:N BlockedCategory
WebCategoryDomain       @@unique([categoryId, domain])
BlockedCategory         @@unique([profileId, categoryId]) — 1:N CategoryOverride
CategoryOverride        @@unique([blockedCategoryId, domain]) — per-domain exception within a blocked category
CustomBlockedDomain     @@unique([profileId, domain])
```

## School Mode (Sprint 8)

```
SchoolSchedule    profileId unique (1:1) — isEnabled, template start/end, manualOverride
  ├─ 1:N SchoolDaySchedule  @@unique([scheduleId, dayOfWeek])
  └─ 1:N AllowedSchoolApp   @@unique([scheduleId, packageName])
```

## Location & Safety

```
LocationLog     profileId + deviceId, lat/lng/accuracy/source, @@index([profileId, createdAt])
Geofence        profileId, name/lat/lng/radius — 1:N GeofenceEvent
GeofenceEvent   geofenceId + profileId, type ENTER|EXIT, @@index([profileId, createdAt])
SOSAlert        profileId + deviceId, status ACTIVE|ACKNOWLEDGED|RESOLVED, audioUrl,
                @@index([profileId, createdAt])
Warning         profileId, warningType/message/userResponse (soft-warning log)
Notification    userId, title/message/type, isRead
```

## YouTube / AI Safety (Sprint 9)

```
YouTubeLog    profileId + deviceId, isAnalyzed, dangerLevel (1-5), category
              (SAFE|BULLY|SEXUAL|DRUG|VIOLENCE|SELF_HARM|DISTURBING), aiSummary, isBlocked
              @@index([profileId, watchedAt]) @@index([isAnalyzed]) @@index([dangerLevel])
              └─ 1:N AIAlert
AIAlert       profileId + youtubeLogId, dangerLevel/category/summary, isRead
              @@index([profileId, createdAt]) @@index([isRead])
BlockedVideo  profileId, reason AI_DETECTED|PARENT_MANUAL, @@index([profileId])
```

## Reports (Sprint 9)

```
ReportSnapshot   profileId, type DAILY|WEEKLY, periodStart/periodEnd, data (Json)
                 @@unique([profileId, type, periodStart])
```

## Related

- [backend.md](backend.md) — which controllers read/write each model
