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
        private const val QUOTA_DAY_START_HOUR = 6 // khớp backend QUOTA_DAY_START_HOUR
        // Server-synced limits
        var limits: MutableMap<String, AppLimitInfo> = mutableMapOf()

        // Track warned apps (chỉ warn 1 lần/ngày/app)
        var warnedApps: MutableSet<String> = mutableSetOf()
    }

    /**
     * Kiểm tra xem app có vượt/gần vượt limit chưa.
     *
     * Nguồn dữ liệu:
     * - [limit.usedSeconds] / [limit.remainingSeconds]: server tính từ UsageLog (sync mỗi 5 phút)
     * - [getTodayUsageSeconds]: UsageStatsManager real-time trên device (API 21+)
     * - [getRealTimeOffset]: giây đã trôi qua kể từ khi app lên foreground (session hiện tại)
     *
     * Quy tắc:
     * - Nếu UsageStats có dữ liệu (> 0): dùng trực tiếp — nó đã bao gồm session hiện tại,
     *   KHÔNG cộng thêm realTimeOffset (sẽ đếm 2 lần).
     * - Nếu UsageStats trả về 0 (emulator hoặc chưa có quyền): dùng
     *   server's remainingSeconds trừ đi thời gian đã trôi qua kể từ khi app lên foreground.
     *
     * Return: "OK" | "WARNING" | "BLOCKED"
     */
    fun checkStatus(packageName: String): String {
        val limit = limits[packageName] ?: return "OK"

        val deviceUsed = getTodayUsageSeconds(packageName)
        val realTimeOffset = getRealTimeOffset(packageName)
        val actualRemaining = if (deviceUsed > 0) {
            // UsageStats has data but may be stale by up to ~2 minutes.
            // Take the more conservative (lower) of two estimates so a stale UsageStats
            // reading doesn't silently allow the child to exceed their per-app limit.
            val fromUsageStats = limit.dailyLimitMinutes * 60 - deviceUsed
            val fromServer = limit.remainingSeconds - realTimeOffset
            minOf(fromUsageStats, fromServer)
        } else {
            // UsageStats has no data (emulator / permission not granted) — use server remaining
            limit.remainingSeconds - realTimeOffset
        }

        android.util.Log.d("AppLimit", "📊 checkStatus pkg=$packageName deviceUsed=${deviceUsed}s serverRemaining=${limit.remainingSeconds}s actualRemaining=${actualRemaining}s")

        return when {
            actualRemaining <= 0 -> "BLOCKED"
            actualRemaining <= 5 * 60 -> "WARNING"
            else -> "OK"
        }
    }

    /**
     * Lấy remaining minutes cho warning notification
     */
    fun getRemainingMinutes(packageName: String): Int {
        val limit = limits[packageName] ?: return 999
        val deviceUsed = getTodayUsageSeconds(packageName)
        val realTimeOffset = getRealTimeOffset(packageName)
        val actualRemaining = if (deviceUsed > 0) {
            val fromUsageStats = limit.dailyLimitMinutes * 60 - deviceUsed
            val fromServer = limit.remainingSeconds - realTimeOffset
            minOf(fromUsageStats, fromServer)
        } else {
            limit.remainingSeconds - realTimeOffset
        }
        return maxOf(0, actualRemaining / 60)
    }

    /**
     * Lấy app name cho notification
     */
    fun getAppName(packageName: String): String {
        return limits[packageName]?.appName ?: packageName
    }

    /**
     * Giây foreground của app trong NGÀY HẠN MỨC (06:00 → 05:59 hôm sau, giờ VN),
     * khớp backend (vnQuotaDayRange). Dùng sự kiện RESUMED/PAUSED thay cho bucket
     * INTERVAL_DAILY — bucket luôn tính từ nửa đêm nên không cắt được ở 06:00.
     */
    private fun getTodayUsageSeconds(packageName: String): Int {
        return try {
            val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val events = usm.queryEvents(quotaDayStartMillis(now), now)
            val event = android.app.usage.UsageEvents.Event()
            var startedAt = -1L
            var totalMs = 0L
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.packageName != packageName) continue
                when (event.eventType) {
                    android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED ->
                        if (startedAt < 0) startedAt = event.timeStamp
                    android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED,
                    android.app.usage.UsageEvents.Event.ACTIVITY_STOPPED -> if (startedAt >= 0) {
                        totalMs += event.timeStamp - startedAt
                        startedAt = -1L
                    }
                }
            }
            // Phiên đang mở được getRealTimeOffset cộng riêng — không cộng ở đây.
            (totalMs / 1000).toInt()
        } catch (e: Exception) {
            android.util.Log.e("AppLimitChecker", "Error querying usage events: ${e.message}")
            0
        }
    }

    private fun quotaDayStartMillis(now: Long): Long {
        val cal = Calendar.getInstance(java.util.TimeZone.getTimeZone("Asia/Ho_Chi_Minh"))
        cal.timeInMillis = now
        if (cal.get(Calendar.HOUR_OF_DAY) < QUOTA_DAY_START_HOUR) cal.add(Calendar.DAY_OF_MONTH, -1)
        cal.set(Calendar.HOUR_OF_DAY, QUOTA_DAY_START_HOUR)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun getRealTimeOffset(packageName: String): Int {
        if (packageName == AppBlockerService.lastForegroundPackage && AppBlockerService.lastForegroundStartTime > 0) {
            val offset = (System.currentTimeMillis() - AppBlockerService.lastForegroundStartTime) / 1000
            if (offset > 0) return offset.toInt()
        }
        return 0
    }

}
