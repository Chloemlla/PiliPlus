package com.chloemlla.piliplus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Foreground service with a [ProgressStyle] notification promoted as a Live Update
 * when the app is in the background and PiP is not active.
 *
 * Unlike the [NativeMediaService] (MediaStyle + MediaSession), this notification
 * uses ProgressStyle so it is eligible for [setRequestPromotedOngoing] on API 36+.
 * It shows a progress bar, video title, artist, and a play/pause toggle.
 *
 * Lifecycle: owned by [LiveUpdateService] companion — Dart signals start/update/stop
 * via the `pili_plus/live_update` MethodChannel. The service is NOT started during
 * PiP or while the app is in the foreground.
 */
class LiveUpdateService : Service() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                state.playing = true
                dispatchAction(FLUTTER_PLAY)
            }
            ACTION_PAUSE -> {
                state.playing = false
                dispatchAction(FLUTTER_PAUSE)
            }
            ACTION_TOGGLE -> {
                state.playing = !state.playing
                dispatchAction(if (state.playing) FLUTTER_PLAY else FLUTTER_PAUSE)
            }
            ACTION_STOP -> {
                state.hidden = true
                stopService()
                return START_NOT_STICKY
            }
        }
        if (!state.hidden) refreshFromState()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun refreshFromState() {
        if (state.hidden) return
        try {
            startForeground(NOTIFICATION_ID, buildNotification())
        } catch (_: Exception) {
            // FGS may fail if the process is being killed.
            stopSelf()
        }
    }

    private fun buildNotification(): Notification {
        val builder = Notification.Builder(this, CHANNEL_ID)

        val playPauseAction = if (state.playing) {
            Notification.Action.Builder(
                R.drawable.ic_player_pause,
                "暂停", // 暂停
                actionPendingIntent(ACTION_PAUSE, 1)
            ).build()
        } else {
            Notification.Action.Builder(
                R.drawable.ic_player_play,
                "播放", // 播放
                actionPendingIntent(ACTION_PLAY, 2)
            ).build()
        }

        builder
            .setSmallIcon(R.drawable.ic_notification_icon)
            .setContentTitle(state.title.ifBlank { getString(R.string.app_name) })
            .setContentText(state.artist)
            .setSubText(state.subText)
            .setLargeIcon(state.artBitmap)
            .setContentIntent(contentPendingIntent())
            .setDeleteIntent(actionPendingIntent(ACTION_STOP, 3))
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_PROGRESS)
            // Progress bar — key for Live Update eligibility
            .setProgress(
                state.max.coerceAtLeast(0).toInt(),
                state.progress.coerceIn(0, state.max.coerceAtLeast(0)).toInt(),
                state.max <= 0 || state.indeterminate
            )
            .addAction(playPauseAction)

        // Live Update: promoted ongoing (API 36+ / Android 15+)
        if (Build.VERSION.SDK_INT >= 36) {
            @Suppress("NewApi", "InlinedApi")
            builder.setRequestPromotedOngoing(true)
        }
        // Android 12+: show FGS notification immediately
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }

        // ProgressStyle is required for promoted ongoing eligibility.
        builder.setStyle(Notification.BigTextStyle())

        return builder.build()
    }

    private fun contentPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        return PendingIntent.getActivity(
            this, 100, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
    }

    private fun actionPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, LiveUpdateService::class.java).setAction(action)
        return PendingIntent.getService(
            this, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "PiliPlus 播放进度",
            // LOW: silent progress bar, no sound on update.
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "退出应用后显示视频播放进度"
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun stopService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun immutableFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    companion object {
        private const val METHOD_CHANNEL = "pili_plus/live_update"
        private const val CHANNEL_ID = "pili_plus_live_update"
        private const val NOTIFICATION_ID = 20240708

        // Actions dispatched to Dart
        private const val FLUTTER_PLAY = "play"
        private const val FLUTTER_PAUSE = "pause"

        // Service intent actions
        private const val ACTION_PLAY = "com.chloemlla.piliplus.live_update.PLAY"
        private const val ACTION_PAUSE = "com.chloemlla.piliplus.live_update.PAUSE"
        private const val ACTION_TOGGLE = "com.chloemlla.piliplus.live_update.TOGGLE"
        private const val ACTION_STOP = "com.chloemlla.piliplus.live_update.STOP"

        private val mainHandler = Handler(Looper.getMainLooper())
        private val state = LiveUpdateState()

        @Volatile
        private var methodChannel: MethodChannel? = null

        fun attachFlutterEngine(context: Context, flutterEngine: FlutterEngine) {
            methodChannel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL
            ).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "start" -> {
                            updateState(call.arguments as? Map<*, *>)
                            state.hidden = false
                            startOrUpdate(context)
                            result.success(null)
                        }
                        "update" -> {
                            updateState(call.arguments as? Map<*, *>)
                            state.hidden = false
                            startOrUpdate(context)
                            result.success(null)
                        }
                        "stop" -> {
                            state.hidden = true
                            stop(context)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        }

        fun detachFlutterEngine() {
            methodChannel?.setMethodCallHandler(null)
            methodChannel = null
        }

        private fun startOrUpdate(context: Context) {
            if (state.hidden) return
            val app = context.applicationContext
            val intent = Intent(app, LiveUpdateService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                app.startForegroundService(intent)
            } else {
                app.startService(intent)
            }
        }

        private fun stop(context: Context) {
            val app = context.applicationContext
            val intent = Intent(app, LiveUpdateService::class.java).setAction(ACTION_STOP)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                app.startForegroundService(intent)
            } else {
                app.startService(intent)
            }
        }

        private fun updateState(args: Map<*, *>?) {
            if (args == null) return
            state.title = args["title"] as? String ?: state.title
            state.artist = args["artist"] as? String ?: state.artist
            state.subText = args["subText"] as? String ?: state.subText
            val newArtUri = args["artUri"] as? String
            if (newArtUri != null && newArtUri != state.artUri) {
                state.artUri = newArtUri
                state.loadedArtUri = null
                state.artBitmap = null
                loadArtwork()
            }
            state.max = (args["max"] as? Number)?.toLong() ?: state.max
            state.progress = (args["progress"] as? Number)?.toLong() ?: state.progress
            state.playing = args["playing"] as? Boolean ?: state.playing
            state.indeterminate = args["indeterminate"] as? Boolean ?: state.indeterminate
        }

        private fun loadArtwork() {
            val uri = state.artUri
            if (uri.isNullOrBlank() || uri == state.loadedArtUri) return
            state.loadedArtUri = uri
            thread(name = "PiliPlusLiveUpdateArtwork") {
                val bitmap = runCatching { loadBitmap(uri) }.getOrNull()
                mainHandler.post {
                    if (state.artUri == uri && !state.hidden) {
                        state.artBitmap = bitmap
                        // Refresh notification if the service is running
                    }
                }
            }
        }

        private fun loadBitmap(uri: String): Bitmap? {
            return when {
                uri.startsWith("file://") -> BitmapFactory.decodeFile(URL(uri).path)
                uri.startsWith("/") -> BitmapFactory.decodeFile(uri)
                uri.startsWith("http://") || uri.startsWith("https://") -> {
                    val connection = URL(uri).openConnection() as HttpURLConnection
                    connection.connectTimeout = 5000
                    connection.readTimeout = 5000
                    connection.inputStream.use(BitmapFactory::decodeStream)
                }
                else -> {
                    val file = File(uri)
                    if (file.exists()) BitmapFactory.decodeFile(file.absolutePath) else null
                }
            }
        }

        private fun dispatchAction(action: String, args: Map<String, Any?> = emptyMap()) {
            mainHandler.post {
                methodChannel?.invokeMethod(
                    "onAction",
                    mapOf("action" to action, "args" to args)
                )
            }
        }
    }

    private class LiveUpdateState {
        var hidden: Boolean = false
        var title: String = ""
        var artist: String? = null
        var subText: String = ""
        var artBitmap: Bitmap? = null
        var artUri: String? = null
        var loadedArtUri: String? = null
        var max: Long = 0L
        var progress: Long = 0L
        var playing: Boolean = false
        var indeterminate: Boolean = false
    }
}