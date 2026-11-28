package com.kidfun.mobile.services

import android.media.session.PlaybackState
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

data class YouTubeVideoInfo(
    val title: String,
    val channelName: String?,
    val videoId: String?,
    val thumbnailUrl: String?,
    val startedAt: Long,
    // Title guessed by the tier-3 tree scan (no known view ID): may be a subtitle line
    val fromTreeScan: Boolean = false,
    // Title/channel read from YouTube's MediaSession: exact even in fullscreen, channel is the display name
    val fromMediaSession: Boolean = false,
    val isShort: Boolean = false,
    // Lúc bắt đầu xem (watchedAt gửi lên server). startedAt là mốc của ĐOẠN đang phát,
    // bị đặt lại mỗi lần resume — prod 28/11: watchedAt lệch đúng bằng thời lượng video.
    val firstStartedAt: Long = startedAt,
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
        // Fullscreen overlay title (top-left, shown with the controls). Unverified ID: harmless if absent.
        "$YOUTUBE_PACKAGE:id/player_video_title_view",
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
        // YouTube Playables (games) section — logged as a "video" in prod 17/11
        "Playables", "Trò chơi",
        // Downloads page — logged as a "video" in prod 19/11 (#165)
        "Downloads", "Nội dung tải xuống",
        // Suggested-video card/end screen label — logged as a "video" in prod 20/11 (#180)
        "Suggested video", "Suggested videos", "Video đề xuất", "Video được đề xuất",
    )

    // "<channel> is live!" badge/notification card — logged as a "video" in prod 19/11 (#166)
    private val LIVE_BADGE_REGEX = Regex("^.+\\s(is live!?|đang phát trực tiếp)$", RegexOption.IGNORE_CASE)

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

    // Control chars (\n, \t, …) become spaces; format chars (\p{Cf}: U+200B–U+200F zero-width
    // and LRM/RLM, U+202A–U+202E embeddings, U+2066–U+2069 isolates, U+FEFF BOM) and the
    // object replacement char U+FFFC are dropped. YouTube wraps hashtags and @handles in these.
    private val CONTROL_CHARS_REGEX = Regex("\\p{Cc}")
    private val INVISIBLE_CHARS_REGEX = Regex("[\\p{Cf}\\uFFFC]")
    private val MULTI_SPACE_REGEX = Regex("[\\s\\u00A0\\u2007\\u202F]+")
    private val LETTER_OR_DIGIT_REGEX = Regex("[\\p{L}\\p{N}]")
    private const val MIN_TITLE_LENGTH = 3
    private const val MAX_TITLE_SCAN_DEPTH = 20
    private val CAPTION_ID_MARKERS = listOf("subtitle", "caption")

    /** Remove invisible characters and collapse whitespace, so titles stored on the server are clean. */
    fun cleanText(text: String): String =
        text.replace(CONTROL_CHARS_REGEX, " ")
            .replace(INVISIBLE_CHARS_REGEX, "")
            .replace(MULTI_SPACE_REGEX, " ")
            .trim()

    fun isIgnoredTitle(text: String): Boolean = IGNORED_TITLES.contains(text)

    /**
     * Whether [next] should end [current] and start a new session. A tree-scan title may only
     * start tracking, never replace a tracked video: in fullscreen the title node is gone and
     * the scan picks a subtitle line, which split one video into two logs (prod 20/11 #178/#179).
     */
    fun isNewVideo(current: YouTubeVideoInfo?, next: YouTubeVideoInfo): Boolean {
        if (current == null) return true
        // MediaSession reports every switch of the regular player itself; only a Short (not
        // covered by it) may replace that session from the accessibility side.
        if (current.fromMediaSession && !next.isShort) return false
        if (shouldAdoptTitle(current, next)) return false
        return next.title != current.title && !next.fromTreeScan
    }

    /**
     * A session started from a tree-scan title (video opened straight in fullscreen) gets renamed
     * — not split — once a known view shows the real title (controls tapped, fullscreen exited).
     */
    fun shouldAdoptTitle(current: YouTubeVideoInfo?, next: YouTubeVideoInfo): Boolean =
        current != null && current.fromTreeScan && !next.fromTreeScan && next.title != current.title

    enum class MediaAction { START, SWITCH, ADOPT }

    /** A video from MediaSession metadata (report 22/11: fullscreen from second 0 has no title node). */
    fun fromMediaMetadata(title: String?, artist: String?, now: Long): YouTubeVideoInfo? {
        val cleanTitle = title?.let { cleanText(it) } ?: return null
        if (!isValidTitle(cleanTitle)) return null
        return YouTubeVideoInfo(
            title = cleanTitle,
            channelName = artist?.let { cleanText(it) }?.takeIf { it.isNotEmpty() },
            videoId = null,
            thumbnailUrl = null,
            startedAt = now,
            fromMediaSession = true,
        )
    }

    /**
     * What a MediaSession title means for the tracked session. Same title or a tree-scan guess
     * (often a subtitle line) → rename in place; any other title → the player moved on (autoplay,
     * next button), which the accessibility tree cannot see while controls are hidden.
     */
    fun mediaAction(current: YouTubeVideoInfo?, next: YouTubeVideoInfo): MediaAction = when {
        current == null -> MediaAction.START
        current.title == next.title || current.fromTreeScan -> MediaAction.ADOPT
        else -> MediaAction.SWITCH
    }

    /** Rename the tracked session to the MediaSession title, keeping its watch time. */
    fun adoptMediaInfo(next: YouTubeVideoInfo) {
        val current = currentVideo ?: return
        currentVideo = current.copy(
            title = next.title,
            channelName = if (shouldReplaceChannel(current.channelName, next.channelName)) next.channelName else current.channelName,
            fromTreeScan = false,
            fromMediaSession = true,
        )
        if (current.title != next.title) Log.d(TAG, "✏️ Title adopted (media): ${current.title} → ${next.title}")
    }

    fun isHandle(channel: String?): Boolean = channel?.startsWith("@") == true

    /** The @handle is still wanted when only MediaSession's display name is known. */
    fun needsHandle(channel: String?): Boolean = !isHandle(channel)

    /** Fill an empty channel; upgrade a display name to an @handle; never downgrade. */
    fun shouldReplaceChannel(current: String?, next: String?): Boolean {
        if (next == null) return false
        if (current == null) return true
        return !isHandle(current) && isHandle(next)
    }

    fun isPlayingState(state: Int): Boolean = when (state) {
        PlaybackState.STATE_PLAYING,
        PlaybackState.STATE_BUFFERING,
        PlaybackState.STATE_CONNECTING,
        PlaybackState.STATE_FAST_FORWARDING,
        PlaybackState.STATE_REWINDING -> true
        else -> false
    }

    /** Rename the tracked session to [next]'s real title, keeping its watch time. */
    fun adoptRealTitle(next: YouTubeVideoInfo): Boolean {
        val current = currentVideo ?: return false
        if (!shouldAdoptTitle(current, next)) return false
        currentVideo = current.copy(
            title = next.title,
            channelName = next.channelName ?: current.channelName,
            fromTreeScan = false,
        )
        Log.d(TAG, "✏️ Title adopted: ${current.title} → ${next.title}")
        return true
    }

    /** A cleaned title is worth logging only if it has a real letter/digit and is not a UI label. */
    fun isValidTitle(text: String): Boolean =
        text.length >= MIN_TITLE_LENGTH && !isIgnoredTitle(text) &&
            LETTER_OR_DIGIT_REGEX.containsMatchIn(text) && !LIVE_BADGE_REGEX.matches(text)

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

    // "@handle" not glued to a preceding letter/digit (so "a@gmail.com" is not matched), but
    // allowed after punctuation like "•@x" or "(@x". Text is cleaned first so bidi marks
    // around the handle (U+2068 @x U+2069) do not hide it.
    // \p{M} keeps Vietnamese combining marks; YouTube handles allow letters, digits, . _ -
    private val HANDLE_REGEX = Regex("(?<![\\p{L}\\p{M}\\p{N}._-])(@[\\p{L}\\p{M}\\p{N}._-]{2,})")
    // Litho-rendered watch page nests the metadata line deeply; 25 was too shallow in practice
    private const val MAX_TEXT_SCAN_DEPTH = 40

    /** Extract the first "@handle" from a text, e.g. "@PhêPhim 26K likes …" → "@PhêPhim". */
    fun extractHandle(text: String?): String? {
        if (text.isNullOrBlank()) return null
        return HANDLE_REGEX.find(cleanText(text))?.groupValues?.get(1)?.trimEnd('.', '-', '_')
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
        val clean = texts.map { cleanText(it) }
        val titleIndex = clean.indexOfFirst { it.contains(title) }
        if (titleIndex >= 0) {
            // One node may hold "title @handle 2.5K likes …" (combined contentDescription)
            extractHandle(clean[titleIndex].substringAfter(title))?.let { return it }
            clean.drop(titleIndex + 1).firstNotNullOfOrNull { extractHandle(it) }?.let { return it }
        }
        return clean.firstNotNullOfOrNull { extractHandle(it) }
    }

    // The "@handle · likes · views" line sits right under the title; avatar/Join/bell come after
    private const val HANDLE_LOOKAHEAD = 8

    /**
     * Strict variant for backfilling a video already being tracked: the handle must be in
     * the title node itself or a few nodes below it. No fallback to any @ on screen, because
     * in fullscreen/comments the title is gone and @mentions belong to other people.
     */
    fun pickHandleBelowTitle(texts: List<String>, title: String): String? {
        val clean = texts.map { cleanText(it) }
        val titleIndex = clean.indexOfFirst { it.contains(title) }
        if (titleIndex < 0) return null
        extractHandle(clean[titleIndex].substringAfter(title))?.let { return it }
        return clean.drop(titleIndex + 1).take(HANDLE_LOOKAHEAD).firstNotNullOfOrNull { extractHandle(it) }
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
        val clean = texts.map { cleanText(it) }
        val handleIndex = clean.indexOfFirst { HANDLE_ONLY_REGEX.matches(it) }
        if (handleIndex < 0) return null
        val handle = clean[handleIndex]
        val caption = clean.drop(handleIndex + 1)
            .take(SHORTS_CAPTION_LOOKAHEAD)
            .map { it.replace(TRAILING_ELLIPSIS_REGEX, "").trim() }
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

    /**
     * Shorts only when a Shorts container is visible AND covers the screen centre. YouTube can
     * keep a Shorts container in the tree behind the long-video watch page; taking the Shorts
     * branch there returned null and blocked the channel backfill of long videos (19/11).
     */
    fun isShortsPlayer(root: AccessibilityNodeInfo): Boolean {
        val screen = android.graphics.Rect().also { root.getBoundsInScreen(it) }
        val cx = screen.centerX()
        val cy = screen.centerY()
        for (id in SHORTS_CONTEXT_IDS) {
            try {
                val hit = root.findAccessibilityNodeInfosByViewId(id).any { node ->
                    val r = android.graphics.Rect().also { node.getBoundsInScreen(it) }
                    node.isVisibleToUser && r.contains(cx, cy)
                }
                if (hit) return true
            } catch (_: Exception) {}
        }
        return false
    }

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
            isShort = true,
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

    /**
     * Throttled dump of the texts right after the title, so a tester's logcat shows how the
     * metadata line is exposed when no @handle is found (19/11: regular videos had none).
     */
    private fun logMissingHandle(texts: List<String>, title: String) {
        val now = System.currentTimeMillis()
        if (now - lastHandleDumpMs < SHORTS_DUMP_INTERVAL_MS) return
        lastHandleDumpMs = now
        val titleIndex = texts.indexOfFirst { cleanText(it).contains(title) }.coerceAtLeast(0)
        val preview = texts.drop(titleIndex).take(SHORTS_DUMP_MAX_ENTRIES)
            .joinToString(" ¦ ") { escapeInvisible(it.take(80)) }
        Log.d(TAG, "🩻 Video: no @handle for \"$title\" (titleIdx=$titleIndex/${texts.size}), texts=[$preview]")
    }

    /** Show hidden format chars as \\uXXXX in debug logs. */
    private fun escapeInvisible(text: String): String =
        text.replace(INVISIBLE_CHARS_REGEX) { "\\u%04X".format(it.value[0].code) }

    private var lastHandleDumpMs = 0L

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
        if (current.title != info.title || !shouldReplaceChannel(current.channelName, info.channelName)) return
        currentVideo = current.copy(channelName = info.channelName)
        Log.d(TAG, "🏷️ Channel backfilled: ${info.channelName} for ${current.title}")
    }

    /**
     * Backfill straight from the tree, using the tracked title — independent of title
     * re-detection (which can fail when player controls hide). Shorts carry their handle
     * from the start, so this only matters for long videos.
     */
    fun backfillChannelFromTree(root: AccessibilityNodeInfo) {
        val current = currentVideo ?: return
        if (!needsHandle(current.channelName) || current.isShort) return
        val texts = collectNodeTexts(root)
        val handle = pickHandleBelowTitle(texts, current.title) ?: run {
            logMissingHandle(texts, current.title)
            return
        }
        currentVideo = current.copy(channelName = handle)
        Log.d(TAG, "🏷️ Channel backfilled (tree): $handle for ${current.title}")
    }

    var currentVideo: YouTubeVideoInfo? = null
    private var accumulatedSeconds: Int = 0
    var isPaused: Boolean = false
    val pendingLogs: MutableList<Map<String, Any?>> = mutableListOf()
    var blockedVideos: List<Map<String, String?>> = emptyList()

    private fun hasRegularPlayer(root: AccessibilityNodeInfo): Boolean = PLAY_PAUSE_IDS.any { id ->
        try { root.findAccessibilityNodeInfosByViewId(id).isNotEmpty() } catch (_: Exception) { false }
    }

    /** Shorts are tracked from the overlay only; MediaSession updates are ignored there. */
    fun isOnShortsScreen(root: AccessibilityNodeInfo): Boolean = !hasRegularPlayer(root) && isShortsPlayer(root)

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
        val hasRegularPlayer = hasRegularPlayer(root)
        if (!hasRegularPlayer && isShortsPlayer(root)) return extractShortsInfo(root)

        // Tier 1: known view IDs
        var title = findTextByIds(root, TITLE_VIEW_IDS)

        // Tier 2: event text — reliable for TYPE_WINDOW_STATE_CHANGED
        if (title == null && event != null) {
            title = event.text
                ?.mapNotNull { it?.toString()?.let { t -> cleanText(t) } }
                ?.firstOrNull { looksLikeTitle(it) }
            if (title != null) {
                Log.d(TAG, "📝 Title from event.text: $title")
            }
        }

        // Tier 3: tree scan — only runs when the regular player UI is visible, to avoid
        // scanning home/browse screens where recommendation titles cause false positives.
        var fromTreeScan = false
        if (title == null && hasRegularPlayer) {
            title = scanTreeForTitle(root)
            if (title != null) {
                fromTreeScan = true
                Log.d(TAG, "🌲 Title from tree scan: $title")
            }
        }

        title = title?.let { cleanText(it) }
        if (title == null || !isValidTitle(title)) return null

        // Old UI: dedicated channel-name node. New UI (2026): no channel name, only an
        // "@handle 26K likes 1.7M views 5y ago more" line right under the title.
        val channel = normalizeChannel(findTextByIds(root, CHANNEL_VIEW_IDS)?.let { cleanText(it) })
            ?: run {
                val texts = collectNodeTexts(root)
                pickHandle(texts, title) ?: null.also { logMissingHandle(texts, title) }
            }
        return YouTubeVideoInfo(
            title = title,
            channelName = channel,
            videoId = null,
            thumbnailUrl = null,
            startedAt = System.currentTimeMillis(),
            fromTreeScan = fromTreeScan,
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
    private fun scanTreeForTitle(root: AccessibilityNodeInfo?): String? =
        toTreeNode(root)?.let { pickTitleFromTree(it) }

    /** Plain copy of the accessibility tree (text + view ID), so the scan is testable with fake trees. */
    data class TreeNode(val text: String?, val viewId: String?, val children: List<TreeNode> = emptyList())

    private fun toTreeNode(node: AccessibilityNodeInfo?, depth: Int = 0): TreeNode? {
        if (node == null || depth > MAX_TITLE_SCAN_DEPTH) return null
        val children = (0 until node.childCount).mapNotNull { i ->
            toTreeNode(try { node.getChild(i) } catch (_: Exception) { null }, depth + 1)
        }
        return TreeNode(node.text?.toString(), node.viewIdResourceName, children)
    }

    /** Subtitle (CC) containers: their text is dialogue, never the title (report 20/11). */
    fun isCaptionViewId(viewId: String?): Boolean {
        val name = viewId?.substringAfter(":id/")?.lowercase() ?: return false
        return CAPTION_ID_MARKERS.any { name.contains(it) }
    }

    fun pickTitleFromTree(root: TreeNode): String? {
        val candidates = mutableListOf<String>()
        fun walk(node: TreeNode) {
            if (isCaptionViewId(node.viewId)) return
            val text = node.text?.trim()
            if (!text.isNullOrBlank() && looksLikeTitle(text)) candidates.add(text)
            node.children.forEach { walk(it) }
        }
        walk(root)
        return candidates.maxByOrNull { scoreTitleCandidate(it) }
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
                "watchedAt" to current.firstStartedAt,
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
