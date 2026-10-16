package com.kidfun.mobile.usage

/**
 * Sự kiện dùng app đã rút gọn từ `UsageEvents.Event` — tách khỏi Android để test được trên JVM.
 */
data class UsageEventLite(val timeMs: Long, val packageName: String, val type: Type) {
    enum class Type { RESUMED, PAUSED, SCREEN_OFF, SHUTDOWN }
}

/** Thời gian dùng một app trong một giờ. `hourStartMs` là mốc UTC tròn giờ. */
data class HourlyBucket(
    val packageName: String,
    val hourStartMs: Long,
    val usageSeconds: Int,
    val launchCount: Int,
)

/**
 * Ghép sự kiện mở/đóng app thành các khoảng foreground rồi cắt theo từng giờ.
 *
 * Mô hình "một app foreground tại một thời điểm": app mới RESUMED thì app đang mở bị đóng,
 * kể cả khi thiếu sự kiện PAUSED. Tắt màn hình / tắt máy đóng app đang mở.
 * Ranh giới giờ tính theo UTC — với VN (UTC+7, không đổi giờ mùa hè) trùng đúng ranh giới giờ địa phương.
 */
object HourlyBucketer {
    const val HOUR_MS = 3_600_000L

    // RESUMED lại cùng app trong khoảng này (chuyển màn hình nội bộ app) không tính là một lần mở mới.
    private const val MERGE_GAP_MS = 2_000L

    private data class Interval(val packageName: String, val startMs: Long, val endMs: Long, val isLaunch: Boolean)

    fun bucketize(
        events: List<UsageEventLite>,
        windowStartMs: Long,
        nowMs: Long,
        ignoredPackages: Set<String>,
    ): List<HourlyBucket> {
        val intervals = buildIntervals(events.sortedBy { it.timeMs }, nowMs)
            .filter { it.packageName !in ignoredPackages }
        return splitByHour(intervals, windowStartMs, nowMs)
    }

    private fun buildIntervals(sorted: List<UsageEventLite>, nowMs: Long): List<Interval> {
        val intervals = mutableListOf<Interval>()
        val lastCloseMs = mutableMapOf<String, Long>()
        var openPackage: String? = null
        var openStartMs = 0L

        fun close(atMs: Long) {
            val pkg = openPackage ?: return
            if (atMs > openStartMs) {
                val previousClose = lastCloseMs[pkg]
                val isLaunch = previousClose == null || openStartMs - previousClose > MERGE_GAP_MS
                intervals += Interval(pkg, openStartMs, atMs, isLaunch)
                lastCloseMs[pkg] = atMs
            }
            openPackage = null
        }

        for (event in sorted) {
            when (event.type) {
                UsageEventLite.Type.RESUMED -> {
                    if (openPackage == event.packageName) continue
                    close(event.timeMs)
                    openPackage = event.packageName
                    openStartMs = event.timeMs
                }
                UsageEventLite.Type.PAUSED -> if (openPackage == event.packageName) close(event.timeMs)
                UsageEventLite.Type.SCREEN_OFF, UsageEventLite.Type.SHUTDOWN -> close(event.timeMs)
            }
        }
        close(nowMs)
        return intervals
    }

    private fun splitByHour(intervals: List<Interval>, windowStartMs: Long, nowMs: Long): List<HourlyBucket> {
        val usageMs = mutableMapOf<Pair<String, Long>, Long>()
        val launches = mutableMapOf<Pair<String, Long>, Int>()

        for (interval in intervals) {
            val start = maxOf(interval.startMs, windowStartMs)
            val end = minOf(interval.endMs, nowMs)
            if (end <= start) continue

            if (interval.isLaunch && interval.startMs >= windowStartMs) {
                val key = interval.packageName to floorHour(interval.startMs)
                launches[key] = (launches[key] ?: 0) + 1
            }

            var hourStart = floorHour(start)
            while (hourStart < end) {
                val pieceStart = maxOf(start, hourStart)
                val pieceEnd = minOf(end, hourStart + HOUR_MS)
                val key = interval.packageName to hourStart
                usageMs[key] = (usageMs[key] ?: 0L) + (pieceEnd - pieceStart)
                hourStart += HOUR_MS
            }
        }

        return (usageMs.keys + launches.keys)
            .map { key ->
                HourlyBucket(
                    packageName = key.first,
                    hourStartMs = key.second,
                    usageSeconds = ((usageMs[key] ?: 0L) / 1000L).toInt().coerceAtMost(3600),
                    launchCount = launches[key] ?: 0,
                )
            }
            .filter { it.usageSeconds > 0 || it.launchCount > 0 }
            .sortedWith(compareBy({ it.hourStartMs }, { it.packageName }))
    }

    private fun floorHour(timeMs: Long): Long = Math.floorDiv(timeMs, HOUR_MS) * HOUR_MS
}
