package com.kidfun.mobile.usage

import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant

/**
 * Đồ án chuyên ngành — phần mạng + lưu trạng thái của luật tầng 1 (logic thuần ở Tier1Rules).
 * Chạy sau mỗi lần HourlyUsageWorker thu thập (30 phút/lần), dùng lại các ô theo giờ vừa tính:
 *  1. lấy mức thường ngày (GET /api/child/behavior-baseline), lưu tạm, làm mới mỗi BASELINE_REFRESH_MS;
 *  2. Tier1Rules.detect -> bỏ cảnh báo đã gửi -> POST /api/child/behavior-alerts (server dựng câu + FCM).
 * Lỗi ở đây không được làm hỏng việc thu thập: HourlyUsageWorker gọi trong try/catch.
 */
object Tier1Client {
    private const val TAG = "Tier1Client"
    private const val KEY_BASELINE = "tier1_baseline"
    private const val KEY_BASELINE_AT = "tier1_baseline_at"
    private const val KEY_ALERTED = "tier1_alerted"
    private const val BASELINE_REFRESH_MS = 6 * HourlyBucketer.HOUR_MS
    private const val ALERTED_KEEP_MS = 48 * HourlyBucketer.HOUR_MS
    private const val TIMEOUT_MS = 20_000

    fun run(prefs: SharedPreferences, baseUrl: String, deviceCode: String, buckets: List<HourlyBucket>, nowMs: Long) {
        val baseline = baseline(prefs, baseUrl, deviceCode, nowMs)
        val alerted = loadAlerted(prefs).filter { hourOf(it) >= nowMs - ALERTED_KEEP_MS }.toMutableSet()
        val fresh = Tier1Rules.detect(buckets, baseline, nowMs).filter { it.key !in alerted }
        if (fresh.isNotEmpty()) {
            val status = postAlerts(baseUrl, deviceCode, fresh)
            // 4xx gửi lại cũng bị từ chối -> coi như đã xử lý để không lặp mãi; 5xx / lỗi mạng -> lần sau gửi lại
            if (status in 200..499) alerted += fresh.map { it.key }
            Log.i(TAG, "Gửi ${fresh.size} cảnh báo tầng 1, HTTP $status")
        }
        prefs.edit().putStringSet(KEY_ALERTED, alerted).apply()
    }

    private fun baseline(prefs: SharedPreferences, baseUrl: String, deviceCode: String, nowMs: Long): Tier1Baseline {
        val cached = prefs.getString(KEY_BASELINE, null)
        val fetchedAt = prefs.getLong(KEY_BASELINE_AT, 0L)
        if (cached == null || nowMs - fetchedAt >= BASELINE_REFRESH_MS) {
            try {
                val fresh = fetchBaseline(baseUrl, deviceCode)
                if (fresh != null) {
                    prefs.edit().putString(KEY_BASELINE, fresh).putLong(KEY_BASELINE_AT, nowMs).apply()
                    return parseOrEmpty(fresh)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Không tải được mức thường ngày, dùng bản đã lưu: ${e.message}")
            }
        }
        return cached?.let(::parseOrEmpty) ?: Tier1Baseline.EMPTY
    }

    /** JSON mức thường ngày, "{}" khi server chưa tính cho trẻ này, null khi lỗi HTTP. */
    private fun fetchBaseline(baseUrl: String, deviceCode: String): String? {
        val query = URLEncoder.encode(deviceCode, "UTF-8")
        val conn = URL("$baseUrl/api/child/behavior-baseline?deviceCode=$query").openConnection() as HttpURLConnection
        return try {
            conn.connectTimeout = TIMEOUT_MS
            conn.readTimeout = TIMEOUT_MS
            if (conn.responseCode !in 200..299) return null
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            JSONObject(body).optJSONObject("data")?.optJSONObject("baseline")?.toString() ?: "{}"
        } finally {
            conn.disconnect()
        }
    }

    private fun parseOrEmpty(json: String): Tier1Baseline = try {
        Tier1Baseline.parse(json)
    } catch (e: Exception) {
        Tier1Baseline.EMPTY
    }

    private fun postAlerts(baseUrl: String, deviceCode: String, detections: List<Tier1Detection>): Int {
        val items = JSONArray()
        for (d in detections) {
            items.put(
                JSONObject()
                    .put("rule", d.rule)
                    .put("category", d.category)
                    .put("dayType", d.dayType)
                    .put("slotStart", Instant.ofEpochMilli(d.hourStartMs).toString())
                    .put("minutes", d.minutes)
                    .put("usualMinutes", d.usualMinutes)
            )
        }
        val body = JSONObject().put("deviceCode", deviceCode).put("alerts", items).toString()
        val conn = URL("$baseUrl/api/child/behavior-alerts").openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.connectTimeout = TIMEOUT_MS
            conn.readTimeout = TIMEOUT_MS
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            conn.responseCode
        } finally {
            conn.disconnect()
        }
    }

    private fun loadAlerted(prefs: SharedPreferences): Set<String> =
        prefs.getStringSet(KEY_ALERTED, emptySet()) ?: emptySet()

    private fun hourOf(key: String) = key.substringBefore('|').toLongOrNull() ?: 0L

    fun clearState(prefs: SharedPreferences) {
        prefs.edit().remove(KEY_BASELINE).remove(KEY_BASELINE_AT).remove(KEY_ALERTED).apply()
    }
}
