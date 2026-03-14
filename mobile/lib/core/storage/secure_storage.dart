import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _fcmTokenKey = 'fcm_token';
  static const _userIdKey = 'user_id';

  // ── User ID ──────────────────────────────────────
  static Future<void> saveUserId(int userId) async {
    await _storage.write(key: _userIdKey, value: userId.toString());
  }

  static Future<int?> getUserId() async {
    final val = await _storage.read(key: _userIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  // ── JWT Auth Token ──────────────────────────────
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // ── Refresh Token ───────────────────────────────
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // ── FCM Device Token ────────────────────────────
  static Future<void> saveFcmToken(String token) async {
    await _storage.write(key: _fcmTokenKey, value: token);
  }

  static Future<String?> getFcmToken() async {
    return await _storage.read(key: _fcmTokenKey);
  }

  // ── Xóa tất cả khi logout ───────────────────────
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
