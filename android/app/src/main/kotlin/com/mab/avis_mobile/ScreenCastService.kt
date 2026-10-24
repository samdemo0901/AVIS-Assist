package com.mab.avis_mobile

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * AVIS AI Vision Foreground Service for Screen Projection
 * Required by Android 10+ (API 29) & Android 14+ (API 34) for MediaProjection.
 * Ensures the foreground service with FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
 * is actively running BEFORE getMediaProjection is invoked.
 */
class ScreenCastService : Service() {

    companion object {
        const val CHANNEL_ID = "avis_screencast_channel"
        const val NOTIFICATION_ID = 2002
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val EXTRA_RESULT_CODE = "EXTRA_RESULT_CODE"
        const val EXTRA_RESULT_DATA = "EXTRA_RESULT_DATA"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        if (action == ACTION_STOP) {
            stopForegroundService()
            return START_NOT_STICKY
        }

        createNotificationChannel()
        val notification = createNotification()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            MainActivity.instance?.onProjectionError("SERVICE_START_FAILED", "Failed to start screen projection foreground service: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED) ?: Activity.RESULT_CANCELED
        val resultData: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra(EXTRA_RESULT_DATA)
        }

        if (resultCode == Activity.RESULT_OK && resultData != null) {
            try {
                val mpManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                val projection = mpManager.getMediaProjection(resultCode, resultData)
                if (projection != null) {
                    MainActivity.instance?.startScreenProjectionWithMediaProjection(projection)
                } else {
                    MainActivity.instance?.onProjectionError("PROJECTION_NULL", "MediaProjection was null")
                    stopForegroundService()
                }
            } catch (e: Exception) {
                e.printStackTrace()
                MainActivity.instance?.onProjectionError("CAPTURE_INIT_FAILED", "Screen capture failed: ${e.message}")
                stopForegroundService()
            }
        }

        return START_STICKY
    }

    private fun stopForegroundService() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AVIS AI Vision Screen Share",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active MediaProjection Screen Share notification for AVIS AI Vision"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AVIS AI Vision — Live Screen Share")
            .setContentText("AVIS is viewing your screen in real time")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
