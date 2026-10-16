package com.kidfun.mobile.usage

import com.kidfun.mobile.usage.UsageEventLite.Type.PAUSED
import com.kidfun.mobile.usage.UsageEventLite.Type.RESUMED
import com.kidfun.mobile.usage.UsageEventLite.Type.SCREEN_OFF
import com.kidfun.mobile.usage.UsageEventLite.Type.SHUTDOWN
import org.junit.Assert.assertEquals
import org.junit.Test

class HourlyBucketerTest {

    // Mốc 2026-10-16T19:00:00Z = 02:00 sáng 17/10 giờ VN
    private val h0 = 1_792_177_200_000L
    private val hour = HourlyBucketer.HOUR_MS
    private val min = 60_000L
    private val yt = "com.google.android.youtube"
    private val zalo = "com.zing.zalo"

    private fun ev(t: Long, pkg: String, type: UsageEventLite.Type) = UsageEventLite(t, pkg, type)

    private fun run(
        events: List<UsageEventLite>,
        now: Long = h0 + 3 * hour,
        windowStart: Long = h0 - hour,
        ignored: Set<String> = emptySet(),
    ) = HourlyBucketer.bucketize(events, windowStart, now, ignored)

    @Test
    fun `mot phien gon trong mot gio`() {
        val result = run(listOf(ev(h0 + 10 * min, yt, RESUMED), ev(h0 + 25 * min, yt, PAUSED)))

        assertEquals(listOf(HourlyBucket(yt, h0, 15 * 60, 1)), result)
    }

    @Test
    fun `phien vat qua ranh gioi gio duoc chia hai, lan mo tinh o gio bat dau`() {
        val result = run(listOf(ev(h0 + 50 * min, yt, RESUMED), ev(h0 + hour + 10 * min, yt, PAUSED)))

        assertEquals(
            listOf(HourlyBucket(yt, h0, 10 * 60, 1), HourlyBucket(yt, h0 + hour, 10 * 60, 0)),
            result,
        )
    }

    @Test
    fun `app dang mo chua PAUSED thi tinh den thoi diem hien tai`() {
        val now = h0 + 40 * min
        val result = run(listOf(ev(h0 + 30 * min, yt, RESUMED)), now = now)

        assertEquals(listOf(HourlyBucket(yt, h0, 10 * 60, 1)), result)
    }

    @Test
    fun `tat man hinh dong phien dang mo`() {
        val result = run(
            listOf(
                ev(h0, yt, RESUMED),
                ev(h0 + 5 * min, "android", SCREEN_OFF),
                ev(h0 + 50 * min, yt, PAUSED), // PAUSED muộn sau khi tắt màn hình — không tính
            )
        )

        assertEquals(listOf(HourlyBucket(yt, h0, 5 * 60, 1)), result)
    }

    @Test
    fun `tat may dong phien dang mo`() {
        val result = run(listOf(ev(h0, yt, RESUMED), ev(h0 + 3 * min, "android", SHUTDOWN)))

        assertEquals(listOf(HourlyBucket(yt, h0, 3 * 60, 1)), result)
    }

    @Test
    fun `app moi RESUMED thi app cu bi dong du thieu PAUSED`() {
        val result = run(
            listOf(ev(h0, yt, RESUMED), ev(h0 + 10 * min, zalo, RESUMED), ev(h0 + 12 * min, zalo, PAUSED))
        )

        assertEquals(
            listOf(HourlyBucket(yt, h0, 10 * 60, 1), HourlyBucket(zalo, h0, 2 * 60, 1)),
            result,
        )
    }

    @Test
    fun `chuyen man hinh trong cung app khong tinh them lan mo`() {
        val result = run(
            listOf(
                ev(h0, yt, RESUMED),
                ev(h0 + 5 * min, yt, PAUSED),
                ev(h0 + 5 * min + 500, yt, RESUMED), // activity khác của cùng app, cách 0,5 giây
                ev(h0 + 8 * min, yt, PAUSED),
            )
        )

        // 300 s + 179,5 s = 479,5 s → làm tròn xuống 479 s
        assertEquals(listOf(HourlyBucket(yt, h0, 479, 1)), result)
    }

    @Test
    fun `mo lai app sau mot luc thi tinh them lan mo`() {
        val result = run(
            listOf(
                ev(h0, yt, RESUMED),
                ev(h0 + 5 * min, yt, PAUSED),
                ev(h0 + 20 * min, yt, RESUMED),
                ev(h0 + 22 * min, yt, PAUSED),
            )
        )

        assertEquals(listOf(HourlyBucket(yt, h0, 7 * 60, 2)), result)
    }

    @Test
    fun `PAUSED khong co RESUMED truoc do bi bo qua`() {
        val result = run(listOf(ev(h0 + 5 * min, yt, PAUSED)))

        assertEquals(emptyList<HourlyBucket>(), result)
    }

    @Test
    fun `bo qua app trong danh sach loai tru nhung van dong app truoc do`() {
        val launcher = "com.android.launcher3"
        val result = run(
            listOf(ev(h0, yt, RESUMED), ev(h0 + 4 * min, launcher, RESUMED), ev(h0 + 30 * min, launcher, PAUSED)),
            ignored = setOf(launcher),
        )

        assertEquals(listOf(HourlyBucket(yt, h0, 4 * 60, 1)), result)
    }

    @Test
    fun `phan truoc moc cua so bi cat bo`() {
        val result = run(
            listOf(ev(h0 - 10 * min, yt, RESUMED), ev(h0 + 5 * min, yt, PAUSED)),
            windowStart = h0,
        )

        // Lần mở xảy ra trước cửa sổ → không tính vào launchCount
        assertEquals(listOf(HourlyBucket(yt, h0, 5 * 60, 0)), result)
    }

    @Test
    fun `su kien khong theo thu tu thoi gian van tinh dung`() {
        val result = run(listOf(ev(h0 + 25 * min, yt, PAUSED), ev(h0 + 10 * min, yt, RESUMED)))

        assertEquals(listOf(HourlyBucket(yt, h0, 15 * 60, 1)), result)
    }

    @Test
    fun `moc gio luon tron gio UTC`() {
        val result = run(listOf(ev(h0 + 2 * hour + 1, yt, RESUMED), ev(h0 + 2 * hour + 61_000, yt, PAUSED)))

        assertEquals(h0 + 2 * hour, result.single().hourStartMs)
        assertEquals(0L, result.single().hourStartMs % hour)
    }
}
