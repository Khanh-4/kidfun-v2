package com.kidfun.mobile.services

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Prod 20/11:
 * - #178 → #179: toàn màn hình không có node tiêu đề → quét cây nhặt câu phụ đề làm tiêu đề
 *   → một video bị tách thành 2 dòng, dòng sau không có kênh.
 * - #180: nhãn giao diện "Suggested video" bị ghi như một video.
 * Tiêu đề dưới đây là dữ liệu giả.
 */
class YouTubeVideoSwitchTest {

    private fun info(title: String, fromTreeScan: Boolean = false, channel: String? = "@kenhMau") =
        YouTubeVideoInfo(
            title = title,
            channelName = channel,
            videoId = null,
            thumbnailUrl = null,
            startedAt = 0L,
            fromTreeScan = fromTreeScan,
        )

    private val tracked = info("Video mẫu A: Phân tích một bộ phim | Kênh Mẫu")

    @Test
    fun `suggested video labels are not video titles`() {
        assertFalse(YouTubeTracker.isValidTitle("Suggested video"))
        assertFalse(YouTubeTracker.isValidTitle("Suggested videos"))
        assertFalse(YouTubeTracker.isValidTitle("Video đề xuất"))
        assertFalse(YouTubeTracker.isValidTitle("Video được đề xuất"))
    }

    @Test
    fun `tree scanned caption text does not split the tracked video`() {
        val caption = info("và rồi chúng ta cùng nhau đi tiếp đoạn đường", fromTreeScan = true, channel = null)
        assertFalse(YouTubeTracker.isNewVideo(tracked, caption))
    }

    @Test
    fun `title from a known view id starts a new video`() {
        val next = info("Video mẫu B: Hành trình khám phá")
        assertTrue(YouTubeTracker.isNewVideo(tracked, next))
    }

    @Test
    fun `same title is not a new video`() {
        assertFalse(YouTubeTracker.isNewVideo(tracked, info(tracked.title)))
    }

    @Test
    fun `tree scan may start tracking when nothing is tracked yet`() {
        val first = info("Video mẫu C: Thử nghiệm khoa học vui", fromTreeScan = true)
        assertTrue(YouTubeTracker.isNewVideo(null, first))
    }
}
