package com.kidfun.mobile.services

import android.view.accessibility.AccessibilityNodeInfo

data class YouTubeVideoInfo(
    val title: String,
    val channelName: String?,
    val videoId: String?,
    val thumbnailUrl: String?,
    val startedAt: Long,
)

object YouTubeTracker {
    const val YOUTUBE_PACKAGE = "com.google.android.youtube"

    private val TITLE_VIEW_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/title",
        "$YOUTUBE_PACKAGE:id/video_title",
        "$YOUTUBE_PACKAGE:id/watch_video_title",
        // YouTube Shorts
        "$YOUTUBE_PACKAGE:id/reel_player_title",
        "$YOUTUBE_PACKAGE:id/shorts_video_title",
        "$YOUTUBE_PACKAGE:id/reel_title_text",
    )

    private val CHANNEL_VIEW_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/channel_name",
        "$YOUTUBE_PACKAGE:id/owner_name",
        "$YOUTUBE_PACKAGE:id/byline",
        "$YOUTUBE_PACKAGE:id/author",
        // YouTube Shorts
        "$YOUTUBE_PACKAGE:id/reel_channel_bar_inner_container",
        "$YOUTUBE_PACKAGE:id/reel_player_header_text",
        "$YOUTUBE_PACKAGE:id/channel_textview",
    )

    // Play/pause button IDs to detect pause state
    private val PLAY_PAUSE_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/player_control_play_pause_replay_button",
        "$YOUTUBE_PACKAGE:id/play_pause_button",
    )

    var currentVideo: YouTubeVideoInfo? = null

    // Accumulated seconds across pause/resume cycles
    private var accumulatedSeconds: Int = 0

    // True when video is paused but not yet stopped
    var isPaused: Boolean = false

    // Queue pending logs để Flutter upload lên server
    val pendingLogs: MutableList<Map<String, Any?>> = mutableListOf()

    // Blocked videos synced từ server
    var blockedVideos: List<Map<String, String?>> = emptyList()

    fun extractVideoInfo(root: AccessibilityNodeInfo): YouTubeVideoInfo? {
        val title = findTextByIds(root, TITLE_VIEW_IDS) ?: return null
        if (title.length < 3 || title == "YouTube" || title == "Trang chủ" || title == "Home"
            || title == "Shorts" || title == "Đang tải..." || title == "Loading...") return null

        val channel = findTextByIds(root, CHANNEL_VIEW_IDS)
        return YouTubeVideoInfo(
            title = title,
            channelName = channel,
            videoId = null,
            thumbnailUrl = null,
            startedAt = System.currentTimeMillis(),
        )
    }

    // Detect if video is currently paused by checking play button content description
    fun detectPauseState(root: AccessibilityNodeInfo): Boolean {
        for (id in PLAY_PAUSE_IDS) {
            try {
                val nodes = root.findAccessibilityNodeInfosByViewId(id)
                for (node in nodes) {
                    val desc = node.contentDescription?.toString()?.lowercase() ?: continue
                    if (desc.contains("play") || desc.contains("phát")) return true   // paused → button shows "Play"
                    if (desc.contains("pause") || desc.contains("tạm dừng")) return false // playing → button shows "Pause"
                }
            } catch (_: Exception) {}
        }
        return false
    }

    private fun findTextByIds(root: AccessibilityNodeInfo, ids: List<String>): String? {
        for (id in ids) {
            try {
                val nodes = root.findAccessibilityNodeInfosByViewId(id)
                for (node in nodes) {
                    val text = node.text?.toString()?.trim()
                    if (!text.isNullOrBlank()) return text
                    // Also check content description for Shorts channel names
                    val desc = node.contentDescription?.toString()?.trim()
                    if (!desc.isNullOrBlank() && desc.length > 1) return desc
                }
            } catch (_: Exception) {}
        }
        return null
    }

    // Called when video is paused — accumulates duration without clearing currentVideo
    fun pauseCurrentVideo() {
        val current = currentVideo ?: return
        if (isPaused) return  // already paused

        val elapsed = ((System.currentTimeMillis() - current.startedAt) / 1000).toInt()
        accumulatedSeconds += elapsed
        isPaused = true

        android.util.Log.d("YouTubeTracker", "⏸️ Paused: ${current.title} (+${elapsed}s, total=${accumulatedSeconds}s)")
    }

    // Called when video resumes — resets startedAt so duration tracks from resume point
    fun resumeCurrentVideo() {
        val current = currentVideo ?: return
        if (!isPaused) return

        isPaused = false
        currentVideo = current.copy(startedAt = System.currentTimeMillis())

        android.util.Log.d("YouTubeTracker", "▶️ Resumed: ${current.title} (accumulated=${accumulatedSeconds}s)")
    }

    fun stopCurrentVideo() {
        val current = currentVideo ?: return

        // Add elapsed since last resume/start
        if (!isPaused) {
            val elapsed = ((System.currentTimeMillis() - current.startedAt) / 1000).toInt()
            accumulatedSeconds += elapsed
        }

        val totalDuration = accumulatedSeconds

        android.util.Log.d("YouTubeTracker", "⏹️ Stopping: ${current.title} (totalDuration=${totalDuration}s)")

        // Reset state regardless of min-duration threshold
        currentVideo = null
        accumulatedSeconds = 0
        isPaused = false

        if (totalDuration < 10) {
            android.util.Log.d("YouTubeTracker", "⏭️ Skipped (< 10s): ${current.title}")
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

        android.util.Log.d("YouTubeTracker", "📺 Saved: ${current.title} (${totalDuration}s)")
    }

    fun isVideoBlocked(title: String, channel: String?): Boolean {
        return blockedVideos.any { blocked ->
            val bTitle = blocked["videoTitle"] ?: return@any false
            title.equals(bTitle, ignoreCase = true) || title.contains(bTitle, ignoreCase = true)
        }
    }
}
