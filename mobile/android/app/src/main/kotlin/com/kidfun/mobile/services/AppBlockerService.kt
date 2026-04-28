package com.kidfun.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.kidfun.mobile.MainActivity
import com.kidfun.mobile.helpers.BlockNotificationHelper

class AppBlockerService : AccessibilityService() {
    companion object {
        var blockedPackages: MutableSet<String> = mutableSetOf()
        var isEnabled = false
        var instance: AppBlockerService? = null
        // Track the last app seen in foreground via accessibility events — used by
        // forceCheckForeground() to detect the current app without querying UsageStatsManager
        // (which is unreliable in short time windows).
        var lastForegroundPackage: String? = null
        var lastForegroundStartTime: Long = 0L

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

        // Interval (ms) cho periodic per-app limit check khi app đang ở foreground
        // 5s so per-app blocking fires within 5s of limit expiry.
        private const val APP_LIMIT_CHECK_INTERVAL_MS = 5_000L

        // System overlay packages — NOT real foreground app changes.
        // When YouTube enters fullscreen, Android fires TYPE_WINDOW_STATE_CHANGED from
        // com.android.systemui for nav bar hide animations. Treating this as a foreground
        // change would incorrectly stop YouTube tracking and corrupt lastForegroundPackage.
        private val SYSTEM_OVERLAY_PACKAGES = setOf(
            "com.android.systemui",
            "android",
        )

        // Per-app time limit: track which packages have triggered the "bring to front" action
        // so we only do it once (not every 5s check cycle).
        var perAppBlockedSet: MutableSet<String> = mutableSetOf()
    }

    private val handler = Handler(Looper.getMainLooper())

    // Debounce TYPE_WINDOW_CONTENT_CHANGED events for YouTube to reduce CPU/log spam
    private var lastYtContentChangedMs: Long = 0L
    private val YT_CONTENT_CHANGED_DEBOUNCE_MS = 2000L

    /**
     * Periodic runnable: check app đang foreground mỗi 30s để bắt warning/block
     * kể cả khi không có window-state-change event nào.
     */
    private val periodicAppLimitCheck = object : Runnable {
        override fun run() {
            android.util.Log.d("AppLimit", "⏱ periodicCheck fired — foreground=${lastForegroundPackage}, limits=${AppLimitChecker.limits.size}")
            checkForegroundAppLimit()
            checkSchoolMode()
            // Force-close safety: if YouTube is no longer foreground but tracker still holds a video, stop it
            if (lastForegroundPackage != YouTubeTracker.YOUTUBE_PACKAGE && YouTubeTracker.currentVideo != null) {
                android.util.Log.d("YouTubeTracker", "⚠️ periodicCheck: YouTube not foreground but video still tracked — stopping")
                YouTubeTracker.stopCurrentVideo()
            }
            handler.postDelayed(this, APP_LIMIT_CHECK_INTERVAL_MS)
        }
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
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        // Bắt đầu periodic check ngay sau khi service kết nối
        handler.postDelayed(periodicAppLimitCheck, APP_LIMIT_CHECK_INTERVAL_MS)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return

        // 1. App-level blocking (TYPE_WINDOW_STATE_CHANGED only)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // System overlay packages (com.android.systemui, android) fire
            // TYPE_WINDOW_STATE_CHANGED for nav bar / status bar animations — they are NOT
            // real foreground app changes. Skipping them preserves lastForegroundPackage
            // (e.g. YouTube) and prevents incorrectly stopping YouTube tracking when the
            // player enters fullscreen and auto-hides navigation bars.
            val isSystemOverlay = SYSTEM_OVERLAY_PACKAGES.contains(packageName)
            if (!isSystemOverlay && lastForegroundPackage != packageName) {
                if (lastForegroundPackage == YouTubeTracker.YOUTUBE_PACKAGE) {
                    // Only stop tracking if YouTube window is actually gone.
                    val ytStillVisible = try {
                        windows?.any { it.root?.packageName?.toString() == YouTubeTracker.YOUTUBE_PACKAGE } == true
                    } catch (_: Exception) { false }
                    if (!ytStillVisible) YouTubeTracker.stopCurrentVideo()
                }
                lastForegroundPackage = packageName
                lastForegroundStartTime = System.currentTimeMillis()
            }

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

            // 2. Per-app time limit check (Sprint 8) — dùng chung logic với periodic check
            checkForegroundAppLimit()
        }

        // Sprint 9: YouTube tracking
        if (packageName == YouTubeTracker.YOUTUBE_PACKAGE) {
            handleYouTubeEvent(event)
            return
        }

        // 3. School Mode check (Sprint 8)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (SchoolModeChecker.isActive && !SchoolModeChecker.isAppAllowed(packageName)) {
                android.util.Log.d("SchoolMode", "🚫 onEvent BLOCKING $packageName — school mode active")
                try { BlockNotificationHelper.showSchoolModeBlock(this, packageName) } catch (_: Exception) {}
                performGlobalAction(GLOBAL_ACTION_HOME)
                return
            }
        }

        // 2. Web URL blocking — monitor browser URL bar content
        if (BROWSER_PACKAGES.contains(packageName) && blockedDomains.isNotEmpty()) {
            // Thử lấy URL từ event text trước (nhanh hơn, Chrome đôi khi đặt URL ở đây)
            val eventText = event.text?.firstOrNull()?.toString()
            val urlFromEvent = if (!eventText.isNullOrBlank() && looksLikeUrl(eventText)) eventText else null

            val url = urlFromEvent ?: run {
                val root = rootInActiveWindow ?: return
                extractUrl(root, packageName)
            } ?: return

            val domain = extractDomain(url) ?: return
            if (isDomainBlocked(domain)) {
                BlockNotificationHelper.showWebBlocked(this, domain)
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }
    }

    // ── Sprint 9: YouTube Tracking ────────────────────────────────────────────

    /**
     * Find YouTube's window root via the windows list (FLAG_RETRIEVE_INTERACTIVE_WINDOWS).
     * Falls back to rootInActiveWindow if windows API is unavailable.
     * Using windows list avoids the bug where rootInActiveWindow returns an accessibility
     * overlay window (e.g. VoiceAccess) instead of the actual YouTube window.
     */
    private fun getYouTubeRoot(): AccessibilityNodeInfo? {
        try {
            val ytRoot = windows
                ?.firstOrNull { it.root?.packageName?.toString() == YouTubeTracker.YOUTUBE_PACKAGE }
                ?.root
            if (ytRoot != null) return ytRoot
        } catch (_: Exception) {}
        val root = rootInActiveWindow ?: return null
        return if (root.packageName?.toString() == YouTubeTracker.YOUTUBE_PACKAGE) root else null
    }

    private fun handleYouTubeEvent(event: AccessibilityEvent) {
        // Only handle relevant event types
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> handleYouTubeWindowChange(event)
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> handleYouTubeContentChange()
            else -> return
        }
    }

    /**
     * Handle TYPE_WINDOW_STATE_CHANGED — detect new video or leaving YouTube.
     * This fires infrequently (only on actual window transitions) so no debounce needed.
     *
     * When YouTube resumes from background (app exit or screen unlock), the accessibility
     * tree may not be populated yet at the moment of the window event. We schedule a
     * delayed retry so the re-opened/unlocked session is still tracked.
     */
    private fun handleYouTubeWindowChange(event: AccessibilityEvent) {
        val root = getYouTubeRoot() ?: run {
            // YouTube window root not ready yet — retry after UI settles
            scheduleYouTubeRedetection(1000L)
            return
        }
        val info = YouTubeTracker.extractVideoInfo(root, event) ?: run {
            // Video info not extractable yet (YouTube UI still loading) — retry after settle
            scheduleYouTubeRedetection(1000L)
            return
        }

        // Same video — no action needed
        if (YouTubeTracker.currentVideo?.title == info.title) return

        // New video → stop previous, start new
        YouTubeTracker.stopCurrentVideo()

        if (YouTubeTracker.isVideoBlocked(info.title, info.channelName)) {
            BlockNotificationHelper.showVideoBlocked(this, info.title)
            performGlobalAction(GLOBAL_ACTION_HOME)
            return
        }

        YouTubeTracker.currentVideo = info
        android.util.Log.d("YouTubeTracker", "▶️ Started: ${info.title} | ${info.channelName}")
    }

    /**
     * Schedule a delayed re-detection of the current YouTube video.
     * Used after screen unlock or app return when the YouTube UI may not be ready yet
     * at the moment the window event fires.
     *
     * Guards: only fires if YouTube is still foreground and no video is currently tracked.
     */
    fun scheduleYouTubeRedetection(delayMs: Long) {
        handler.postDelayed({
            if (lastForegroundPackage != YouTubeTracker.YOUTUBE_PACKAGE) return@postDelayed
            if (YouTubeTracker.currentVideo != null) return@postDelayed
            val root = getYouTubeRoot() ?: return@postDelayed
            val info = YouTubeTracker.extractVideoInfo(root, null) ?: return@postDelayed
            android.util.Log.d("YouTubeTracker", "▶️ Re-detected (retry): ${info.title} | ${info.channelName}")
            YouTubeTracker.currentVideo = info
        }, delayMs)
    }

    /**
     * Handle TYPE_WINDOW_CONTENT_CHANGED — detect initial video OR pause/resume.
     * Heavily debounced (2s) because YouTube fires these events dozens of times per second.
     *
     * YouTube uses fragment navigation when tapping a video: no TYPE_WINDOW_STATE_CHANGED
     * fires, only CONTENT_CHANGED. So initial video detection must also happen here.
     */
    private fun handleYouTubeContentChange() {
        // Debounce: YouTube fires CONTENT_CHANGED very frequently
        val now = System.currentTimeMillis()
        if (now - lastYtContentChangedMs < YT_CONTENT_CHANGED_DEBOUNCE_MS) return
        lastYtContentChangedMs = now

        val root = getYouTubeRoot() ?: return

        // Always try to extract current visible video info
        val info = YouTubeTracker.extractVideoInfo(root, null)

        if (YouTubeTracker.currentVideo == null) {
            // No video tracked yet — try detecting from content tree (fragment navigation)
            if (info == null) return
            if (YouTubeTracker.isVideoBlocked(info.title, info.channelName)) {
                BlockNotificationHelper.showVideoBlocked(this, info.title)
                performGlobalAction(GLOBAL_ACTION_HOME)
                return
            }
            YouTubeTracker.currentVideo = info
            android.util.Log.d("YouTubeTracker", "▶️ Started (content): ${info.title} | ${info.channelName}")
            return
        }

        // Video tracked — check if user navigated to a different video (related video tap)
        if (info != null && info.title != YouTubeTracker.currentVideo?.title) {
            YouTubeTracker.stopCurrentVideo()
            if (YouTubeTracker.isVideoBlocked(info.title, info.channelName)) {
                BlockNotificationHelper.showVideoBlocked(this, info.title)
                performGlobalAction(GLOBAL_ACTION_HOME)
                return
            }
            YouTubeTracker.currentVideo = info
            android.util.Log.d("YouTubeTracker", "▶️ Started (navigation): ${info.title} | ${info.channelName}")
            return
        }

        // Same video — detect pause/resume via play/pause button state
        // Tri-state: true=paused, false=playing, null=controls hidden (keep current state)
        val pauseState = YouTubeTracker.detectPauseState(root) ?: return
        if (pauseState && !YouTubeTracker.isPaused) {
            YouTubeTracker.pauseCurrentVideo()
        } else if (!pauseState && YouTubeTracker.isPaused) {
            YouTubeTracker.resumeCurrentVideo()
        }
    }

    /**
     * Extract URL text from browser's URL-bar by searching for known resource IDs.
     * Falls back to tree traversal if no known ID matches (handles Chrome version changes).
     */
    private fun extractUrl(root: AccessibilityNodeInfo, pkg: String): String? {
        val urlBarIds = listOf(
            "$pkg:id/url_bar",                                 // Chrome ≤ 114
            "$pkg:id/omnibox_text",                            // Chrome 115+
            "$pkg:id/search_box_text",                         // Chrome (some builds)
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

        // Fallback: duyệt cây accessibility tìm EditText chứa URL
        return findUrlInTree(root)
    }

    /**
     * Duyệt cây AccessibilityNodeInfo tìm node EditText/TextView chứa URL.
     * Chrome đôi khi expose URL qua content description của node thay vì text.
     */
    private fun findUrlInTree(node: AccessibilityNodeInfo?): String? {
        if (node == null) return null
        val className = node.className?.toString() ?: ""
        if (className.contains("EditText") || className.contains("TextView")) {
            val text = node.text?.toString()
            if (!text.isNullOrBlank() && looksLikeUrl(text)) return text
            val desc = node.contentDescription?.toString()
            if (!desc.isNullOrBlank() && looksLikeUrl(desc)) return desc
        }
        for (i in 0 until node.childCount) {
            val result = findUrlInTree(node.getChild(i))
            if (result != null) return result
        }
        return null
    }

    private fun looksLikeUrl(text: String): Boolean {
        return text.startsWith("http://") || text.startsWith("https://") ||
            (text.contains(".") && !text.contains(" ") && text.length > 4)
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

    /**
     * Kiểm tra app đang foreground có bị limit không.
     * Được gọi bởi periodicAppLimitCheck mỗi 30s và bởi onAccessibilityEvent.
     */
    private fun checkForegroundAppLimit() {
        val pkg = lastForegroundPackage ?: return
        if (!AppLimitChecker.limits.containsKey(pkg)) return
        if (isFullLockMode) return  // Full lock đã handle riêng

        val checker = AppLimitChecker(this)
        val appName = checker.getAppName(pkg)
        val status = checker.checkStatus(pkg)
        android.util.Log.d("AppLimit", "🔍 check pkg=$pkg status=$status remaining=${checker.getRemainingMinutes(pkg)}min")
        when (status) {
            "BLOCKED" -> {
                android.util.Log.d("AppLimit", "🚫 BLOCKING $pkg — time limit exceeded")
                BlockNotificationHelper.showTimeLimitExceeded(this, appName, pkg)
                performGlobalAction(GLOBAL_ACTION_HOME)
                // On first BLOCKED detection, also bring KidFun to front.
                // performGlobalAction(HOME) can fail against fullscreen apps; launching
                // a new Activity is harder for the foreground app to suppress.
                if (perAppBlockedSet.add(pkg)) {
                    bringKidFunToFront()
                }
            }
            "WARNING" -> {
                if (!AppLimitChecker.warnedApps.contains(pkg)) {
                    AppLimitChecker.warnedApps.add(pkg)
                    val remainingMinutes = checker.getRemainingMinutes(pkg)
                    android.util.Log.d("AppLimit", "⚠️ WARNING $pkg — ${remainingMinutes}min remaining")
                    BlockNotificationHelper.showTimeLimitWarning(this, appName, remainingMinutes)
                }
            }
        }
    }

    /**
     * Check school mode cho app đang foreground — dùng trong periodic check.
     */
    private fun checkSchoolMode() {
        val pkg = lastForegroundPackage ?: return
        if (isFullLockMode) return
        if (!SchoolModeChecker.isActive) return
        if (SchoolModeChecker.isAppAllowed(pkg)) return

        android.util.Log.d("SchoolMode", "🚫 periodicCheck BLOCKING $pkg — school mode active")
        try { BlockNotificationHelper.showSchoolModeBlock(this, pkg) } catch (_: Exception) {}
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    /**
     * Gọi ngay sau khi school mode được bật để kick app không hợp lệ đang ở foreground.
     */
    fun forceCheckSchoolMode() {
        val pkg = lastForegroundPackage ?: return
        if (isFullLockMode) return
        if (!SchoolModeChecker.isActive) return
        if (SchoolModeChecker.isAppAllowed(pkg)) return

        android.util.Log.d("SchoolMode", "🚫 forceCheck BLOCKING $pkg — school mode just activated")
        bringKidFunToFront()
    }

    override fun onInterrupt() {
        isEnabled = false
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(periodicAppLimitCheck)
        isEnabled = false
        instance = null
    }
}
