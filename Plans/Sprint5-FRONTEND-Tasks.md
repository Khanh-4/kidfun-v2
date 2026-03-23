# KidFun V3 — Sprint 5: Native Android & Lock Screen — FRONTEND (Flutter + Kotlin)

> **Sprint Goal:** Tích hợp Android native APIs — theo dõi app usage, chặn app, lock screen
> **Quan trọng:** Sprint này cần viết Kotlin native code, giao tiếp Flutter ↔ Kotlin qua MethodChannel
> **Branch gốc:** `develop`

---

## Tổng quan Sprint 5 — Frontend Tasks

| Task | Nội dung | Phụ thuộc (Backend) |
|------|----------|---------------------|
| **Task 1** | Flutter ↔ Kotlin MethodChannel setup | Không |
| **Task 2** | Kotlin: ForegroundService (chạy nền 24/7) | Task 1 |
| **Task 3** | Kotlin: UsageStatsManager (thu thập app usage) | Task 1, 2 |
| **Task 4** | Kotlin: AccessibilityService (chặn app) | Task 1, 2 |
| **Task 5** | Kotlin: DevicePolicyManager (lock screen) | Task 1 |
| **Task 6** | Child App: Lock Screen fullscreen + gửi usage data | Backend Task 1 |
| **Task 7** | Parent App: App Blocking UI | Backend Task 2 |
| **Task 8** | Integration test | Backend Task 6 |

---

## Task 1: Flutter ↔ Kotlin MethodChannel Setup

> Thiết lập kênh giao tiếp giữa Flutter (Dart) và Android native (Kotlin).

**Branch:** `feature/mobile/method-channel`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/method-channel
```

### 1.1: Tạo MethodChannel trong Flutter

File tạo mới: `mobile/lib/core/services/native_service.dart`

```dart
import 'package:flutter/services.dart';

class NativeService {
  static const _channel = MethodChannel('com.kidfun.native');

  /// Lấy danh sách app usage từ Android UsageStatsManager
  static Future<List<Map<String, dynamic>>> getAppUsage() async {
    final result = await _channel.invokeMethod('getAppUsage');
    return List<Map<String, dynamic>>.from(result);
  }

  /// Bắt đầu foreground service
  static Future<void> startForegroundService() async {
    await _channel.invokeMethod('startForegroundService');
  }

  /// Dừng foreground service
  static Future<void> stopForegroundService() async {
    await _channel.invokeMethod('stopForegroundService');
  }

  /// Chặn app bằng AccessibilityService
  static Future<void> setBlockedApps(List<String> packageNames) async {
    await _channel.invokeMethod('setBlockedApps', {'packages': packageNames});
  }

  /// Lock screen bằng DevicePolicyManager
  static Future<void> lockScreen() async {
    await _channel.invokeMethod('lockScreen');
  }

  /// Kiểm tra quyền UsageStats đã cấp chưa
  static Future<bool> hasUsageStatsPermission() async {
    return await _channel.invokeMethod('hasUsageStatsPermission');
  }

  /// Mở Settings để cấp quyền UsageStats
  static Future<void> requestUsageStatsPermission() async {
    await _channel.invokeMethod('requestUsageStatsPermission');
  }

  /// Kiểm tra AccessibilityService đã bật chưa
  static Future<bool> isAccessibilityEnabled() async {
    return await _channel.invokeMethod('isAccessibilityEnabled');
  }

  /// Mở Settings để bật AccessibilityService
  static Future<void> requestAccessibilityPermission() async {
    await _channel.invokeMethod('requestAccessibilityPermission');
  }
}
```

### 1.2: Tạo Kotlin handler

File sửa: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/MainActivity.kt`

```kotlin
package com.kidfun.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kidfun.native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppUsage" -> {
                        // Task 3: UsageStatsManager
                        result.success(emptyList<Map<String, Any>>())
                    }
                    "startForegroundService" -> {
                        // Task 2: ForegroundService
                        result.success(null)
                    }
                    "stopForegroundService" -> {
                        result.success(null)
                    }
                    "setBlockedApps" -> {
                        // Task 4: AccessibilityService
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        result.success(null)
                    }
                    "lockScreen" -> {
                        // Task 5: DevicePolicyManager
                        result.success(null)
                    }
                    "hasUsageStatsPermission" -> {
                        result.success(false) // Task 3
                    }
                    "requestUsageStatsPermission" -> {
                        result.success(null)
                    }
                    "isAccessibilityEnabled" -> {
                        result.success(false) // Task 4
                    }
                    "requestAccessibilityPermission" -> {
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): setup Flutter-Kotlin MethodChannel for native APIs"
git push origin feature/mobile/method-channel
```
→ PR → develop → Khanh review → merge

---

## Task 2: Kotlin ForegroundService (Chạy nền 24/7)

> Service chạy liên tục để monitoring app usage + enforce blocking.

**Branch:** `feature/mobile/foreground-service`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/foreground-service
```

### 2.1: Tạo KidFunService.kt

File tạo mới: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/services/KidFunService.kt`

```kotlin
package com.kidfun.mobile.services

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.kidfun.mobile.MainActivity

class KidFunService : Service() {
    companion object {
        const val CHANNEL_ID = "kidfun_foreground"
        const val NOTIFICATION_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("KidFun đang hoạt động")
            .setContentText("Đang giám sát thiết bị")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(PendingIntent.getActivity(
                this, 0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            .build()

        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY // Tự restart nếu bị kill
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KidFun Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Giám sát thiết bị của trẻ"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
```

### 2.2: Đăng ký trong AndroidManifest.xml

File sửa: `mobile/android/app/src/main/AndroidManifest.xml`

```xml
<!-- Thêm permissions -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>

<!-- Thêm service trong <application> -->
<service
    android:name=".services.KidFunService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="specialUse"/>
```

### 2.3: Kết nối với MethodChannel

Trong `MainActivity.kt`, xử lý start/stop:

```kotlin
"startForegroundService" -> {
    val serviceIntent = Intent(this, KidFunService::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        startForegroundService(serviceIntent)
    } else {
        startService(serviceIntent)
    }
    result.success(null)
}
"stopForegroundService" -> {
    stopService(Intent(this, KidFunService::class.java))
    result.success(null)
}
```

### 2.4: Tự động start khi Child mở app

Trong `child_dashboard_screen.dart`, thêm vào `_initializeDashboard()`:

```dart
// Start foreground service (Child only)
NativeService.startForegroundService();
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add KidFun ForegroundService for 24/7 monitoring"
git push origin feature/mobile/foreground-service
```
→ PR → develop → Khanh review → merge

---

## Task 3: Kotlin UsageStatsManager (Thu thập app usage)

> Đọc app usage data từ Android và gửi lên server.

**Branch:** `feature/mobile/usage-stats`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/usage-stats
```

### 3.1: Thêm permission

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
    tools:ignore="ProtectedPermissions"/>
```

### 3.2: Implement UsageStatsHelper.kt

File tạo mới: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/helpers/UsageStatsHelper.kt`

```kotlin
package com.kidfun.mobile.helpers

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import java.util.Calendar

class UsageStatsHelper(private val context: Context) {

    fun hasPermission(): Boolean {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -1)
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            cal.timeInMillis,
            System.currentTimeMillis()
        )
        return stats != null && stats.isNotEmpty()
    }

    fun requestPermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    fun getTodayUsage(): List<Map<String, Any>> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)

        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            cal.timeInMillis,
            System.currentTimeMillis()
        )

        return stats
            .filter { it.totalTimeInForeground > 60000 } // > 1 phút
            .sortedByDescending { it.totalTimeInForeground }
            .map { stat ->
                val appName = try {
                    val pm = context.packageManager
                    pm.getApplicationLabel(pm.getApplicationInfo(stat.packageName, 0)).toString()
                } catch (e: Exception) { stat.packageName }

                mapOf(
                    "packageName" to stat.packageName,
                    "appName" to appName,
                    "usageSeconds" to (stat.totalTimeInForeground / 1000).toInt()
                )
            }
    }
}
```

### 3.3: Kết nối MethodChannel

```kotlin
// MainActivity.kt
private lateinit var usageHelper: UsageStatsHelper

override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    usageHelper = UsageStatsHelper(this)
    
    // Trong handler:
    "getAppUsage" -> result.success(usageHelper.getTodayUsage())
    "hasUsageStatsPermission" -> result.success(usageHelper.hasPermission())
    "requestUsageStatsPermission" -> { usageHelper.requestPermission(); result.success(null) }
}
```

### 3.4: Flutter — gửi usage data lên server định kỳ

Trong Child Dashboard, thêm timer gửi mỗi 5 phút:

```dart
Timer.periodic(const Duration(minutes: 5), (_) async {
  final hasPermission = await NativeService.hasUsageStatsPermission();
  if (!hasPermission) return;
  
  final usage = await NativeService.getAppUsage();
  if (usage.isNotEmpty && _deviceCode != null) {
    await _childRepo.syncAppUsage(_deviceCode!, usage);
  }
});
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add UsageStatsManager for app usage tracking"
git push origin feature/mobile/usage-stats
```
→ PR → develop → Khanh review → merge

---

## Task 4: Kotlin AccessibilityService (Chặn app)

> Phát hiện app foreground và chặn nếu nằm trong blacklist.

**Branch:** `feature/mobile/accessibility-service`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/accessibility-service
```

### 4.1: Tạo AppBlockerService.kt

File tạo mới: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/services/AppBlockerService.kt`

```kotlin
package com.kidfun.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {
    companion object {
        var blockedPackages: MutableSet<String> = mutableSetOf()
        var isEnabled = false
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isEnabled = true
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return

            if (blockedPackages.contains(packageName)) {
                // Chặn: quay về home screen
                performGlobalAction(GLOBAL_ACTION_HOME)
                // TODO: Hiện overlay thông báo "App bị chặn"
            }
        }
    }

    override fun onInterrupt() {
        isEnabled = false
    }

    override fun onDestroy() {
        super.onDestroy()
        isEnabled = false
    }
}
```

### 4.2: Config AccessibilityService

File tạo mới: `mobile/android/app/src/main/res/xml/accessibility_service_config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:canRetrieveWindowContent="false"
    android:description="@string/accessibility_description"
    android:notificationTimeout="100"
    android:packageNames=""
    android:settingsActivity="com.kidfun.mobile.MainActivity"/>
```

### 4.3: Đăng ký trong AndroidManifest.xml

```xml
<service
    android:name=".services.AppBlockerService"
    android:exported="true"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService"/>
    </intent-filter>
    <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/accessibility_service_config"/>
</service>
```

### 4.4: Kết nối MethodChannel

```kotlin
"setBlockedApps" -> {
    val packages = call.argument<List<String>>("packages") ?: emptyList()
    AppBlockerService.blockedPackages.clear()
    AppBlockerService.blockedPackages.addAll(packages)
    result.success(null)
}
"isAccessibilityEnabled" -> {
    result.success(AppBlockerService.isEnabled)
}
"requestAccessibilityPermission" -> {
    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    startActivity(intent)
    result.success(null)
}
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add AccessibilityService for app blocking"
git push origin feature/mobile/accessibility-service
```
→ PR → develop → Khanh review → merge

---

## Task 5: Kotlin DevicePolicyManager (Lock Screen)

> Khóa màn hình thiết bị khi hết giờ — thay thế dialog hiện tại.

**Branch:** `feature/mobile/device-lock`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/device-lock
```

### 5.1: Tạo DeviceAdmin

File tạo mới: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/receivers/DeviceAdminReceiver.kt`

```kotlin
package com.kidfun.mobile.receivers

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class KidFunDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }
}
```

### 5.2: Config

File tạo mới: `mobile/android/app/src/main/res/xml/device_admin.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<device-admin>
    <uses-policies>
        <force-lock/>
    </uses-policies>
</device-admin>
```

### 5.3: AndroidManifest

```xml
<receiver
    android:name=".receivers.KidFunDeviceAdminReceiver"
    android:permission="android.permission.BIND_DEVICE_ADMIN">
    <meta-data
        android:name="android.app.device_admin"
        android:resource="@xml/device_admin"/>
    <intent-filter>
        <action android:name="android.app.action.DEVICE_ADMIN_ENABLED"/>
    </intent-filter>
</receiver>
```

### 5.4: MethodChannel

```kotlin
"lockScreen" -> {
    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val adminComponent = ComponentName(this, KidFunDeviceAdminReceiver::class.java)
    if (dpm.isAdminActive(adminComponent)) {
        dpm.lockNow()
        result.success(true)
    } else {
        // Yêu cầu quyền Device Admin
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "KidFun cần quyền để khóa màn hình khi hết giờ")
        }
        startActivity(intent)
        result.success(false)
    }
}
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add DevicePolicyManager for lock screen"
git push origin feature/mobile/device-lock
```
→ PR → develop → Khanh review → merge

---

## Task 6: Child App — Lock Screen + Gửi Usage Data

**Branch:** `feature/mobile/child-lock-usage`

### 6.1: Thay dialog "Hết giờ" bằng native lock

Trong `child_dashboard_screen.dart`, sửa `_onTimeUp()`:

```dart
void _onTimeUp() async {
  _countdownTimer?.cancel();
  _heartbeatTimer?.cancel();
  
  // Log warning
  if (_deviceCode != null) {
    _childRepo.logWarning(deviceCode: _deviceCode!, type: 'TIME_UP', remainingMinutes: 0);
  }

  // Lock screen bằng native API
  await NativeService.lockScreen();
  
  // Vẫn hiện fullscreen dialog (backup nếu lock screen không hoạt động)
  // ... giữ nguyên code dialog hiện tại ...
}
```

### 6.2: Sync blocked apps khi mở app

```dart
Future<void> _syncBlockedApps() async {
  if (_deviceCode == null) return;
  try {
    final blockedApps = await _childRepo.getBlockedApps(_deviceCode!);
    final packages = blockedApps.map((a) => a.packageName).toList();
    await NativeService.setBlockedApps(packages);
  } catch (e) {
    print('Error syncing blocked apps: $e');
  }
}
```

### 6.3: Listen blockedAppsUpdated event

```dart
SocketService.instance.socket.on('blockedAppsUpdated', (data) {
  _syncBlockedApps(); // Re-sync khi Parent thay đổi
});
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): integrate native lock screen and blocked apps sync"
git push origin feature/mobile/child-lock-usage
```
→ PR → develop → Khanh review → merge

---

## Task 7: Parent App — App Blocking UI

**Branch:** `feature/mobile/app-blocking-ui`

### 7.1: Màn hình App Blocking

- [ ] Hiển thị danh sách app đã cài trên device Child (lấy từ app usage data)
- [ ] Mỗi app có toggle chặn/bỏ chặn
- [ ] Gọi POST/DELETE /api/profiles/:id/blocked-apps khi toggle
- [ ] Navigate từ Profile Detail

### 7.2: Màn hình App Usage Report

- [ ] Biểu đồ bar chart app usage hôm nay (top 10 apps)
- [ ] Biểu đồ line chart usage 7 ngày
- [ ] Gọi GET /api/profiles/:id/app-usage và /app-usage/weekly

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add app blocking UI and usage reports for parent"
git push origin feature/mobile/app-blocking-ui
```
→ PR → develop → Khanh review → merge

---

## Task 8: Integration Test

### Permission Flow:
1. [ ] Child mở app → request UsageStats permission → cấp quyền
2. [ ] Child mở app → request Accessibility → bật trong Settings
3. [ ] Child mở app → request Device Admin → cấp quyền

### App Usage:
4. [ ] Child dùng YouTube 5 phút → app usage data gửi lên server
5. [ ] Parent xem Reports → thấy YouTube 5 phút

### App Blocking:
6. [ ] Parent chặn YouTube → Child nhận blockedAppsUpdated
7. [ ] Child mở YouTube → bị quay về Home screen
8. [ ] Parent bỏ chặn → Child mở YouTube bình thường

### Lock Screen:
9. [ ] Đặt time limit 2 phút → hết giờ → thiết bị bị lock
10. [ ] ForegroundService chạy → thấy notification "KidFun đang hoạt động"

---

## Checklist cuối Sprint 5 — Frontend

| # | Task | Status |
|---|------|--------|
| 1 | MethodChannel Flutter ↔ Kotlin hoạt động | ⬜ |
| 2 | ForegroundService chạy nền, notification hiện | ⬜ |
| 3 | UsageStatsManager thu thập usage data đúng | ⬜ |
| 4 | Usage data gửi lên server thành công | ⬜ |
| 5 | AccessibilityService chặn app trong blacklist | ⬜ |
| 6 | DevicePolicyManager lock screen khi hết giờ | ⬜ |
| 7 | Child sync blocked apps từ server | ⬜ |
| 8 | blockedAppsUpdated event cập nhật real-time | ⬜ |
| 9 | Parent App Blocking UI (toggle chặn/bỏ chặn) | ⬜ |
| 10 | Parent App Usage Reports (biểu đồ) | ⬜ |
| 11 | Permission flow hoạt động đúng | ⬜ |
| 12 | Tất cả code pushed lên develop | ⬜ |

---

## Lưu ý quan trọng

- **Android permissions:** UsageStats, Accessibility, Device Admin đều cần user **tự bật trong Settings**. App chỉ có thể mở Settings page, không tự bật được.
- **Accessibility Service** bị Google Play Store kiểm duyệt nghiêm ngặt. Cho đồ án thì OK, nhưng nếu publish lên Store cần justify rõ use case.
- **ForegroundService** cần notification visible — đây là yêu cầu Android, không bỏ được.
- **Test trên thiết bị thật** — Emulator có thể không hỗ trợ đầy đủ UsageStats và Accessibility.

## Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/<tên-task>
git commit -m "feat(mobile): mô tả"
git push origin feature/mobile/<tên-task>
# → PR → develop → Khanh review → merge
```
