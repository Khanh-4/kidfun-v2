package com.kidfun.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {
    companion object {
        var blockedPackages: MutableSet<String> = mutableSetOf()
        var isEnabled = false
        var instance: AppBlockerService? = null
        // Track the last app seen in foreground via accessibility events — used by
        // forceCheckForeground() to detect the current app without querying UsageStatsManager
        // (which is unreliable in short time windows).
        var lastForegroundPackage: String? = null
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
            // Always update foreground tracking, even for non-blocked apps
            lastForegroundPackage = packageName
            if (blockedPackages.contains(packageName)) {
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }
    }

    /**
     * Force-close the currently visible app if it's in the blocked list.
     * Called immediately after the blocked-apps list is updated so that an app
     * already in the foreground is ejected without waiting for the next window event.
     *
     * Uses [lastForegroundPackage] (kept fresh by [onAccessibilityEvent]) instead of
     * querying UsageStatsManager, which is unreliable for short time windows.
     */
    fun forceCheckForeground() {
        val currentPkg = lastForegroundPackage ?: return
        if (blockedPackages.contains(currentPkg)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
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
