package com.kidfun.mobile.services

import com.kidfun.mobile.services.YouTubeMediaWatcher.Health
import com.kidfun.mobile.services.YouTubeMediaWatcher.Recovery
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Báo cáo 26/11: quyền "Truy cập thông báo" đã bật, YouTube có MediaSession đang PLAYING kèm tiêu đề,
 * nhưng logcat không có dòng 🎵 nào → watcher chưa bao giờ bám được phiên. Watcher phải tự hồi phục
 * mỗi lần YouTube lên foreground thay vì chỉ thử lúc dịch vụ kết nối.
 */
class YouTubeMediaWatcherHealthTest {

    @Test
    fun `no permission wins over everything else`() {
        assertEquals(Health.NO_PERMISSION, YouTubeMediaWatcher.health(permission = false, started = true, attached = true))
    }

    @Test
    fun `permission but never registered is not started`() {
        assertEquals(Health.NOT_STARTED, YouTubeMediaWatcher.health(permission = true, started = false, attached = false))
    }

    @Test
    fun `registered without a YouTube controller has no session`() {
        assertEquals(Health.NO_SESSION, YouTubeMediaWatcher.health(permission = true, started = true, attached = false))
    }

    @Test
    fun `registered with a YouTube controller is attached`() {
        assertEquals(Health.ATTACHED, YouTubeMediaWatcher.health(permission = true, started = true, attached = true))
    }

    @Test
    fun `not started recovers by starting`() {
        assertEquals(Recovery.START, YouTubeMediaWatcher.recovery(Health.NOT_STARTED, started = false))
    }

    @Test
    fun `no session recovers by rescanning active sessions`() {
        assertEquals(Recovery.RESCAN, YouTubeMediaWatcher.recovery(Health.NO_SESSION, started = true))
    }

    @Test
    fun `attached needs nothing`() {
        assertEquals(Recovery.NONE, YouTubeMediaWatcher.recovery(Health.ATTACHED, started = true))
    }

    @Test
    fun `permission revoked while registered drops the stale registration`() {
        assertEquals(Recovery.STOP, YouTubeMediaWatcher.recovery(Health.NO_PERMISSION, started = true))
    }

    @Test
    fun `no permission and not registered does nothing`() {
        assertEquals(Recovery.NONE, YouTubeMediaWatcher.recovery(Health.NO_PERMISSION, started = false))
    }
}
