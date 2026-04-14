class ApiConstants {
  // Production server (Railway)
  static const String baseUrl = 'https://kidfun-backend-production.up.railway.app';

  // Uncomment cho dev local:
  // static const String baseUrl = 'http://10.0.2.2:3001'; // Android emulator
  // static const String baseUrl = 'http://192.168.x.x:3001'; // Android thật

  // Auth endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refreshToken = '/api/auth/refresh-token';
  static const String logout = '/api/auth/logout';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPasswordOtp = '/api/auth/reset-password-otp';

  // Profile endpoints
  static const String profiles = '/api/profiles';

  // FCM endpoints
  static const String fcmRegister = '/api/fcm-tokens/register';
  static const String fcmUnregister = '/api/fcm-tokens/unregister';

  // Device endpoints
  static const String devices = '/api/devices';
  static const String devicesGeneratePairingCode = '/api/devices/generate-pairing-code';
  static const String devicesLink = '/api/devices/link';
  
  // Device status endpoint (Sprint 3)
  static String deviceStatus(int deviceId) => '/api/devices/$deviceId/status';

  // Web filtering endpoints (Sprint 8)
  static const String webCategories = '/api/web-categories';
}
