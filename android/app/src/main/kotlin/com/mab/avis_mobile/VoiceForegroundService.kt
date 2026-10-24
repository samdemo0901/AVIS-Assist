package com.mab.avis_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * AVIS AI Neural Voice Foreground Service
 *
 * Runs continuously in the background to grant AudioRecord background microphone access
 * under Android 9+, Android 10+ (API 29), and Android 14+ (API 34).
 * Declares FOREGROUND_SERVICE_TYPE_MICROPHONE & FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK.
 *
 * Provides actionable quick buttons in the persistent notification:
 * - Mute / Unmute microphone
 * - End Session cleanly
 * - Tap to resume app without reload
 */
class VoiceForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "avis_voice_channel"
        const val CHANNEL_NAME = "AVIS Neural Voice Service"
        const val NOTIFICATION_ID = 9001

        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_TOGGLE_MUTE = "ACTION_TOGGLE_MUTE"
        const val ACTION_END_SESSION = "ACTION_END_SESSION"
        const val ACTION_UPDATE_STATE = "ACTION_UPDATE_STATE"

        const val EXTRA_IS_MUTED = "EXTRA_IS_MUTED"

        fun startService(context: Context, isMuted: Boolean = false) {
            val intent = Intent(context, VoiceForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_IS_MUTED, isMuted)
            }
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, VoiceForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun updateState(context: Context, isMuted: Boolean) {
            val intent = Intent(context, VoiceForegroundService::class.java).apply {
                action = ACTION_UPDATE_STATE
                putExtra(EXTRA_IS_MUTED, isMuted)
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var isMuted = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AVIS:VoiceServiceWakeLock")
            wakeLock?.acquire(4 * 60 * 60 * 1000L) // 4 hours max
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        when (action) {
            ACTION_STOP -> {
                stopForegroundVoice()
                return START_NOT_STICKY
            }
            ACTION_TOGGLE_MUTE -> {
                MainActivity.instance?.toggleMuteFromNotification()
                return START_STICKY
            }
            ACTION_END_SESSION -> {
                MainActivity.instance?.endSessionFromNotification()
                stopForegroundVoice()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_STATE -> {
                isMuted = intent?.getBooleanExtra(EXTRA_IS_MUTED, isMuted) ?: isMuted
                updateNotification()
                return START_STICKY
            }
            ACTION_START -> {
                isMuted = intent?.getBooleanExtra(EXTRA_IS_MUTED, false) ?: false
                startForegroundWithNotification()
                return START_STICKY
            }
        }
        return START_STICKY
    }

    private fun startForegroundWithNotification() {
        createNotificationChannel()
        val notification = buildNotification()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                }
                startForeground(NOTIFICATION_ID, notification, type)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, buildNotification())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun buildNotification(): Notification {
        // Tap on notification: Reopen MainActivity smoothly without restarting
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action 1: Toggle Mute
        val muteIntent = Intent(this, VoiceForegroundService::class.java).apply {
            action = ACTION_TOGGLE_MUTE
        }
        val mutePendingIntent = PendingIntent.getService(
            this,
            1,
            muteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val muteActionTitle = if (isMuted) "Unmute Mic" else "Mute Mic"
        val muteActionIcon = if (isMuted) android.R.drawable.ic_lock_silent_mode_off else android.R.drawable.ic_btn_speak_now

        // Action 2: End Session
        val endIntent = Intent(this, VoiceForegroundService::class.java).apply {
            action = ACTION_END_SESSION
        }
        val endPendingIntent = PendingIntent.getService(
            this,
            2,
            endIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val endActionTitle = "End Session"
        val endActionIcon = android.R.drawable.ic_menu_close_clear_cancel

        val statusText = if (isMuted) "Microphone Muted // Tap Unmute to speak" else "Listening & Active in Background"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AVIS AI Assistant")
            .setContentText(statusText)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(muteActionIcon, muteActionTitle, mutePendingIntent)
            .addAction(endActionIcon, endActionTitle, endPendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "AVIS Neural Voice real-time audio communication"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun stopForegroundVoice() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            wakeLock = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopForegroundVoice()
        super.onDestroy()
    }
}
