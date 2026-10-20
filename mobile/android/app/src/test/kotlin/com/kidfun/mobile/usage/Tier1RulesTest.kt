package com.kidfun.mobile.usage

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate

class Tier1RulesTest {

    private val vectors = JSONObject(
        javaClass.classLoader!!.getResource("tier1_test_vectors.json")!!.readText(Charsets.UTF_8)
    )
    private val baseline = Tier1Baseline.parse(vectors.getJSONObject("baseline").toString())

    @Test
    fun `cho cùng kết quả với bản Python trên mọi ca kiểm thử dùng chung`() {
        val cases = vectors.getJSONArray("cases")
        assertTrue(cases.length() > 0)
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val minutesJson = c.getJSONObject("minutes")
            val minutes = minutesJson.keys().asSequence().associateWith { minutesJson.getDouble(it) }
            val expectedJson = c.getJSONArray("expected")
            val expected = (0 until expectedJson.length()).map {
                val pair = expectedJson.getJSONArray(it)
                Tier1Alert(pair.getString(0), pair.getString(1))
            }
            val got = Tier1Rules.checkHour(minutes, c.getInt("hour"), c.getString("dayType"), baseline)
            assertEquals(c.getString("name"), expected, got)
        }
    }

    @Test
    fun `đọc JSON mức thường ngày, thiếu trường thì dùng mặc định`() {
        val b = Tier1Baseline.parse(
            """{"baseline":[],"rules":{"spikeRatioByKey":{"weekend:game":3.75}},
               "categories":{"com.roblox.client":"game"},"dayTypes":{"2026-04-30":"off"}}"""
        )
        assertEquals(10.0, b.config.nightMinMinutes, 0.0)
        assertEquals(3.75, b.config.spikeRatioByKey["weekend:game"]!!, 0.0)
        assertEquals("game", Tier1Rules.categoryOf("com.roblox.client", b))
        assertEquals("other", Tier1Rules.categoryOf("com.unknown", b))
        assertEquals(false, b.hasUsage)
        assertEquals(Tier1Baseline.EMPTY.config, Tier1Baseline.parse("{}").config)
    }

    @Test
    fun `loại ngày theo lịch server, thiếu thì tự suy thứ Bảy Chủ nhật`() {
        val b = Tier1Baseline.parse("""{"dayTypes":{"2026-04-30":"off"}}""")
        assertEquals("off", Tier1Rules.dayTypeOf(LocalDate.parse("2026-04-30"), b)) // thứ Năm nhưng là ngày lễ
        assertEquals("weekend", Tier1Rules.dayTypeOf(LocalDate.parse("2026-10-24"), b)) // thứ Bảy
        assertEquals("school", Tier1Rules.dayTypeOf(LocalDate.parse("2026-10-21"), b)) // thứ Tư
    }

    // 02:00 sáng 21/10/2026 giờ VN = 19:00 UTC 20/10
    private val twoAmVn = Instant.parse("2026-10-20T19:00:00Z").toEpochMilli()
    private val categories = """{"com.roblox.client":"game","com.google.android.youtube":"video"}"""

    @Test
    fun `chưa có mức thường ngày thì chỉ báo khuya, không báo đột biến`() {
        val buckets = listOf(HourlyBucket("com.roblox.client", twoAmVn, 25 * 60, 2))
        val noUsage = Tier1Baseline.parse("""{"categories":$categories}""")
        val got = Tier1Rules.detect(buckets, noUsage, twoAmVn + 30 * 60_000)
        assertEquals(1, got.size)
        val d = got.single()
        assertEquals("night", d.rule)
        assertEquals("game", d.category)
        assertEquals("school", d.dayType)
        assertEquals(25.0, d.minutes, 1e-9)
        assertEquals("$twoAmVn|night|game", d.key)
    }

    @Test
    fun `chưa có mức thường ngày thì không báo khuya lúc 22h-23h`() {
        val elevenPmVn = Instant.parse("2026-10-21T16:00:00Z").toEpochMilli()
        val buckets = listOf(HourlyBucket("com.roblox.client", elevenPmVn, 40 * 60, 2))
        val noUsage = Tier1Baseline.parse("""{"categories":$categories}""")
        assertTrue(Tier1Rules.detect(buckets, noUsage, elevenPmVn + 50 * 60_000).isEmpty())
    }

    @Test
    fun `có mức thường ngày thì báo đột biến theo nhóm app, kèm mức thường ngày`() {
        val eightPmVn = Instant.parse("2026-10-21T13:00:00Z").toEpochMilli() // 20h thứ Tư
        val withUsage = Tier1Baseline.parse(
            """{"categories":$categories,
               "baseline":[{"dayType":"school","hour":20,"cat":"video","mean":10.0,"std":2.0}]}"""
        )
        val buckets = listOf(
            HourlyBucket("com.google.android.youtube", eightPmVn, 40 * 60, 3),
            HourlyBucket("com.roblox.client", eightPmVn, 5 * 60, 1),
        )
        val got = Tier1Rules.detect(buckets, withUsage, eightPmVn + 50 * 60_000)
        assertEquals(listOf("spike" to "video"), got.map { it.rule to it.category })
        assertEquals(40.0, got.single().minutes, 1e-9)
        assertEquals(10.0, got.single().usualMinutes, 1e-9)
    }

    @Test
    fun `chỉ xét giờ hiện tại và 2 giờ trước`() {
        val buckets = listOf(HourlyBucket("com.roblox.client", twoAmVn, 30 * 60, 1))
        val b = Tier1Baseline.parse("""{"categories":$categories}""")
        val fourHoursLater = twoAmVn + 4 * HourlyBucketer.HOUR_MS
        assertTrue(Tier1Rules.detect(buckets, b, fourHoursLater).isEmpty())
        assertEquals(1, Tier1Rules.detect(buckets, b, twoAmVn + 2 * HourlyBucketer.HOUR_MS).size)
    }
}
