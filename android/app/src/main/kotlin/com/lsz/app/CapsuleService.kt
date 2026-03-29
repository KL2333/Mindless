package com.lsz.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.annotation.RequiresApi
import kotlin.math.roundToInt

class CapsuleService : Service() {

    companion object {
        const val ACTION_SHOW = "show"
        const val ACTION_UPDATE = "update"
        const val ACTION_DISMISS = "dismiss"
        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_PROGRESS = "progress"

        fun show(context: Context, title: String, subtitle: String, progress: Float) {
            val intent = Intent(context, CapsuleService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_SUBTITLE, subtitle)
                putExtra(EXTRA_PROGRESS, progress)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, subtitle: String, progress: Float) {
            val intent = Intent(context, CapsuleService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_SUBTITLE, subtitle)
                putExtra(EXTRA_PROGRESS, progress)
            }
            context.startService(intent)
        }

        fun dismiss(context: Context) {
            context.stopService(Intent(context, CapsuleService::class.java))
        }
    }

    private val notifId = 9527
    private val channelId = "live_capsule_channel"

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "实时胶囊", NotificationManager.IMPORTANCE_DEFAULT
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: ""
                val subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: ""
                val progress = intent.getFloatExtra(EXTRA_PROGRESS, 0f)
                startForeground(notifId, buildNotification(title, subtitle, progress))
            }
            ACTION_UPDATE -> {
                val subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: ""
                val progress = intent.getFloatExtra(EXTRA_PROGRESS, 0f)
                if (Build.VERSION.SDK_INT >= 36) {
                    getSystemService(NotificationManager::class.java)
                        .notify(notifId, buildNotification("专注计时", subtitle, progress))
                }
            }
            ACTION_DISMISS -> stopSelf()
        }
        return START_NOT_STICKY
    }

    @RequiresApi(36)
    private fun buildNotification(title: String, subtitle: String, progress: Float): Notification {
        val style = Notification.ProgressStyle()
        style.progress = (progress.coerceIn(0f, 1f) * 100f).roundToInt()

        return Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setRequestPromotedOngoing(true)
            .setStyle(style)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        getSystemService(NotificationManager::class.java).cancel(notifId)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

private fun Notification.Builder.setRequestPromotedOngoing(request: Boolean): Notification.Builder {
    try {
        val m = this::class.java.getMethod(
            "setRequestPromotedOngoing",
            Boolean::class.javaPrimitiveType
        )
        m.invoke(this, request)
    } catch (_: Exception) {
    }
    return this
}

