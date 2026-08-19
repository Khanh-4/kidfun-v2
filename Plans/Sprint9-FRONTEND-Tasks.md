# KidFun V3 — Sprint 9: YouTube Monitoring, AI Safety & Reports — FRONTEND (Flutter + Kotlin)

> **Sprint Goal:** YouTube tracker + Parent Dashboard + AI Alert + Daily/Weekly Reports + Activity History
> **Branch gốc:** `develop`
> **Cơ chế YouTube:** Mở rộng AccessibilityService đã có (Sprint 5+8)
> **Charts:** `fl_chart` package
> **Reports:** CHỈ Parent App — không touch Child app

---

## Tổng quan Sprint 9 — Frontend Tasks

### Phần A: YouTube Monitoring + AI Safety

| Task | Nội dung | Phụ thuộc (Backend) |
|------|----------|---------------------|
| **Task 1** | Kotlin: YouTube Tracker (đọc title + channel) | Không |
| **Task 2** | Kotlin: Track watch duration | Task 1 |
| **Task 3** | Kotlin: Block video logic + overlay | Task 1 |
| **Task 4** | Flutter: Batch upload service | Backend A2 |
| **Task 5** | Parent UI: Dashboard YouTube | Backend A6 |
| **Task 6** | Parent UI: Drill-down logs + Block manual | Backend A6, A7 |
| **Task 7** | Parent UI: AI Alert dialog + Alert center | Backend A5 |

### Phần B: Reports & Analytics (Parent only)

| Task | Nội dung | Phụ thuộc (Backend) |
|------|----------|---------------------|
| **Task 8** | Reports Screen với TabBar | Backend B8-B11 |
| **Task 9** | Daily Report Tab — biểu đồ + cards | Backend B8 |
| **Task 10** | Weekly Report Tab — bar chart 7 ngày | Backend B9 |
| **Task 11** | Activity History Screen (timeline) | Backend B10 |
| **Task 12** | Navigation — thêm entry vào Parent Home | Không |

### Phần C: Test

| Task | Nội dung |
|------|----------|
| **Task 13** | Integration test toàn bộ Sprint 9 |

---

## 🎯 PHẦN A: YouTube Monitoring & AI Safety

## Task 1: Kotlin YouTube Tracker

> **Branch:** `feature/mobile/youtube-tracker`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/youtube-tracker
```

### 1.1: YouTubeTracker class

File tạo mới: `mobile/android/app/src/main/kotlin/com/kidfun/mobile/services/YouTubeTracker.kt`

```kotlin
package com.kidfun.mobile.services

import android.view.accessibility.AccessibilityNodeInfo

data class YouTubeVideoInfo(
    val title: String,
    val channelName: String?,
    val videoId: String?, // Có thể null nếu không lấy được
    val thumbnailUrl: String?,
    val startedAt: Long, // System.currentTimeMillis()
)

object YouTubeTracker {
    const val YOUTUBE_PACKAGE = "com.google.android.youtube"
    
    // Resource IDs cho YouTube app (cần check từng version)
    private val TITLE_VIEW_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/title",
        "$YOUTUBE_PACKAGE:id/video_title",
        "$YOUTUBE_PACKAGE:id/watch_video_title",
    )
    
    private val CHANNEL_VIEW_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/channel_name",
        "$YOUTUBE_PACKAGE:id/owner_name",
        "$YOUTUBE_PACKAGE:id/byline",
    )

    // Current video being tracked
    var currentVideo: YouTubeVideoInfo? = null
    
    // Pending logs to upload (in-memory queue)
    val pendingLogs: MutableList<Map<String, Any?>> = mutableListOf()
    
    // Blocked videos (sync from server)
    var blockedVideos: List<Map<String, String?>> = emptyList()

    /**
     * Extract video info from YouTube watch page
     */
    fun extractVideoInfo(root: AccessibilityNodeInfo): YouTubeVideoInfo? {
        val title = findTextByIds(root, TITLE_VIEW_IDS) ?: return null
        val channel = findTextByIds(root, CHANNEL_VIEW_IDS)
        
        // Skip if title quá ngắn hoặc generic
        if (title.length < 3 || title == "YouTube" || title == "Trang chủ") return null
        
        return YouTubeVideoInfo(
            title = title,
            channelName = channel,
            videoId = null, // YouTube ẩn URL trong app, khó lấy
            thumbnailUrl = null, // Sẽ tạo từ videoId nếu có
            startedAt = System.currentTimeMillis(),
        )
    }

    private fun findTextByIds(root: AccessibilityNodeInfo, ids: List<String>): String? {
        for (id in ids) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            for (node in nodes) {
                val text = node.text?.toString()?.trim()
                if (!text.isNullOrBlank()) return text
            }
        }
        return null
    }

    /**
     * Called when video changes or user leaves YouTube
     */
    fun stopCurrentVideo() {
        val current = currentVideo ?: return
        val durationSec = ((System.currentTimeMillis() - current.startedAt) / 1000).toInt()
        
        // Skip nếu xem < 10 giây
        if (durationSec < 10) {
            currentVideo = null
            return
        }

        pendingLogs.add(mapOf(
            "videoTitle" to current.title,
            "channelName" to current.channelName,
            "videoId" to current.videoId,
            "thumbnailUrl" to current.thumbnailUrl,
            "watchedAt" to current.startedAt,
            "durationSeconds" to durationSec,
        ))

        android.util.Log.d("YouTubeTracker", "📺 Video done: ${current.title} (${durationSec}s)")
        currentVideo = null
    }

    /**
     * Check if video should be blocked
     */
    fun isVideoBlocked(title: String, channel: String?): Boolean {
        return blockedVideos.any { blocked ->
            val bTitle = blocked["videoTitle"] as? String ?: return@any false
            // Match by title (exact hoặc contains)
            title.equals(bTitle, ignoreCase = true) ||
            title.contains(bTitle, ignoreCase = true)
        }
    }
}
```

### 1.2: Tích hợp vào AppBlockerService

File sửa: `AppBlockerService.kt`

```kotlin
override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    if (event == null) return
    val pkg = event.packageName?.toString() ?: return

    // ... existing checks (app blocklist, per-app limit, school mode, web filter) ...

    // NEW: YouTube tracking
    if (pkg == YouTubeTracker.YOUTUBE_PACKAGE) {
        handleYouTubeEvent(event)
    } else if (YouTubeTracker.currentVideo != null) {
        // Switched away from YouTube
        YouTubeTracker.stopCurrentVideo()
    }
}

private fun handleYouTubeEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
        event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) return

    val root = rootInActiveWindow ?: return
    val info = YouTubeTracker.extractVideoInfo(root) ?: return

    // Same video → skip
    if (YouTubeTracker.currentVideo?.title == info.title) return

    // New video detected
    YouTubeTracker.stopCurrentVideo() // Save previous

    // Check if blocked
    if (YouTubeTracker.isVideoBlocked(info.title, info.channelName)) {
        BlockNotificationHelper.showVideoBlocked(this, info.title)
        performGlobalAction(GLOBAL_ACTION_HOME)
        return
    }

    // Start tracking new video
    YouTubeTracker.currentVideo = info
    android.util.Log.d("YouTubeTracker", "▶️ Started: ${info.title} | ${info.channelName}")
}
```

### 1.3: Lưu khi screen off / app kill

Thêm trong `KidFunService` (foreground service):

```kotlin
// Listen screen off
private val screenReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_SCREEN_OFF) {
            YouTubeTracker.stopCurrentVideo()
        }
    }
}

override fun onCreate() {
    // ...
    registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
}
```

### Commit:

```bash
git commit -m "feat(mobile): add YouTube tracker via AccessibilityService"
git push origin feature/mobile/youtube-tracker
```
→ PR → develop → merge

---

## Task 2: Watch Duration Tracking

Đã được implement trong Task 1 (tự động tính từ `startedAt` đến lúc `stopCurrentVideo`).

**Edge cases cần xử lý:**

| Case | Xử lý |
|------|-------|
| User pause video | Tracker vẫn count time → có thể inflate. Chấp nhận cho đồ án. |
| User chuyển video khác trong YouTube | `extractVideoInfo` detect title mới → save cũ + start mới |
| User minimize app | `onAccessibilityEvent` cho package khác → stop current |
| User force close YouTube | Screen off receiver → stop current |
| Video rất dài (> 1 giờ) | OK, chỉ là 1 record duy nhất |

---

## Task 3: Block Overlay

> Đã có nền tảng từ Sprint 8 (`BlockNotificationHelper`)

### 3.1: Thêm method vào BlockNotificationHelper

```kotlin
fun showVideoBlocked(context: Context, videoTitle: String) {
    ensureChannel(context)
    val notification = NotificationCompat.Builder(context, CHANNEL_ID)
        .setContentTitle("🚫 Video bị chặn")
        .setContentText("Video \"${videoTitle.take(60)}...\" không phù hợp với bạn.")
        .setSmallIcon(android.R.drawable.ic_dialog_alert)
        .setAutoCancel(true)
        .build()
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    manager.notify(videoTitle.hashCode(), notification)
}
```

### Commit:

```bash
git commit -m "feat(mobile): add blocked video notification helper"
```

---

## Task 4: Flutter Batch Upload Service

> **Branch:** `feature/mobile/youtube-upload-service`

### 4.1: YouTube Service (Flutter)

File tạo mới: `mobile/lib/core/services/youtube_service.dart`

```dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

class YouTubeService {
  static final instance = YouTubeService._();
  YouTubeService._();

  static const _channel = MethodChannel('com.kidfun.native');
  Timer? _uploadTimer;
  Timer? _syncBlockedTimer;

  /// Start periodic upload + sync
  void start(String deviceCode) {
    // Upload pending logs every 5 minutes
    _uploadTimer = Timer.periodic(const Duration(minutes: 5), (_) => _uploadPending(deviceCode));
    
    // Sync blocked videos every 2 minutes
    _syncBlockedTimer = Timer.periodic(const Duration(minutes: 2), (_) => _syncBlockedVideos(deviceCode));

    // Run once at start
    _syncBlockedVideos(deviceCode);
  }

  void stop() {
    _uploadTimer?.cancel();
    _syncBlockedTimer?.cancel();
  }

  Future<void> _uploadPending(String deviceCode) async {
    try {
      final pending = await _channel.invokeMethod<List<dynamic>>('getPendingYouTubeLogs') ?? [];
      if (pending.isEmpty) return;

      final logs = pending.map((e) => Map<String, dynamic>.from(e)).toList();

      await _dio.post('/api/child/youtube-logs', data: {
        'deviceCode': deviceCode,
        'logs': logs,
      });

      // Clear after successful upload
      await _channel.invokeMethod('clearPendingYouTubeLogs');
      print('✅ [YOUTUBE] Uploaded ${logs.length} logs');
    } catch (e) {
      print('❌ [YOUTUBE] Upload error: $e');
    }
  }

  Future<void> _syncBlockedVideos(String deviceCode) async {
    try {
      final response = await _dio.get('/api/child/blocked-videos', queryParameters: {'deviceCode': deviceCode});
      final blocked = List<Map<String, dynamic>>.from(response.data['data']['blockedVideos'] ?? []);
      await _channel.invokeMethod('setBlockedVideos', {'videos': blocked});
      print('✅ [YOUTUBE] Synced ${blocked.length} blocked videos');
    } catch (e) {
      print('❌ [YOUTUBE] Sync blocked error: $e');
    }
  }

  /// Force sync (call when receiving Socket.IO event)
  void forceSyncBlocked(String deviceCode) => _syncBlockedVideos(deviceCode);
}
```

### 4.2: Kotlin MethodChannel handlers

```kotlin
// MainActivity.kt
"getPendingYouTubeLogs" -> {
    val logs = YouTubeTracker.pendingLogs.toList()
    result.success(logs)
}
"clearPendingYouTubeLogs" -> {
    YouTubeTracker.pendingLogs.clear()
    result.success(null)
}
"setBlockedVideos" -> {
    val videos = call.argument<List<Map<String, String?>>>("videos") ?: emptyList()
    YouTubeTracker.blockedVideos = videos
    result.success(null)
}
```

### 4.3: Start service trong Child Dashboard

```dart
@override
void initState() {
  super.initState();
  if (_deviceCode != null) {
    PolicyService.instance.start(_deviceCode!);
    YouTubeService.instance.start(_deviceCode!); // NEW
  }

  SocketService.instance.socket.on('blockedVideosUpdated', (_) {
    YouTubeService.instance.forceSyncBlocked(_deviceCode!);
  });
}

@override
void dispose() {
  YouTubeService.instance.stop();
  super.dispose();
}
```

### Commit:

```bash
git commit -m "feat(mobile): add YouTube upload + blocked sync service"
```

---

## Task 5: Parent Dashboard Screen

> **Branch:** `feature/mobile/parent-youtube-dashboard`

### 5.1: Dashboard structure

File tạo mới: `mobile/lib/features/youtube/screens/youtube_dashboard_screen.dart`

**Layout (top to bottom):**

```
┌─────────────────────────────────────┐
│ 📺 YouTube Activity - Bé An          │
│ [7 ngày ▼]                           │
├─────────────────────────────────────┤
│ TỔNG QUAN                            │
│ ┌──────────┬────────────┬─────────┐ │
│ │ Videos   │ Watch time │ Alerts  │ │
│ │   245    │ 4h 23m     │   3 🔴 │ │
│ └──────────┴────────────┴─────────┘ │
├─────────────────────────────────────┤
│ MỨC ĐỘ NỘI DUNG                      │
│ ▓▓▓▓▓░░░░░ Level 1 (An toàn): 120   │
│ ▓▓▓░░░░░░░ Level 2: 60               │
│ ▓░░░░░░░░░ Level 3: 25               │
│ ▓░░░░░░░░░ Level 4 (Nguy hiểm): 8   │
│ ░░░░░░░░░░ Level 5: 0                │
│ ░░░░░░░░░░ Chưa phân tích: 32       │
├─────────────────────────────────────┤
│ TOP CHANNELS                         │
│ 1. Cocomelon - 45 videos - 1h 23m   │
│ 2. PewDiePie - 30 videos - 50m      │
│ ... [Xem tất cả →]                   │
├─────────────────────────────────────┤
│ DANH MỤC ĐÁNG NGHI                   │
│ 🟠 VIOLENCE: 5                       │
│ 🟠 DISTURBING: 3                     │
│ 🔴 SEXUAL: 0                         │
├─────────────────────────────────────┤
│ ⚠️ CẢNH BÁO GẦN ĐÂY (5)              │
│ [Card 1] - tap to drill down         │
│ [Card 2]                             │
│ ...                                  │
├─────────────────────────────────────┤
│ HOẠT ĐỘNG THEO NGÀY                  │
│ [Bar chart 7 ngày]                   │
├─────────────────────────────────────┤
│ [Xem tất cả videos →]                │
└─────────────────────────────────────┘
```

### 5.2: Code skeleton

```dart
class YouTubeDashboardScreen extends StatefulWidget {
  final int profileId;
  final String profileName;
  
  // ... StatefulWidget setup ...
  
  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    final response = await _dio.get('/api/profiles/${widget.profileId}/youtube/dashboard',
        queryParameters: {'days': _selectedDays});
    setState(() {
      _data = response.data['data'];
      _loading = false;
    });
  }
  
  Widget _buildSummaryCards() => /* 3 cards: total, time, alerts */ ;
  Widget _buildDangerLevelChart() => /* Horizontal bar chart 1-5 */ ;
  Widget _buildTopChannels() => /* List với progress bars */ ;
  Widget _buildCategoriesGrid() => /* Grid icons + counts */ ;
  Widget _buildRecentAlerts() => /* List of alert cards */ ;
  Widget _buildDailyActivity() => /* Bar chart by day */ ;
}
```

### 5.3: Charts package

```bash
flutter pub add fl_chart
```

### Commit:

```bash
git commit -m "feat(mobile): parent YouTube dashboard with charts"
```

---

## Task 6: Drill-down Logs + Manual Block

> **Branch:** `feature/mobile/youtube-logs-screen`

### 6.1: Logs Screen

File tạo mới: `mobile/lib/features/youtube/screens/youtube_logs_screen.dart`

**Filters:**
- Date picker
- Min danger level (slider 0-5)
- Channel filter (dropdown)

**List item:**

```
┌─────────────────────────────────────┐
│ [Thumbnail] Title video             │
│             Channel · 5 phút trước   │
│             ⚠️ Level 4 - VIOLENCE   │
│             "Tóm tắt AI..."          │
│             [Đã chặn ✓]  [Bỏ chặn]  │
└─────────────────────────────────────┘
```

### 6.2: Block/Unblock action

```dart
Future<void> _toggleBlock(YouTubeLog log) async {
  if (log.isBlocked) {
    // Find blocked video by title and delete
    await _dio.delete('/api/blocked-videos/${log.blockedId}');
  } else {
    await _dio.post('/api/profiles/${widget.profileId}/blocked-videos', data: {
      'videoTitle': log.videoTitle,
      'channelName': log.channelName,
      'videoId': log.videoId,
    });
  }
  _refresh();
}
```

### 6.3: Pagination

Implement infinite scroll với `page` param.

### Commit:

```bash
git commit -m "feat(mobile): YouTube logs screen with filters and manual block"
```

---

## Task 7: AI Alert Dialog + Alert Center

> **Branch:** `feature/mobile/ai-alerts`

### 7.1: AI Alert Dialog (real-time)

Listen Socket.IO event và hiện dialog ưu tiên cao:

```dart
// Trong global listener (HomeScreen hoặc AppShell)
SocketService.instance.socket.on('aiAlert', (data) async {
  await showDialog(
    context: NavigatorService.navigatorKey.currentContext!,
    barrierDismissible: false,
    builder: (_) => AIAlertDialog(data: data),
  );
});
```

### 7.2: AI Alert Dialog UI

File tạo mới: `mobile/lib/features/youtube/widgets/ai_alert_dialog.dart`

```dart
class AIAlertDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  
  @override
  Widget build(BuildContext context) {
    final dangerLevel = data['dangerLevel'];
    final color = dangerLevel >= 5 ? Colors.red.shade900 : Colors.red;
    
    return Dialog(
      backgroundColor: color.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, color: color, size: 64),
            const SizedBox(height: 16),
            Text('⚠️ NỘI DUNG NGUY HIỂM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text('Mức độ: $dangerLevel/5 - ${data['category']}'),
            const SizedBox(height: 16),
            // Profile name
            Text('${data['profileName']} đã xem:'),
            const SizedBox(height: 8),
            // Video title
            Card(
              child: ListTile(
                title: Text(data['videoTitle'], maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(data['channelName'] ?? ''),
              ),
            ),
            const SizedBox(height: 12),
            // AI summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Text('🤖 ${data['summary']}'),
            ),
            const SizedBox(height: 8),
            const Text('✅ Video đã được tự động chặn', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to YouTube logs centered on this alert
                  },
                  child: const Text('Xem chi tiết'),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 7.3: Alert Center (Inbox)

File tạo mới: `mobile/lib/features/youtube/screens/ai_alerts_screen.dart`

- Tab "Chưa đọc" / "Tất cả"
- List các AI alerts (sorted newest first)
- Tap → mở chi tiết với video info
- Mark as read khi tap
- Badge số lượng unread

### 7.4: Badge unread

Trên Home screen, hiện badge số alerts chưa đọc:

```dart
Stack(
  children: [
    IconButton(icon: Icon(Icons.warning), onPressed: () => navigateToAlerts()),
    if (_unreadCount > 0)
      Positioned(
        right: 0,
        top: 0,
        child: CircleAvatar(
          radius: 10,
          backgroundColor: Colors.red,
          child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
  ],
)
```

### Commit:

```bash
git commit -m "feat(mobile): AI alert dialog and alert center for parent"
```

---


---

## 📊 PHẦN B: Reports & Analytics

## Task 8: Reports Screen với Tab Switcher

> **Branch:** `feature/mobile/parent-reports-screen`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/parent-reports-screen
```

### 8.1: Reports Screen chính

File tạo mới: `mobile/lib/features/reports/screens/reports_screen.dart`

```dart
import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  final int profileId;
  final String profileName;
  
  const ReportsScreen({super.key, required this.profileId, required this.profileName});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Báo cáo - ${widget.profileName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hôm nay', icon: Icon(Icons.today)),
            Tab(text: 'Tuần này', icon: Icon(Icons.calendar_view_week)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DailyReportTab(profileId: widget.profileId),
          WeeklyReportTab(profileId: widget.profileId),
        ],
      ),
    );
  }
}
```

### 8.2: Repository

File tạo mới: `mobile/lib/features/reports/data/report_repository.dart`

```dart
class ReportRepository {
  final Dio _dio;
  ReportRepository(this._dio);

  Future<Map<String, dynamic>> getDailyReport(int profileId, {DateTime? date}) async {
    final params = <String, dynamic>{};
    if (date != null) {
      params['date'] = date.toIso8601String().substring(0, 10);
    }
    final response = await _dio.get('/api/profiles/$profileId/reports/daily', queryParameters: params);
    return response.data['data']['report']['data'] ?? {};
  }

  Future<Map<String, dynamic>> getWeeklyReport(int profileId, {DateTime? weekStart}) async {
    final params = <String, dynamic>{};
    if (weekStart != null) {
      params['weekStart'] = weekStart.toIso8601String().substring(0, 10);
    }
    final response = await _dio.get('/api/profiles/$profileId/reports/weekly', queryParameters: params);
    return response.data['data']['report']['data'] ?? {};
  }

  Future<List<dynamic>> getActivityHistory(int profileId, {DateTime? date}) async {
    final params = <String, dynamic>{};
    if (date != null) {
      params['date'] = date.toIso8601String().substring(0, 10);
    }
    final response = await _dio.get('/api/profiles/$profileId/activity-history', queryParameters: params);
    return response.data['data']['activities'] ?? [];
  }
}
```

### Commit:

```bash
git commit -m "feat(mobile): parent reports screen with tab switcher"
```

---

## Task 9: Daily Report Tab

> **Branch:** `feature/mobile/daily-report-tab`

### 9.1: Layout

```
┌─────────────────────────────────────┐
│ [DatePicker: Hôm nay ▼]              │
├─────────────────────────────────────┤
│ TỔNG QUAN                            │
│ ┌──────────────┬─────────────────┐ │
│ │ ⏱️ Screen time│ 📱 Apps đã dùng│ │
│ │   2h 35m      │     12           │ │
│ └──────────────┴─────────────────┘ │
│ ┌──────────────┬─────────────────┐ │
│ │ 📺 YouTube   │ 🆘 SOS          │ │
│ │  45m (15 vid)│     0            │ │
│ └──────────────┴─────────────────┘ │
├─────────────────────────────────────┤
│ TOP APPS (Pie chart)                 │
│ [Pie với legend]                     │
│ 1. YouTube 45m 🔴                    │
│ 2. TikTok 30m                        │
│ 3. Chrome 20m                        │
├─────────────────────────────────────┤
│ MỨC ĐỘ VIDEO YOUTUBE                 │
│ Level 1 (an toàn): ▓▓▓▓▓▓ 10        │
│ Level 2: ▓▓▓▓ 3                      │
│ Level 3: ▓ 1                         │
│ Level 4 (nguy hiểm): ▓ 1            │
├─────────────────────────────────────┤
│ DI CHUYỂN                            │
│ • Vào "Nhà" lúc 07:30                │
│ • Rời "Nhà" lúc 12:15                │
│ • Vào "Trường" lúc 13:00             │
├─────────────────────────────────────┤
│ CẢNH BÁO                             │
│ ⚠️ 1 cảnh báo AI                     │
│ ⚠️ 2 cảnh báo mềm (xin thêm giờ)    │
└─────────────────────────────────────┘
```

### 9.2: Code

File tạo mới: `mobile/lib/features/reports/widgets/daily_report_tab.dart`

```dart
class DailyReportTab extends StatefulWidget {
  final int profileId;
  const DailyReportTab({super.key, required this.profileId});

  @override
  State<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<DailyReportTab> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.getDailyReport(widget.profileId, date: _selectedDate);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return const Center(child: Text('Chưa có dữ liệu'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDatePicker(),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildTopAppsChart(),
          const SizedBox(height: 16),
          _buildYouTubeDangerLevels(),
          const SizedBox(height: 16),
          _buildLocationSection(),
          const SizedBox(height: 16),
          _buildAlertsSection(),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 90)),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            Text(_formatDate(_selectedDate)),
            const Spacer(),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final screenMinutes = _data!['totalScreenMinutes'] ?? 0;
    final topApps = (_data!['topApps'] as List?) ?? [];
    final ytStats = _data!['youtubeStats'] as Map? ?? {};
    final sosCount = _data!['sosAlertsCount'] ?? 0;
    final aiAlertsCount = _data!['aiAlertsCount'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _summaryCard('⏱️ Thời gian màn hình', _formatDuration(screenMinutes), Colors.blue),
        _summaryCard('📱 Apps đã dùng', '${topApps.length}', Colors.green),
        _summaryCard('📺 YouTube', '${ytStats['totalMinutes']}m · ${ytStats['totalVideos']} video', Colors.red),
        _summaryCard('⚠️ Cảnh báo', '${aiAlertsCount + sosCount}', Colors.orange),
      ],
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppsChart() {
    final topApps = (_data!['topApps'] as List?) ?? [];
    if (topApps.isEmpty) return const SizedBox();

    // Use fl_chart PieChart
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Apps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: topApps.take(5).toList().asMap().entries.map((e) {
                    final app = e.value;
                    return PieChartSectionData(
                      value: (app['seconds'] as num).toDouble(),
                      title: app['appName'] ?? app['packageName'],
                      radius: 60,
                      color: _pieColors[e.key % _pieColors.length],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            ...topApps.take(5).toList().asMap().entries.map((e) {
              final app = e.value;
              final mins = ((app['seconds'] as num) / 60).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, color: _pieColors[e.key % _pieColors.length]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(app['appName'] ?? app['packageName'])),
                    Text('${mins}m'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildYouTubeDangerLevels() {
    final ytStats = _data!['youtubeStats'] as Map? ?? {};
    final dangerLevels = ytStats['dangerLevels'] as Map? ?? {};
    
    if ((ytStats['totalVideos'] ?? 0) == 0) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mức độ nội dung YouTube', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...[1, 2, 3, 4, 5].map((level) {
              final count = dangerLevels['$level'] ?? 0;
              return _dangerBar(level, count);
            }),
          ],
        ),
      ),
    );
  }

  Widget _dangerBar(int level, int count) {
    final colors = {1: Colors.green, 2: Colors.lightGreen, 3: Colors.orange, 4: Colors.red, 5: Colors.red.shade900};
    final labels = {1: 'An toàn', 2: 'Nhẹ', 3: 'Đáng nghi', 4: 'Nguy hiểm', 5: 'Cực nguy hiểm'};
    final total = ((_data!['youtubeStats'] as Map)['totalVideos'] ?? 1) as int;
    final percent = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('Level $level', style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: colors[level],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: Text('$count (${labels[level]})', style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final loc = _data!['locationStats'] as Map? ?? {};
    final events = (loc['geofenceEvents'] as List?) ?? [];
    if (events.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Di chuyển', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...events.take(10).map((e) {
              final isEnter = e['type'] == 'ENTER';
              return ListTile(
                leading: Icon(isEnter ? Icons.login : Icons.logout, color: isEnter ? Colors.green : Colors.orange),
                title: Text('${isEnter ? "Vào" : "Rời"} ${e['geofenceName']}'),
                subtitle: Text(_formatTime(DateTime.parse(e['timestamp']))),
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    final aiCount = _data!['aiAlertsCount'] ?? 0;
    final sosCount = _data!['sosAlertsCount'] ?? 0;
    final extCount = _data!['approvedExtensionsCount'] ?? 0;

    if (aiCount == 0 && sosCount == 0 && extCount == 0) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sự kiện', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (aiCount > 0) _eventRow(Icons.psychology, '$aiCount cảnh báo AI', Colors.red),
            if (sosCount > 0) _eventRow(Icons.warning, '$sosCount SOS khẩn cấp', Colors.red.shade900),
            if (extCount > 0) _eventRow(Icons.access_time, '$extCount xin thêm giờ được duyệt', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _eventRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(text)]),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Hôm nay (${d.day}/${d.month})';
    return '${d.day}/${d.month}/${d.year}';
  }
  String _formatDuration(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
  String _formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static const _pieColors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];
}
```

### Commit:

```bash
git commit -m "feat(mobile): daily report tab with charts and summaries"
```

---

## Task 10: Weekly Report Tab

> **Branch:** `feature/mobile/weekly-report-tab`

### 10.1: Layout

Tương tự Daily nhưng:
- Thay DatePicker bằng **Week picker** (chọn tuần)
- Thêm **Bar chart 7 ngày** (screen time mỗi ngày trong tuần)
- Summary cards tuần (tổng 7 ngày)

### 10.2: Code skeleton

```dart
class WeeklyReportTab extends StatefulWidget {
  final int profileId;
  const WeeklyReportTab({super.key, required this.profileId});
  // ...
}

class _WeeklyReportTabState extends State<WeeklyReportTab> {
  DateTime _weekStart = _currentMonday();

  static DateTime _currentMonday() {
    final now = DateTime.now();
    final diff = now.weekday - 1;
    return DateTime(now.year, now.month, now.day - diff);
  }

  // Load weekly report
  // Render summary cards + bar chart 7 ngày + top apps tuần + alerts tổng
}
```

### 10.3: Bar chart 7 ngày

Weekly report chỉ có tổng cả tuần, không có breakdown theo ngày. Để vẽ bar chart 7 ngày, **gọi song song 7 daily reports** trong tuần:

```dart
Future<List<double>> _load7DaysScreenTime() async {
  final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
  final reports = await Future.wait(
    days.map((d) => _repo.getDailyReport(widget.profileId, date: d)),
  );
  return reports.map((r) => ((r['totalScreenMinutes'] ?? 0) as num).toDouble()).toList();
}
```

Bar chart với fl_chart:

```dart
BarChart(
  BarChartData(
    barGroups: List.generate(7, (i) => BarChartGroupData(
      x: i,
      barRods: [BarChartRodData(toY: dailyMinutes[i], color: Colors.blue)],
    )),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) {
            const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
            return Text(labels[v.toInt()]);
          },
        ),
      ),
    ),
  ),
)
```

### Commit:

```bash
git commit -m "feat(mobile): weekly report tab with 7-day bar chart"
```

---

## Task 11: Activity History Screen

> **Branch:** `feature/mobile/activity-history`

### 11.1: Layout — Timeline

```
┌─────────────────────────────────────┐
│ Lịch sử hoạt động - Bé An            │
│ [DatePicker: Hôm nay ▼]              │
├─────────────────────────────────────┤
│ 14:35 🔴 SOS khẩn cấp                │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─              │
│ 13:20 ⚠️ Cảnh báo AI: VIOLENCE       │
│      "Video có bạo lực rõ ràng"      │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─              │
│ 13:00 📍 Vào "Trường"                │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─              │
│ 12:15 📍 Rời "Nhà"                   │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─              │
│ 10:30 ⏰ Xin thêm 15 phút (Duyệt)    │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─              │
│ 10:25 🔔 Cảnh báo mềm 5 phút         │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─              │
│ 08:30 📱 Bắt đầu dùng điện thoại     │
└─────────────────────────────────────┘
```

### 11.2: Code

File tạo mới: `mobile/lib/features/reports/screens/activity_history_screen.dart`

```dart
class ActivityHistoryScreen extends StatefulWidget {
  final int profileId;
  final String profileName;
  const ActivityHistoryScreen({super.key, required this.profileId, required this.profileName});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final activities = await _repo.getActivityHistory(widget.profileId, date: _selectedDate);
      setState(() {
        _activities = activities;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lịch sử ${widget.profileName}')),
      body: Column(
        children: [
          _buildDatePicker(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _activities.isEmpty
                    ? const Center(child: Text('Không có hoạt động'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _activities.length,
                          itemBuilder: (_, i) => _buildActivityItem(_activities[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> a) {
    final type = a['type'] as String;
    final timestamp = DateTime.parse(a['timestamp']);
    final config = _typeConfig(type);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: config.color.withOpacity(0.2), shape: BoxShape.circle),
        child: Icon(config.icon, color: config.color),
      ),
      title: Text(a['title']),
      subtitle: Text(a['description'] ?? _formatTime(timestamp)),
      trailing: Text(
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  _TypeConfig _typeConfig(String type) {
    switch (type) {
      case 'SOS': return _TypeConfig(Icons.warning, Colors.red.shade900);
      case 'AI_ALERT': return _TypeConfig(Icons.psychology, Colors.red);
      case 'GEOFENCE_ENTER': return _TypeConfig(Icons.login, Colors.green);
      case 'GEOFENCE_EXIT': return _TypeConfig(Icons.logout, Colors.orange);
      case 'TIME_EXTENSION': return _TypeConfig(Icons.access_time, Colors.blue);
      case 'WARNING': return _TypeConfig(Icons.notifications, Colors.yellow.shade800);
      case 'SESSION_START': return _TypeConfig(Icons.play_arrow, Colors.blue);
      case 'SESSION_END': return _TypeConfig(Icons.stop, Colors.grey);
      default: return _TypeConfig(Icons.circle, Colors.grey);
    }
  }

  // ... _buildDatePicker tương tự Daily tab ...
}

class _TypeConfig {
  final IconData icon;
  final Color color;
  _TypeConfig(this.icon, this.color);
}
```

### Commit:

```bash
git commit -m "feat(mobile): activity history timeline screen"
```

---

## Task 12: Navigation Entry

> **Branch:** `feature/mobile/reports-navigation`

### 12.1: Thêm vào Parent Home

Thêm 2 cards/buttons vào Parent Home Screen:

```dart
GridView.count(
  crossAxisCount: 2,
  children: [
    _navCard('📊 Báo cáo', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen(profileId: ..., profileName: ...)))),
    _navCard('📅 Lịch sử hoạt động', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityHistoryScreen(...)))),
    // ... existing nav cards ...
  ],
)
```

### 12.2: Alternative — Bottom Nav Bar hoặc Drawer

Nếu Parent Home đã đầy nav buttons, có thể thêm Reports vào bottom nav bar hoặc drawer menu.

### Commit:

```bash
git commit -m "feat(mobile): add reports navigation entry to parent home"
```

---


---

## 🚀 PHẦN C: Integration Test

## Task 13: Integration Test (Full Sprint 9)

### Phần A: YouTube + AI (20 flows)

| # | Test | ✅ |
|---|------|---|
| A1 | Child mở YouTube → AccessibilityService đọc title + channel | ⬜ |
| A2 | Child xem video > 10 giây → log vào pendingLogs | ⬜ |
| A3 | Child xem video < 10 giây → KHÔNG log (skip) | ⬜ |
| A4 | Child chuyển video → log video cũ + start tracking video mới | ⬜ |
| A5 | Child rời YouTube → log saved | ⬜ |
| A6 | Mỗi 5 phút: pendingLogs upload lên server (batch) | ⬜ |
| A7 | Backend nhận logs, lưu DB | ⬜ |
| A8 | AI Worker chạy mỗi 10 phút, phân tích videos (cần GEMINI_API_KEY) | ⬜ |
| A9 | Video an toàn (level 1-3): chỉ lưu log, không alert | ⬜ |
| A10 | Video nguy hiểm (level 4-5): tạo alert + block + push | ⬜ |
| A11 | Parent nhận push notification | ⬜ |
| A12 | Parent mở app → Dialog AI Alert hiện (Socket.IO) | ⬜ |
| A13 | Parent xem dashboard → tổng quan đúng | ⬜ |
| A14 | Top channels, danger summary, alerts hiển thị | ⬜ |
| A15 | Drill-down logs với filter | ⬜ |
| A16 | Parent manual block 1 video | ⬜ |
| A17 | Child sync blocked list → mở video bị chặn → kick về Home | ⬜ |
| A18 | Parent unblock → Child mở được lại | ⬜ |
| A19 | Alert center hiển thị danh sách alerts chưa đọc | ⬜ |
| A20 | Mark as read → badge giảm | ⬜ |

### Phần B: Reports (16 flows)

| # | Test | ✅ |
|---|------|---|
| B1 | Parent mở Reports → tab "Hôm nay" hiện | ⬜ |
| B2 | Summary cards hiển thị đúng số liệu | ⬜ |
| B3 | Pie chart Top Apps render đúng | ⬜ |
| B4 | YouTube danger levels hiển thị nếu có data | ⬜ |
| B5 | Geofence events timeline trong ngày | ⬜ |
| B6 | Alerts summary đúng số lượng | ⬜ |
| B7 | DatePicker đổi ngày → reload data | ⬜ |
| B8 | Ngày cũ load từ cache (nhanh < 1s) | ⬜ |
| B9 | Ngày hôm nay load realtime | ⬜ |
| B10 | Tab "Tuần này" → bar chart 7 ngày | ⬜ |
| B11 | Week picker đổi tuần | ⬜ |
| B12 | Activity History timeline đúng thứ tự | ⬜ |
| B13 | Tất cả 6 loại events hiển thị (session, geofence, extension, SOS, AI, warning) | ⬜ |
| B14 | Icons + colors đúng cho mỗi type | ⬜ |
| B15 | Pull-to-refresh hoạt động | ⬜ |
| B16 | Empty state khi không có data | ⬜ |

---

## ✅ Checklist Tổng hợp Sprint 9 — Frontend

### Phần A: YouTube + AI

| # | Task | Status |
|---|------|--------|
| A1 | YouTubeTracker đọc title + channel từ YouTube UI | ⬜ |
| A2 | Watch duration tracking chính xác | ⬜ |
| A3 | Skip video xem < 10 giây | ⬜ |
| A4 | Auto stop khi rời YouTube / screen off | ⬜ |
| A5 | YouTube blocked check + kick về Home | ⬜ |
| A6 | Block notification cho video bị chặn | ⬜ |
| A7 | Flutter batch upload mỗi 5 phút | ⬜ |
| A8 | Sync blocked videos mỗi 2 phút + Socket.IO | ⬜ |
| A9 | Dashboard YouTube với charts (fl_chart) | ⬜ |
| A10 | Top channels, danger summary, daily activity | ⬜ |
| A11 | Drill-down logs với filter (date, danger, channel) | ⬜ |
| A12 | Manual block/unblock video | ⬜ |
| A13 | AI Alert Dialog (Socket.IO real-time) | ⬜ |
| A14 | AI Alert Center / Inbox | ⬜ |
| A15 | Badge unread alerts | ⬜ |
| A16 | Push notification handling | ⬜ |

### Phần B: Reports

| # | Task | Status |
|---|------|--------|
| B1 | Reports Screen với TabBar (Hôm nay / Tuần này) | ⬜ |
| B2 | ReportRepository | ⬜ |
| B3 | Daily Report Tab — summary cards | ⬜ |
| B4 | Daily — Pie chart top apps | ⬜ |
| B5 | Daily — YouTube danger levels bar | ⬜ |
| B6 | Daily — Location timeline | ⬜ |
| B7 | Daily — Alerts section | ⬜ |
| B8 | Weekly Report Tab — 7-day bar chart | ⬜ |
| B9 | Weekly — Summary tuần | ⬜ |
| B10 | Week picker | ⬜ |
| B11 | Activity History Screen | ⬜ |
| B12 | Timeline item với icons + colors | ⬜ |
| B13 | Date picker | ⬜ |
| B14 | Navigation entry vào Parent Home | ⬜ |

---

## 📝 Lưu ý quan trọng

### Về YouTube Tracker

- **YouTube UI thay đổi liên tục** — Resource IDs có thể khác giữa các version YouTube. Test trên version YouTube hiện tại của thiết bị, có thể cần update list IDs trong `YouTubeTracker.kt`.
- **Tracking không 100% chính xác** — Title nhanh thay đổi khi user scroll, có thể miss vài videos. Chấp nhận cho đồ án.
- **Watch duration có thể lệch** — Pause/buffer/skip không detect được. Số giây tracked = thời gian YouTube foreground.
- **Test trên thiết bị thật** — YouTube UI khác hoàn toàn giữa emulator và thiết bị thật.

### Về AI Alerts

- **AI có thể chậm** — Worker chạy mỗi 10 phút, nên video mới xem có thể 10-15 phút sau mới thấy alert.
- **Block by title** — Match theo string, có thể có false positive nếu 2 videos cùng tên. Acceptable cho đồ án.
- **Nếu chưa có GEMINI_API_KEY** — AI Worker skip, video logs vẫn lưu nhưng không có dangerLevel. UI nên handle `dangerLevel == null` (chưa phân tích).

### Về Reports

- **fl_chart package** đã cài — không cần cài lại
- **Weekly tab load 7 daily reports** có thể chậm ~2-5 giây. Thêm skeleton loading.
- **Empty state:** Không phải ngày nào cũng có đủ data (ví dụ ngày con không dùng điện thoại). Handle gracefully.
- **Responsive:** Test trên cả màn nhỏ (360px) và lớn (tablet nếu có)

### Về Privacy

- **Chỉ log metadata** (title, channel, duration). KHÔNG record video, screenshot, comment.
- **UI Parent rõ ràng** — hiển thị nguồn data, lý do AI đánh giá, không spy con mức độ vô lý.

---

## 🔀 Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/<tên-task>
git commit -m "feat(mobile): mô tả"
git push origin feature/mobile/<tên-task>
# → PR → develop → Khanh review → merge
```
