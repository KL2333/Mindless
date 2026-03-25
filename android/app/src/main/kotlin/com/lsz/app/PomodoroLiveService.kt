package com.lsz.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * PomodoroLiveService — ForegroundService，每秒更新通知内容。
 *
 * ── 为什么用 ForegroundService 而不是 flutter_local_notifications？──────────
 * ColorOS 的"流体云/灵动岛"（Live Update）要求通知满足：
 *   1. 通知类型必须是 FOREGROUND_SERVICE（前台服务通知）
 *   2. Channel importance = IMPORTANCE_HIGH
 *   3. 使用 DecoratedCustomViewStyle（自定义 RemoteViews）
 *   4. 通知必须 ongoing = true，且绑定到一个真正运行的前台服务
 *   5. setCustomContentView + setCustomBigContentView 提供胶囊/展开两套布局
 *
 * flutter_local_notifications 无法满足第 1、3、4 条，所以必须原生实现。
 * ─────────────────────────────────────────────────────────────────────────────
 */
class PomodoroLiveService : Service() {

    companion object {
        const val CHANNEL_ID   = "lsz_live_update"
        const val CHANNEL_NAME = "番茄钟 · 灵动岛"
        const val NOTIF_ID     = 9001

        const val ACTION_START         = "com.lsz.app.ACTION_POM_START"
        const val ACTION_UPDATE        = "com.lsz.app.ACTION_POM_UPDATE"
        const val ACTION_STOP          = "com.lsz.app.ACTION_POM_STOP"
        const val ACTION_PAUSE_RESUME  = "com.lsz.app.ACTION_POM_PAUSE_RESUME"

        const val EXTRA_SECS_LEFT  = "secs_left"
        const val EXTRA_TOTAL_SECS = "total_secs"
        const val EXTRA_PHASE      = "phase"       // "focus" | "short_break" | "long_break"
        const val EXTRA_TASK_NAME  = "task_name"
        const val EXTRA_CYCLE      = "cycle"
        const val EXTRA_RUNNING    = "running"

        /** 从 Flutter 侧启动/更新灵动岛 */
        fun startOrUpdate(context: Context, secsLeft: Int, totalSecs: Int,
                          phase: String, taskName: String?, cycle: Int, running: Boolean) {
            val intent = Intent(context, PomodoroLiveService::class.java).apply {
                action = if (isRunning) ACTION_UPDATE else ACTION_START
                putExtra(EXTRA_SECS_LEFT,  secsLeft)
                putExtra(EXTRA_TOTAL_SECS, totalSecs)
                putExtra(EXTRA_PHASE,      phase)
                putExtra(EXTRA_TASK_NAME,  taskName ?: "")
                putExtra(EXTRA_CYCLE,      cycle)
                putExtra(EXTRA_RUNNING,    running)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Android 14+ ForegroundServiceStartNotAllowedException:
                // 后台启动受限时静默忽略，番茄钟计时不受影响
                android.util.Log.w("PomodoroLive", "startForegroundService failed: ${e.message}")
            }
        }

        /** 停止并撤销通知 */
        fun stop(context: Context) {
            context.stopService(Intent(context, PomodoroLiveService::class.java))
        }

        var isRunning = false
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private var tickRunnable: Runnable? = null

    // 当前状态（每次 UPDATE intent 刷新）
    private var secsLeft  = 0
    private var totalSecs = 0
    private var phase     = "focus"
    private var taskName  = ""
    private var cycle     = 1
    private var running   = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createChannel()
        // 启动时立即 startForeground 占位，避免 ANR
        startForeground(NOTIF_ID, buildPlaceholderNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START, ACTION_UPDATE -> {
                secsLeft  = intent.getIntExtra(EXTRA_SECS_LEFT,  1500)
                totalSecs = intent.getIntExtra(EXTRA_TOTAL_SECS, 1500)
                phase     = intent.getStringExtra(EXTRA_PHASE)    ?: "focus"
                taskName  = intent.getStringExtra(EXTRA_TASK_NAME) ?: ""
                cycle     = intent.getIntExtra(EXTRA_CYCLE, 1)
                running   = intent.getBooleanExtra(EXTRA_RUNNING, true)
                pushNotification()
                scheduleNextTick()
            }
            ACTION_PAUSE_RESUME -> {
                running = !running
                pushNotification()
                if (running) scheduleNextTick() else cancelTick()
            }
            ACTION_STOP -> stopSelf()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        cancelTick()
        NotificationManagerCompat.from(this).cancel(NOTIF_ID)
        super.onDestroy()
    }

    // ─── 每秒 tick（服务自驱动，Flutter 侧也会定期 UPDATE） ────────────────────
    private fun scheduleNextTick() {
        cancelTick()
        if (!running) return
        tickRunnable = Runnable {
            if (secsLeft > 0) {
                secsLeft--
                pushNotification()
                scheduleNextTick()
            }
        }
        handler.postDelayed(tickRunnable!!, 1000L)
    }

    private fun cancelTick() {
        tickRunnable?.let { handler.removeCallbacks(it) }
        tickRunnable = null
    }

    // ─── 构建并推送通知 ────────────────────────────────────────────────────────
    private fun pushNotification() {
        NotificationManagerCompat.from(this).notify(NOTIF_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val m = secsLeft / 60
        val s = secsLeft % 60
        val timeStr = "%02d:%02d".format(m, s)

        val phaseLabel = when (phase) {
            "focus"      -> "🍅 专注"
            "long_break" -> "🛋 长休息"
            else         -> "☕ 短休息"
        }

        // ── RemoteViews ────────────────────────────────────────────
        val compactView = RemoteViews(packageName, R.layout.notif_island_compact).apply {
            setTextViewText(R.id.island_phase, phaseLabel)
            setTextViewText(R.id.island_time,  timeStr)
        }

        val expandedView = RemoteViews(packageName, R.layout.notif_island_expanded).apply {
            setTextViewText(R.id.expand_phase, phaseLabel)
            setTextViewText(R.id.expand_time,  timeStr)
            setTextViewText(R.id.expand_task,
                if (taskName.isNotEmpty()) "📌 $taskName" else "暂无绑定任务")
            setTextViewText(R.id.expand_cycle, "第 $cycle 轮")
            val progress = if (totalSecs > 0) ((totalSecs - secsLeft) * 100 / totalSecs) else 0
            setProgressBar(R.id.expand_progress, 100, progress, false)

            // 暂停/恢复按钮
            val pauseIntent = PendingIntent.getService(
                this@PomodoroLiveService, 0,
                Intent(this@PomodoroLiveService, PomodoroLiveService::class.java)
                    .setAction(ACTION_PAUSE_RESUME),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            setOnClickPendingIntent(R.id.btn_pause_resume, pauseIntent)
            setTextViewText(R.id.btn_pause_resume, if (running) "暂停" else "继续")

            // 结束按钮
            val stopIntent = PendingIntent.getService(
                this@PomodoroLiveService, 1,
                Intent(this@PomodoroLiveService, PomodoroLiveService::class.java)
                    .setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            setOnClickPendingIntent(R.id.btn_stop, stopIntent)
        }

        // ── 点击通知打开 App ───────────────────────────────────────
        val openIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── 构建 Notification ─────────────────────────────────────
        // DecoratedCustomViewStyle 是 ColorOS 流体云/灵动岛的关键：
        //   - 使用系统装饰框（带 App 图标、应用名）
        //   - setCustomContentView → 胶囊收起态
        //   - setCustomBigContentView → 展开卡片态
        // ColorOS 12+ 会将 importance=HIGH + ongoing + DecoratedCustomViewStyle
        // 的前台服务通知提升为"流体云"胶囊显示在刘海/打孔屏旁。
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(openIntent)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(compactView)
            .setCustomBigContentView(expandedView)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            // ticker 文字在极度精简模式下显示（某些定制 ROM）
            .setTicker("$phaseLabel $timeStr")
            // ColorOS 用 color 来染色流体云胶囊边框
            .setColor(if (phase == "focus") 0xFFE07040.toInt() else 0xFF4A90C0.toInt())
            .setColorized(true)
            .build()
    }

    private fun buildPlaceholderNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("番茄钟启动中…")
            .setOngoing(true)
            .setSilent(true)
            .build()

    // ─── Channel ──────────────────────────────────────────────────────────────
    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH  // ← ColorOS 要求 HIGH 才上岛
            ).apply {
                description = "番茄钟专注计时 · ColorOS 流体云"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                // lockscreenVisibility PUBLIC：锁屏也显示完整内容
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }
}
