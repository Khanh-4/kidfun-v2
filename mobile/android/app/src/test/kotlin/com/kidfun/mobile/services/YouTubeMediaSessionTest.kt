package com.kidfun.mobile.services

import android.media.session.PlaybackState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Báo cáo 22/11: mở thẳng / tự phát tiếp ở toàn màn hình không chạm → cây accessibility không có
 * tiêu đề. `dumpsys media_session` cho thấy YouTube luôn công bố tiêu đề + tên kênh hiển thị qua
 * MediaSession → dùng làm nguồn chính cho video thường. Tiêu đề dưới đây là dữ liệu giả.
 */
class YouTubeMediaSessionTest {

    private fun info(
        title: String,
        channel: String? = "@kenhMau",
        fromTreeScan: Boolean = false,
        fromMediaSession: Boolean = false,
        isShort: Boolean = false,
    ) = YouTubeVideoInfo(
        title = title,
        channelName = channel,
        videoId = null,
        thumbnailUrl = null,
        startedAt = 0L,
        fromTreeScan = fromTreeScan,
        fromMediaSession = fromMediaSession,
        isShort = isShort,
    )

    private val titleA = "Video mẫu A: Phân tích một bộ phim | Kênh Mẫu"
    private val titleB = "Video mẫu B: Lịch sử một thành phố cổ"

    // ── fromMediaMetadata ──────────────────────────────────────────────────

    @Test
    fun `metadata title and artist become a media session video`() {
        val v = YouTubeTracker.fromMediaMetadata(titleA, "KÊNH MẪU", now = 123L)!!
        assertEquals(titleA, v.title)
        assertEquals("KÊNH MẪU", v.channelName)
        assertTrue(v.fromMediaSession)
        assertFalse(v.fromTreeScan)
        assertEquals(123L, v.startedAt)
    }

    @Test
    fun `metadata text is cleaned of invisible characters`() {
        val v = YouTubeTracker.fromMediaMetadata("⁨$titleA⁩​", " KÊNH MẪU ", now = 0L)!!
        assertEquals(titleA, v.title)
        assertEquals("KÊNH MẪU", v.channelName)
    }

    @Test
    fun `missing or label-like metadata title is ignored`() {
        assertNull(YouTubeTracker.fromMediaMetadata(null, "KÊNH", now = 0L))
        assertNull(YouTubeTracker.fromMediaMetadata("  ", "KÊNH", now = 0L))
        assertNull(YouTubeTracker.fromMediaMetadata("Suggested video", "KÊNH", now = 0L))
    }

    @Test
    fun `blank artist gives no channel`() {
        assertNull(YouTubeTracker.fromMediaMetadata(titleA, "  ", now = 0L)!!.channelName)
        assertNull(YouTubeTracker.fromMediaMetadata(titleA, null, now = 0L)!!.channelName)
    }

    // ── mediaAction ────────────────────────────────────────────────────────

    @Test
    fun `nothing tracked starts a session`() {
        val next = info(titleA, channel = "KÊNH", fromMediaSession = true)
        assertEquals(YouTubeTracker.MediaAction.START, YouTubeTracker.mediaAction(null, next))
    }

    @Test
    fun `autoplay to a new title in fullscreen switches the session`() {
        val current = info(titleA, fromMediaSession = true)
        val next = info(titleB, channel = "KÊNH", fromMediaSession = true)
        assertEquals(YouTubeTracker.MediaAction.SWITCH, YouTubeTracker.mediaAction(current, next))
    }

    @Test
    fun `same title only adopts, does not split`() {
        val current = info(titleA)
        val next = info(titleA, channel = "KÊNH", fromMediaSession = true)
        assertEquals(YouTubeTracker.MediaAction.ADOPT, YouTubeTracker.mediaAction(current, next))
    }

    @Test
    fun `tree scan caption title is renamed to the media title`() {
        val current = info("và rồi chúng ta cùng nhau đi tiếp", channel = null, fromTreeScan = true)
        val next = info(titleA, channel = "KÊNH", fromMediaSession = true)
        assertEquals(YouTubeTracker.MediaAction.ADOPT, YouTubeTracker.mediaAction(current, next))
    }

    @Test
    fun `accessibility session with a different title is switched`() {
        val current = info(titleA)
        val next = info(titleB, fromMediaSession = true)
        assertEquals(YouTubeTracker.MediaAction.SWITCH, YouTubeTracker.mediaAction(current, next))
    }

    // ── isNewVideo with media sessions ─────────────────────────────────────

    @Test
    fun `accessibility title cannot replace a media session video`() {
        val current = info(titleA, fromMediaSession = true)
        assertFalse(YouTubeTracker.isNewVideo(current, info(titleB)))
    }

    @Test
    fun `a short still replaces a media session video`() {
        val current = info(titleA, fromMediaSession = true)
        assertTrue(YouTubeTracker.isNewVideo(current, info("Short mẫu #vui", isShort = true)))
    }

    // ── channel preference ─────────────────────────────────────────────────

    @Test
    fun `handle replaces a display name but never the other way round`() {
        assertTrue(YouTubeTracker.shouldReplaceChannel(null, "KÊNH"))
        assertTrue(YouTubeTracker.shouldReplaceChannel("KÊNH", "@kenhMau"))
        assertFalse(YouTubeTracker.shouldReplaceChannel("@kenhMau", "KÊNH"))
        assertFalse(YouTubeTracker.shouldReplaceChannel("@kenhMau", "@khac"))
        assertFalse(YouTubeTracker.shouldReplaceChannel("KÊNH", null))
    }

    @Test
    fun `display-name channel still needs the handle backfill`() {
        assertTrue(YouTubeTracker.needsHandle(null))
        assertTrue(YouTubeTracker.needsHandle("KÊNH"))
        assertFalse(YouTubeTracker.needsHandle("@kenhMau"))
    }

    // ── playback state ─────────────────────────────────────────────────────

    @Test
    fun `playing-like states count as watching`() {
        assertTrue(YouTubeTracker.isPlayingState(PlaybackState.STATE_PLAYING))
        assertTrue(YouTubeTracker.isPlayingState(PlaybackState.STATE_BUFFERING))
        assertFalse(YouTubeTracker.isPlayingState(PlaybackState.STATE_PAUSED))
        assertFalse(YouTubeTracker.isPlayingState(PlaybackState.STATE_STOPPED))
        assertFalse(YouTubeTracker.isPlayingState(PlaybackState.STATE_NONE))
    }
}
