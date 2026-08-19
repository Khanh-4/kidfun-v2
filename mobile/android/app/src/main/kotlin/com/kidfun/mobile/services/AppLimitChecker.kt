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

    private fun getTodayUsageSeconds(packageName: String): Int {
        return try {
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
            (stat.totalTimeInForeground / 1000).toInt()
        } catch (e: Exception) {
            android.util.Log.e("AppLimitChecker", "Error querying usage stats: ${e.message}")
            0
        }
    }

    private fun getRealTimeOffset(packageName: String): Int {
        if (packageName == AppBlockerService.lastForegroundPackage && AppBlockerService.lastForegroundStartTime > 0) {
            val offset = (System.currentTimeMillis() - AppBlockerService.lastForegroundStartTime) / 1000
            if (offset > 0) return offset.toInt()
        }
        return 0
    }
}
