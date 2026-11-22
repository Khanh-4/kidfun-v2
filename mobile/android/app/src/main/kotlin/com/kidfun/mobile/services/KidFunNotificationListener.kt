package com.kidfun.mobile.services

import android.service.notification.NotificationListenerService

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
        // Access revoked: drop the stale registration so a later grant registers from scratch.
        YouTubeMediaWatcher.stop()
    }
}
