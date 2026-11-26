package com.kidfun.mobile.services

import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.util.Log

/**
 * Exists only so Android allows reading YouTube's MediaSession (getActiveSessions requires an
 * enabled notification listener). Notification contents are never read.
 */
class KidFunNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        // Access may be granted after the accessibility service started — hook up now.
        AppBlockerService.instance?.startMediaWatcher()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        // Not the same as access revoked: Android unbinds listeners on its own while the toggle
        // stays on, and getActiveSessions() only needs the toggle. Stopping the watcher here could
        // leave it dead until the next app restart (suspect for report 26/11). Revocation is handled by
        // YouTubeMediaWatcher.ensureRunning(); just ask to be bound again.
        Log.d("YouTubeTracker", "🎵 Notification listener disconnected — requesting rebind")
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        try {
            requestRebind(ComponentName(this, KidFunNotificationListener::class.java))
        } catch (e: Exception) {
            Log.w("YouTubeTracker", "🎵 requestRebind failed (${e.message})")
        }
    }
}
