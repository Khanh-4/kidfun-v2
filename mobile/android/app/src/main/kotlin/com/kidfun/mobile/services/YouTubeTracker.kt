package com.kidfun.mobile.services

import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

data class YouTubeVideoInfo(
    val title: String,
    val channelName: String?,
    val videoId: String?,
    val thumbnailUrl: String?,
    val startedAt: Long,
)

object YouTubeTracker {
    private const val TAG = "YouTubeTracker"
    const val YOUTUBE_PACKAGE = "com.google.android.youtube"

    // Primary IDs — regular video player
    private val TITLE_VIEW_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/title",
        "$YOUTUBE_PACKAGE:id/video_title",
        "$YOUTUBE_PACKAGE:id/watch_video_title",
        // Shorts — various YouTube versions
        "$YOUTUBE_PACKAGE:id/reel_player_title",
        "$YOUTUBE_PACKAGE:id/shorts_video_title",
        "$YOUTUBE_PACKAGE:id/reel_title_text",
        "$YOUTUBE_PACKAGE:id/reel_player_page_title",
        "$YOUTUBE_PACKAGE:id/video_metadata_title",
        "$YOUTUBE_PACKAGE:id/player_view_title",
        "$YOUTUBE_PACKAGE:id/title_anim_text",
    )

    private val CHANNEL_VIEW_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/channel_name",
        "$YOUTUBE_PACKAGE:id/owner_name",
        "$YOUTUBE_PACKAGE:id/byline",
        "$YOUTUBE_PACKAGE:id/author",
        // Shorts — various YouTube versions
        "$YOUTUBE_PACKAGE:id/reel_channel_bar_inner_container",
        "$YOUTUBE_PACKAGE:id/reel_player_header_text",
        "$YOUTUBE_PACKAGE:id/channel_textview",
        "$YOUTUBE_PACKAGE:id/reel_channel_bar_slim_textview_label",
        "$YOUTUBE_PACKAGE:id/reel_channel_name",
    )

    private val PLAY_PAUSE_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/player_control_play_pause_replay_button",
        "$YOUTUBE_PACKAGE:id/play_pause_button",
    )

    private val IGNORED_TITLES = setOf(
        "YouTube", "Trang chủ", "Home", "Shorts", "Đang tải...", "Loading...",
        "Khám phá", "Explore", "Thư viện", "Library", "Đăng ký", "Subscriptions",
        "Tìm kiếm", "Search", "Xem sau", "Watch later",
    )

    var currentVideo: YouTubeVideoInfo? = null
    private var accumulatedSeconds: Int = 0
    var isPaused: Boolean = false
    val pendingLogs: MutableList<Map<String, Any?>> = mutableListOf()
    var blockedVideos: List<Map<String, String?>> = emptyList()

    /**
     * Extract video info using 3-tier strategy:
     * 1. Known view IDs (fastest, version-dependent)
     * 2. AccessibilityEvent text (reliable for window changes)
     * 3. Full tree scan for TextView nodes (fallback when IDs change)
     */
    fun extractVideoInfo(root: AccessibilityNodeInfo, event: AccessibilityEvent? = null): YouTubeVideoInfo? {
        // Tier 1: known view IDs
        var title = findTextByIds(root, TITLE_VIEW_IDS)

        // Tier 2: event text — reliable for TYPE_WINDOW_STATE_CHANGED
        if (title == null && event != null) {
            title = event.text
                ?.mapNotNull { it?.toString()?.trim() }
                ?.firstOrNull { it.length in 5..200 && !IGNORED_TITLES.contains(it) && !it.startsWith("http") }
            if (title != null) {
                Log.d(TAG, "📝 Title from event.text: $title")
            }
        }

        // Tier 3: tree scan — last resort when YouTube obfuscates view IDs
        if (title == null) {
            title = scanTreeForTitle(root)
            if (title != null) {
                Log.d(TAG, "🌲 Title from tree scan: $title")
            }
        }

        if (title == null || title.length < 3 || IGNORED_TITLES.contains(title)) return null

        val channel = findTextByIds(root, CHANNEL_VIEW_IDS)
        return YouTubeVideoInfo(
            title = title,
            channelName = channel,
            videoId = null,
            thumbnailUrl = null,
            startedAt = System.currentTimeMillis(),
        )
    }

    /**
     * Detect pause state from play/pause button.
     * Returns:
     *   true  — button says "play" → video IS paused
     *   false — button says "pause" → video IS playing
     *   null  — button not found (controls hidden) → UNKNOWN, keep current state
     */
    fun detectPauseState(root: AccessibilityNodeInfo): Boolean? {
        for (id in PLAY_PAUSE_IDS) {
            try {
                val nodes = root.findAccessibilityNodeInfosByViewId(id)
                for (node in nodes) {
                    val desc = node.contentDescription?.toString()?.lowercase() ?: continue
                    if (desc.contains("play") || desc.contains("phát")) return true
                    if (desc.contains("pause") || desc.contains("tạm dừng")) return false
                }
            } catch (_: Exception) {}
        }
        // Controls hidden — cannot determine, return null so caller keeps current state
        return null
    }

    private fun findTextByIds(root: AccessibilityNodeInfo, ids: List<String>): String? {
        for (id in ids) {
            try {
                val nodes = root.findAccessibilityNodeInfosByViewId(id)
                for (node in nodes) {
                    val text = node.text?.toString()?.trim()
                    if (!text.isNullOrBlank()) return text
                    val desc = node.contentDescription?.toString()?.trim()
                    if (!desc.isNullOrBlank() && desc.length > 1) return desc
                }
            } catch (_: Exception) {}
        }
        return null
    }

    /**
     * Scan the accessibility tree for a text node that looks like a video title.
     * Checks all nodes for text — depth 20 to handle deep Compose trees.
     * YouTube migrated to Jetpack Compose which doesn't use TextView class names,
     * so we can't filter by className anymore.
     */
    private fun scanTreeForTitle(node: AccessibilityNodeInfo?, depth: Int = 0): String? {
        if (node == null || depth > 20) return null
        val text = node.text?.toString()?.trim()
        if (!text.isNullOrBlank() && text.length in 8..200 &&
            !IGNORED_TITLES.contains(text) && !text.startsWith("http")) {
            return text
        }
        for (i in 0 until node.childCount) {
            val result = scanTreeForTitle(try { node.getChild(i) } catch (_: Exception) { null }, depth + 1)
            if (result != null) return result
        }
        return null
    }

    fun pauseCurrentVideo() {
        val current = currentVideo ?: return
        if (isPaused) return
        val elapsed = ((System.currentTimeMillis() - current.startedAt) / 1000).toInt()
        accumulatedSeconds += elapsed
        isPaused = true
        Log.d(TAG, "⏸️ Paused: ${current.title} (+${elapsed}s, total=${accumulatedSeconds}s)")
    }

    fun resumeCurrentVideo() {
        val current = currentVideo ?: return
        if (!isPaused) return
        isPaused = false
        currentVideo = current.copy(startedAt = System.currentTimeMillis())
        Log.d(TAG, "▶️ Resumed: ${current.title} (accumulated=${accumulatedSeconds}s)")
    }

    fun stopCurrentVideo() {
        val current = currentVideo ?: return
        if (!isPaused) {
            val elapsed = ((System.currentTimeMillis() - current.startedAt) / 1000).toInt()
            accumulatedSeconds += elapsed
        }
        val totalDuration = accumulatedSeconds
        Log.d(TAG, "⏹️ Stopping: ${current.title} (totalDuration=${totalDuration}s)")
        currentVideo = null
        accumulatedSeconds = 0
        isPaused = false

        if (totalDuration < 10) {
            Log.d(TAG, "⏭️ Skipped (< 10s): ${current.title}")
            return
        }

        pendingLogs.add(
            mapOf(
                "videoTitle" to current.title,
                "channelName" to current.channelName,
                "videoId" to current.videoId,
                "thumbnailUrl" to current.thumbnailUrl,
                "watchedAt" to current.startedAt,
                "durationSeconds" to totalDuration,
            )
        )
        Log.d(TAG, "📺 Saved: ${current.title} (${totalDuration}s)")
    }

    fun isVideoBlocked(title: String, channel: String?): Boolean {
        return blockedVideos.any { blocked ->
            val bTitle = blocked["videoTitle"] ?: return@any false
            title.equals(bTitle, ignoreCase = true) || title.contains(bTitle, ignoreCase = true)
        }
    }
}
