package com.kidfun.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import com.kidfun.mobile.MainActivity

class AppBlockerService : AccessibilityService() {
    companion object {
        var blockedPackages: MutableSet<String> = mutableSetOf()
        var isEnabled = false
        var instance: AppBlockerService? = null
        // Track the last app seen in foreground via accessibility events — used by
        // forceCheckForeground() to detect the current app without querying UsageStatsManager
        // (which is unreliable in short time windows).
        var lastForegroundPackage: String? = null

        /**
         * Full lock mode: khi hết giờ, chặn TẤT CẢ app trừ KidFun.
         * Khi trẻ mở khoá và cố mở bất kỳ app nào, sẽ bị đẩy về KidFun.
         */
        var isFullLockMode = false

        private const val KIDFUN_PACKAGE = "com.kidfun.mobile"
        // System UI packages that must remain accessible for device to function
        private val ALLOWED_SYSTEM_PACKAGES = setOf(
            KIDFUN_PACKAGE,
            "com.android.systemui",           // Status bar, notification shade
            "com.android.settings",           // Needed briefly for permission screens
        )
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

            if (isFullLockMode) {
                // Full lock: block EVERYTHING except KidFun and essential system UI
                if (!ALLOWED_SYSTEM_PACKAGES.contains(packageName)) {
                    bringKidFunToFront()
                }
                return
            }

            // Normal mode: only block specific apps
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

        if (isFullLockMode) {
            if (!ALLOWED_SYSTEM_PACKAGES.contains(currentPkg)) {
                bringKidFunToFront()
            }
            return
        }

        if (blockedPackages.contains(currentPkg)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    /**
     * Launch KidFun app to foreground — used in full lock mode
     * so the child always sees the "Hết giờ" screen.
     */
    private fun bringKidFunToFront() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
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
