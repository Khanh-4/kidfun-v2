package com.kidfun.mobile.services

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.OffsetDateTime

/**
 * Native tự tính Chế độ đi học theo giờ thực — trước đây lúc tới giờ bắt đầu /
 * kết thúc phải chờ lượt đồng bộ 5 phút (lỗi test 10/11).
 */
class SchoolModeCheckerTest {
    /** Mốc giờ VN, vd. vn("2026-11-10", "07:00"). */
    private fun vn(date: String, time: String): Long =
        OffsetDateTime.parse("${date}T$time:00+07:00").toInstant().toEpochMilli()

    @Before
    fun reset() {
        SchoolModeChecker.update(
            serverActive = false, allowedApps = emptyList(), startTime = "07:00", endTime = "11:30",
            scheduleDate = "2026-11-10", overrideMode = null, overrideUntilMs = 0L, serverTimeMs = 0L,
        )
    }

    @Test
    fun `tự bật đúng 07_00 và tự tắt đúng 11_30 mà không cần đồng bộ lại`() {
        assertFalse(SchoolModeChecker.isActiveAt(vn("2026-11-10", "06:59")))
        assertTrue(SchoolModeChecker.isActiveAt(vn("2026-11-10", "07:00")))
        assertTrue(SchoolModeChecker.isActiveAt(vn("2026-11-10", "11:29")))
        assertFalse(SchoolModeChecker.isActiveAt(vn("2026-11-10", "11:30")))
    }

    @Test
    fun `sang ngày khác ngày lịch thì không áp khung giờ cũ`() {
        assertFalse(SchoolModeChecker.isActiveAt(vn("2026-11-11", "08:00")))
    }

    @Test
    fun `hôm nay không có giờ học thì luôn tắt`() {
        SchoolModeChecker.update(false, emptyList(), null, null, "2026-11-10", null, 0L, 0L)
        assertFalse(SchoolModeChecker.isActiveAt(vn("2026-11-10", "08:00")))
    }

    @Test
    fun `FORCE_ON bật tới hạn rồi quay về theo lịch`() {
        val until = vn("2026-11-10", "06:30")
        SchoolModeChecker.update(true, emptyList(), "07:00", "11:30", "2026-11-10", "FORCE_ON", until, 0L)
        assertTrue(SchoolModeChecker.isActiveAt(vn("2026-11-10", "06:00")))
        assertFalse(SchoolModeChecker.isActiveAt(vn("2026-11-10", "06:45")))
        assertTrue(SchoolModeChecker.isActiveAt(vn("2026-11-10", "07:15")))
    }

    @Test
    fun `FORCE_OFF trong giờ học tắt tới hạn rồi bật lại theo lịch`() {
        val until = vn("2026-11-10", "09:00")
        SchoolModeChecker.update(false, emptyList(), "07:00", "11:30", "2026-11-10", "FORCE_OFF", until, 0L)
        assertFalse(SchoolModeChecker.isActiveAt(vn("2026-11-10", "08:00")))
        assertTrue(SchoolModeChecker.isActiveAt(vn("2026-11-10", "09:00")))
    }

    @Test
    fun `server cũ không gửi scheduleDate thì dùng isActive của server như trước`() {
        SchoolModeChecker.update(true, emptyList(), "07:00", "11:30", null, null, 0L, 0L)
        assertTrue(SchoolModeChecker.isActiveAt(vn("2026-11-10", "23:00")))
    }

    @Test
    fun `app KidFun luôn được phép khi đang trong giờ học`() {
        SchoolModeChecker.update(true, listOf("com.edu.app"), null, null, null, null, 0L, 0L)
        assertTrue(SchoolModeChecker.isAppAllowed("com.kidfun.mobile"))
        assertTrue(SchoolModeChecker.isAppAllowed("com.edu.app"))
        assertFalse(SchoolModeChecker.isAppAllowed("com.game.app"))
    }
}
