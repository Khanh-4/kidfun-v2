package com.kidfun.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.usage.UsageStatsManager
import android.content.Context
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {
    companion object {
        var blockedPackages: MutableSet<String> = mutableSetOf()
        var isEnabled = false
        var instance: AppBlockerService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isEnabled = true
        instance = this
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return
            if (blockedPackages.contains(packageName)) {
                // Chặn: quay về home screen
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }
    }

    /**
     * Force-check foreground app sau khi blocked list thay đổi.
     * Nếu app hiện tại đang bị chặn → đẩy về Home ngay lập tức.
     */
    fun forceCheckForeground() {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
            val now = System.currentTimeMillis()
            // Query usage events trong 5 giây gần nhất để tìm foreground app
            val stats = usm.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                now - 5000,
                now
            )
            val currentApp = stats
                ?.maxByOrNull { it.lastTimeUsed }
                ?.packageName

            if (currentApp != null && blockedPackages.contains(currentApp)) {
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        } catch (e: Exception) {
            // Silently fail — UsageStats permission may not be granted
        }
    }

    override fun onInterrupt() {
        isEnabled = false
    }

    override fun onDestroy() {
        super.onDestroy()
        isEnabled = false
        instance = null
    }
}
