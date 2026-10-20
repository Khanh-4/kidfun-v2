package com.kidfun.mobile.usage

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.kidfun.mobile.helpers.UsageStatsHelper
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Đồ án chuyên ngành — thu thập thời gian dùng từng app theo từng giờ và gửi lên server theo đợt.
 *
 * Mỗi lần chạy tính lại TOÀN BỘ các giờ từ 00:00 hôm qua tới hiện tại từ sự kiện gốc của Android,
 * rồi chỉ gửi những ô đã đổi so với lần gửi thành công trước. Server ghi đè (giá trị tuyệt đối),
 * nên gửi trùng hay gửi bù sau khi mất mạng đều không làm sai số liệu.
 * Thiết kế: docs/thesis/01-thiet-ke-thu-thap-theo-gio.md
 */
class HourlyUsageWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        val ctx = applicationContext
        val deviceCode = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(FLUTTER_DEVICE_CODE_KEY, null)
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val baseUrl = prefs.getString(KEY_BASE_URL, null)

        if (deviceCode.isNullOrEmpty() || baseUrl.isNullOrEmpty()) return Result.success()
        if (!UsageStatsHelper(ctx).hasPermission()) return Result.success()

        val nowMs = System.currentTimeMillis()
        val windowStartMs = startOfYesterday(nowMs)
        val ignored = setOf(ctx.packageName) + launcherPackages(ctx)
        val buckets = HourlyBucketer.bucketize(readEvents(ctx, windowStartMs, nowMs), windowStartMs, nowMs, ignored)

        val sent = loadSent(prefs).filterKeys { hourOf(it) >= windowStartMs }.toMutableMap()
        val changed = buckets.filter { sent[keyOf(it)] != valueOf(it) }

        for (batch in changed.chunked(MAX_BATCH)) {
            val status = try {
                post(baseUrl, deviceCode, batch, ctx)
            } catch (e: IOException) {
                Log.w(TAG, "Gửi dữ liệu theo giờ thất bại, thử lại sau: ${e.message}")
                saveSent(prefs, sent)
                return Result.retry()
            }
            when {
                status in 200..299 -> batch.forEach { sent[keyOf(it)] = valueOf(it) }
                status == 404 -> {
                    // Máy đã bị gỡ liên kết phía server → ngừng hẳn, app sẽ lên lịch lại khi liên kết mới.
                    Log.i(TAG, "Thiết bị không còn liên kết, huỷ lịch thu thập theo giờ")
                    HourlyUsageScheduler.cancel(ctx)
                    return Result.success()
                }
                status in 400..499 -> {
                    // Gửi lại y nguyên cũng bị từ chối → đánh dấu đã xử lý để không lặp mãi
                    Log.w(TAG, "Server từ chối lô dữ liệu theo giờ (HTTP $status), bỏ qua lô này")
                    batch.forEach { sent[keyOf(it)] = valueOf(it) }
                }
                else -> {
                    saveSent(prefs, sent)
                    return Result.retry()
                }
            }
        }

        saveSent(prefs, sent)
        // M2 tầng 1 (đồ án chuyên ngành): kiểm tra luật trên chính các ô vừa tính, báo phụ huynh ngay.
        try {
            Tier1Client.run(prefs, baseUrl, deviceCode, buckets, nowMs)
        } catch (e: Exception) {
            Log.w(TAG, "Luật tầng 1 lỗi, bỏ qua lần này: ${e.message}")
        }
        return Result.success()
    }

    private fun readEvents(ctx: Context, fromMs: Long, toMs: Long): List<UsageEventLite> {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(fromMs, toMs) ?: return emptyList()
        val result = mutableListOf<UsageEventLite>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val type = when (event.eventType) {
                EVENT_RESUMED -> UsageEventLite.Type.RESUMED
                EVENT_PAUSED -> UsageEventLite.Type.PAUSED
                EVENT_SCREEN_NON_INTERACTIVE -> UsageEventLite.Type.SCREEN_OFF
                EVENT_DEVICE_SHUTDOWN -> UsageEventLite.Type.SHUTDOWN
                else -> null
            } ?: continue
            result += UsageEventLite(event.timeStamp, event.packageName ?: "", type)
        }
        return result
    }

    private fun launcherPackages(ctx: Context): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return ctx.packageManager.queryIntentActivities(intent, 0)
            .mapNotNull { it.activityInfo?.packageName }
            .toSet()
    }

    private fun post(baseUrl: String, deviceCode: String, batch: List<HourlyBucket>, ctx: Context): Int {
        val pm = ctx.packageManager
        val items = JSONArray()
        for (bucket in batch) {
            val appName = try {
                pm.getApplicationLabel(pm.getApplicationInfo(bucket.packageName, 0)).toString()
            } catch (e: Exception) {
                null
            }
            items.put(
                JSONObject()
                    .put("packageName", bucket.packageName)
                    .put("appName", appName ?: JSONObject.NULL)
                    .put("hourStart", Instant.ofEpochMilli(bucket.hourStartMs).toString())
                    .put("usageSeconds", bucket.usageSeconds)
                    .put("launchCount", bucket.launchCount)
            )
        }
        val body = JSONObject().put("deviceCode", deviceCode).put("buckets", items).toString()

        val conn = URL("$baseUrl/api/child/app-usage/hourly").openConnection() as HttpURLConnection
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

    companion object {
        private const val TAG = "HourlyUsageWorker"

        const val PREFS = "kidfun_hourly_usage"
        const val KEY_BASE_URL = "base_url"
        private const val KEY_SENT = "sent_buckets"

        // shared_preferences của Flutter lưu ở file này với tiền tố "flutter."
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val FLUTTER_DEVICE_CODE_KEY = "flutter.device_code"

        // Mã sự kiện của UsageEvents.Event (ACTIVITY_RESUMED/PAUSED trùng mã MOVE_TO_FOREGROUND/BACKGROUND cũ)
        private const val EVENT_RESUMED = 1
        private const val EVENT_PAUSED = 2
        private const val EVENT_SCREEN_NON_INTERACTIVE = 16
        private const val EVENT_DEVICE_SHUTDOWN = 26

        private const val MAX_BATCH = 500
        private const val TIMEOUT_MS = 20_000

        private fun keyOf(b: HourlyBucket) = "${b.hourStartMs}|${b.packageName}"
        private fun valueOf(b: HourlyBucket) = "${b.usageSeconds}:${b.launchCount}"
        private fun hourOf(key: String) = key.substringBefore('|').toLongOrNull() ?: 0L

        private fun startOfYesterday(nowMs: Long): Long = Calendar.getInstance().apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, -1)
        }.timeInMillis

        private fun loadSent(prefs: SharedPreferences): Map<String, String> {
            val raw = prefs.getString(KEY_SENT, null) ?: return emptyMap()
            return try {
                val json = JSONObject(raw)
                json.keys().asSequence().associateWith { json.getString(it) }
            } catch (e: Exception) {
                emptyMap()
            }
        }

        private fun saveSent(prefs: SharedPreferences, sent: Map<String, String>) {
            prefs.edit().putString(KEY_SENT, JSONObject(sent).toString()).apply()
        }

        fun clearState(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_SENT).apply()
            Tier1Client.clearState(prefs)
        }
    }
}

/** Lên lịch / huỷ worker thu thập theo giờ. Gọi từ MainActivity qua MethodChannel. */
object HourlyUsageScheduler {
    private const val WORK_NAME = "kidfun_hourly_usage"
    private const val INTERVAL_MINUTES = 30L

    fun schedule(context: Context, baseUrl: String) {
        context.getSharedPreferences(HourlyUsageWorker.PREFS, Context.MODE_PRIVATE)
            .edit().putString(HourlyUsageWorker.KEY_BASE_URL, baseUrl.trimEnd('/')).apply()

        val request = PeriodicWorkRequestBuilder<HourlyUsageWorker>(INTERVAL_MINUTES, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        // KEEP: app mở lại nhiều lần không làm lịch bị đặt lại từ đầu
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        HourlyUsageWorker.clearState(context)
    }
}
