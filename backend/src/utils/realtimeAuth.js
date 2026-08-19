const jwt = require('jsonwebtoken');

// Ký JWT riêng cho Supabase Realtime, KHÁC JWT_SECRET của app (app dùng JWT
// tự ký, không dùng Supabase Auth — Supabase Realtime cần JWT ký bằng chính
// jwt_secret của project Supabase để RLS ("authenticated" role) chấp nhận).
// Lấy jwt_secret ở Supabase Dashboard → Settings → API.
const REALTIME_TOKEN_TTL_SECONDS = 60 * 60; // 1h — mobile tự refresh khi hết hạn

const getSecret = () => {
  if (!process.env.SUPABASE_REALTIME_JWT_SECRET) {
    throw new Error('SUPABASE_REALTIME_JWT_SECRET not configured');
  }
  return process.env.SUPABASE_REALTIME_JWT_SECRET;
};

// Parent app instance: RLS lọc theo app_user_id.
function mintParentRealtimeToken(userId) {
  return jwt.sign(
    { aud: 'authenticated', role: 'authenticated', app_user_id: userId },
    getSecret(),
    { expiresIn: REALTIME_TOKEN_TTL_SECONDS }
  );
}

// Child app instance: không có JWT thường (auth bằng deviceCode) — RLS lọc
// theo app_device_id / app_profile_id thay vì app_user_id.
function mintChildRealtimeToken(deviceId, profileId) {
  return jwt.sign(
    { aud: 'authenticated', role: 'authenticated', app_device_id: deviceId, app_profile_id: profileId },
    getSecret(),
    { expiresIn: REALTIME_TOKEN_TTL_SECONDS }
  );
}

module.exports = {
  mintParentRealtimeToken,
  mintChildRealtimeToken,
  REALTIME_TOKEN_TTL_SECONDS,
};
