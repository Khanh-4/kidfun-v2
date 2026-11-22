package com.kidfun.mobile.services

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log

/**
 * Follows YouTube's MediaSession (title, channel display name, playing/paused). Unlike the
 * accessibility tree it is exact in fullscreen with hidden controls (report 22/11).
 * Needs the "Notification access" toggle: getActiveSessions() is only allowed for an enabled
 * NotificationListenerService. Without it the tracker keeps working from accessibility only.
 */
object YouTubeMediaWatcher {
    private const val TAG = "YouTubeTracker"

    interface Listener {
        fun onYouTubeMetadata(title: String?, artist: String?)
        fun onYouTubePlaying(isPlaying: Boolean)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var manager: MediaSessionManager? = null
    private var controller: MediaController? = null
    private var listener: Listener? = null

    private val sessionsListener = MediaSessionManager.OnActiveSessionsChangedListener { attach(it) }

    private val callback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) = dispatchMetadata(metadata)
        override fun onPlaybackStateChanged(state: PlaybackState?) = dispatchState(state)
        override fun onSessionDestroyed() = attach(null)
    }

    fun isPermissionGranted(context: Context): Boolean {
        val enabled = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners") ?: return false
        val target = listenerComponent(context).flattenToString()
        return enabled.split(":").any { it.trim().equals(target, ignoreCase = true) }
    }

    /** Safe to call repeatedly (accessibility connect, listener connect). Returns false without permission. */
    fun start(context: Context, listener: Listener): Boolean {
        this.listener = listener
        if (manager != null) return true
        if (!isPermissionGranted(context)) {
            Log.d(TAG, "🎵 MediaSession: notification access not granted — accessibility only")
            return false
        }
        val mgr = context.getSystemService(MediaSessionManager::class.java) ?: return false
        val component = listenerComponent(context)
        return try {
            mgr.addOnActiveSessionsChangedListener(sessionsListener, component, handler)
            manager = mgr
            attach(mgr.getActiveSessions(component))
            Log.d(TAG, "🎵 MediaSession watcher started")
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "🎵 MediaSession: not allowed (${e.message})")
            false
        }
    }

    fun stop() {
        controller?.unregisterCallback(callback)
        controller = null
        try { manager?.removeOnActiveSessionsChangedListener(sessionsListener) } catch (_: Exception) {}
        manager = null
        listener = null
    }

    /** Re-send the current state, e.g. when YouTube comes back to the foreground. */
    fun refresh() {
        val c = controller ?: return
        dispatchMetadata(c.metadata)
        dispatchState(c.playbackState)
    }

    /** Last known playing state of YouTube's session; null when there is no session. */
    fun isPlaying(): Boolean? = controller?.playbackState?.let { YouTubeTracker.isPlayingState(it.state) }

    private fun attach(sessions: List<MediaController>?) {
        val yt = sessions?.firstOrNull { it.packageName == YouTubeTracker.YOUTUBE_PACKAGE }
        if (yt?.sessionToken == controller?.sessionToken) return
        controller?.unregisterCallback(callback)
        controller = yt
        if (yt == null) return
        yt.registerCallback(callback, handler)
        Log.d(TAG, "🎵 MediaSession attached: ${yt.packageName}")
        refresh()
    }

    private fun dispatchMetadata(metadata: MediaMetadata?) {
        metadata ?: return
        val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
        val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
        val durationMs = metadata.getLong(MediaMetadata.METADATA_KEY_DURATION)
        // Logged for diagnosis (ads, Shorts): what YouTube publishes is not documented.
        Log.d(TAG, "🎵 Media metadata: $title | $artist | ${durationMs / 1000}s")
        listener?.onYouTubeMetadata(title, artist)
    }

    private fun dispatchState(state: PlaybackState?) {
        state ?: return
        listener?.onYouTubePlaying(YouTubeTracker.isPlayingState(state.state))
    }

    private fun listenerComponent(context: Context) =
        ComponentName(context, KidFunNotificationListener::class.java)
}
