package com.kidfun.mobile.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class YouTubeChannelHandleTest {

    @Test
    fun `extracts handle from merged metadata line`() {
        val line = "@PhêPhim 26K likes 1.7M views 5y ago more"
        assertEquals("@PhêPhim", YouTubeTracker.extractHandle(line))
    }

    @Test
    fun `extracts handle when separated by bullet`() {
        assertEquals("@ABC.Kids_vn", YouTubeTracker.extractHandle("@ABC.Kids_vn • 1,2 Tr lượt xem"))
    }

    @Test
    fun `extracts handle not at start of string`() {
        assertEquals("@PhêPhim", YouTubeTracker.extractHandle("Kênh @PhêPhim 26K likes"))
    }

    @Test
    fun `ignores email-like text and single char`() {
        assertNull(YouTubeTracker.extractHandle("lienhe@gmail.com"))
        assertNull(YouTubeTracker.extractHandle("@ 26K likes"))
        assertNull(YouTubeTracker.extractHandle(null))
    }

    @Test
    fun `normalizeChannel keeps old-style channel name`() {
        assertEquals("Phê Phim", YouTubeTracker.normalizeChannel("Phê Phim"))
    }

    @Test
    fun `normalizeChannel strips stats from merged line`() {
        assertEquals("@PhêPhim", YouTubeTracker.normalizeChannel("@PhêPhim 26K likes 1.7M views 5y ago more"))
    }

    @Test
    fun `normalizeChannel returns null for blank`() {
        assertNull(YouTubeTracker.normalizeChannel("  "))
        assertNull(YouTubeTracker.normalizeChannel(null))
    }

    @Test
    fun `pickHandle prefers first handle after title node`() {
        val title = "TẤT TẦN TẬT VỀ KẺ TRỘM MẶT TRĂNG & MINION"
        val texts = listOf(
            "@KenhKhac quảng cáo",
            title,
            "@PhêPhim 26K likes 1.7M views 5y ago more",
            "@nguoiBinhLuan hay quá",
        )
        assertEquals("@PhêPhim", YouTubeTracker.pickHandle(texts, title))
    }

    @Test
    fun `pickHandle falls back to first handle when title not in tree`() {
        val texts = listOf("Something", "@PhêPhim 26K likes", "@other")
        assertEquals("@PhêPhim", YouTubeTracker.pickHandle(texts, "Không có trong cây"))
    }

    @Test
    fun `pickHandle returns null when no handle`() {
        assertNull(YouTubeTracker.pickHandle(listOf("Phê Phim", "26K likes"), "Phê Phim"))
    }
}
