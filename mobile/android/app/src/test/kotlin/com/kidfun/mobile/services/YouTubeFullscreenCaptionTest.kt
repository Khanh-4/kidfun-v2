package com.kidfun.mobile.services

import com.kidfun.mobile.services.YouTubeTracker.TreeNode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Báo cáo 20/11 (Luồng 17 B5 / Luồng 03): xem YouTube toàn màn hình có bật CC → app ghi câu phụ
 * đề làm tên video. Cây dưới đây là cây giả, tiêu đề / phụ đề là dữ liệu giả.
 */
class YouTubeFullscreenCaptionTest {

    private val pkg = "com.google.android.youtube:id"

    private fun info(title: String, fromTreeScan: Boolean = false, channel: String? = "@kenhMau") =
        YouTubeVideoInfo(title, channel, null, null, 0L, fromTreeScan)

    private fun fullscreenTree(vararg extra: TreeNode) = TreeNode(
        text = null, viewId = "$pkg/watch_while_layout",
        children = listOf(
            TreeNode(null, "$pkg/player_control_play_pause_replay_button"),
            TreeNode(
                null, "$pkg/subtitle_window",
                children = listOf(TreeNode("Và rồi chúng ta cùng nhau đi tiếp đoạn đường dài", "$pkg/subtitle_text")),
            ),
            TreeNode(
                null, "$pkg/captions_overlay",
                children = listOf(TreeNode("Hôm nay trời đẹp quá các bạn ơi", null)),
            ),
        ) + extra,
    )

    @Test
    fun `caption container ids are recognised`() {
        assertTrue(YouTubeTracker.isCaptionViewId("$pkg/subtitle_window"))
        assertTrue(YouTubeTracker.isCaptionViewId("$pkg/captions_overlay"))
        assertFalse(YouTubeTracker.isCaptionViewId("$pkg/player_video_title_view"))
        assertFalse(YouTubeTracker.isCaptionViewId(null))
    }

    @Test
    fun `tree scan skips caption subtrees and finds nothing when only captions show`() {
        assertNull(YouTubeTracker.pickTitleFromTree(fullscreenTree()))
    }

    @Test
    fun `tree scan picks the overlay title over caption lines`() {
        val title = "Video mẫu A: Phân tích một bộ phim"
        val tree = fullscreenTree(TreeNode(title, "$pkg/some_overlay_text"))
        assertEquals(title, YouTubeTracker.pickTitleFromTree(tree))
    }

    @Test
    fun `real title renames a session started from a tree scan instead of splitting it`() {
        val started = info("Câu thoại mẫu đang chạy trên màn hình", fromTreeScan = true, channel = null)
        val real = info("Video mẫu B: Hành trình khám phá")
        assertTrue(YouTubeTracker.shouldAdoptTitle(started, real))
        assertFalse(YouTubeTracker.isNewVideo(started, real))
    }

    @Test
    fun `a session with a real title is not renamed`() {
        val tracked = info("Video mẫu A: Phân tích một bộ phim")
        val next = info("Video mẫu B: Hành trình khám phá")
        assertFalse(YouTubeTracker.shouldAdoptTitle(tracked, next))
        assertTrue(YouTubeTracker.isNewVideo(tracked, next))
    }

    @Test
    fun `another tree scan title does not rename a tree scan session`() {
        val started = info("Câu thoại mẫu thứ nhất trên màn hình", fromTreeScan = true)
        val next = info("Câu thoại mẫu thứ hai trên màn hình", fromTreeScan = true)
        assertFalse(YouTubeTracker.shouldAdoptTitle(started, next))
        assertFalse(YouTubeTracker.isNewVideo(started, next))
        assertFalse(YouTubeTracker.shouldAdoptTitle(null, next))
    }
}
