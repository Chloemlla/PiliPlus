package com.example.piliplus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class NativeMediaService : Service() {
    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        service = this
        createNotificationChannel()
        ensureMediaSession()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> dispatchFlutterAction(FLUTTER_PLAY)
            ACTION_PAUSE -> dispatchFlutterAction(FLUTTER_PAUSE)
            ACTION_TOGGLE -> dispatchFlutterAction(if (state.playing) FLUTTER_PAUSE else FLUTTER_PLAY)
            ACTION_REWIND -> dispatchFlutterAction(FLUTTER_REWIND)
            ACTION_FAST_FORWARD -> dispatchFlutterAction(FLUTTER_FAST_FORWARD)
            ACTION_PREVIOUS -> dispatchFlutterAction(FLUTTER_PREVIOUS)
            ACTION_NEXT -> dispatchFlutterAction(FLUTTER_NEXT)
            ACTION_STOP -> {
                dispatchFlutterAction(FLUTTER_CLEAR_SESSION)
                stopPlaybackService()
                return START_NOT_STICKY
            }
            ACTION_HIDE -> {
                state.hidden = true
                stopPlaybackService()
                return START_NOT_STICKY
            }
            ACTION_BACKGROUND_AUDIO -> dispatchFlutterAction(FLUTTER_BACKGROUND_AUDIO)
            ACTION_MINI_PLAYER -> dispatchFlutterAction(FLUTTER_MINI_PLAYER)
            ACTION_SLEEP_TIMER -> dispatchFlutterAction(FLUTTER_SLEEP_TIMER)
            ACTION_SPEED -> dispatchFlutterAction(FLUTTER_SPEED)
            ACTION_DANMAKU -> dispatchFlutterAction(FLUTTER_DANMAKU)
            ACTION_REPEAT -> dispatchFlutterAction(FLUTTER_REPEAT)
        }
        refreshFromState()
        return START_STICKY
    }

    override fun onDestroy() {
        if (service === this) service = null
        mediaSession?.release()
        mediaSession = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureMediaSession() {
        if (mediaSession != null) return
        mediaSession = MediaSession(this, "PiliPlusMediaSession").apply {
            setFlags(
                MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setSessionActivity(contentPendingIntent())
            setCallback(
                object : MediaSession.Callback() {
                    override fun onPlay() = dispatchFlutterAction(FLUTTER_PLAY)
                    override fun onPause() = dispatchFlutterAction(FLUTTER_PAUSE)
                    override fun onStop() = dispatchFlutterAction(FLUTTER_CLEAR_SESSION)
                    override fun onSkipToPrevious() = dispatchFlutterAction(FLUTTER_PREVIOUS)
                    override fun onSkipToNext() = dispatchFlutterAction(FLUTTER_NEXT)
                    override fun onRewind() = dispatchFlutterAction(FLUTTER_REWIND)
                    override fun onFastForward() = dispatchFlutterAction(FLUTTER_FAST_FORWARD)

                    override fun onSeekTo(pos: Long) {
                        state.positionMs = pos.coerceAtLeast(0L)
                        refreshFromState()
                        dispatchFlutterAction(
                            FLUTTER_SEEK,
                            mapOf(ARG_POSITION_MS to state.positionMs)
                        )
                    }

                    override fun onCustomAction(action: String, extras: Bundle?) {
                        when (action) {
                            ACTION_BACKGROUND_AUDIO -> dispatchFlutterAction(FLUTTER_BACKGROUND_AUDIO)
                            ACTION_MINI_PLAYER -> dispatchFlutterAction(FLUTTER_MINI_PLAYER)
                            ACTION_SLEEP_TIMER -> dispatchFlutterAction(FLUTTER_SLEEP_TIMER)
                            ACTION_SPEED -> dispatchFlutterAction(FLUTTER_SPEED)
                            ACTION_DANMAKU -> dispatchFlutterAction(FLUTTER_DANMAKU)
                            ACTION_REPEAT -> dispatchFlutterAction(FLUTTER_REPEAT)
                            ACTION_STOP -> dispatchFlutterAction(FLUTTER_CLEAR_SESSION)
                        }
                    }

                    override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                        val event = mediaButtonIntent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                        if (event?.action != KeyEvent.ACTION_DOWN) return true
                        when (event.keyCode) {
                            KeyEvent.KEYCODE_MEDIA_PLAY -> dispatchFlutterAction(FLUTTER_PLAY)
                            KeyEvent.KEYCODE_MEDIA_PAUSE -> dispatchFlutterAction(FLUTTER_PAUSE)
                            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> dispatchFlutterAction(
                                if (state.playing) FLUTTER_PAUSE else FLUTTER_PLAY
                            )
                            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> dispatchFlutterAction(FLUTTER_PREVIOUS)
                            KeyEvent.KEYCODE_MEDIA_NEXT -> dispatchFlutterAction(FLUTTER_NEXT)
                            KeyEvent.KEYCODE_MEDIA_REWIND -> dispatchFlutterAction(FLUTTER_REWIND)
                            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> dispatchFlutterAction(FLUTTER_FAST_FORWARD)
                            KeyEvent.KEYCODE_MEDIA_STOP -> dispatchFlutterAction(FLUTTER_CLEAR_SESSION)
                        }
                        return true
                    }
                }
            )
            isActive = true
        }
    }

    private fun refreshFromState() {
        if (state.hidden || !state.active) return
        ensureMediaSession()
        updateMediaSession()
        loadArtworkIfNeeded()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    private fun updateMediaSession() {
        val session = mediaSession ?: return
        session.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, state.title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, state.artist)
                .putLong(
                    MediaMetadata.METADATA_KEY_DURATION,
                    if (state.live) -1L else state.durationMs.coerceAtLeast(0L)
                )
                .apply {
                    state.artBitmap?.let {
                        putBitmap(MediaMetadata.METADATA_KEY_ART, it)
                        putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it)
                    }
                }
                .build()
        )

        var actions = PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_STOP or
            PlaybackState.ACTION_SEEK_TO
        actions = actions or if (state.playing) PlaybackState.ACTION_PAUSE else PlaybackState.ACTION_PLAY
        if (!state.live) {
            actions = actions or PlaybackState.ACTION_REWIND or PlaybackState.ACTION_FAST_FORWARD
        }
        if (state.supportsPrevious) actions = actions or PlaybackState.ACTION_SKIP_TO_PREVIOUS
        if (state.supportsNext) actions = actions or PlaybackState.ACTION_SKIP_TO_NEXT

        val playbackState = when {
            state.buffering -> PlaybackState.STATE_BUFFERING
            state.completed -> PlaybackState.STATE_STOPPED
            state.playing -> PlaybackState.STATE_PLAYING
            else -> PlaybackState.STATE_PAUSED
        }

        session.setPlaybackState(
            PlaybackState.Builder()
                .setActions(actions)
                .setState(
                    playbackState,
                    state.positionMs.coerceAtLeast(0L),
                    if (state.playing) state.speed else 0f,
                    SystemClock.elapsedRealtime()
                )
                .addVideoCustomActions()
                .build()
        )
    }

    private fun PlaybackState.Builder.addVideoCustomActions(): PlaybackState.Builder {
        if (!state.videoActions) return this
        addCustomAction(ACTION_BACKGROUND_AUDIO, if (state.backgroundAudio) "关闭后台音频" else "后台音频", R.drawable.ic_player_audio)
        addCustomAction(ACTION_MINI_PLAYER, "小窗播放", R.drawable.ic_player_pip)
        addCustomAction(ACTION_SLEEP_TIMER, "定时关闭", R.drawable.ic_player_timer)
        addCustomAction(ACTION_SPEED, "倍速", R.drawable.ic_player_speed)
        addCustomAction(ACTION_DANMAKU, if (state.danmakuEnabled) "关闭弹幕" else "开启弹幕", R.drawable.ic_player_danmaku)
        addCustomAction(ACTION_REPEAT, "循环模式", R.drawable.ic_player_repeat)
        addCustomAction(ACTION_STOP, "清除播放", R.drawable.ic_player_stop)
        return this
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val actions = notificationActions()
        actions.forEach { builder.addAction(it.action) }

        val compactIndices = actions
            .mapIndexedNotNull { index, action -> if (action.compact) index else null }
            .take(3)
            .toIntArray()

        return builder
            .setSmallIcon(R.drawable.ic_notification_icon)
            .setContentTitle(state.title.ifBlank { getString(R.string.app_name) })
            .setContentText(state.artist)
            .setSubText(
                when {
                    state.buffering -> "缓冲中"
                    state.videoActions -> "${state.speedLabel()} / ${state.repeatMode}"
                    else -> null
                }
            )
            .setLargeIcon(state.artBitmap)
            .setContentIntent(contentPendingIntent())
            .setDeleteIntent(servicePendingIntent(ACTION_HIDE, 90))
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setOngoing(state.playing)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(mediaSession?.sessionToken)
                    .setShowActionsInCompactView(*compactIndices)
            )
            .build()
    }

    private data class NotificationMediaAction(
        val action: Notification.Action,
        val compact: Boolean,
    )

    private fun notificationActions(): List<NotificationMediaAction> {
        val actions = ArrayList<NotificationMediaAction>(5)
        if (!state.live && state.supportsPrevious) {
            actions += NotificationMediaAction(
                notificationAction(R.drawable.ic_player_previous, "上一项", ACTION_PREVIOUS, 1),
                compact = false,
            )
        }
        if (!state.live) {
            actions += NotificationMediaAction(
                notificationAction(R.drawable.ic_player_rewind_10s, "后退 10 秒", ACTION_REWIND, 2),
                compact = true,
            )
        }
        actions += NotificationMediaAction(
            if (state.playing) {
                notificationAction(R.drawable.ic_player_pause, "暂停", ACTION_PAUSE, 3)
            } else {
                notificationAction(R.drawable.ic_player_play, "播放", ACTION_PLAY, 4)
            },
            compact = true,
        )
        if (!state.live) {
            actions += NotificationMediaAction(
                notificationAction(R.drawable.ic_player_fast_forward_10s, "快进 10 秒", ACTION_FAST_FORWARD, 5),
                compact = true,
            )
        }
        if (!state.live && state.supportsNext) {
            actions += NotificationMediaAction(
                notificationAction(R.drawable.ic_player_next, "下一项", ACTION_NEXT, 6),
                compact = false,
            )
        }
        if (actions.size < 5) {
            actions += NotificationMediaAction(
                notificationAction(R.drawable.ic_player_stop, "清除", ACTION_STOP, 7),
                compact = false,
            )
        }
        return actions.take(5)
    }

    private fun notificationAction(icon: Int, title: String, action: String, requestCode: Int): Notification.Action {
        return Notification.Action.Builder(
            icon,
            title,
            servicePendingIntent(action, requestCode)
        ).build()
    }

    private fun contentPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        return PendingIntent.getActivity(
            this,
            100,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
    }

    private fun servicePendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, NativeMediaService::class.java).setAction(action)
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "PiliPlus media playback",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Media playback controls"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun stopPlaybackService() {
        mediaSession?.isActive = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun loadArtworkIfNeeded() {
        val uri = state.artUri
        if (uri.isNullOrBlank() || uri == state.loadedArtUri || uri == state.loadingArtUri) return
        state.loadingArtUri = uri
        thread(name = "PiliPlusArtworkLoader") {
            val bitmap = runCatching { loadBitmap(uri) }.getOrNull()
            mainHandler.post {
                if (state.artUri == uri) {
                    state.artBitmap = bitmap
                    state.loadedArtUri = uri
                    state.loadingArtUri = null
                    if (!state.hidden && state.active) refreshFromState()
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

    private fun NativeMediaState.speedLabel(): String {
        return if (speed == 1f) "1x" else "${speed}x"
    }

    companion object {
        private const val METHOD_CHANNEL = "pili_plus/native_media_notification"
        private const val CHANNEL_ID = "pili_plus_native_media"
        private const val NOTIFICATION_ID = 20240707

        private const val ACTION_REFRESH = "com.example.piliplus.native_media.REFRESH"
        private const val ACTION_PLAY = "com.example.piliplus.native_media.PLAY"
        private const val ACTION_PAUSE = "com.example.piliplus.native_media.PAUSE"
        private const val ACTION_TOGGLE = "com.example.piliplus.native_media.TOGGLE"
        private const val ACTION_REWIND = "com.example.piliplus.native_media.REWIND"
        private const val ACTION_FAST_FORWARD = "com.example.piliplus.native_media.FAST_FORWARD"
        private const val ACTION_PREVIOUS = "com.example.piliplus.native_media.PREVIOUS"
        private const val ACTION_NEXT = "com.example.piliplus.native_media.NEXT"
        private const val ACTION_STOP = "com.example.piliplus.native_media.STOP"
        private const val ACTION_HIDE = "com.example.piliplus.native_media.HIDE"
        private const val ACTION_BACKGROUND_AUDIO = "com.example.piliplus.native_media.BACKGROUND_AUDIO"
        private const val ACTION_MINI_PLAYER = "com.example.piliplus.native_media.MINI_PLAYER"
        private const val ACTION_SLEEP_TIMER = "com.example.piliplus.native_media.SLEEP_TIMER"
        private const val ACTION_SPEED = "com.example.piliplus.native_media.SPEED"
        private const val ACTION_DANMAKU = "com.example.piliplus.native_media.DANMAKU"
        private const val ACTION_REPEAT = "com.example.piliplus.native_media.REPEAT"

        private const val FLUTTER_PLAY = "play"
        private const val FLUTTER_PAUSE = "pause"
        private const val FLUTTER_SEEK = "seek"
        private const val FLUTTER_REWIND = "rewind"
        private const val FLUTTER_FAST_FORWARD = "fastForward"
        private const val FLUTTER_PREVIOUS = "previous"
        private const val FLUTTER_NEXT = "next"
        private const val FLUTTER_BACKGROUND_AUDIO = "backgroundAudio"
        private const val FLUTTER_MINI_PLAYER = "miniPlayer"
        private const val FLUTTER_SLEEP_TIMER = "sleepTimer"
        private const val FLUTTER_SPEED = "speed"
        private const val FLUTTER_DANMAKU = "danmaku"
        private const val FLUTTER_REPEAT = "repeat"
        private const val FLUTTER_CLEAR_SESSION = "clearSession"

        private const val ARG_POSITION_MS = "positionMs"

        private val mainHandler = Handler(Looper.getMainLooper())
        private val state = NativeMediaState()

        @Volatile
        private var methodChannel: MethodChannel? = null

        @Volatile
        private var service: NativeMediaService? = null

        fun attachFlutterEngine(context: Context, flutterEngine: FlutterEngine) {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "start" -> {
                            updateState(call.arguments as? Map<*, *>)
                            state.active = true
                            state.hidden = false
                            startOrUpdate(context)
                            result.success(null)
                        }
                        "updateMetadata" -> {
                            updateState(call.arguments as? Map<*, *>)
                            state.active = true
                            startOrUpdate(context)
                            result.success(null)
                        }
                        "updatePlayback" -> {
                            updateState(call.arguments as? Map<*, *>)
                            state.active = true
                            startOrUpdate(context)
                            result.success(null)
                        }
                        "stop" -> {
                            state.reset()
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
            val intent = Intent(app, NativeMediaService::class.java).setAction(ACTION_REFRESH)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                app.startForegroundService(intent)
            } else {
                app.startService(intent)
            }
            service?.refreshFromState()
        }

        private fun stop(context: Context) {
            val app = context.applicationContext
            service?.stopPlaybackService()
            app.stopService(Intent(app, NativeMediaService::class.java))
        }

        private fun updateState(args: Map<*, *>?) {
            if (args == null) return
            val nextMediaId = args["id"] as? String
            if (nextMediaId != null && nextMediaId != state.mediaId) {
                state.hidden = false
                state.loadedArtUri = null
                state.artBitmap = null
            }
            state.mediaId = nextMediaId ?: state.mediaId
            state.title = args["title"] as? String ?: state.title
            state.artist = args["artist"] as? String ?: state.artist
            state.artUri = args["artUri"] as? String ?: state.artUri
            state.durationMs = (args["durationMs"] as? Number)?.toLong() ?: state.durationMs
            state.positionMs = (args["positionMs"] as? Number)?.toLong() ?: state.positionMs
            state.bufferedMs = (args["bufferedMs"] as? Number)?.toLong() ?: state.bufferedMs
            state.speed = (args["speed"] as? Number)?.toFloat() ?: state.speed
            state.playing = args["playing"] as? Boolean ?: state.playing
            state.buffering = args["buffering"] as? Boolean ?: state.buffering
            state.completed = args["completed"] as? Boolean ?: state.completed
            state.live = args["live"] as? Boolean ?: state.live
            state.videoActions = args["videoActions"] as? Boolean ?: state.videoActions
            state.supportsPrevious = args["supportsPrevious"] as? Boolean ?: state.supportsPrevious
            state.supportsNext = args["supportsNext"] as? Boolean ?: state.supportsNext
            state.backgroundAudio = args["backgroundAudio"] as? Boolean ?: state.backgroundAudio
            state.danmakuEnabled = args["danmakuEnabled"] as? Boolean ?: state.danmakuEnabled
            state.repeatMode = args["repeatMode"] as? String ?: state.repeatMode
        }

        private fun dispatchFlutterAction(action: String, args: Map<String, Any?> = emptyMap()) {
            mainHandler.post {
                methodChannel?.invokeMethod(
                    "onAction",
                    mapOf(
                        "action" to action,
                        "args" to args,
                    )
                )
            }
        }

        private fun immutableFlag(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        }
    }

    private class NativeMediaState {
        var active: Boolean = false
        var hidden: Boolean = false
        var mediaId: String? = null
        var title: String = ""
        var artist: String? = null
        var artUri: String? = null
        var loadedArtUri: String? = null
        var loadingArtUri: String? = null
        var artBitmap: Bitmap? = null
        var durationMs: Long = 0L
        var positionMs: Long = 0L
        var bufferedMs: Long = 0L
        var speed: Float = 1f
        var playing: Boolean = false
        var buffering: Boolean = false
        var completed: Boolean = false
        var live: Boolean = false
        var videoActions: Boolean = false
        var supportsPrevious: Boolean = false
        var supportsNext: Boolean = false
        var backgroundAudio: Boolean = false
        var danmakuEnabled: Boolean = true
        var repeatMode: String = ""

        fun reset() {
            active = false
            hidden = false
            mediaId = null
            title = ""
            artist = null
            artUri = null
            loadedArtUri = null
            loadingArtUri = null
            artBitmap = null
            durationMs = 0L
            positionMs = 0L
            bufferedMs = 0L
            speed = 1f
            playing = false
            buffering = false
            completed = false
            live = false
            videoActions = false
            supportsPrevious = false
            supportsNext = false
            backgroundAudio = false
            danmakuEnabled = true
            repeatMode = ""
        }
    }
}
