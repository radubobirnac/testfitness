package com.radubobirnac.testfitness

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.pm.ServiceInfo
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.text.format.DateFormat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlin.math.max
import java.util.Date
import java.util.concurrent.TimeUnit

class RestTimerForegroundService : Service() {
    companion object {
        private const val ACTION_START = "com.testfitness.timer.START"
        private const val ACTION_UPDATE = "com.testfitness.timer.UPDATE"
        private const val ACTION_STOP = "com.testfitness.timer.STOP"

        private const val EXTRA_END_EPOCH_MS = "endEpochMs"
        private const val EXTRA_TOTAL_MS = "totalDurationMs"
        private const val EXTRA_REMAINING_MS = "remainingMs"

        private const val CHANNEL_ID = "timer_service_channel_id"
        private const val CHANNEL_NAME = "Timer Service"
        private const val CHANNEL_DESCRIPTION = "Foreground service for active rest timer"
        private const val NOTIFICATION_ID = 2301

        @Volatile
        private var running = false

        fun isRunning(): Boolean = running

        fun start(
            context: Context,
            endEpochMs: Long,
            totalDurationMs: Long,
            remainingMs: Long
        ) {
            val intent = Intent(context, RestTimerForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_END_EPOCH_MS, endEpochMs)
                putExtra(EXTRA_TOTAL_MS, totalDurationMs)
                putExtra(EXTRA_REMAINING_MS, remainingMs)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(
            context: Context,
            endEpochMs: Long,
            totalDurationMs: Long,
            remainingMs: Long
        ) {
            val intent = Intent(context, RestTimerForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_END_EPOCH_MS, endEpochMs)
                putExtra(EXTRA_TOTAL_MS, totalDurationMs)
                putExtra(EXTRA_REMAINING_MS, remainingMs)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, RestTimerForegroundService::class.java)
            context.stopService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopServiceInternal()
                return START_NOT_STICKY
            }
            ACTION_START, ACTION_UPDATE, null -> {
                val endEpochMs = intent?.getLongExtra(EXTRA_END_EPOCH_MS, 0L) ?: 0L
                val totalDurationMs = intent?.getLongExtra(EXTRA_TOTAL_MS, 0L) ?: 0L
                val remainingMs = intent?.getLongExtra(EXTRA_REMAINING_MS, 0L) ?: 0L
                startOrUpdate(endEpochMs, totalDurationMs, remainingMs)
                return START_NOT_STICKY
            }
            else -> return START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        running = false
        stopForegroundCompat()
        super.onDestroy()
    }

    private fun startOrUpdate(endEpochMs: Long, totalDurationMs: Long, remainingMs: Long) {
        createChannelIfNeeded()
        val notification = buildNotification(endEpochMs, totalDurationMs, remainingMs)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!running) {
            startForegroundCompat(notification)
            running = true
        } else {
            manager.notify(NOTIFICATION_ID, notification)
        }
    }

    private fun stopServiceInternal() {
        running = false
        stopForegroundCompat()
        stopSelf()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        )
        channel.description = CHANNEL_DESCRIPTION
        channel.setSound(null, null)
        channel.enableVibration(false)
        channel.enableLights(false)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(
        endEpochMs: Long,
        totalDurationMs: Long,
        remainingMs: Long
    ): Notification {
        val title = "Rest timer running"
        val remainingText = if (remainingMs > 0L) {
            "Remaining ${formatRemaining(remainingMs)}"
        } else if (endEpochMs > 0L) {
            "Ends at ${formatTime(endEpochMs)}"
        } else {
            "Rest timer in progress"
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            pendingIntentFlags()
        )

        val progressMax = if (totalDurationMs > 0L) totalDurationMs else 1L
        val progressValue = max(0L, totalDurationMs - remainingMs)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(remainingText)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setProgress(progressMax.toInt(), progressValue.toInt(), false)
            .build()
    }

    private fun pendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun formatRemaining(remainingMs: Long): String {
        val totalSeconds = max(0L, TimeUnit.MILLISECONDS.toSeconds(remainingMs))
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%d:%02d", minutes, seconds)
    }

    private fun formatTime(epochMs: Long): String {
        val formatter = DateFormat.getTimeFormat(this)
        return formatter.format(Date(epochMs))
    }
}
