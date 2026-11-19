package com.kidfun.mobile.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Báo cáo 19/11 (tái phát): video dài lúc có lúc không @handle (prod YouTubeLog #160–#177).
 * Backfill quét trực tiếp dưới tiêu đề đang theo dõi, không fallback sang @ bất kỳ.
 */
class YouTubeChannelBackfillTest {

    private val title = "CÁI CHẾT CỦA CÁC VỊ THẦN | SAMURICE"

    @Test
    fun `finds handle on the metadata line below the tracked title`() {
        val texts = listOf("Home", title, "@thesamurice 2.5K likes 90K views 5mo ago more", "Join")
        assertEquals("@thesamurice", YouTubeTracker.pickHandleBelowTitle(texts, title))
    }

    @Test
    fun `finds handle in content description that also holds the title`() {
        val texts = listOf("$title ⁨@thesamurice⁩ 90K views", "@nguoiBinhLuan hay")
        assertEquals("@thesamurice", YouTubeTracker.pickHandleBelowTitle(texts, title))
    }

    @Test
    fun `returns null when tracked title is not on screen, e g fullscreen`() {
        // Comments / other cards may carry @mentions — must not be taken as the uploader
        val texts = listOf("@nguoiBinhLuan hay quá", "@KenhKhac quảng cáo")
        assertNull(YouTubeTracker.pickHandleBelowTitle(texts, title))
    }

    @Test
    fun `only looks a few nodes below the title`() {
        val far = listOf(title) + List(30) { "label $it" } + "@nguoiBinhLuan"
        assertNull(YouTubeTracker.pickHandleBelowTitle(far, title))
    }

    @Test
    fun `downloads page and live badges are not video titles`() {
        assertFalse(YouTubeTracker.isValidTitle("Downloads"))
        assertFalse(YouTubeTracker.isValidTitle("Nội dung tải xuống"))
        assertFalse(YouTubeTracker.isValidTitle("Baaz Carrom is live!"))
        assertFalse(YouTubeTracker.isValidTitle("Kênh ABC đang phát trực tiếp"))
        assertTrue(YouTubeTracker.isValidTitle("The Truth About Borax"))
    }
}
