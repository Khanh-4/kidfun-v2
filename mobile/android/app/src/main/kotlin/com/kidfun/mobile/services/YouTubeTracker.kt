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

    // Shorts has no traditional play/pause button — detect active Shorts player
    // by checking for Shorts-specific container/title nodes that only appear in the player view
    private val SHORTS_CONTEXT_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/reel_player_page",
        "$YOUTUBE_PACKAGE:id/shorts_container",
        "$YOUTUBE_PACKAGE:id/reel_player_title",
        "$YOUTUBE_PACKAGE:id/shorts_video_title",
        "$YOUTUBE_PACKAGE:id/reel_title_text",
        "$YOUTUBE_PACKAGE:id/reel_channel_name",
    )

    private val IGNORED_TITLES = setOf(
        "YouTube", "Trang chủ", "Home", "Shorts", "Đang tải...", "Loading...",
        "Khám phá", "Explore", "Thư viện", "Library", "Đăng ký", "Subscriptions",
        "Tìm kiếm", "Search", "Xem sau", "Watch later",
        // Navigation & player UI
        "Up next", "Tiếp theo", "Now playing", "Đang phát",
        "Recommended", "Đề xuất", "Related videos", "Video liên quan",
        "More videos", "Video khác",
        // Action labels
        "Comments", "Bình luận", "Replies", "Phản hồi",
        "More", "Xem thêm", "See all", "Xem tất cả", "Show less", "Ẩn bớt",
        "Share", "Chia sẻ", "Download", "Tải xuống",
        "Save", "Lưu", "Report", "Báo cáo",
        "Subscribe", "Đăng ký theo dõi", "Unsubscribe", "Hủy đăng ký",
        "Liked videos", "Video đã thích",
        // Player controls & settings
        "Auto-play", "Autoplay", "Tự động phát",
        "Settings", "Cài đặt", "About", "Giới thiệu",
        "Subtitles", "Phụ đề", "Quality", "Chất lượng",
        "Full screen", "Toàn màn hình", "Miniplayer",
        "Add to playlist", "Thêm vào danh sách phát",
    )

    // Matches duration strings like "16 minutes, 28 seconds", "1 hour, 5 minutes", "1 phút 30 giây"
    private val DURATION_REGEX = Regex(
        "\\d+\\s*(minute|second|hour|phút|giây|giờ)",
        RegexOption.IGNORE_CASE
    )
    // Matches video timestamps like "1:23:45" or "12:34"
    private val TIMESTAMP_REGEX = Regex("^\\d+:\\d{2}(:\\d{2})?$")
    // Matches pure numbers, view counts, like counts ("1,234,567", "1.2M", "123K")
    private val METRIC_REGEX = Regex("^[\\d,\\.]+([KMB])?\\s*(views?|likes?|comments?)?$", RegexOption.IGNORE_CASE)
    // Matches relative time like "2 days ago", "3 tháng trước"
    private val RELATIVE_TIME_REGEX = Regex(
        "\\b\\d+\\s*(năm|tháng|ngày|tuần|giờ|phút|giây|year|month|week|day|hour|minute|second)s?\\s*(trước|ago)\\b",
        RegexOption.IGNORE_CASE
    )
    // Matches subscriber/follower counts like "1.2M subscribers", "500K người đăng ký"
    private val SUBSCRIBER_COUNT_REGEX = Regex(
        "\\b[\\d,\\.]+[KMBkmb]?\\s*(subscribers?|người đăng ký|follower)\\b",
        RegexOption.IGNORE_CASE
    )

    private fun looksLikeTitle(text: String): Boolean {
        if (text.length !in 8..200) return false
        if (IGNORED_TITLES.contains(text)) return false
        if (text.startsWith("http")) return false
        if (DURATION_REGEX.containsMatchIn(text)) return false
        if (TIMESTAMP_REGEX.matches(text)) return false
        if (METRIC_REGEX.matches(text)) return false
        if (RELATIVE_TIME_REGEX.containsMatchIn(text)) return false
        if (SUBSCRIBER_COUNT_REGEX.containsMatchIn(text)) return false
        // Must be mostly alphabetic — filters out number/symbol-heavy UI elements
        val letterCount = text.count { it.isLetter() }
        if (letterCount < text.length * 0.4f) return false
        return true
    }

    var currentVideo: YouTubeVideoInfo? = null
    private var accumulatedSeconds: Int = 0
    var isPaused: Boolean = false
    val pendingLogs: MutableList<Map<String, Any?>> = mutableListOf()
    var blockedVideos: List<Map<String, String?>> = emptyList()

    /**
     * Extract video info using 3-tier strategy:
     * 1. Known view IDs (fastest, version-dependent)
     * 2. AccessibilityEvent text (reliable for window changes)
     * 3. Full tree scan — only when player controls are visible (not on home/browse screens)
     */
    fun extractVideoInfo(root: AccessibilityNodeInfo, event: AccessibilityEvent? = null): YouTubeVideoInfo? {
        // Tier 1: known view IDs
        var title = findTextByIds(root, TITLE_VIEW_IDS)

        // Tier 2: event text — reliable for TYPE_WINDOW_STATE_CHANGED
        if (title == null && event != null) {
            title = event.text
                ?.mapNotNull { it?.toString()?.trim() }
                ?.firstOrNull { looksLikeTitle(it) }
            if (title != null) {
                Log.d(TAG, "📝 Title from event.text: $title")
            }
        }

        // Tier 3: tree scan — only runs when a video player UI is visible.
        // hasActivePlayer() checks both the regular player (play/pause button) and
        // the Shorts player (Shorts-specific container nodes) to avoid scanning
        // YouTube home/browse screens where recommendation titles would cause false positives.
        if (title == null && hasActivePlayer(root)) {
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

    private fun hasActivePlayer(root: AccessibilityNodeInfo): Boolean {
        // Regular player: check play/pause button
        for (id in PLAY_PAUSE_IDS) {
            try {
                if (root.findAccessibilityNodeInfosByViewId(id).isNotEmpty()) return true
            } catch (_: Exception) {}
        }
        // Shorts player: no traditional play/pause button — check Shorts-specific nodes
        for (id in SHORTS_CONTEXT_IDS) {
            try {
                if (root.findAccessibilityNodeInfosByViewId(id).isNotEmpty()) return true
            } catch (_: Exception) {}
        }
        return false
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
     * Scan the accessibility tree for text nodes that look like a video title.
     * Collects all candidates then picks the highest-scoring one to avoid false positives
     * from the first matching node (which could be a comment, description, etc.).
     */
    private fun scanTreeForTitle(root: AccessibilityNodeInfo?): String? {
        val candidates = mutableListOf<String>()
        collectTitleCandidates(root, candidates)
        return candidates.maxByOrNull { scoreTitleCandidate(it) }
    }

    private fun collectTitleCandidates(node: AccessibilityNodeInfo?, candidates: MutableList<String>, depth: Int = 0) {
        if (node == null || depth > 20) return
        val text = node.text?.toString()?.trim()
        if (!text.isNullOrBlank() && looksLikeTitle(text)) {
            candidates.add(text)
        }
        for (i in 0 until node.childCount) {
            collectTitleCandidates(try { node.getChild(i) } catch (_: Exception) { null }, candidates, depth + 1)
        }
    }

    private fun scoreTitleCandidate(text: String): Int {
        var score = 0
        val words = text.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
        // Video titles typically have 3–12 words
        when {
            words.size in 3..12 -> score += 3
            words.size in 2..15 -> score += 2
            words.size >= 2 -> score += 1
        }
        // Video titles typically are 20–100 chars
        when {
            text.length in 20..100 -> score += 2
            text.length in 10..150 -> score += 1
        }
        // Most titles start with an uppercase letter
        if (text.firstOrNull()?.isUpperCase() == true) score += 1
        // Mostly alphabetic (not symbol/number heavy)
        val letterRatio = text.count { it.isLetter() }.toFloat() / text.length
        if (letterRatio > 0.7f) score += 2
        else if (letterRatio > 0.5f) score += 1
        return score
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
