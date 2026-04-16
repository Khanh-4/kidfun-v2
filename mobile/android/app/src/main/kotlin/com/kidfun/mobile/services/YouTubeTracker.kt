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
        "$YOUTUBE_PACKAGE:id/reel_player_title",
    )

    private val CHANNEL_VIEW_IDS = listOf(
        "$YOUTUBE_PACKAGE:id/channel_name",
        "$YOUTUBE_PACKAGE:id/owner_name",
        "$YOUTUBE_PACKAGE:id/byline",
        "$YOUTUBE_PACKAGE:id/author",
    )

    var currentVideo: YouTubeVideoInfo? = null

    // Queue pending logs để Flutter upload lên server
    val pendingLogs: MutableList<Map<String, Any?>> = mutableListOf()

    // Blocked videos synced từ server
    var blockedVideos: List<Map<String, String?>> = emptyList()

    fun extractVideoInfo(root: AccessibilityNodeInfo): YouTubeVideoInfo? {
        val title = findTextByIds(root, TITLE_VIEW_IDS) ?: return null
        if (title.length < 3 || title == "YouTube" || title == "Trang chủ" || title == "Home") return null

        val channel = findTextByIds(root, CHANNEL_VIEW_IDS)
        return YouTubeVideoInfo(
            title = title,
            channelName = channel,
            videoId = null,
            thumbnailUrl = null,
            startedAt = System.currentTimeMillis(),
        )
    }

    private fun findTextByIds(root: AccessibilityNodeInfo, ids: List<String>): String? {
        for (id in ids) {
            try {
                val nodes = root.findAccessibilityNodeInfosByViewId(id)
                for (node in nodes) {
                    val text = node.text?.toString()?.trim()
                    if (!text.isNullOrBlank()) return text
                }
            } catch (_: Exception) {}
        }
        return null
    }

    fun stopCurrentVideo() {
        val current = currentVideo ?: return
        val durationSec = ((System.currentTimeMillis() - current.startedAt) / 1000).toInt()

        if (durationSec < 10) {
            currentVideo = null
            return
        }

        pendingLogs.add(
            mapOf(
                "videoTitle" to current.title,
                "channelName" to current.channelName,
                "videoId" to current.videoId,
                "thumbnailUrl" to current.thumbnailUrl,
                "watchedAt" to current.startedAt,
                "durationSeconds" to durationSec,
            )
        )

        android.util.Log.d("YouTubeTracker", "📺 Saved: ${current.title} (${durationSec}s)")
        currentVideo = null
    }

    fun isVideoBlocked(title: String, channel: String?): Boolean {
        return blockedVideos.any { blocked ->
            val bTitle = blocked["videoTitle"] ?: return@any false
            title.equals(bTitle, ignoreCase = true) || title.contains(bTitle, ignoreCase = true)
        }
    }
}
