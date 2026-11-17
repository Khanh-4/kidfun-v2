package com.kidfun.mobile.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Shorts overlay (bottom-left), top to bottom:
 *   [avatar] @handle [Subscribe]
 *   caption / title …
 * Texts reach pickShortsMeta already filtered to the visible page and sorted top → bottom.
 */
class YouTubeShortsMetaTest {

    @Test
    fun `picks handle and caption from tester screenshot layout`() {
        val texts = listOf(
            "Go to channel",
            "@hismathakmal4231",
            "Subscribe",
            "Ever since I got a cat, personal space has complet ...",
            "3.2M", "Share", "13K", "Save", "15",
        )
        val meta = YouTubeTracker.pickShortsMeta(texts)!!
        assertEquals("@hismathakmal4231", meta.handle)
        assertEquals("Ever since I got a cat, personal space has complet", meta.title)
    }

    @Test
    fun `skips subscribe content description that repeats the handle`() {
        val texts = listOf("@hismathakmal4231", "Subscribe to @hismathakmal4231.", "Cat steals the chair")
        assertEquals("Cat steals the chair", YouTubeTracker.pickShortsMeta(texts)!!.title)
    }

    @Test
    fun `skips Vietnamese subscribe labels`() {
        val texts = listOf("@KenhThieuNhi", "Đăng ký", "Bé học đếm số cùng gấu", "Chia sẻ")
        val meta = YouTubeTracker.pickShortsMeta(texts)!!
        assertEquals("@KenhThieuNhi", meta.handle)
        assertEquals("Bé học đếm số cùng gấu", meta.title)
    }

    @Test
    fun `skips already-subscribed label`() {
        val texts = listOf("@abc", "Đã đăng ký", "Mèo con nhảy múa")
        assertEquals("Mèo con nhảy múa", YouTubeTracker.pickShortsMeta(texts)!!.title)
    }

    @Test
    fun `strips unicode ellipsis from truncated caption`() {
        val texts = listOf("@abc", "Subscribe", "Funny dog compilation…")
        assertEquals("Funny dog compilation", YouTubeTracker.pickShortsMeta(texts)!!.title)
    }

    @Test
    fun `keeps hashtag-only caption`() {
        val texts = listOf("@abc", "Subscribe", "#shorts #cat")
        assertEquals("#shorts #cat", YouTubeTracker.pickShortsMeta(texts)!!.title)
    }

    @Test
    fun `falls back to handle-based title when the short has no caption`() {
        val texts = listOf("@abc_kids", "Subscribe", "3.2M", "Share", "Remix")
        val meta = YouTubeTracker.pickShortsMeta(texts)!!
        assertEquals("@abc_kids", meta.handle)
        assertEquals("YouTube Shorts (@abc_kids)", meta.title)
    }

    @Test
    fun `first caption wins over later sound attribution`() {
        val texts = listOf("@abc", "Subscribe", "My first skateboard trick", "♪ original sound - abc")
        assertEquals("My first skateboard trick", YouTubeTracker.pickShortsMeta(texts)!!.title)
    }

    @Test
    fun `ignores handle embedded in a sentence and requires handle-only node`() {
        val texts = listOf("Cảm ơn @abc đã xem", "Subscribe", "Something")
        assertNull(YouTubeTracker.pickShortsMeta(texts))
    }

    @Test
    fun `returns null when there is no handle`() {
        assertNull(YouTubeTracker.pickShortsMeta(listOf("Shorts", "Share", "3.2M")))
        assertNull(YouTubeTracker.pickShortsMeta(emptyList()))
    }
}
