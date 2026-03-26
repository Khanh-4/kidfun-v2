package com.kidfun.mobile.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
        const val ACTION_ENTER_LOCKED_STATE = "ENTER_LOCKED_STATE"
        const val ACTION_EXIT_LOCKED_STATE = "EXIT_LOCKED_STATE"
        // Grace period (ms) child has to request extension before re-locking
        const val RELOCK_DELAY_MS = 30_000L
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lockAtMillis: Long = 0
    private var isInLockedState = false
    private var userPresentReceiver: BroadcastReceiver? = null

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

    private val reLockRunnable = Runnable {
        if (isInLockedState) lockScreen()
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

        when (intent?.action) {
            ACTION_SET_LOCK_TIME -> {
                val newLockAt = intent.getLongExtra(EXTRA_LOCK_AT, 0L)
                handler.removeCallbacks(checkLockRunnable)
                lockAtMillis = newLockAt
                if (lockAtMillis > 0) {
                    handler.post(checkLockRunnable)
                }
            }
            ACTION_ENTER_LOCKED_STATE -> {
                isInLockedState = true
                registerUserPresentReceiver()
            }
            ACTION_EXIT_LOCKED_STATE -> {
                isInLockedState = false
                handler.removeCallbacks(reLockRunnable)
                unregisterUserPresentReceiver()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        unregisterUserPresentReceiver()
    }

    private fun registerUserPresentReceiver() {
        if (userPresentReceiver != null) return
        userPresentReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_USER_PRESENT && isInLockedState) {
                    // Mở app để trẻ có thể nhấn "Xin thêm giờ"
                    val appIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    }
                    context.startActivity(appIntent)
                    // Khoá lại sau RELOCK_DELAY_MS nếu vẫn đang trong trạng thái khoá
                    handler.removeCallbacks(reLockRunnable)
                    handler.postDelayed(reLockRunnable, RELOCK_DELAY_MS)
                }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(userPresentReceiver, IntentFilter(Intent.ACTION_USER_PRESENT), RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(userPresentReceiver, IntentFilter(Intent.ACTION_USER_PRESENT))
        }
    }

    private fun unregisterUserPresentReceiver() {
        userPresentReceiver?.let {
            try { unregisterReceiver(it) } catch (_: IllegalArgumentException) {}
            userPresentReceiver = null
        }
    }

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
