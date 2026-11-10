package com.kidfun.mobile.services

import android.os.SystemClock
import java.time.LocalDate

/**
 * SchoolModeChecker — kiểm tra xem app có được phép dùng trong giờ học không.
 * State được sync từ server qua MethodChannel (`setSchoolMode`).
 *
 * [isActive] được TÍNH theo giờ thực từ khung giờ hôm nay + override mà server
 * gửi, nên vòng kiểm tra 5 giây của AppBlockerService tự bật/tắt đúng giờ bắt
 * đầu/kết thúc. Trước đây đây là cờ cố định lúc đồng bộ → chậm tới 5 phút
 * (lỗi test 10/11).
 *
 * Giờ "bây giờ" lấy theo server (serverTime + SystemClock.elapsedRealtime), không
 * theo đồng hồ máy — trẻ chỉnh giờ hệ thống không lách được.
 */
object SchoolModeChecker {
    private const val KIDFUN_PACKAGE = "com.kidfun.mobile"
    private const val VN_OFFSET_MS = 7 * 60 * 60 * 1000L
    private const val DAY_MS = 24 * 60 * 60 * 1000L
    private const val MINUTE_MS = 60 * 1000L

    @Volatile private var serverActive = false
    @Volatile var allowedPackages: Set<String> = emptySet()
        private set
    @Volatile var startTime: String? = null  // "07:00"; null = hôm nay không học
        private set
    @Volatile var endTime: String? = null    // "11:30"
        private set
    @Volatile private var scheduleEpochDay: Long? = null  // null = server cũ → dùng serverActive
    @Volatile private var overrideMode: String? = null
    @Volatile private var overrideUntilMs = 0L
    @Volatile private var serverMsAtSync = 0L
    @Volatile private var elapsedAtSync = 0L

    /** Đang trong giờ học (tính tại thời điểm gọi). */
    val isActive: Boolean
        get() = isActiveAt(nowMs())

    fun update(
        serverActive: Boolean,
        allowedApps: List<String>,
        startTime: String?,
        endTime: String?,
        scheduleDate: String?,
        overrideMode: String?,
        overrideUntilMs: Long,
        serverTimeMs: Long,
    ) {
        this.serverActive = serverActive
        this.allowedPackages = allowedApps.toSet()
        this.startTime = startTime
        this.endTime = endTime
        this.scheduleEpochDay = scheduleDate?.let { runCatching { LocalDate.parse(it).toEpochDay() }.getOrNull() }
        this.overrideMode = overrideMode
        this.overrideUntilMs = overrideUntilMs
        if (serverTimeMs > 0) {
            elapsedAtSync = SystemClock.elapsedRealtime()
            serverMsAtSync = serverTimeMs
        } else {
            serverMsAtSync = 0L
        }
    }

    private fun nowMs(): Long =
        if (serverMsAtSync > 0) serverMsAtSync + (SystemClock.elapsedRealtime() - elapsedAtSync)
        else System.currentTimeMillis()

    fun isActiveAt(nowMs: Long): Boolean {
        val day = scheduleEpochDay ?: return serverActive

        val mode = overrideMode
        if (mode != null && nowMs < overrideUntilMs) return mode == "FORCE_ON"

        val start = minuteOfDay(startTime) ?: return false
        val end = minuteOfDay(endTime) ?: return false
        val vn = nowMs + VN_OFFSET_MS
        // Sang ngày mới thì chưa biết lịch hôm nay — chờ lượt đồng bộ kế.
        if (Math.floorDiv(vn, DAY_MS) != day) return false

        val minute = (Math.floorMod(vn, DAY_MS) / MINUTE_MS).toInt()
        return minute in start until end
    }

    /** "07:30" → 450; sai định dạng → null. */
    private fun minuteOfDay(hhmm: String?): Int? {
        val parts = hhmm?.split(":") ?: return null
        if (parts.size < 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        return h * 60 + m
    }

    /**
     * Kiểm tra app có được phép dùng trong School Mode không
     */
    fun isAppAllowed(packageName: String): Boolean {
        if (!isActive) return true

        // Always allow KidFun itself
        if (packageName == KIDFUN_PACKAGE) return true

        // Always allow system UI
        if (packageName == "com.android.systemui" || packageName == "com.android.settings") {
            return true
        }

        return allowedPackages.contains(packageName)
    }
}
