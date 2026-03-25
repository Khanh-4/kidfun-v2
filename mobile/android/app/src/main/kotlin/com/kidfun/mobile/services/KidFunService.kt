package com.kidfun.mobile.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.kidfun.mobile.MainActivity
import com.kidfun.mobile.receivers.KidFunDeviceAdminReceiver

class KidFunService : Service() {
    companion object {
        const val CHANNEL_ID = "kidfun_foreground"
        const val NOTIFICATION_ID = 1001
        const val ACTION_SET_LOCK_TIME = "SET_LOCK_TIME"
        const val EXTRA_LOCK_AT = "lockAtMillis"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lockAtMillis: Long = 0

    private val checkLockRunnable = object : Runnable {
        override fun run() {
            if (lockAtMillis > 0 && System.currentTimeMillis() >= lockAtMillis) {
                lockScreen()
                lockAtMillis = 0
            } else if (lockAtMillis > 0) {
                handler.postDelayed(this, 10_000L) // kiểm tra mỗi 10 giây
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("KidFun đang hoạt động")
            .setContentText("Đang giám sát thiết bị")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this, 0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()

        startForeground(NOTIFICATION_ID, notification)

        if (intent?.action == ACTION_SET_LOCK_TIME) {
            val newLockAt = intent.getLongExtra(EXTRA_LOCK_AT, 0L)
            handler.removeCallbacks(checkLockRunnable)
            lockAtMillis = newLockAt
            if (lockAtMillis > 0) {
                handler.post(checkLockRunnable)
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun lockScreen() {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(this, KidFunDeviceAdminReceiver::class.java)
        if (dpm.isAdminActive(admin)) {
            dpm.lockNow()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KidFun Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Giám sát thiết bị của trẻ"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
