-- ============================================================================
-- KHÔNG tự động chạy — copy/paste vào Supabase Dashboard → SQL Editor và chạy
-- thủ công sau khi đã review. File này KHÔNG được apply tự động bởi Prisma
-- migrate hay bất kỳ script nào trong repo.
--
-- Mục đích: cho phép mobile app subscribe trực tiếp vào thay đổi DB (Postgres
-- Changes) qua Supabase Realtime, thay cho Socket.IO. Vì app dùng JWT tự ký
-- (không phải Supabase Auth), các RLS policy dưới đây đọc claim tuỳ biến
-- (app_user_id / app_device_id / app_profile_id) từ JWT được mint bởi
-- backend/src/utils/realtimeAuth.js — ký bằng SUPABASE_REALTIME_JWT_SECRET
-- (= jwt_secret của project, lấy ở Settings → API).
--
-- Sau khi chạy file này: bật Realtime cho các bảng trong Database → Replication
-- (hoặc dùng lệnh ALTER PUBLICATION ở cuối file).
-- ============================================================================

-- ── Helper functions: đọc custom claim từ JWT hiện tại ─────────────────────
create or replace function app_current_user_id() returns int
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::json ->> 'app_user_id', '')::int
$$;

create or replace function app_current_device_id() returns int
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::json ->> 'app_device_id', '')::int
$$;

create or replace function app_current_profile_id() returns int
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::json ->> 'app_profile_id', '')::int
$$;

-- ── Device: cột userId trực tiếp ────────────────────────────────────────────
alter table "Device" enable row level security;
create policy "family can read own devices" on "Device"
  for select to authenticated
  using ("userId" = app_current_user_id() or id = app_current_device_id());

-- ── Các bảng có profileId: family = chủ profile (parent) hoặc chính profile đó (child) ──
-- TimeExtensionRequest, GeofenceEvent, SOSAlert, AIAlert, BlockedApp,
-- CustomBlockedDomain, BlockedVideo, AppTimeLimit, TimeLimit, LocationLog,
-- SchoolSchedule

do $$
declare
  t text;
  tables text[] := array[
    'TimeExtensionRequest', 'GeofenceEvent', 'SOSAlert', 'AIAlert',
    'BlockedApp', 'CustomBlockedDomain', 'BlockedVideo', 'AppTimeLimit',
    'TimeLimit', 'LocationLog', 'SchoolSchedule'
  ];
begin
  foreach t in array tables loop
    execute format('alter table %I enable row level security', t);
    execute format(
      'create policy "family can read own %s" on %I
         for select to authenticated
         using (
           "profileId" in (select id from "Profile" where "userId" = app_current_user_id())
           or "profileId" = app_current_profile_id()
         )',
      t, t
    );
  end loop;
end $$;

-- ── Bật Realtime (Postgres Changes) cho các bảng trên ───────────────────────
alter publication supabase_realtime add table
  "Device", "TimeExtensionRequest", "GeofenceEvent", "SOSAlert", "AIAlert",
  "BlockedApp", "CustomBlockedDomain", "BlockedVideo", "AppTimeLimit",
  "TimeLimit", "LocationLog", "SchoolSchedule";

-- ============================================================================
-- Ghi chú:
-- - Chỉ tạo policy SELECT (đọc) — Realtime chỉ cần quyền đọc để relay event,
--   không đổi quyền ghi hiện có của app (app vẫn ghi qua Prisma bằng
--   DATABASE_URL, không qua RLS này).
-- - Nếu policy tên trùng đã tồn tại (chạy lại script), xoá policy cũ trước:
--   drop policy if exists "family can read own <Table>" on "<Table>";
-- - locationRequested KHÔNG có trong danh sách trên vì đó là lệnh tức thời
--   (không tạo row DB) — xử lý qua Realtime Broadcast riêng, xem
--   docs/CODEBASE_AUDIT.md / PR liên quan.
-- ============================================================================
