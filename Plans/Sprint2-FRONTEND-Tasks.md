# KidFun V3 — Sprint 2 Tasks: FRONTEND (Flutter)

> **Thời gian:** 1 tuần
> **Branch gốc:** `develop`
> **API Server:** https://kidfun-backend-production.up.railway.app
> **Test device:** Android thật

---

## Trước khi bắt đầu — Setup môi trường

### 0.1: Cài đặt

- [ ] Cài Flutter SDK trên Windows: https://docs.flutter.dev/get-started/install/windows/mobile
  - Download Flutter SDK → giải nén vào `C:\flutter`
  - Thêm `C:\flutter\bin` vào System PATH
- [ ] Cài Android Studio: https://developer.android.com/studio
  - Mở Android Studio → SDK Manager → cài Android SDK 34
  - SDK Tools: Build-Tools, Command-line Tools, Platform-Tools
- [ ] Chạy kiểm tra:
```bash
flutter doctor -v
```
Phải thấy: Flutter ✓, Android toolchain ✓, Android Studio ✓

- [ ] Cài VSCode Extensions:
  - Flutter (Dart-Code.flutter)
  - Dart (Dart-Code.dart-code)
  - Kotlin (fwcd.kotlin)
  - GitLens (eamodio.gitlens)

### 0.2: Clone repo + checkout develop

```bash
git clone git@github.com:Khanh-4/kidfun-v2.git
cd kidfun-v2
git checkout develop
git pull origin develop
```

### 0.3: Tạo Flutter project

**Branch:** `feature/mobile/project-setup`

```bash
git checkout develop
git checkout -b feature/mobile/project-setup

cd kidfun-v2
flutter create --org com.kidfun mobile
cd mobile
```

### 0.4: Cài dependencies

Mở `mobile/pubspec.yaml`, thay phần `dependencies` và `dev_dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0

  # Navigation
  go_router: ^13.0.0

  # HTTP & API
  dio: ^5.4.0

  # Storage
  flutter_secure_storage: ^9.0.0

  # Firebase
  firebase_core: ^2.25.0
  firebase_messaging: ^14.7.0

  # UI
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.1

  # Utils
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  riverpod_generator: ^2.3.0
  build_runner: ^2.4.0
```

```bash
flutter pub get
```

### 0.5: Tạo cấu trúc thư mục

```
mobile/lib/
├── core/
│   ├── constants/
│   │   ├── api_constants.dart
│   │   ├── app_colors.dart
│   │   └── app_text_styles.dart
│   ├── network/
│   │   ├── dio_client.dart
│   │   └── api_exceptions.dart
│   ├── storage/
│   │   └── secure_storage.dart
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       ├── register_screen.dart
│   │       └── forgot_password_screen.dart
│   └── profile/
│       ├── data/
│       │   └── profile_repository.dart
│       ├── providers/
│       │   └── profile_provider.dart
│       └── screens/
│           ├── profile_list_screen.dart
│           ├── create_profile_screen.dart
│           └── edit_profile_screen.dart
├── shared/
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   └── loading_widget.dart
│   └── models/
│       ├── user_model.dart
│       └── profile_model.dart
├── app.dart
└── main.dart
```

- [ ] Tạo tất cả folders và files trống
- [ ] Chạy `flutter run` trên Android thật → thấy app mặc định

### Commit & Push
```bash
cd ~/kidfun-v2
git add -A
git commit -m "feat(mobile): initial Flutter project setup with folder structure"
git push origin feature/mobile/project-setup
```
→ GitHub tạo PR → target `develop` → nhờ Khanh review → merge

---

## Ngày 1-2: Core Setup + Auth UI

**Branch:** `feature/mobile/auth-screens`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/auth-screens
```

### Task 1.1: API Constants

File: `mobile/lib/core/constants/api_constants.dart`

```dart
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

  // Profile endpoints
  static const String profiles = '/api/profiles';

  // FCM endpoints
  static const String fcmRegister = '/api/fcm-tokens/register';
  static const String fcmUnregister = '/api/fcm-tokens/unregister';
}
```

### Task 1.2: App Colors + Theme

File: `mobile/lib/core/constants/app_colors.dart`

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2196F3);       // Xanh dương
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFFBBDEFB);
  static const Color accent = Color(0xFFFF9800);         // Cam
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}
```

File: `mobile/lib/core/theme/app_theme.dart`

- [ ] Tạo ThemeData với AppColors
- [ ] Set font chữ (Google Fonts hoặc default)
- [ ] Style cho Button, TextField, AppBar, Card

### Task 1.3: Secure Storage Wrapper

File: `mobile/lib/core/storage/secure_storage.dart`

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
```

### Task 1.4: Dio Client + JWT Interceptor

File: `mobile/lib/core/network/dio_client.dart`

```dart
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class DioClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  static Dio get instance {
    _dio.interceptors.clear();
    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    return _dio;
  }

  static Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Tự động attach JWT token
        final token = await SecureStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Nếu 401 → thử refresh token
        if (error.response?.statusCode == 401) {
          try {
            final refreshToken = await SecureStorage.getRefreshToken();
            if (refreshToken != null) {
              final response = await Dio().post(
                '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
                data: {'refreshToken': refreshToken},
              );
              if (response.data['success'] == true) {
                // Lưu token mới
                await SecureStorage.saveToken(response.data['data']['token']);
                await SecureStorage.saveRefreshToken(response.data['data']['refreshToken']);
                // Retry request gốc
                error.requestOptions.headers['Authorization'] =
                    'Bearer ${response.data['data']['token']}';
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              }
            }
          } catch (_) {}
        }
        handler.next(error);
      },
    );
  }
}
```

### Task 1.5: User Model

File: `mobile/lib/shared/models/user_model.dart`

```dart
class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String? phoneNumber;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['fullName'],
      phoneNumber: json['phoneNumber'],
    );
  }
}
```

### Task 1.6: Auth Screens (UI)

**Login Screen** — `mobile/lib/features/auth/screens/login_screen.dart`
- [ ] Logo KidFun ở trên
- [ ] Email TextField
- [ ] Password TextField (có toggle show/hide)
- [ ] Nút "Đăng nhập" (primary button)
- [ ] Link "Quên mật khẩu?" → navigate forgot password
- [ ] Link "Chưa có tài khoản? Đăng ký" → navigate register
- [ ] Loading spinner khi đang gọi API
- [ ] Hiện error message khi fail

**Register Screen** — `mobile/lib/features/auth/screens/register_screen.dart`
- [ ] Họ tên TextField
- [ ] Email TextField
- [ ] Mật khẩu TextField
- [ ] Xác nhận mật khẩu TextField
- [ ] Nút "Đăng ký"
- [ ] Link "Đã có tài khoản? Đăng nhập"
- [ ] Validation: email format, password match, tên không trống

**Forgot Password Screen** — `mobile/lib/features/auth/screens/forgot_password_screen.dart`
- [ ] Email TextField
- [ ] Nút "Gửi email khôi phục"
- [ ] Thông báo thành công sau khi gửi

### Commit & Push
```bash
git add -A
git commit -m "feat(mobile): add Dio client, secure storage, auth screens UI"
git push origin feature/mobile/auth-screens
```
→ PR → develop

---

## Ngày 3-4: Kết nối Auth API + Auto Login

**Branch:** `feature/mobile/auth-integration`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/auth-integration
```

### Task 2.1: Auth Repository

File: `mobile/lib/features/auth/data/auth_repository.dart`

```dart
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';

class AuthRepository {
  final _dio = DioClient.instance;

  Future<UserModel> login(String email, String password) async {
    final response = await _dio.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
    final data = response.data['data'];
    await SecureStorage.saveToken(data['token']);
    await SecureStorage.saveRefreshToken(data['refreshToken']);
    return UserModel.fromJson(data['user']);
  }

  Future<UserModel> register(String fullName, String email, String password) async {
    final response = await _dio.post(ApiConstants.register, data: {
      'fullName': fullName,
      'email': email,
      'password': password,
    });
    final data = response.data['data'];
    await SecureStorage.saveToken(data['token']);
    await SecureStorage.saveRefreshToken(data['refreshToken']);
    return UserModel.fromJson(data['user']);
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post(ApiConstants.forgotPassword, data: {'email': email});
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } finally {
      await SecureStorage.clearAll();
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await SecureStorage.getToken();
    return token != null;
  }
}
```

- [ ] Implement tất cả methods
- [ ] Handle errors (try-catch, throw custom exceptions)

### Task 2.2: Auth Provider (Riverpod)

File: `mobile/lib/features/auth/providers/auth_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/user_model.dart';

// Auth states
sealed class AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final _repo = AuthRepository();

  AuthNotifier() : super(AuthLoading()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    // Kiểm tra token có hợp lệ không
    // Nếu có → AuthAuthenticated
    // Nếu không → AuthUnauthenticated
  }

  Future<void> login(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.login(email, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.register(name, email, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = AuthUnauthenticated();
  }
}
```

- [ ] Implement `checkAuth()` — verify token khi app mở
- [ ] Handle tất cả states trong UI

### Task 2.3: GoRouter + Auth Guard

File: `mobile/lib/app.dart`

```dart
// Routes
// /splash — kiểm tra auth
// /login
// /register
// /forgot-password
// /home — redirect /login nếu chưa auth
// /profiles
// /profiles/create
// /profiles/:id/edit
```

- [ ] Splash screen: check auth → navigate phù hợp
- [ ] Auth guard: chưa login → redirect /login
- [ ] Đã login → không vào /login được (redirect /home)

### Task 2.4: Kết nối Auth Screens với Provider

- [ ] Login Screen: gọi `ref.read(authProvider.notifier).login(email, password)`
- [ ] Khi AuthAuthenticated → navigate /home
- [ ] Khi AuthError → hiện SnackBar error
- [ ] Khi AuthLoading → hiện CircularProgressIndicator
- [ ] Register Screen: tương tự
- [ ] Forgot Password: gọi API → hiện thông báo thành công

### Task 2.5: FCM Setup

- [ ] Tạo Firebase project config cho Android:
  - Firebase Console → Project Settings → Add app → Android
  - Package name: `com.kidfun.mobile`
  - Download `google-services.json` → đặt vào `mobile/android/app/`
- [ ] Config `mobile/android/build.gradle` và `mobile/android/app/build.gradle`
- [ ] Trong `main.dart`:
```dart
await Firebase.initializeApp();
final fcmToken = await FirebaseMessaging.instance.getToken();
// Gửi token lên server sau khi login
```
- [ ] Request notification permission
- [ ] Handle foreground notification (hiện local notification)

### Commit & Push
```bash
git add -A
git commit -m "feat(mobile): integrate auth API, auto login, GoRouter, FCM setup"
git push origin feature/mobile/auth-integration
```
→ PR → develop

---

## Ngày 5-6: Profile Management

**Branch:** `feature/mobile/profile-management`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/profile-management
```

### Task 3.1: Profile Model

File: `mobile/lib/shared/models/profile_model.dart`

```dart
class ProfileModel {
  final int id;
  final int userId;
  final String profileName;
  final DateTime? dateOfBirth;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.userId,
    required this.profileName,
    this.dateOfBirth,
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      userId: json['userId'],
      profileName: json['profileName'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      avatarUrl: json['avatarUrl'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Tính tuổi
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
}
```

### Task 3.2: Profile Repository

File: `mobile/lib/features/profile/data/profile_repository.dart`

- [ ] `Future<List<ProfileModel>> getProfiles()` → GET /api/profiles
- [ ] `Future<ProfileModel> createProfile(String name, DateTime? dob)` → POST /api/profiles
- [ ] `Future<ProfileModel> updateProfile(int id, String? name, DateTime? dob)` → PUT /api/profiles/:id
- [ ] `Future<void> deleteProfile(int id)` → DELETE /api/profiles/:id

### Task 3.3: Profile Provider

File: `mobile/lib/features/profile/providers/profile_provider.dart`

- [ ] State: `ProfileLoading`, `ProfileLoaded(profiles)`, `ProfileError(message)`
- [ ] Methods: `fetchProfiles()`, `createProfile()`, `updateProfile()`, `deleteProfile()`
- [ ] Tự động refresh list sau khi tạo/sửa/xóa

### Task 3.4: Profile List Screen

File: `mobile/lib/features/profile/screens/profile_list_screen.dart`

- [ ] AppBar: "Hồ sơ con" + nút "+"
- [ ] ListView.builder hiển thị profiles dạng Card
- [ ] Mỗi card: avatar (icon mặc định), tên, tuổi
- [ ] Nhấn card → navigate edit screen
- [ ] Swipe để xóa (hoặc long press → bottom sheet confirm)
- [ ] Empty state: "Chưa có hồ sơ nào. Nhấn + để thêm."
- [ ] Pull to refresh
- [ ] Loading shimmer khi đang tải

### Task 3.5: Create Profile Screen

File: `mobile/lib/features/profile/screens/create_profile_screen.dart`

- [ ] TextField: Tên (bắt buộc)
- [ ] Date Picker: Ngày sinh (optional)
- [ ] Avatar: chọn từ 6-8 preset avatars (icons/illustrations)
- [ ] Nút "Tạo hồ sơ"
- [ ] Validation: tên không trống, tên ≤ 50 ký tự
- [ ] Sau khi tạo → quay lại list + refresh

### Task 3.6: Edit Profile Screen

File: `mobile/lib/features/profile/screens/edit_profile_screen.dart`

- [ ] Giống Create nhưng pre-fill data từ profile hiện tại
- [ ] Nút "Lưu thay đổi"
- [ ] Nút "Xóa hồ sơ" (màu đỏ, confirm dialog)
- [ ] Sau khi lưu/xóa → quay lại list + refresh

### Commit & Push
```bash
git add -A
git commit -m "feat(mobile): add profile management screens with API integration"
git push origin feature/mobile/profile-management
```
→ PR → develop

---

## Ngày 7: Test End-to-End

### Test trên Android thật:

- [ ] Mở app → thấy Splash → chuyển Login (chưa có token)
- [ ] Đăng ký tài khoản mới → thành công → vào Home
- [ ] Đăng xuất → về Login
- [ ] Đăng nhập lại → thành công
- [ ] Tắt app → mở lại → auto login (không cần nhập lại)
- [ ] Tạo hồ sơ "Bé An" → thấy trong list
- [ ] Tạo hồ sơ "Bé Bình" → thấy 2 profiles
- [ ] Sửa "Bé An" thành "Bé An Nguyễn" → cập nhật
- [ ] Xóa "Bé Bình" → còn 1 profile
- [ ] Push notification nhận được

### Fix bugs nếu có

---

## Checklist cuối Sprint 2 — Frontend

| # | Task | Status |
|---|------|--------|
| 1 | Flutter project tạo + chạy được trên Android | ⬜ |
| 2 | Cấu trúc thư mục đúng | ⬜ |
| 3 | Dio client + JWT interceptor hoạt động | ⬜ |
| 4 | Secure storage lưu/đọc token | ⬜ |
| 5 | Login screen + kết nối API | ⬜ |
| 6 | Register screen + kết nối API | ⬜ |
| 7 | Forgot password screen | ⬜ |
| 8 | Auto login khi mở app lại | ⬜ |
| 9 | JWT refresh tự động khi hết hạn | ⬜ |
| 10 | Profile list screen | ⬜ |
| 11 | Create profile screen | ⬜ |
| 12 | Edit profile screen | ⬜ |
| 13 | Delete profile + confirm | ⬜ |
| 14 | FCM push notification nhận được | ⬜ |
| 15 | Tất cả code pushed lên develop | ⬜ |

---

## Tài liệu tham khảo

- Flutter docs: https://docs.flutter.dev
- Riverpod docs: https://riverpod.dev
- Dio docs: https://pub.dev/packages/dio
- GoRouter docs: https://pub.dev/packages/go_router
- Flutter Secure Storage: https://pub.dev/packages/flutter_secure_storage
- Firebase Messaging: https://pub.dev/packages/firebase_messaging

## Liên hệ Backend

API đã deploy tại: **https://kidfun-backend-production.up.railway.app**

Test nhanh:
```bash
# Health check
curl https://kidfun-backend-production.up.railway.app/api/health

# Register
curl -X POST https://kidfun-backend-production.up.railway.app/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"123456","fullName":"Test User"}'
```

Khi cần API mà Backend chưa xong → dùng mock data trước:
```dart
// Tạm thời hardcode
final mockProfiles = [
  ProfileModel(id: 1, userId: 1, profileName: "Bé An", createdAt: DateTime.now()),
  ProfileModel(id: 2, userId: 1, profileName: "Bé Bình", createdAt: DateTime.now()),
];
```
Khi Backend deploy xong → đổi sang gọi API thật.
