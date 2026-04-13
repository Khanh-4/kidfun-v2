package com.kidfun.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
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

        // Web blocklist — domains bị chặn (Sprint 8)
        var blockedDomains: MutableSet<String> = mutableSetOf()

        // Browser packages cần monitor URL
        val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "com.chrome.beta",
            "org.mozilla.firefox",
            "com.microsoft.emmx",              // Edge
            "com.opera.browser",
            "com.brave.browser",
            "com.sec.android.app.sbrowser",    // Samsung Internet
        )

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
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                         AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return

        // 1. App-level blocking (TYPE_WINDOW_STATE_CHANGED only)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
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
                return
            }

            // 2. Per-app time limit check (Sprint 8)
            if (AppLimitChecker.limits.containsKey(packageName)) {
                val checker = AppLimitChecker(this)
                when (checker.checkStatus(packageName)) {
                    "BLOCKED" -> {
                        android.util.Log.d("AppBlocker", "⏰ App time limit exceeded: $packageName")
                        performGlobalAction(GLOBAL_ACTION_HOME)
                        return
                    }
                    "WARNING" -> {
                        if (!AppLimitChecker.warnedApps.contains(packageName)) {
                            AppLimitChecker.warnedApps.add(packageName)
                            android.util.Log.d("AppBlocker", "⚠️ App time limit warning: $packageName")
                        }
                    }
                }
            }
        }

        // 3. School Mode check (Sprint 8)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (SchoolModeChecker.isActive && !SchoolModeChecker.isAppAllowed(packageName)) {
                android.util.Log.d("AppBlocker", "📚 School mode blocked: $packageName")
                performGlobalAction(GLOBAL_ACTION_HOME)
                return
            }
        }

        // 2. Web URL blocking — monitor browser URL bar content
        if (BROWSER_PACKAGES.contains(packageName) && blockedDomains.isNotEmpty()) {
            val root = rootInActiveWindow ?: return
            val url = extractUrl(root, packageName) ?: return
            val domain = extractDomain(url) ?: return

            if (isDomainBlocked(domain)) {
                android.util.Log.d("AppBlocker", "🚫 Blocked URL: $url (domain: $domain)")
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }
    }

    /**
     * Extract URL text from browser's URL-bar by searching for known resource IDs.
     * Each major browser uses a different view ID for the address bar.
     */
    private fun extractUrl(root: AccessibilityNodeInfo, pkg: String): String? {
        val urlBarIds = listOf(
            "$pkg:id/url_bar",                                 // Chrome
            "$pkg:id/mozac_browser_toolbar_url_view",          // Firefox
            "$pkg:id/location_bar_edit_text",                  // Samsung Internet
            "$pkg:id/url_field",                               // Opera / generic
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

    /**
     * Parse domain from URL string.
     * Handles URLs with and without protocol prefix (e.g. "google.com" or "https://google.com/path").
     */
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

    /**
     * Check if a domain matches the blocklist.
     * Supports exact match and subdomain matching (e.g. m.facebook.com matches facebook.com).
     */
    private fun isDomainBlocked(domain: String): Boolean {
        if (blockedDomains.contains(domain)) return true
        for (blocked in blockedDomains) {
            if (domain.endsWith(".$blocked")) return true
        }
        return false
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
