package com.kidfun.mobile.helpers

import android.app.*
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Helper để hiện notification khi app/web bị chặn.
 * Sử dụng trong AppBlockerService khi phát hiện vi phạm.
 */
object BlockNotificationHelper {
    private const val CHANNEL_ID = "kidfun_blocks"
    private const val CHANNEL_NAME = "App Blocking Notifications"

    fun showTimeLimitExceeded(context: Context, appName: String, packageName: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("⏰ $appName đã hết giờ hôm nay")
            .setContentText("Bạn đã dùng hết giới hạn thời gian cho ứng dụng này.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(packageName.hashCode(), notification)
    }

    fun showTimeLimitWarning(context: Context, appName: String, remainingMinutes: Int) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("⚠️ $appName còn $remainingMinutes phút")
            .setContentText("Sắp hết giới hạn thời gian cho ứng dụng này. Hãy dùng hợp lý nhé!")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify("warn_$appName".hashCode(), notification)
    }

    fun showSchoolModeBlock(context: Context, appName: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("📚 Đang trong giờ học")
            .setContentText("$appName không được phép dùng trong giờ học.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(appName.hashCode(), notification)
    }

    fun showVideoBlocked(context: Context, videoTitle: String) {
        ensureChannel(context)
        val shortTitle = if (videoTitle.length > 60) videoTitle.take(60) + "..." else videoTitle
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("🚫 Video bị chặn")
            .setContentText("\"$shortTitle\" không phù hợp với bạn.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(videoTitle.hashCode(), notification)
    }

    fun showWebBlocked(context: Context, domain: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("🚫 Trang web bị chặn")
            .setContentText("$domain không được phép truy cập.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(domain.hashCode(), notification)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Notifications khi app/web bị chặn"
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
