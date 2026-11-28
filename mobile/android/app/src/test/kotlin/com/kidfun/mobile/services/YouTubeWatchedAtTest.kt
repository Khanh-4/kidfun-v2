package com.kidfun.mobile.services

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Prod 28/11 (YouTubeLog 219–221): mỗi lần YouTube tự phát tiếp, MediaSession đi qua cặp
 * PAUSED → PLAYING ngay trước khi đổi bài. resumeCurrentVideo() ghi đè startedAt nên watchedAt
 * lưu lên là lần resume cuối, lệch đúng bằng thời lượng video (bắt đầu 13:19:58, lưu 13:23:31).
 * Tiêu đề dưới đây là dữ liệu giả.
 */
class YouTubeWatchedAtTest {

    @Before
    fun reset() {
        YouTubeTracker.currentVideo = null
        YouTubeTracker.isPaused = false
        YouTubeTracker.pendingLogs.clear()
    }

    @After
    fun cleanup() = reset()

    @Test
    fun `watchedAt is when the video started, not the last resume`() {
        val startedAt = System.currentTimeMillis() - 300_000L
        YouTubeTracker.currentVideo = YouTubeVideoInfo(
            title = "Video mẫu: Hành trình khám phá đại dương",
            channelName = "Kênh Mẫu",
            videoId = null,
            thumbnailUrl = null,
            startedAt = startedAt,
            fromMediaSession = true,
        )

        YouTubeTracker.pauseCurrentVideo()
        YouTubeTracker.resumeCurrentVideo()
        YouTubeTracker.stopCurrentVideo()

        val log = YouTubeTracker.pendingLogs.single()
        assertEquals(startedAt, log["watchedAt"])
        // Thời lượng vẫn cộng dồn đủ ~300s qua lần tạm dừng.
        val duration = log["durationSeconds"] as Int
        assertEquals(300.0, duration.toDouble(), 2.0)
    }
}
