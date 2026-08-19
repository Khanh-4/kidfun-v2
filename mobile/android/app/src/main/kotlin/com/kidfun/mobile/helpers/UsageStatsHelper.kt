package com.kidfun.mobile.helpers

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
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

    fun getInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        return pm.getInstalledApplications(0)
            .filter { (it.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) == 0 }
            .mapNotNull { info ->
                try {
                    val appName = pm.getApplicationLabel(info).toString()
                    mapOf(
                        "packageName" to info.packageName,
                        "appName" to appName,
                        "usageSeconds" to 0
                    )
                } catch (e: Exception) {
                    null
                }
            }
    }

    fun getTodayUsage(): List<Map<String, Any>> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            cal.timeInMillis,
            System.currentTimeMillis()
        ) ?: return emptyList()

        return stats
            .filter { it.totalTimeInForeground > 60_000L } // > 1 phút
            .sortedByDescending { it.totalTimeInForeground }
            .map { stat ->
                val appName = try {
                    val pm = context.packageManager
                    pm.getApplicationLabel(pm.getApplicationInfo(stat.packageName, 0)).toString()
                } catch (e: Exception) {
                    stat.packageName
                }
                mapOf(
                    "packageName" to stat.packageName,
                    "appName" to appName,
                    "usageSeconds" to (stat.totalTimeInForeground / 1000).toInt()
                )
            }
    }
}
