package com.kidfun.mobile.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Báo cáo test 19/11: (1) video thường mất @handle trên giao diện mới,
 * (2) ký tự điều khiển Unicode ẩn tạo bản ghi video rác.
 */
class YouTubeTextSanitizeTest {

    private val title = "Đừng để bị 'dắt mũi' bởi những nội dung này"

    @Test
    fun `extracts handle from tester screenshot metadata line`() {
        val line = "@thesamurice 2.5K likes 90K views 5mo ago 1 product more"
        assertEquals("@thesamurice", YouTubeTracker.extractHandle(line))
    }

    @Test
    fun `extracts handle wrapped in bidi isolate characters`() {
        // YouTube wraps user names in FSI/PDI (U+2068/U+2069) or LRM (U+200E)
        assertEquals("@thesamurice", YouTubeTracker.extractHandle("⁨@thesamurice⁩ 2.5K likes"))
        assertEquals("@thesamurice", YouTubeTracker.extractHandle("‎@thesamurice 90K views"))
        assertEquals("@thesamurice", YouTubeTracker.extractHandle("‪@thesamurice‬"))
    }

    @Test
    fun `extracts handle after punctuation but still ignores emails`() {
        assertEquals("@thesamurice", YouTubeTracker.extractHandle("•@thesamurice"))
        assertEquals("@thesamurice", YouTubeTracker.extractHandle("(@thesamurice)"))
        assertNull(YouTubeTracker.extractHandle("lienhe@gmail.com"))
    }

    @Test
    fun `pickHandle finds handle in combined title plus metadata description`() {
        val texts = listOf("$title ⁨@thesamurice⁩ 2.5K likes 90K views 5mo ago", "Join", "Comments 245")
        assertEquals("@thesamurice", YouTubeTracker.pickHandle(texts, title))
    }

    @Test
    fun `cleanText strips all format and control characters`() {
        val dirty = "‪Bé học đếm‬ #hoctap​‎﻿￼⁦ vui⁩"
        assertEquals("Bé học đếm #hoctap vui", YouTubeTracker.cleanText(dirty))
    }

    @Test
    fun `cleanText turns control whitespace and nbsp into single spaces`() {
        assertEquals("Bé học đếm", YouTubeTracker.cleanText("Bé\nhọc  đếm\t"))
    }

    @Test
    fun `cleaned titles with only invisible differences are equal`() {
        val a = YouTubeTracker.cleanText("Mèo con #shorts​")
        val b = YouTubeTracker.cleanText("⁨Mèo con #shorts⁩")
        assertEquals(a, b)
    }

    @Test
    fun `title without any letter or digit is invalid`() {
        assertFalse(YouTubeTracker.isValidTitle(YouTubeTracker.cleanText("​￼ ‮")))
        assertFalse(YouTubeTracker.isValidTitle("•••"))
        assertFalse(YouTubeTracker.isValidTitle("# … !!"))
        assertFalse(YouTubeTracker.isValidTitle("Playables"))
        assertTrue(YouTubeTracker.isValidTitle(title))
        assertTrue(YouTubeTracker.isValidTitle("2048"))
    }

    @Test
    fun `shorts handle node wrapped in bidi characters is recognised`() {
        val meta = YouTubeTracker.pickShortsMeta(listOf("⁨@thesamurice⁩", "Mèo con dễ thương"))!!
        assertEquals("@thesamurice", meta.handle)
        assertEquals("Mèo con dễ thương", meta.title)
    }
}
