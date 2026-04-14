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

        // Dùng UsageStatsManager (real-time) làm nguồn chính.
        // limit.usedSeconds từ server có thể stale — lấy max để tránh undercount.
        val deviceUsed = getTodayUsageSeconds(packageName)
        val actualUsed = maxOf(limit.usedSeconds, deviceUsed)
        val actualRemaining = limit.dailyLimitMinutes * 60 - actualUsed

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
        val actualUsed = maxOf(limit.usedSeconds, deviceUsed)
        return maxOf(0, (limit.dailyLimitMinutes * 60 - actualUsed) / 60)
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
}
