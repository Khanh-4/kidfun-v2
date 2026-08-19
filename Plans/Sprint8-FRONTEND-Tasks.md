# KidFun V3 — Sprint 8: Web Filtering, School Mode & Per-app Limits — FRONTEND (Flutter + Kotlin)

> **Sprint Goal:** UI quản lý web filter, school mode, per-app limit. Mở rộng AccessibilityService chặn URL browser
> **Branch gốc:** `develop`
> **Cơ chế:** Tận dụng AccessibilityService đã có từ Sprint 5 — KHÔNG dùng VPN

---

## Tổng quan Sprint 8 — Frontend Tasks

| Task | Nội dung | Phụ thuộc (Backend) |
|------|----------|---------------------|
| **Task 1** | Kotlin: Mở rộng AccessibilityService đọc URL browser | Không |
| **Task 2** | Kotlin: Per-app time limit enforcement | Backend Task 2 |
| **Task 3** | Kotlin: School Mode enforcement | Backend Task 4 |
| **Task 4** | Kotlin: Overlay "App hết giờ" + notification | Task 2 |
| **Task 5** | Flutter: MethodChannel + PolicyService sync | Backend Task 5 |
| **Task 6** | Parent UI: Per-app Time Limit screen | Backend Task 2 |
| **Task 7** | Parent UI: Web Filtering (categories + custom) | Backend Task 3 |
| **Task 8** | Parent UI: School Mode (template + override + apps) | Backend Task 4 |
| **Task 9** | Integration test | Backend Task 7 |

---

## Task 1: Mở Rộng AccessibilityService — Đọc URL Browser

> **Branch:** `feature/mobile/web-filtering-accessibility`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/web-filtering-accessibility
```

### 1.1: Cập nhật AppBlockerService

File sửa: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/services/AppBlockerService.kt`

```kotlin
package com.kidfun.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AppBlockerService : AccessibilityService() {
    companion object {
        // App blocklist (đã có từ Sprint 5)
        var blockedPackages: MutableSet<String> = mutableSetOf()
        
        // Web blocklist (mới cho Sprint 8)
        var blockedDomains: MutableSet<String> = mutableSetOf()
        
        // Browser packages cần monitor URL
        val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "com.chrome.beta",
            "org.mozilla.firefox",
            "com.microsoft.emmx",  // Edge
            "com.opera.browser",
            "com.brave.browser",
            "com.sec.android.app.sbrowser", // Samsung Internet
        )
        
        var isEnabled = false
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isEnabled = true
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                         AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            // Limit to browsers + all apps (performance)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        // 1. App blocking (từ Sprint 5)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (blockedPackages.contains(pkg)) {
                performGlobalAction(GLOBAL_ACTION_HOME)
                return
            }
        }

        // 2. Web URL blocking (MỚI)
        if (BROWSER_PACKAGES.contains(pkg)) {
            val root = rootInActiveWindow ?: return
            val url = extractUrl(root, pkg) ?: return
            val domain = extractDomain(url) ?: return

            if (isDomainBlocked(domain)) {
                android.util.Log.d("AppBlocker", "🚫 Blocked URL: $url (domain: $domain)")
                performGlobalAction(GLOBAL_ACTION_HOME)
                // TODO: Hiện notification "URL bị chặn"
            }
        }
    }

    private fun extractUrl(root: AccessibilityNodeInfo, pkg: String): String? {
        // Chrome: resource-id "com.android.chrome:id/url_bar"
        // Firefox: "org.mozilla.firefox:id/mozac_browser_toolbar_url_view"
        // Samsung Internet: "com.sec.android.app.sbrowser:id/location_bar_edit_text"
        val urlBarIds = listOf(
            "$pkg:id/url_bar",
            "$pkg:id/mozac_browser_toolbar_url_view",
            "$pkg:id/location_bar_edit_text",
            "$pkg:id/url_field",
        )

        for (id in urlBarIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (nodes.isNotEmpty()) {
                val text = nodes[0].text?.toString()
                if (!text.isNullOrBlank()) return text
            }
        }
        return null
    }

    private fun extractDomain(url: String): String? {
        return try {
            val cleanUrl = if (url.startsWith("http")) url else "https://$url"
            val uri = java.net.URI(cleanUrl)
            uri.host?.lowercase()?.removePrefix("www.")
        } catch (e: Exception) {
            // Fallback: regex extract
            val regex = Regex("""(?:https?://)?(?:www\.)?([^/\s]+)""")
            regex.find(url)?.groupValues?.get(1)?.lowercase()
        }
    }

    private fun isDomainBlocked(domain: String): Boolean {
        // Match exact hoặc subdomain
        if (blockedDomains.contains(domain)) return true
        for (blocked in blockedDomains) {
            if (domain.endsWith(".$blocked")) return true
        }
        return false
    }

    override fun onInterrupt() {
        isEnabled = false
    }
}
```

### 1.2: Cập nhật accessibility_service_config.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged|typeWindowContentChanged|typeViewTextChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:canRetrieveWindowContent="true"
    android:description="@string/accessibility_description"
    android:notificationTimeout="100"
    android:packageNames=""
    android:settingsActivity="com.kidfun.mobile.MainActivity"/>
```

**Quan trọng:** `canRetrieveWindowContent="true"` — cho phép đọc nội dung view.

### 1.3: MethodChannel

```kotlin
// MainActivity.kt
"setBlockedDomains" -> {
    val domains = call.argument<List<String>>("domains") ?: emptyList()
    AppBlockerService.blockedDomains.clear()
    AppBlockerService.blockedDomains.addAll(domains.map { it.lowercase() })
    android.util.Log.d("WebFilter", "🌐 Updated blocked domains: ${domains.size}")
    result.success(null)
}
```

### Commit:

```bash
git commit -m "feat(mobile): extend AccessibilityService to block URLs in browsers"
git push origin feature/mobile/web-filtering-accessibility
```
→ PR → develop → merge

---

## Task 2: Per-app Time Limit Enforcement (Kotlin)

> **Branch:** `feature/mobile/per-app-enforcement`

### 2.1: AppLimitChecker service

File tạo mới: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/services/AppLimitChecker.kt`

```kotlin
package com.kidfun.mobile.services

import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.Calendar

data class AppLimitInfo(
    val packageName: String,
    val appName: String,
    val dailyLimitMinutes: Int,
    val usedSeconds: Int,
    val remainingSeconds: Int,
)

class AppLimitChecker(private val context: Context) {
    companion object {
        // Server-synced limits
        var limits: MutableMap<String, AppLimitInfo> = mutableMapOf()
        
        // Track warned apps (chỉ warn 1 lần/ngày/app)
        var warnedApps: MutableSet<String> = mutableSetOf()
    }

    /**
     * Kiểm tra xem app có vượt/gần vượt limit chưa
     * Return: "OK" | "WARNING" | "BLOCKED"
     */
    fun checkStatus(packageName: String): String {
        val limit = limits[packageName] ?: return "OK"
        
        // Lấy usage hôm nay (foreground time, realtime từ UsageStatsManager)
        val currentUsedSeconds = getTodayUsageSeconds(packageName)
        val actualUsed = limit.usedSeconds + currentUsedSeconds  // cộng từ server + live
        val actualRemaining = limit.dailyLimitMinutes * 60 - actualUsed

        return when {
            actualRemaining <= 0 -> "BLOCKED"
            actualRemaining <= 5 * 60 -> "WARNING"
            else -> "OK"
        }
    }

    private fun getTodayUsageSeconds(packageName: String): Int {
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
        val stat = stats.firstOrNull { it.packageName == packageName } ?: return 0
        return (stat.totalTimeInForeground / 1000).toInt()
    }
}
```

### 2.2: Tích hợp vào AppBlockerService

```kotlin
// AppBlockerService.kt — thêm vào onAccessibilityEvent
if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
    // 1. App blacklist (từ Sprint 5)
    if (blockedPackages.contains(pkg)) {
        performGlobalAction(GLOBAL_ACTION_HOME)
        return
    }

    // 2. Per-app time limit check (MỚI)
    val checker = AppLimitChecker(this)
    when (checker.checkStatus(pkg)) {
        "BLOCKED" -> {
            showBlockedOverlay(pkg)
            performGlobalAction(GLOBAL_ACTION_HOME)
            return
        }
        "WARNING" -> {
            if (!AppLimitChecker.warnedApps.contains(pkg)) {
                AppLimitChecker.warnedApps.add(pkg)
                showWarningNotification(pkg)
            }
        }
    }
    // ... continue with other checks (School Mode, web)
}
```

### 2.3: Methods show notification + overlay

Xem Task 4.

### Commit:

```bash
git commit -m "feat(mobile): add per-app time limit enforcement"
```

---

## Task 3: School Mode Enforcement

> **Branch:** `feature/mobile/school-mode-enforcement`

### 3.1: SchoolModeChecker

File tạo mới: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/services/SchoolModeChecker.kt`

```kotlin
package com.kidfun.mobile.services

object SchoolModeChecker {
    // Sync từ server
    var isActive: Boolean = false
    var allowedPackages: MutableSet<String> = mutableSetOf()
    var startTime: String? = null  // "07:00"
    var endTime: String? = null    // "11:30"

    /**
     * Kiểm tra app có được phép dùng trong School Mode không
     */
    fun isAppAllowed(packageName: String): Boolean {
        if (!isActive) return true
        
        // Always allow KidFun itself
        if (packageName == "com.kidfun.mobile") return true
        
        return allowedPackages.contains(packageName)
    }
}
```

### 3.2: Tích hợp vào AppBlockerService

```kotlin
// Trong onAccessibilityEvent, sau app blacklist check:
if (SchoolModeChecker.isActive && !SchoolModeChecker.isAppAllowed(pkg)) {
    showSchoolModeOverlay()
    performGlobalAction(GLOBAL_ACTION_HOME)
    return
}
```

### 3.3: MethodChannel

```kotlin
"setSchoolMode" -> {
    val isActive = call.argument<Boolean>("isActive") ?: false
    val allowedApps = call.argument<List<String>>("allowedApps") ?: emptyList()
    val startTime = call.argument<String>("startTime")
    val endTime = call.argument<String>("endTime")

    SchoolModeChecker.isActive = isActive
    SchoolModeChecker.allowedPackages.clear()
    SchoolModeChecker.allowedPackages.addAll(allowedApps)
    SchoolModeChecker.startTime = startTime
    SchoolModeChecker.endTime = endTime

    android.util.Log.d("SchoolMode", "📚 Active=$isActive, allowed=${allowedApps.size}")
    result.success(null)
}
```

### Commit:

```bash
git commit -m "feat(mobile): add school mode enforcement"
```

---

## Task 4: Overlay + Notification (Combo UI chặn)

> **Branch:** `feature/mobile/block-ui`

### 4.1: BlockNotificationHelper

File tạo mới: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/helpers/BlockNotificationHelper.kt`

```kotlin
package com.kidfun.mobile.helpers

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.kidfun.mobile.R

object BlockNotificationHelper {
    private const val CHANNEL_ID = "kidfun_blocks"
    private const val CHANNEL_NAME = "App Blocking Notifications"

    fun showTimeLimitExceeded(context: Context, appName: String, packageName: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("⏰ $appName đã hết giờ hôm nay")
            .setContentText("Bạn đã dùng hết giới hạn thời gian cho ứng dụng này.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(packageName.hashCode(), notification)
    }

    fun showTimeLimitWarning(context: Context, appName: String, remainingMinutes: Int) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("⚠️ $appName còn $remainingMinutes phút")
            .setContentText("Sắp hết giới hạn thời gian cho ứng dụng này. Hãy dùng hợp lý nhé!")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify("warn_$appName".hashCode(), notification)
    }

    fun showSchoolModeBlock(context: Context, appName: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("📚 Đang trong giờ học")
            .setContentText("$appName không được phép dùng trong giờ học.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(appName.hashCode(), notification)
    }

    fun showWebBlocked(context: Context, domain: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("🚫 Trang web bị chặn")
            .setContentText("$domain không được phép truy cập.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(domain.hashCode(), notification)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Notifications khi app/web bị chặn"
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
```

### 4.2: Sử dụng trong AppBlockerService

```kotlin
// Khi block by app limit:
BlockNotificationHelper.showTimeLimitExceeded(this, appName, pkg)
performGlobalAction(GLOBAL_ACTION_HOME)

// Khi warning:
BlockNotificationHelper.showTimeLimitWarning(this, appName, remainingMinutes)

// Khi school mode:
BlockNotificationHelper.showSchoolModeBlock(this, appName)
performGlobalAction(GLOBAL_ACTION_HOME)

// Khi block web:
BlockNotificationHelper.showWebBlocked(this, domain)
performGlobalAction(GLOBAL_ACTION_HOME)
```

### Commit:

```bash
git commit -m "feat(mobile): add block notifications helper"
```

---

## Task 5: Flutter PolicyService + Sync

> **Branch:** `feature/mobile/policy-service`

### 5.1: PolicyService

File tạo mới: `mobile/lib/core/services/policy_service.dart`

```dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'native_service.dart';

class PolicyService {
  static final instance = PolicyService._();
  PolicyService._();

  final Dio _dio;
  Timer? _syncTimer;

  PolicyService._() : _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  /// Start periodic sync (every 2 minutes)
  void start(String deviceCode) {
    _sync(deviceCode);
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) => _sync(deviceCode));
  }

  void stop() {
    _syncTimer?.cancel();
  }

  Future<void> _sync(String deviceCode) async {
    try {
      final response = await _dio.get('/api/child/policy', queryParameters: {'deviceCode': deviceCode});
      final data = response.data['data'];

      // 1. Per-app limits
      final appLimits = List<Map<String, dynamic>>.from(data['appTimeLimits']['limits'] ?? []);
      await NativeService.setAppTimeLimits(appLimits);

      // 2. Blocked domains
      final domains = List<String>.from(data['blockedDomains']['domains'] ?? []);
      await NativeService.setBlockedDomains(domains);

      // 3. School mode
      final schoolMode = data['schoolMode'];
      await NativeService.setSchoolMode(
        isActive: schoolMode['isActive'] ?? false,
        allowedApps: List<String>.from(
          (schoolMode['allowedApps'] as List? ?? []).map((a) => a['packageName'])
        ),
        startTime: schoolMode['startTime'],
        endTime: schoolMode['endTime'],
      );

      print('✅ [POLICY] Synced — apps=${appLimits.length}, domains=${domains.length}, school=${schoolMode['isActive']}');
    } catch (e) {
      print('❌ [POLICY] Sync error: $e');
    }
  }
}
```

### 5.2: Thêm methods vào NativeService

File sửa: `mobile/lib/core/services/native_service.dart`

```dart
class NativeService {
  // ... existing methods ...

  static Future<void> setAppTimeLimits(List<Map<String, dynamic>> limits) async {
    await _channel.invokeMethod('setAppTimeLimits', {'limits': limits});
  }

  static Future<void> setBlockedDomains(List<String> domains) async {
    await _channel.invokeMethod('setBlockedDomains', {'domains': domains});
  }

  static Future<void> setSchoolMode({
    required bool isActive,
    required List<String> allowedApps,
    String? startTime,
    String? endTime,
  }) async {
    await _channel.invokeMethod('setSchoolMode', {
      'isActive': isActive,
      'allowedApps': allowedApps,
      'startTime': startTime,
      'endTime': endTime,
    });
  }
}
```

### 5.3: Kotlin MethodChannel handlers

```kotlin
// MainActivity.kt
"setAppTimeLimits" -> {
    val limits = call.argument<List<Map<String, Any>>>("limits") ?: emptyList()
    AppLimitChecker.limits.clear()
    AppLimitChecker.warnedApps.clear() // Reset warnings
    for (l in limits) {
        val pkg = l["packageName"] as String
        AppLimitChecker.limits[pkg] = AppLimitInfo(
            packageName = pkg,
            appName = (l["appName"] as? String) ?: pkg,
            dailyLimitMinutes = (l["dailyLimitMinutes"] as Number).toInt(),
            usedSeconds = (l["usedSeconds"] as? Number)?.toInt() ?: 0,
            remainingSeconds = (l["remainingSeconds"] as? Number)?.toInt() ?: 0,
        )
    }
    result.success(null)
}
```

### 5.4: Start trong ChildDashboard

```dart
@override
void initState() {
  super.initState();
  if (_deviceCode != null) {
    PolicyService.instance.start(_deviceCode!);
  }
  
  // Listen Socket.IO events để sync ngay lập tức khi Parent thay đổi
  SocketService.instance.socket.on('appTimeLimitUpdated', (_) {
    PolicyService.instance.forceSyncNow();
  });
  SocketService.instance.socket.on('blockedDomainsUpdated', (_) {
    PolicyService.instance.forceSyncNow();
  });
  SocketService.instance.socket.on('schoolScheduleUpdated', (_) {
    PolicyService.instance.forceSyncNow();
  });
}
```

### Commit:

```bash
git commit -m "feat(mobile): add policy service syncing app/web/school rules"
```

---

## Task 6: Parent UI — Per-app Time Limit Screen

> **Branch:** `feature/mobile/parent-per-app-limit`

### 6.1: Màn hình

File tạo mới: `mobile/lib/features/app_limit/screens/per_app_limit_screen.dart`

Chức năng:
- List tất cả apps đã có time limit (lấy từ API `/app-time-limits`)
- Mỗi item: icon, app name, limit (slider hoặc text), progress today, nút xóa
- Nút "Thêm giới hạn" → mở dialog chọn app (từ list app usage data) → input limit

**UI gợi ý:**

```
┌─────────────────────────────────────┐
│ Giới hạn thời gian riêng             │
│ cho từng ứng dụng                    │
├─────────────────────────────────────┤
│ 📺 YouTube                          │
│ ▓▓▓▓▓░░░░░ 25/60 phút                │
│ Limit: [30] phút/ngày    [Slider]    │
├─────────────────────────────────────┤
│ 🎵 TikTok                           │
│ ▓▓▓▓▓▓▓▓▓░ 45/60 phút    ⚠️ Sắp hết  │
│ Limit: [60] phút/ngày    [Slider]    │
├─────────────────────────────────────┤
│ [+ Thêm giới hạn]                   │
└─────────────────────────────────────┘
```

### Commit:

```bash
git commit -m "feat(mobile): parent per-app time limit screen"
```

---

## Task 7: Parent UI — Web Filtering

> **Branch:** `feature/mobile/parent-web-filter`

### 7.1: 2 Tabs: "Danh mục" và "Tùy chỉnh"

**Tab 1: Danh mục (Categories)**

- List 5 categories từ API `/api/web-categories`
- Mỗi category: icon, name, domain count, toggle bật/tắt
- Expandable: tap vào hiện domain list trong category
- Mỗi domain có toggle "cho phép" (= override whitelist)

**UI gợi ý:**

```
┌─────────────────────────────────────┐
│ Chặn theo danh mục                   │
├─────────────────────────────────────┤
│ 🔞 Người lớn (8 domains)    [ ✓ ]   │
│    ├─ pornhub.com          [Chặn]   │
│    ├─ xvideos.com          [Chặn]   │
│    └─ ... (expand)                   │
├─────────────────────────────────────┤
│ 🎰 Cờ bạc (7 domains)      [ ✓ ]   │
├─────────────────────────────────────┤
│ 🔪 Bạo lực (3 domains)     [   ]   │
├─────────────────────────────────────┤
│ 📱 Mạng xã hội (7)         [   ]   │
│    └─ Bỏ chặn riêng: facebook.com    │
├─────────────────────────────────────┤
│ 🎮 Game online (6)         [   ]   │
└─────────────────────────────────────┘
```

**Tab 2: Tùy chỉnh (Custom)**

- List domains Parent tự thêm
- Input thêm domain mới
- Nút xóa từng domain

### Commit:

```bash
git commit -m "feat(mobile): parent web filtering UI with categories and custom domains"
```

---

## Task 8: Parent UI — School Mode

> **Branch:** `feature/mobile/parent-school-mode`

### 8.1: Màn hình chính — 3 sections

**Section 1: Enable toggle**

```
┌─────────────────────────────────────┐
│ Chế độ học tập          [ ✓ Bật ] │
└─────────────────────────────────────┘
```

**Section 2: Template + Overrides**

```
┌─────────────────────────────────────┐
│ Lịch học mẫu (T2-T6)                │
│ Từ [07:00] đến [11:30]               │
├─────────────────────────────────────┤
│ Tùy chỉnh ngày cụ thể:              │
│ [ ] CN (tắt)                        │
│ [ ] T7 (tắt)                        │
│ [+] Thêm ngày khác lịch              │
└─────────────────────────────────────┘
```

**Section 3: Allowed apps**

```
┌─────────────────────────────────────┐
│ Ứng dụng được phép dùng khi học     │
├─────────────────────────────────────┤
│ ✓ Zoom                               │
│ ✓ Google Classroom                   │
│ ✓ Gmail                              │
│ [+ Thêm ứng dụng]                   │
└─────────────────────────────────────┘
```

**Section 4: Manual override**

```
┌─────────────────────────────────────┐
│ Tắt tạm 1 giờ   [Tắt ngay]          │
│ Bật tạm 1 giờ   [Bật ngay]          │
└─────────────────────────────────────┘
```

### Commit:

```bash
git commit -m "feat(mobile): parent school mode screen with template + override"
```

---

## Task 9: Integration Test

### Test flows:

| # | Test | ✅ |
|---|------|---|
| 1 | Parent thêm limit YouTube 30 phút | ⬜ |
| 2 | Child dùng YouTube 25 phút → notification warning (còn 5 phút) | ⬜ |
| 3 | Child dùng thêm 5 phút → YouTube bị chặn + notification | ⬜ |
| 4 | Parent bật category "Người lớn" | ⬜ |
| 5 | Child mở Chrome → gõ pornhub.com → bị chặn + notification | ⬜ |
| 6 | Parent thêm custom domain "badsite.com" | ⬜ |
| 7 | Child gõ badsite.com → bị chặn | ⬜ |
| 8 | Parent bỏ chặn "facebook.com" trong category Social Media (override) | ⬜ |
| 9 | Child vẫn vào được facebook.com (whitelist override) | ⬜ |
| 10 | Parent cài School Mode T2-T6 7:00-11:30 + allow Zoom | ⬜ |
| 11 | Trong giờ học: Child mở YouTube → chặn, mở Zoom → OK | ⬜ |
| 12 | Parent bấm "Tắt tạm 1 giờ" → Child mở được mọi app | ⬜ |
| 13 | Sau 1 giờ override → tự active lại | ⬜ |
| 14 | Policy sync Socket.IO real-time (< 3 giây sau Parent thay đổi) | ⬜ |

---

## Checklist cuối Sprint 8 — Frontend

| # | Task | Status |
|---|------|--------|
| 1 | AccessibilityService đọc URL browser (Chrome, Firefox, Edge, Samsung) | ⬜ |
| 2 | Domain matching (exact + subdomain) | ⬜ |
| 3 | Per-app limit checker dùng UsageStats | ⬜ |
| 4 | Block overlay + notification khi hết giờ | ⬜ |
| 5 | Warning notification khi còn 5 phút | ⬜ |
| 6 | School Mode checker | ⬜ |
| 7 | PolicyService sync mỗi 2 phút + on Socket.IO event | ⬜ |
| 8 | MethodChannel: setAppTimeLimits, setBlockedDomains, setSchoolMode | ⬜ |
| 9 | Parent: Per-app Time Limit screen | ⬜ |
| 10 | Parent: Web Filtering (Categories + Custom tabs) | ⬜ |
| 11 | Parent: School Mode (template + day overrides + apps + manual) | ⬜ |
| 12 | Integration test 14 bước pass | ⬜ |

---

## Lưu ý quan trọng

- **AccessibilityService đọc URL** chỉ hoạt động với browser thông thường. Một số browser ẩn (Tor, DuckDuckGo) có thể không đọc được.
- **Domain matching** — cần handle cả subdomain (`m.facebook.com` cũng bị chặn nếu chặn `facebook.com`)
- **UsageStats bị delay** ~5-10 giây, per-app enforcement có thể lệch vài giây. Chấp nhận được.
- **Test trên Chrome thật** — Chrome có nhiều layout khác nhau giữa các version, cần thử vài scenario
- **School Mode check thời gian ở Kotlin local** — không gọi API mỗi giây, dùng state đã sync

## Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/<tên-task>
git commit -m "feat(mobile): mô tả"
git push origin feature/mobile/<tên-task>
# → PR → develop → Khanh review → merge
```
