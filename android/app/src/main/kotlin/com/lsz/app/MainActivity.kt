package com.lsz.app

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val USAGE_CHANNEL    = "com.lsz.app/usage_stats"
    private val DEVICE_CHANNEL  = "com.lsz.app/device_info"
    private val LIVE_CHANNEL    = "com.lsz.app/live_update"
    private val KEEPALIVE_CH    = "com.lsz.app/keepalive"
    private val WEATHER_CH      = "com.lsz.app/weather"
    private val ALARM_CH        = "com.lsz.app/pom_alarm"

    private var wakeLock: PowerManager.WakeLock? = null
    private var activeRingtone: android.media.Ringtone? = null
    private var noiseStreamThread: Thread? = null
    private var noiseEventSink: EventChannel.EventSink? = null
    private var _bgImageResult: io.flutter.plugin.common.MethodChannel.Result? = null
    private val REQ_BG_IMAGE = 0x3B6

    // Packages never shown to the user
    private val SYSTEM_BLACKLIST = setOf(
        "android", "com.android.systemui", "com.android.settings",
        "com.android.launcher", "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.miui.home", "com.huawei.android.launcher",
        "com.oppo.launcher", "com.bbk.launcher2", "com.vivo.launcher",
        "com.coloros.launcher", "com.oneplus.launcher", "com.realme.launcher",
        "com.android.inputmethod.latin",
        "com.google.android.inputmethod.latin",
        "com.baidu.input", "com.sogou.android.zhixin",
        "com.android.phone", "com.android.dialer",
        "com.android.packageinstaller", "com.google.android.gms",
        "com.google.android.gsf", "com.google.android.packageinstaller",
        "com.miui.securitycenter", "com.miui.systemAdSolution",
        "com.android.server.telecom"
    )

    // Default category assignments (package prefix → category)
    private val DEFAULT_CATEGORIES = mapOf(
        // ── 系统 / OEM (归 other，不计入娱乐) ─────────────────────────────
        "com.android.vending"                     to "other",
        "com.android.chrome"                      to "other",
        "com.coloros"                             to "other",
        "com.oplus"                               to "other",
        "com.heytap"                              to "other",
        "com.google.android.googlequicksearchbox" to "other",
        "com.microsoft.launcher"                  to "other",
        "com.teslacoilsw.launcher"                to "other",
        // ── 社交 IM / 论坛 ────────────────────────────────────────────────
        "com.tencent.mm"                          to "social",
        "com.tencent.mobileqq"                    to "social",
        "org.telegram.messenger"                  to "social",
        "tw.nekomimi.nekogram"                    to "social",
        "nekox.messenger"                         to "social",
        "top.qwq2333.nullgram"                    to "social",
        "com.discord"                             to "social",
        "jp.naver.line.android"                   to "social",
        "com.instagram.android"                   to "social",
        "com.twitter.android"                     to "social",
        "com.sina.weibo"                          to "social",
        "com.reddit.frontpage"                    to "social",
        "com.zhihu.android"                       to "social",
        "com.xingin.xhs"                          to "social",
        "gov.pianzong.androidnga"                 to "social",
        "org.moegirl.moegirlview"                 to "social",
        "net.afdian.afdian"                       to "social",
        "com.oneplus.bbs"                         to "social",
        "com.facebook.katana"                     to "social",
        "com.whatsapp"                            to "social",
        "com.linkedin.android"                    to "social",
        "com.snapchat.android"                    to "social",
        // ── 视频 ─────────────────────────────────────────────────────────
        "com.google.android.youtube"              to "video",
        "tv.danmaku.bili"                         to "video",
        "com.bilibili.app.in"                     to "video",
        "me.iacn.biliroaming"                     to "video",
        "com.netflix.mediaclient"                 to "video",
        "tv.twitch.android.app"                   to "video",
        "com.ss.android.ugc.aweme"                to "video",
        "com.ss.android.ugc.aweme.mobile"         to "video",
        "com.ss.android.ugc.livelite"             to "video",
        "tw.com.gamer.android.animad"             to "video",
        "com.kmplayer"                            to "video",
        "org.videolan.vlc"                        to "video",
        "com.mxtech.videoplayer.ad"               to "video",
        "dev.anilbeesetti.nextplayer"              to "video",
        "org.xbmc.kodi"                           to "video",
        "com.youku.phone"                         to "video",
        "com.iqiyi.video"                         to "video",
        "com.mgtv.tv"                             to "video",
        "com.tencent.qqlive"                      to "video",
        // ── 音乐 ─────────────────────────────────────────────────────────
        "com.apple.android.music"                 to "music",
        "com.google.android.apps.youtube.music"   to "music",
        "com.spotify.music"                       to "music",
        "io.stellio.music"                        to "music",
        "com.kugou.android"                       to "music",
        "com.netease.cloudmusic"                  to "music",
        "code.name.monkey.retromusic"             to "music",
        "com.cyanchill.missingcore.music"         to "music",
        "com.shanling.shanlingcontroller"         to "music",
        "com.tencent.qqmusic"                     to "music",
        "com.kuwo.player"                         to "music",
        // ── 游戏 ─────────────────────────────────────────────────────────
        "com.nexon.bluearchive"                   to "game",
        "com.tencent.tmgp"                        to "game",
        "com.miHoYo"                              to "game",
        "com.HoYoverse"                           to "game",
        "com.mihoyo.ys"                           to "game",
        "com.mihoyo.hyperion"                     to "game",
        "com.mihoyo.desktopportal"                to "game",
        "com.hypergryph.endfield"                 to "game",
        "com.hypergryph.skland"                   to "game",
        "com.PigeonGames.Phigros"                 to "game",
        "com.c4cat.dynamix"                       to "game",
        "com.leiting.RizlineHk.android"           to "game",
        "com.elpatrixf.OuO"                       to "game",
        "com.mojang.minecraftpe"                  to "game",
        "com.valvesoftware.android.steam"         to "game",
        "com.epicgames.portal"                    to "game",
        "com.taptap"                              to "game",
        "com.max.xiaoheihe"                       to "game",
        "com.gamersky"                            to "game",
        "com.miniclip.plagueinc"                  to "game",
        "com.pid.shotgunking"                     to "game",
        "com.megacrit.sts2"                       to "game",
        "com.humble.SlayTheSpire"                 to "game",
        "com.poncle.vampiresurvivors"             to "game",
        "com.playstack.balatro.android"           to "game",
        "com.RedNexusGamesInc.Peglin"             to "game",
        "org.ppsspp.ppsspp"                       to "game",
        "com.scee.psxandroid"                     to "game",
        "com.supercell"                           to "game",
        "com.riotgames"                           to "game",
        "com.netease.mc"                          to "game",
        "com.netease.lx"                          to "game",
        "com.ea.game"                             to "game",
        // ── 资讯 ─────────────────────────────────────────────────────────
        "com.ss.android.article.news"             to "news",
        "com.tencent.news"                        to "news",
        "com.netease.newsreader.activity"         to "news",
        "com.ifeng.news2"                         to "news",
        "flipboard.cn"                            to "news",
        // ── 购物 ─────────────────────────────────────────────────────────
        "com.taobao.taobao"                       to "shopping",
        "com.taobao.idlefish"                     to "shopping",
        "com.jingdong.app.mall"                   to "shopping",
        "com.amazon.mShop.android.shopping"       to "shopping",
        "com.shizhuang.duapp"                     to "shopping",
        "com.sankuai.meituan"                     to "shopping",
        "ctrip.android.view"                      to "shopping",
        "com.MobileTicket"                        to "shopping",
        "com.autonavi.minimap"                    to "shopping",
        "com.tongcheng.android"                   to "shopping",
        "com.cainiao.wireless"                    to "shopping",
        "com.eg.android.AlipayGphone"             to "shopping",
        "com.unionpay"                            to "shopping",
        "com.vmall.client"                        to "shopping",
        "com.xiaomi.shop"                         to "shopping",
        // ── 工作 / AI / 生产力 ───────────────────────────────────────────
        "com.openai.chatgpt"                      to "work",
        "com.deepseek.chat"                       to "work",
        "com.microsoft.copilot"                   to "work",
        "com.google.android.apps.bard"            to "work",
        "com.microsoft.office"                    to "work",
        "com.microsoft.skydrive"                  to "work",
        "com.microsoft.outlook"                   to "work",
        "com.tencent.wework"                      to "work",
        "com.tencent.wemeet.app"                  to "work",
        "com.baidu.netdisk"                       to "work",
        "com.resilio.sync"                        to "work",
        "md.obsidian"                             to "work",
        "net.cozic.joplin"                        to "work",
        "net.xmind.doughnut"                      to "work",
        "com.ticktick.task"                       to "work",
        "com.microsoft.todos"                     to "work",
        "com.github.android"                      to "work",
        "com.alibaba.android.rimet"               to "work",
        "com.autodesk.autocadws"                  to "work",
        "com.synology.dsdrive"                    to "work",
        // ── 自定义（教育学习类）──────────────────────────────────────────
        "com.maimemo.android.momo"                to "custom",
        "com.shanbay.kaoyan"                      to "custom",
        "com.shanbay.sentence"                    to "custom",
        "com.ichi2.anki"                          to "custom",
        "com.bilingify.readest"                   to "custom",
        "org.geogebra.android"                    to "custom",
        "com.mathworks.matlabmobile"              to "custom",
        "com.amazon.kindle"                       to "custom",
        "com.shazino.paperbot_mendeley"           to "custom",
        "ru.iiec.pydroid3"                        to "custom",
        "com.kvassyu.coding2"                     to "custom",
        "com.wjprogram.biologybasic"              to "custom",
        "org.mewx.wenku8"                         to "custom",
        "com.perol.play.pixez"                    to "custom",
        "jp.pxv.android"                          to "custom"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasUsagePermission())
                    "requestPermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getTodayUsage" -> {
                        if (!hasUsagePermission()) {
                            result.error("NO_PERM", "No usage stats permission", null)
                            return@setMethodCallHandler
                        }
                        @Suppress("UNCHECKED_CAST")
                        val userCategories = (call.argument<Map<*, *>>("userCategories")
                            ?: emptyMap<String, String>())
                            .entries.associate { (k, v) -> k.toString() to v.toString() }
                        result.success(getTodayAppUsage(userCategories))
                    }
                    "getInstalledApps" -> {
                        result.success(getInstalledUserApps())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> result.success(Build.MANUFACTURER.lowercase())
                    "getModel"        -> result.success(Build.MODEL)
                    "getBrand"        -> result.success(Build.BRAND.lowercase())
                    else -> result.notImplemented()
                }
            }

        // ── Live Update (灵动岛) Channel ─────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val secsLeft  = call.argument<Int>("secsLeft")  ?: 1500
                        val totalSecs = call.argument<Int>("totalSecs") ?: 1500
                        val phase     = call.argument<String>("phase")  ?: "focus"
                        val taskName  = call.argument<String>("taskName")
                        val cycle     = call.argument<Int>("cycle")     ?: 1
                        val running   = call.argument<Boolean>("running") ?: true
                        PomodoroLiveService.startOrUpdate(
                            this, secsLeft, totalSecs, phase, taskName, cycle, running)
                        result.success(null)
                    }
                    "dismiss" -> {
                        PomodoroLiveService.stop(this)
                        result.success(null)
                    }
                    "isSupported" -> {
                        // 告诉 Flutter 当前设备品牌，让 Dart 侧决定是否用 Native 服务
                        result.success(Build.BRAND.lowercase())
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 通知数据修复 + 原生通知 Channel ──────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lsz.app/notif_repair")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "clearScheduledData" -> {
                        try {
                            val prefs = getSharedPreferences(
                                "notification_plugin_cache", Context.MODE_PRIVATE)
                            prefs.edit().clear().apply()
                            val prefs2 = getSharedPreferences(
                                packageName + "_preferences", Context.MODE_PRIVATE)
                            prefs2.edit().remove("scheduled_notifications").apply()
                            android.util.Log.i("NotifRepair", "Cleared scheduled notification cache")
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.w("NotifRepair", "Clear failed: ${e.message}")
                            result.success(false)
                        }
                    }
                    // 原生直接发通知，完全绕过 flutter_local_notifications
                    "showNative" -> {
                        try {
                            val id    = call.argument<Int>("id")    ?: 0
                            val title = call.argument<String>("title") ?: ""
                            val body  = call.argument<String>("body")  ?: ""
                            showNativeNotification(id, title, body)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── WakeLock keepalive channel ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEPALIVE_CH)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        try {
                            if (wakeLock == null || wakeLock?.isHeld == false) {
                                val pm = getSystemService(POWER_SERVICE) as PowerManager
                                wakeLock = pm.newWakeLock(
                                    PowerManager.PARTIAL_WAKE_LOCK,
                                    "lsz:PomodoroWakeLock"
                                ).apply { acquire(90 * 60 * 1000L) } // max 90min
                            }
                            // Show heads-up (priority HIGH) focus notification
                            showFocusNotification(
                                call.argument<String>("title") ?: "🍅 专注中",
                                call.argument<String>("body")  ?: "番茄钟正在运行"
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.w("Keepalive", "WakeLock acquire failed: ${e.message}")
                            result.success(false)
                        }
                    }
                    "update" -> {
                        try {
                            showFocusNotification(
                                call.argument<String>("title") ?: "🍅 专注中",
                                call.argument<String>("body")  ?: "番茄钟正在运行"
                            )
                            result.success(true)
                        } catch (e: Exception) { result.success(false) }
                    }
                    "dismiss" -> {
                        try {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            nm.cancel(9001)
                            result.success(true)
                        } catch (e: Exception) { result.success(false) }
                    }
                    "release" -> {
                        try {
                            wakeLock?.let { if (it.isHeld) it.release() }
                            wakeLock = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // ── 天气 Channel（和风天气 QWeather，支持 JWT + API KEY）────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEATHER_CH)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "fetchWeather" -> {
                        // 和风天气 QWeather API v7
                        // 支持 JWT（Ed25519私钥签名）和 API Key 两种认证
                        val apiKey    = call.argument<String>("apiKey")    ?: ""
                        val city      = call.argument<String>("city")      ?: ""
                        val apiHost   = call.argument<String>("apiHost")   ?: ""
                        val jwtSecret = call.argument<String>("jwtSecret") ?: ""
                        val jwtKid    = call.argument<String>("jwtKid")    ?: ""
                        val jwtSub    = call.argument<String>("jwtSub")    ?: ""
                        if (city.isEmpty() || (apiKey.isEmpty() && jwtSecret.isEmpty())) {
                            result.success(null); return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                // ── JWT 生成（Ed25519，Java 15+ / Android 11+）──────────────
                                val bearerToken: String = if (jwtSecret.isNotEmpty() &&
                                        jwtKid.isNotEmpty() && jwtSub.isNotEmpty()) {
                                    val pkPem = jwtSecret
                                        .replace("-----BEGIN PRIVATE KEY-----", "")
                                        .replace("-----END PRIVATE KEY-----", "")
                                        .replace("\n", "").replace(" ", "").trim()
                                    val pkBytes = android.util.Base64.decode(pkPem, android.util.Base64.DEFAULT)
                                    val keySpec = java.security.spec.PKCS8EncodedKeySpec(pkBytes)
                                    val privateKey = java.security.KeyFactory
                                        .getInstance("EdDSA")
                                        .generatePrivate(keySpec)
                                    val iat = System.currentTimeMillis() / 1000 - 30
                                    val exp = iat + 900
                                    val headerJson = """{"alg":"EdDSA","kid":"$jwtKid"}"""
                                    val payloadJson = """{"sub":"$jwtSub","iat":$iat,"exp":$exp}"""
                                    val headerB64 = android.util.Base64.encodeToString(
                                        headerJson.toByteArray(), android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)
                                    val payloadB64 = android.util.Base64.encodeToString(
                                        payloadJson.toByteArray(), android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)
                                    val sigInput = "$headerB64.$payloadB64"
                                    val signer = java.security.Signature.getInstance("EdDSA")
                                    signer.initSign(privateKey)
                                    signer.update(sigInput.toByteArray(Charsets.UTF_8))
                                    val sigBytes = signer.sign()
                                    val sigB64 = android.util.Base64.encodeToString(
                                        sigBytes, android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)
                                    "$sigInput.$sigB64"
                                } else ""

                                // ── 辅助函数：添加认证头 ────────────────────────────────────
                                fun setAuth(conn: java.net.HttpURLConnection) {
                                    if (bearerToken.isNotEmpty())
                                        conn.setRequestProperty("Authorization", "Bearer $bearerToken")
                                    else
                                        conn.setRequestProperty("X-QW-Api-Key", apiKey)
                                    conn.setRequestProperty("Accept-Encoding", "gzip")
                                }
                                fun readConn(conn: java.net.HttpURLConnection): String {
                                    val stream = if (conn.contentEncoding == "gzip")
                                        java.util.zip.GZIPInputStream(conn.inputStream)
                                    else conn.inputStream
                                    return stream.bufferedReader().readText()
                                }

                                // ① GeoAPI：城市名 → LocationID
                                val weatherHost = apiHost.ifEmpty { "devapi.qweather.com" }
                                val geoConn = java.net.URL(
                                    "https://geoapi.qweather.com/v2/city/lookup" +
                                    "?location=" + java.net.URLEncoder.encode(city, "UTF-8") +
                                    "&number=1&lang=zh").openConnection() as java.net.HttpURLConnection
                                geoConn.connectTimeout = 8000; geoConn.readTimeout = 8000
                                setAuth(geoConn)
                                val geoResp = readConn(geoConn)
                                geoConn.disconnect()
                                val locationId = Regex(""""id":"([^"]+)"""").find(geoResp)
                                    ?.groupValues?.getOrNull(1) ?: ""
                                val loc = locationId.ifEmpty {
                                    java.net.URLEncoder.encode(city, "UTF-8") }

                                // ② 实况天气
                                val wxConn = java.net.URL(
                                    "https://$weatherHost/v7/weather/now?location=$loc")
                                    .openConnection() as java.net.HttpURLConnection
                                wxConn.connectTimeout = 8000; wxConn.readTimeout = 8000
                                setAuth(wxConn)
                                val wxResp = readConn(wxConn)
                                wxConn.disconnect()

                                // ③ 解析
                                val iconCode = Regex(""""icon":"(\d+)"""").find(wxResp)
                                    ?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 100
                                val temp = Regex(""""temp":"([-\d.]+)"""").find(wxResp)
                                    ?.groupValues?.getOrNull(1)?.toDoubleOrNull() ?: 20.0
                                val text = Regex(""""text":"([^"]+)"""").find(wxResp)
                                    ?.groupValues?.getOrNull(1) ?: ""

                                android.os.Handler(mainLooper).post {
                                    result.success(mapOf(
                                        "iconCode" to iconCode, "temp" to temp, "desc" to text))
                                }
                            } catch (e: Exception) {
                                android.os.Handler(mainLooper).post { result.success(null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
        // ── 音频噪音测量 MethodChannel ────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lsz.app/audio_noise")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "measureDb" -> {
                        // Quick single 1.5s snapshot (pomodoro background sampling)
                        Thread {
                            try {
                                val recorder = android.media.MediaRecorder()
                                recorder.setAudioSource(android.media.MediaRecorder.AudioSource.MIC)
                                recorder.setOutputFormat(android.media.MediaRecorder.OutputFormat.THREE_GPP)
                                recorder.setAudioEncoder(android.media.MediaRecorder.AudioEncoder.AMR_NB)
                                val tmpFile = java.io.File(cacheDir, "lsz_noise_tmp.3gp")
                                recorder.setOutputFile(tmpFile.absolutePath)
                                recorder.prepare()
                                recorder.start()
                                Thread.sleep(1500)
                                val amplitude = recorder.maxAmplitude.toDouble()
                                recorder.stop()
                                recorder.release()
                                tmpFile.delete()
                                val db = if (amplitude > 0)
                                    20.0 * Math.log10(amplitude / 32768.0) + 90.0
                                else 30.0
                                android.os.Handler(mainLooper).post {
                                    result.success(db.coerceIn(20.0, 100.0))
                                }
                            } catch (e: Exception) {
                                android.os.Handler(mainLooper).post { result.success(null) }
                            }
                        }.start()
                    }
                    "stopMeasure" -> {
                        noiseStreamThread?.interrupt()
                        noiseStreamThread = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 音频噪音实时流 EventChannel ────────────────────────────────────
        // Flutter 侧订阅后，原生每秒推送一个 Double dB 读数，共30次后结束
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lsz.app/audio_noise_stream")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    noiseEventSink = events
                    noiseStreamThread?.interrupt()
                    noiseStreamThread = Thread {
                        var recorder: android.media.MediaRecorder? = null
                        try {
                            recorder = android.media.MediaRecorder()
                            recorder.setAudioSource(android.media.MediaRecorder.AudioSource.MIC)
                            recorder.setOutputFormat(android.media.MediaRecorder.OutputFormat.THREE_GPP)
                            recorder.setAudioEncoder(android.media.MediaRecorder.AudioEncoder.AMR_NB)
                            val tmpFile = java.io.File(cacheDir, "lsz_noise_stream.3gp")
                            recorder.setOutputFile(tmpFile.absolutePath)
                            recorder.prepare()
                            recorder.start()
                            var count = 0
                            while (count < 30 && !Thread.currentThread().isInterrupted) {
                                Thread.sleep(1000)
                                val amp = recorder.maxAmplitude.toDouble()
                                val db = if (amp > 0)
                                    (20.0 * Math.log10(amp / 32768.0) + 90.0).coerceIn(20.0, 100.0)
                                else 30.0
                                count++
                                android.os.Handler(mainLooper).post {
                                    noiseEventSink?.success(db)
                                }
                            }
                            recorder.stop()
                            recorder.release()
                            tmpFile.delete()
                        } catch (e: InterruptedException) {
                            try { recorder?.stop() } catch (_: Exception) {}
                            recorder?.release()
                        } catch (e: Exception) {
                            android.util.Log.w("AudioNoise", "stream error: ${e.message}")
                            android.os.Handler(mainLooper).post {
                                noiseEventSink?.endOfStream()
                            }
                            return@Thread
                        }
                        android.os.Handler(mainLooper).post {
                            noiseEventSink?.endOfStream()
                        }
                    }
                    noiseStreamThread!!.start()
                }

                override fun onCancel(arguments: Any?) {
                    noiseStreamThread?.interrupt()
                    noiseStreamThread = null
                    noiseEventSink = null
                }
            })


        // ── 分享 Channel ──────────────────────────────────────────────────────
        // ── 背景图片选择 Channel ──────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lsz.app/bg_image")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> {
                        _bgImageResult = result
                        val intent = Intent(Intent.ACTION_PICK,
                            android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                        intent.type = "image/*"
                        startActivityForResult(intent, REQ_BG_IMAGE)
                    }
                    "clearImage" -> {
                        val f = java.io.File(filesDir, "lsz_custom_bg.jpg")
                        if (f.exists()) f.delete()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lsz.app/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text    = call.argument<String>("text") ?: ""
                        val subject = call.argument<String>("subject") ?: ""
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            if (subject.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
                        }
                        startActivity(Intent.createChooser(intent, "分享报告"))
                        result.success(true)
                    }
                    "shareFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        val mime = call.argument<String>("mime") ?: "image/png"
                        try {
                            val file = java.io.File(path)
                            val uri = androidx.core.content.FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = mime
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "分享"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // ── 前台应用检测 Channel (bilibili/娱乐 专注干扰检测) ─────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lsz.app/foreground_app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentApp" -> {
                        try {
                            if (!hasUsagePermission()) {
                                result.success(null); return@setMethodCallHandler
                            }
                            val usm = getSystemService(Context.USAGE_STATS_SERVICE)
                                    as UsageStatsManager
                            val now = System.currentTimeMillis()
                            val stats = usm.queryUsageStats(
                                UsageStatsManager.INTERVAL_DAILY, now - 5000, now)
                            val top = stats.maxByOrNull { it.lastTimeUsed }
                            result.success(top?.packageName)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    "isDistractionApp" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        val distractionPkgs = setOf(
                            "tv.danmaku.bili", "com.bilibili.app.in",
                            "com.ss.android.ugc.aweme",  // 抖音
                            "com.zhiliaoapp.musically",   // TikTok
                            "com.tencent.weishi",          // 微视
                            "com.kuaishou.nebula",         // 快手
                            "com.smile.gifmaker",          // 快手极速版
                            "com.sina.weibo",
                            "com.xiaohongshu.android",     // 小红书
                            "tv.danmaku.bilibilihd",
                        )
                        result.success(distractionPkgs.contains(pkg))
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 番茄钟闹钟 Channel（声音 + 震动 + 亮屏 + 全屏唤醒）────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CH)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ring" -> {
                        val playSound = call.argument<Boolean>("sound") ?: true
                        val doVibrate = call.argument<Boolean>("vibrate") ?: true
                        try {
                            // 1. 将 App 置于最前台
                            val am2 = getSystemService(Context.ACTIVITY_SERVICE)
                                    as android.app.ActivityManager
                            am2.moveTaskToFront(taskId, 0)

                            // 2. 点亮屏幕 / 解锁 keyguard
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                                setShowWhenLocked(true)
                                setTurnScreenOn(true)
                            } else {
                                @Suppress("DEPRECATION")
                                window.addFlags(
                                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                                )
                            }
                            // WakeLock 持续到用户关闭通知（最长 10min 保底）
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            val wl = pm.newWakeLock(
                                PowerManager.FULL_WAKE_LOCK or
                                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                                PowerManager.ON_AFTER_RELEASE,
                                "lsz:PomAlarmWake"
                            )
                            wl.acquire(600_000L)

                            // 3. 持续播放系统闹钟铃声（循环，直到 stop 调用）
                            if (playSound) {
                                try {
                                    val alarmUri = RingtoneManager.getDefaultUri(
                                        RingtoneManager.TYPE_ALARM
                                    ) ?: RingtoneManager.getDefaultUri(
                                        RingtoneManager.TYPE_NOTIFICATION
                                    )
                                    activeRingtone = RingtoneManager.getRingtone(
                                        applicationContext, alarmUri
                                    )
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                        activeRingtone?.isLooping = true
                                    }
                                    val audioMgr = getSystemService(Context.AUDIO_SERVICE)
                                            as AudioManager
                                    if (audioMgr.ringerMode != AudioManager.RINGER_MODE_SILENT) {
                                        activeRingtone?.play()
                                    }
                                } catch (e: Exception) {
                                    android.util.Log.w("PomAlarm", "sound failed: ${e.message}")
                                }
                            }

                            // 4. 持续震动（循环直到 stop 调用，repeat=0）
                            if (doVibrate) {
                                try {
                                    val pattern = longArrayOf(0, 500, 300, 500, 300, 800, 500)
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                        val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                                            as VibratorManager
                                        vm.defaultVibrator.vibrate(
                                            VibrationEffect.createWaveform(pattern, 0)
                                        )
                                    } else {
                                        @Suppress("DEPRECATION")
                                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE)
                                            as Vibrator
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                            vibrator.vibrate(
                                                VibrationEffect.createWaveform(pattern, 0)
                                            )
                                        } else {
                                            @Suppress("DEPRECATION")
                                            vibrator.vibrate(pattern, 0)
                                        }
                                    }
                                } catch (e: Exception) {
                                    android.util.Log.w("PomAlarm", "vibrate failed: ${e.message}")
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.w("PomAlarm", "ring failed: ${e.message}")
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        try {
                            // 停止铃声
                            try { activeRingtone?.stop(); activeRingtone = null } catch (_: Exception) {}
                            // 停止震动
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                                        as VibratorManager
                                    vm.defaultVibrator.cancel()
                                } else {
                                    @Suppress("DEPRECATION")
                                    (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
                                }
                            } catch (_: Exception) {}
                            // 清除屏幕常亮 flag
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                                setShowWhenLocked(false)
                                setTurnScreenOn(false)
                            } else {
                                @Suppress("DEPRECATION")
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun showNativeNotification(id: Int, title: String, body: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "lsz_daily_native"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(channelId, "每日任务提醒",
                NotificationManager.IMPORTANCE_DEFAULT).apply {
                setSound(null, null)
                enableVibration(false)
            }
            nm.createNotificationChannel(ch)
        }
        val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setAutoCancel(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setAutoCancel(true)
                .build()
        }
        nm.notify(id, notif)
    }

    private fun showFocusNotification(title: String, body: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "lsz_focus_headsup"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // IMPORTANCE_HIGH = heads-up floating notification
            val ch = NotificationChannel(channelId, "专注计时",
                NotificationManager.IMPORTANCE_HIGH).apply {
                description = "番茄钟专注进度（置顶悬浮）"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(ch)
        }
        val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)          // 置顶，不可滑除
                .setOnlyAlertOnce(true)    // 更新时不重复提示
                .setPriority(Notification.PRIORITY_HIGH)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_HIGH)
                .build()
        }
        nm.notify(9001, notif)
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /// Return list of installed user-facing apps for the category picker.
    private fun getInstalledUserApps(): List<Map<String, String>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, String>>()

        // Query all apps that have a MAIN/LAUNCHER intent — works on all Android versions
        val launcherIntent = Intent(Intent.ACTION_MAIN).also {
            it.addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PackageManager.MATCH_ALL else 0
        val activities = pm.queryIntentActivities(launcherIntent, resolveFlags)

        val seen = mutableSetOf<String>()
        for (ri in activities) {
            val pkg = ri.activityInfo.packageName
            if (!seen.add(pkg)) continue      // deduplicate
            if (pkg == packageName) continue  // skip self
            if (SYSTEM_BLACKLIST.contains(pkg)) continue

            val label = try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (_: Exception) { pkg }

            val defCat = DEFAULT_CATEGORIES.entries
                .firstOrNull { (k, _) -> pkg.startsWith(k) }?.value ?: "other"

            apps.add(mapOf("package" to pkg, "label" to label, "defaultCategory" to defCat))
        }

        apps.sortBy { it["label"] }
        return apps
    }

    private fun getTodayAppUsage(userCategories: Map<String, String>): Map<String, Any> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY,
            cal.timeInMillis, System.currentTimeMillis())

        val appMap = mutableListOf<Map<String, Any>>()
        val totals = mutableMapOf("social" to 0L, "video" to 0L, "game" to 0L,
            "music" to 0L, "news" to 0L, "shopping" to 0L,
            "custom" to 0L, "work" to 0L, "other" to 0L)

        for (stat in stats) {
            val ms  = stat.totalTimeInForeground
            if (ms < 5_000L) continue
            val pkg = stat.packageName
            if (pkg == packageName) continue
            if (SYSTEM_BLACKLIST.contains(pkg)) continue
            if (pkg.startsWith("com.android.") || pkg.startsWith("com.google.android.") &&
                !listOf("youtube","gmail","maps","chrome","docs","photos").any { pkg.contains(it) }) continue

            // User override takes priority, then defaults, then "other"
            val category = userCategories[pkg]
                ?: DEFAULT_CATEGORIES.entries.firstOrNull { (k, _) -> pkg.startsWith(k) }?.value
                ?: "other"

            appMap.add(mapOf("package" to pkg, "ms" to ms, "type" to category))
            totals[category] = (totals[category] ?: 0L) + ms
        }

        appMap.sortByDescending { it["ms"] as Long }

        val entertainment = (totals["social"] ?: 0L) + (totals["video"] ?: 0L) +
                            (totals["game"] ?: 0L) + (totals["music"] ?: 0L) +
                            (totals["news"] ?: 0L) + (totals["shopping"] ?: 0L) +
                            (totals["custom"] ?: 0L)

        return mapOf(
            "apps"              to appMap.take(20),
            "totalSocialMs"     to (totals["social"]   ?: 0L),
            "totalVideoMs"      to (totals["video"]    ?: 0L),
            "totalGameMs"       to (totals["game"]     ?: 0L),
            "totalMusicMs"      to (totals["music"]    ?: 0L),
            "totalNewsMs"       to (totals["news"]     ?: 0L),
            "totalShoppingMs"   to (totals["shopping"] ?: 0L),
            "totalCustomMs"     to (totals["custom"]   ?: 0L),
            "totalWorkMs"       to (totals["work"]     ?: 0L),
            "totalOtherMs"      to (totals["other"]    ?: 0L),
            "totalEntertainMs"  to entertainment
        )
    }
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_BG_IMAGE) {
            val result = _bgImageResult
            _bgImageResult = null
            if (resultCode == android.app.Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    val input = contentResolver.openInputStream(uri)
                    val dest = java.io.File(filesDir, "lsz_custom_bg.jpg")
                    input?.use { ins -> dest.outputStream().use { out -> ins.copyTo(out) } }
                    android.os.Handler(mainLooper).post {
                        result?.success(dest.absolutePath)
                    }
                } catch (e: Exception) {
                    android.os.Handler(mainLooper).post {
                        result?.error("PICK_ERROR", e.message, null)
                    }
                }
            } else {
                android.os.Handler(mainLooper).post { result?.success(null) }
            }
        }
    }

}
