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

    // Shorts has no traditional play/pause button — detect the Shorts pager instead.
    // The first four IDs are confirmed from two independent real-device accessibility dumps
    // (YouTube 2025-2026); regular videos, home, search and comments do not contain them.
    // Older guessed IDs are kept as a harmless fallback.
    private val SHORTS_CONTEXT_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/reel_watch_fragment_root",
        "$YOUTUBE_PACKAGE:id/reel_recycler",
        "$YOUTUBE_PACKAGE:id/reel_player_page_container",
        "$YOUTUBE_PACKAGE:id/reel_watch_player",
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

    // "@handle" at start of string or after whitespace (so "a@gmail.com" is not matched).
    // \p{M} keeps Vietnamese combining marks; YouTube handles allow letters, digits, . _ -
    private val HANDLE_REGEX = Regex("(?:^|\\s)(@[\\p{L}\\p{M}\\p{N}._-]{2,})")
    private const val MAX_TEXT_SCAN_DEPTH = 25

    /** Extract the first "@handle" from a text, e.g. "@PhêPhim 26K likes …" → "@PhêPhim". */
    fun extractHandle(text: String?): String? {
        if (text.isNullOrBlank()) return null
        return HANDLE_REGEX.find(text)?.groupValues?.get(1)?.trimEnd('.', '-', '_')
            ?.takeIf { it.length > 2 }
    }

    /** Old-style name is kept as-is; a merged "@handle + stats" line is reduced to the handle. */
    fun normalizeChannel(raw: String?): String? {
        val text = raw?.trim()
        if (text.isNullOrEmpty()) return null
        return extractHandle(text) ?: text
    }

    /**
     * Pick the channel handle from node texts in tree (pre-order) order: the first handle
     * appearing after the title node — that is the metadata line under the title, before
     * comments/recommendations that may also contain @mentions. Falls back to the first
     * handle anywhere when the title node is not in the tree (title came from event.text).
     */
    fun pickHandle(texts: List<String>, title: String): String? {
        val titleIndex = texts.indexOfFirst { it.trim() == title || it.contains(title) }
        if (titleIndex >= 0) {
            texts.drop(titleIndex + 1).firstNotNullOfOrNull { extractHandle(it) }?.let { return it }
        }
        return texts.firstNotNullOfOrNull { extractHandle(it) }
    }

    // ── Shorts ──────────────────────────────────────────────────────────────
    // Overlay at the bottom-left of a Short, top to bottom:
    //   [avatar] @handle [Subscribe]
    //   caption (used as the title)
    // The pager (reel_recycler) preloads the previous/next Short, so only the page that
    // covers the screen centre is read.

    data class ShortsMeta(val handle: String, val title: String)

    private const val SHORTS_PAGE_ID = "$YOUTUBE_PACKAGE:id/reel_player_page_container"
    private val HANDLE_ONLY_REGEX = Regex("^@[\\p{L}\\p{M}\\p{N}._-]{2,}$")
    private val SHORTS_METRIC_REGEX = Regex("^[\\d.,]+\\s*([KMBkmb]|N|Tr|T)?$")
    private val TRAILING_ELLIPSIS_REGEX = Regex("\\s*(\\.{3}|…)$")
    private val SHORTS_NOISE = setOf(
        "like", "dislike", "share", "save", "remix", "comments", "subscribe", "subscribed",
        "thích", "không thích", "chia sẻ", "lưu", "phối lại", "bình luận",
        "đăng ký", "đã đăng ký", "go to channel", "more", "xem thêm", "shorts",
    )
    private val SUBSCRIBE_PREFIXES = listOf("subscribe", "unsubscribe", "đăng ký", "đã đăng ký", "hủy đăng ký")
    // Captions sit right under the handle row; avatar/subscribe/remix labels may come first
    private const val SHORTS_CAPTION_LOOKAHEAD = 4
    // Overlay text lives in the left part and lower part of the page; the right column
    // holds like/comment/share/remix counts.
    private const val SHORTS_TEXT_MAX_LEFT_RATIO = 0.7f
    private const val SHORTS_TEXT_MIN_TOP_RATIO = 0.4f
    private const val SHORTS_DUMP_INTERVAL_MS = 20_000L
    private const val SHORTS_DUMP_MAX_ENTRIES = 30
    private var lastShortsDumpMs = 0L

    private fun isShortsCaption(text: String, handle: String): Boolean {
        if (text.length < 2 || text.contains(handle)) return false
        val lower = text.lowercase()
        if (lower in SHORTS_NOISE || IGNORED_TITLES.contains(text)) return false
        if (SUBSCRIBE_PREFIXES.any { lower.startsWith(it) }) return false
        if (SHORTS_METRIC_REGEX.matches(text)) return false
        return text.any { it.isLetter() }
    }

    /**
     * Pick handle + caption from the visible Shorts overlay texts (sorted top → bottom).
     * The handle must be a node of its own ("@name"), so @mentions inside a caption or a
     * comment are not taken as the uploader. A Short without caption gets a handle-based title.
     */
    fun pickShortsMeta(texts: List<String>): ShortsMeta? {
        val handleIndex = texts.indexOfFirst { HANDLE_ONLY_REGEX.matches(it.trim()) }
        if (handleIndex < 0) return null
        val handle = texts[handleIndex].trim()
        val caption = texts.drop(handleIndex + 1)
            .take(SHORTS_CAPTION_LOOKAHEAD)
            .map { it.trim().replace(TRAILING_ELLIPSIS_REGEX, "").trim() }
            .firstOrNull { isShortsCaption(it, handle) }
        return ShortsMeta(handle = handle, title = caption ?: "YouTube Shorts ($handle)")
    }

    private fun isVisibleById(root: AccessibilityNodeInfo, ids: List<String>): Boolean {
        for (id in ids) {
            try {
                if (root.findAccessibilityNodeInfosByViewId(id).any { it.isVisibleToUser }) return true
            } catch (_: Exception) {}
        }
        return false
    }

    fun isShortsPlayer(root: AccessibilityNodeInfo): Boolean = isVisibleById(root, SHORTS_CONTEXT_IDS)

    /** The Shorts page covering the vertical centre of the screen (neighbours are preloaded). */
    private fun findVisibleShortsPage(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val screen = android.graphics.Rect().also { root.getBoundsInScreen(it) }
        val centerY = screen.centerY()
        return try {
            root.findAccessibilityNodeInfosByViewId(SHORTS_PAGE_ID).firstOrNull { page ->
                val r = android.graphics.Rect().also { page.getBoundsInScreen(it) }
                page.isVisibleToUser && centerY in r.top..r.bottom
            }
        } catch (_: Exception) { null }
    }

    /** Visible overlay texts of the page, in the lower-left area, sorted top → bottom. */
    private fun collectShortsTexts(page: AccessibilityNodeInfo): List<String> {
        val area = android.graphics.Rect().also { page.getBoundsInScreen(it) }
        val maxLeft = area.left + (area.width() * SHORTS_TEXT_MAX_LEFT_RATIO).toInt()
        val minTop = area.top + (area.height() * SHORTS_TEXT_MIN_TOP_RATIO).toInt()
        val entries = mutableListOf<Pair<String, Int>>()
        fun walk(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > MAX_TEXT_SCAN_DEPTH || !node.isVisibleToUser) return
            val r = android.graphics.Rect().also { node.getBoundsInScreen(it) }
            if (r.left < maxLeft && r.top >= minTop) {
                node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { entries.add(it to r.top) }
                node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { entries.add(it to r.top) }
            }
            for (i in 0 until node.childCount) {
                walk(try { node.getChild(i) } catch (_: Exception) { null }, depth + 1)
            }
        }
        walk(page, 0)
        return entries.sortedBy { it.second }.map { it.first }
    }

    private fun extractShortsInfo(root: AccessibilityNodeInfo): YouTubeVideoInfo? {
        val page = findVisibleShortsPage(root) ?: root
        val texts = collectShortsTexts(page)
        val meta = pickShortsMeta(texts) ?: run {
            logShortsDump(texts)
            return null
        }
        return YouTubeVideoInfo(
            title = meta.title,
            channelName = meta.handle,
            videoId = null,
            thumbnailUrl = null,
            startedAt = System.currentTimeMillis(),
        )
    }

    /** Throttled dump so a tester's logcat shows what the Shorts overlay exposes when parsing fails. */
    private fun logShortsDump(texts: List<String>) {
        val now = System.currentTimeMillis()
        if (now - lastShortsDumpMs < SHORTS_DUMP_INTERVAL_MS) return
        lastShortsDumpMs = now
        val preview = texts.take(SHORTS_DUMP_MAX_ENTRIES).joinToString(" ¦ ") { it.take(60) }
        Log.d(TAG, "🩻 Shorts: no @handle found, visible texts=[$preview]")
    }

    /** Flatten text + contentDescription of the tree in pre-order. */
    private fun collectNodeTexts(root: AccessibilityNodeInfo): List<String> {
        val out = mutableListOf<String>()
        fun walk(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > MAX_TEXT_SCAN_DEPTH) return
            node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { out.add(it) }
            node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { out.add(it) }
            for (i in 0 until node.childCount) {
                walk(try { node.getChild(i) } catch (_: Exception) { null }, depth + 1)
            }
        }
        walk(root, 0)
        return out
    }

    /**
     * The metadata line often loads after the title, so the channel may be null when the
     * video starts. Fill it in later without resetting startedAt/accumulated time.
     */
    fun backfillChannel(info: YouTubeVideoInfo) {
        val current = currentVideo ?: return
        if (current.title != info.title || current.channelName != null || info.channelName == null) return
        currentVideo = current.copy(channelName = info.channelName)
        Log.d(TAG, "🏷️ Channel backfilled: ${info.channelName} for ${current.title}")
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
        // Shorts: different layout (handle + caption overlay), handled separately so the
        // generic tiers below cannot pick a random label. A regular player wins if both exist.
        // Existence (not visibility): the button stays in the tree while controls are hidden.
        val hasRegularPlayer = PLAY_PAUSE_IDS.any { id ->
            try { root.findAccessibilityNodeInfosByViewId(id).isNotEmpty() } catch (_: Exception) { false }
        }
        if (!hasRegularPlayer && isShortsPlayer(root)) return extractShortsInfo(root)

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

        // Tier 3: tree scan — only runs when the regular player UI is visible, to avoid
        // scanning home/browse screens where recommendation titles cause false positives.
        if (title == null && hasRegularPlayer) {
            title = scanTreeForTitle(root)
            if (title != null) {
                Log.d(TAG, "🌲 Title from tree scan: $title")
            }
        }

        if (title == null || title.length < 3 || IGNORED_TITLES.contains(title)) return null

        // Old UI: dedicated channel-name node. New UI (2026): no channel name, only an
        // "@handle 26K likes 1.7M views 5y ago more" line right under the title.
        val channel = normalizeChannel(findTextByIds(root, CHANNEL_VIEW_IDS))
            ?: pickHandle(collectNodeTexts(root), title)
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
