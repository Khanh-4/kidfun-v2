package com.kidfun.mobile.usage

import org.json.JSONObject
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Đồ án chuyên ngành — M2 tầng 1: luật nhẹ chạy ngay trên máy trẻ (đặc tả docs/thesis/05 mục 2.3).
 *
 * Bản Kotlin của ml/tier1/rules.py; hai bản phải cho cùng kết quả trên ml/tier1/test_vectors.json
 * (bản sao ở src/test/resources/tier1_test_vectors.json, test Python kiểm tra hai file giống nhau).
 *  - khuya: giờ thuộc 22h–6h, tổng phút >= nightMinMinutes, và trẻ thường không dùng máy giờ đó
 *    (tổng mức thường ngày cùng giờ, cùng loại ngày <= nightUsualMaxMinutes);
 *  - tăng đột biến: phút của một nhóm app >= spikeRatio × mức thường ngày của nhóm đó và >= spikeMinMinutes.
 */
data class Tier1Config(
    val nightMinMinutes: Double = 10.0,
    val nightUsualMaxMinutes: Double = 3.0,
    val spikeRatio: Double = 3.0,
    val spikeMinMinutes: Double = 20.0,
    val nightMinByDayType: Map<String, Double> = emptyMap(),
    val spikeRatioByKey: Map<String, Double> = emptyMap(),
)

data class Tier1Baseline(
    /** Mức thường ngày, khoá "dayType|hour|cat" -> phút. */
    val means: Map<String, Double>,
    val config: Tier1Config,
    /** packageName -> nhóm app (video, game, social, study, other). */
    val categories: Map<String, String>,
    /** "YYYY-MM-DD" -> school | weekend | off, theo lịch VN do server tính. */
    val dayTypes: Map<String, String>,
) {
    /** true khi server đã gửi mức thường ngày thật (không phải bản rỗng lúc chưa có dữ liệu). */
    val hasUsage: Boolean get() = means.isNotEmpty()

    companion object {
        val EMPTY = Tier1Baseline(emptyMap(), Tier1Config(), emptyMap(), emptyMap())

        fun parse(json: String): Tier1Baseline {
            val root = JSONObject(json)
            val means = mutableMapOf<String, Double>()
            root.optJSONArray("baseline")?.let { arr ->
                for (i in 0 until arr.length()) {
                    val e = arr.getJSONObject(i)
                    means[key(e.getString("dayType"), e.getInt("hour"), e.getString("cat"))] = e.getDouble("mean")
                }
            }
            val rules = root.optJSONObject("rules") ?: JSONObject()
            val defaults = Tier1Config()
            val config = Tier1Config(
                nightMinMinutes = rules.optDouble("nightMinMinutes", defaults.nightMinMinutes),
                nightUsualMaxMinutes = rules.optDouble("nightUsualMaxMinutes", defaults.nightUsualMaxMinutes),
                spikeRatio = rules.optDouble("spikeRatio", defaults.spikeRatio),
                spikeMinMinutes = rules.optDouble("spikeMinMinutes", defaults.spikeMinMinutes),
                nightMinByDayType = doubles(rules.optJSONObject("nightMinByDayType")),
                spikeRatioByKey = doubles(rules.optJSONObject("spikeRatioByKey")),
            )
            return Tier1Baseline(
                means,
                config,
                strings(root.optJSONObject("categories")),
                strings(root.optJSONObject("dayTypes")),
            )
        }

        fun key(dayType: String, hour: Int, cat: String) = "$dayType|$hour|$cat"

        private fun doubles(o: JSONObject?): Map<String, Double> =
            o?.keys()?.asSequence()?.associateWith { o.getDouble(it) } ?: emptyMap()

        private fun strings(o: JSONObject?): Map<String, String> =
            o?.keys()?.asSequence()?.associateWith { o.getString(it) } ?: emptyMap()
    }
}

/** Một vi phạm luật trong một ô giờ. */
data class Tier1Alert(val rule: String, val category: String)

object Tier1Rules {
    val NIGHT_HOURS = setOf(22, 23, 0, 1, 2, 3, 4, 5)
    const val OTHER = "other"

    fun checkHour(
        minutesByCat: Map<String, Double>,
        hour: Int,
        dayType: String,
        baseline: Tier1Baseline,
    ): List<Tier1Alert> {
        if (minutesByCat.isEmpty()) return emptyList()
        val cfg = baseline.config
        val alerts = mutableListOf<Tier1Alert>()
        val total = minutesByCat.values.sum()
        val usualTotal = baseline.means.filterKeys { it.startsWith("$dayType|$hour|") }.values.sum()
        val nightMin = cfg.nightMinByDayType[dayType] ?: cfg.nightMinMinutes
        if (hour in NIGHT_HOURS && total >= nightMin && usualTotal <= cfg.nightUsualMaxMinutes) {
            alerts += Tier1Alert("night", minutesByCat.maxByOrNull { it.value }!!.key)
        }
        for ((cat, used) in minutesByCat) {
            val usual = baseline.means[Tier1Baseline.key(dayType, hour, cat)] ?: 0.0
            val ratio = cfg.spikeRatioByKey["$dayType:$cat"] ?: cfg.spikeRatio
            if (used >= ratio * usual && used >= cfg.spikeMinMinutes) alerts += Tier1Alert("spike", cat)
        }
        return alerts
    }

    /** Loại ngày: theo lịch server gửi, thiếu thì thứ Bảy / Chủ nhật = weekend, còn lại = school. */
    fun dayTypeOf(date: LocalDate, baseline: Tier1Baseline): String =
        baseline.dayTypes[date.toString()]
            ?: if (date.dayOfWeek == DayOfWeek.SATURDAY || date.dayOfWeek == DayOfWeek.SUNDAY) "weekend" else "school"

    fun categoryOf(packageName: String, baseline: Tier1Baseline): String = baseline.categories[packageName] ?: OTHER

    /**
     * Kiểm tra các ô giờ gần đây (giờ hiện tại + LOOKBACK_HOURS giờ trước) -> cảnh báo cần gửi.
     * Chưa có mức thường ngày (trẻ mới / server chưa tính) thì chỉ dùng luật khuya và chỉ trong 0h–6h sáng:
     * so với mức 0, luật đột biến sẽ báo mọi giờ ≥ 20 phút, còn khung 22h cố định báo nhầm ~92% ở trẻ lớn quen
     * ngủ lúc 23h (thực nghiệm tuần 6, docs/thesis/09).
     * Giờ được tính theo giờ VN, khớp với cách server gán loại ngày.
     */
    fun detect(buckets: List<HourlyBucket>, baseline: Tier1Baseline, nowMs: Long): List<Tier1Detection> {
        val currentHourMs = nowMs - Math.floorMod(nowMs, HourlyBucketer.HOUR_MS)
        val fromMs = currentHourMs - LOOKBACK_HOURS * HourlyBucketer.HOUR_MS
        return buckets.filter { it.hourStartMs >= fromMs }
            .groupBy { it.hourStartMs }
            .flatMap { (hourStartMs, inHour) ->
                val local = Instant.ofEpochMilli(hourStartMs).atZone(VN_ZONE)
                val dayType = dayTypeOf(local.toLocalDate(), baseline)
                val minutes = inHour.groupBy { categoryOf(it.packageName, baseline) }
                    .mapValues { (_, b) -> b.sumOf { it.usageSeconds } / 60.0 }
                checkHour(minutes, local.hour, dayType, baseline)
                    .filter { baseline.hasUsage || (it.rule == "night" && local.hour in AFTER_MIDNIGHT) }
                    .map { alert ->
                        val usual = if (alert.rule == "night") {
                            baseline.means.filterKeys { it.startsWith("$dayType|${local.hour}|") }.values.sum()
                        } else {
                            baseline.means[Tier1Baseline.key(dayType, local.hour, alert.category)] ?: 0.0
                        }
                        Tier1Detection(
                            rule = alert.rule,
                            category = alert.category,
                            dayType = dayType,
                            hourStartMs = hourStartMs,
                            minutes = minOf(60.0, if (alert.rule == "night") minutes.values.sum() else minutes.getValue(alert.category)),
                            usualMinutes = minOf(60.0, usual),
                        )
                    }
            }
    }

    private const val LOOKBACK_HOURS = 2
    private val AFTER_MIDNIGHT = 0..5
    private val VN_ZONE: ZoneId = ZoneId.of("Asia/Ho_Chi_Minh")
}

/** Cảnh báo tầng 1 gửi lên POST /api/child/behavior-alerts. */
data class Tier1Detection(
    val rule: String,
    val category: String,
    val dayType: String,
    val hourStartMs: Long,
    val minutes: Double,
    val usualMinutes: Double,
) {
    /** Khoá chống gửi trùng — khớp ràng buộc unique phía server (profile, nguồn, luật, nhóm app, giờ). */
    val key: String get() = "$hourStartMs|$rule|$category"
}
