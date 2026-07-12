package com.chloemlla.piliplus

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/**
 * Application-scoped bridge for Seal DOWNLOAD_STATUS broadcasts.
 *
 * Registered on the Application so status is not lost when an Activity or
 * FlutterEngine is temporarily torn down. Events are queued until Dart calls
 * readyForStatus after installing its MethodChannel handler.
 */
object SealDownloadStatusBridge {
    private const val TAG = "SealDownloadStatus"
    const val CHANNEL_NAME = "pili_plus/seal_download"
    const val ACTION_DOWNLOAD_STATUS = "com.chloemlla.seal.action.DOWNLOAD_STATUS"

    private const val EXTRA_PROTOCOL_VERSION = "protocol_version"
    private const val EXTRA_STATUS = "status"
    private const val EXTRA_ERROR_CODE = "error_code"
    private const val EXTRA_ERROR_MESSAGE = "error_message"
    private const val EXTRA_TASK_ID = "task_id"
    private const val EXTRA_TASK_IDS = "task_ids"
    private const val EXTRA_CALLER_REQUEST_ID = "caller_request_id"
    private const val EXTRA_CONTENT_URI = "content_uri"
    private const val EXTRA_DISPLAY_NAME = "display_name"
    private const val EXTRA_MIME_TYPE = "mime_type"
    private const val PROTOCOL_VERSION = 1
    private const val MAX_QUEUED = 32

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingEvents = ArrayDeque<Map<String, Any?>>()
    private var app: Application? = null
    private var receiver: BroadcastReceiver? = null
    private var channel: MethodChannel? = null
    @Volatile private var dartReady: Boolean = false

    @Synchronized
    fun install(application: Application) {
        if (app != null) return
        app = application
        val broadcastReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action != ACTION_DOWNLOAD_STATUS) return
                    val payload = buildStatusMap(intent).toMutableMap()
                    payload["source"] = "broadcast"
                    Log.i(
                        TAG,
                        "status=${payload["status"]} task=${payload["task_id"]} req=${payload["caller_request_id"]}",
                    )
                    dispatch(payload)
                }
            }
        receiver = broadcastReceiver
        val filter = IntentFilter(ACTION_DOWNLOAD_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            application.registerReceiver(broadcastReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            application.registerReceiver(broadcastReceiver, filter)
        }
        Log.i(TAG, "status receiver installed")
    }

    /** Bind the single MethodChannel used for both commands and status events. */
    @Synchronized
    fun attachChannel(methodChannel: MethodChannel) {
        channel = methodChannel
        dartReady = false
    }

    @Synchronized
    fun detachChannel(methodChannel: MethodChannel) {
        if (channel === methodChannel) {
            channel = null
            dartReady = false
        }
    }

    /** Called from Dart after setMethodCallHandler is installed. */
    @Synchronized
    fun onDartReady() {
        dartReady = true
        val methodChannel = channel ?: return
        flushPending(methodChannel)
    }

    fun emitActivityResult(payload: Map<String, Any?>) {
        val data = payload.toMutableMap()
        data.putIfAbsent("source", "activity_result")
        dispatch(data)
    }

    private fun dispatch(payload: Map<String, Any?>) {
        mainHandler.post {
            val (active, ready) = synchronized(this) { channel to dartReady }
            if (active != null && ready) {
                try {
                    active.invokeMethod("onDownloadStatus", payload)
                } catch (error: Exception) {
                    Log.w(TAG, "invoke Dart failed, queue event", error)
                    enqueue(payload)
                }
            } else {
                enqueue(payload)
            }
        }
    }

    @Synchronized
    private fun enqueue(payload: Map<String, Any?>) {
        while (pendingEvents.size >= MAX_QUEUED) {
            pendingEvents.removeFirst()
        }
        pendingEvents.addLast(payload)
    }

    @Synchronized
    private fun flushPending(methodChannel: MethodChannel) {
        if (pendingEvents.isEmpty()) return
        val snapshot = ArrayList(pendingEvents)
        pendingEvents.clear()
        Log.i(TAG, "flushing ${snapshot.size} queued status event(s) to Dart")
        mainHandler.post {
            snapshot.forEach { event ->
                try {
                    methodChannel.invokeMethod("onDownloadStatus", event)
                } catch (error: Exception) {
                    Log.w(TAG, "flush event failed", error)
                    enqueue(event)
                }
            }
        }
    }

    fun buildStatusMap(data: Intent?): Map<String, Any?> {
        if (data == null) return emptyMap()
        return mapOf(
            "protocol_version" to data.getIntExtra(EXTRA_PROTOCOL_VERSION, PROTOCOL_VERSION),
            "status" to data.getStringExtra(EXTRA_STATUS),
            "error_code" to data.getStringExtra(EXTRA_ERROR_CODE),
            "error_message" to data.getStringExtra(EXTRA_ERROR_MESSAGE),
            "task_id" to data.getStringExtra(EXTRA_TASK_ID),
            "task_ids" to data.getStringArrayExtra(EXTRA_TASK_IDS)?.toList(),
            "caller_request_id" to data.getStringExtra(EXTRA_CALLER_REQUEST_ID),
            "content_uri" to data.getStringExtra(EXTRA_CONTENT_URI),
            "display_name" to data.getStringExtra(EXTRA_DISPLAY_NAME),
            "mime_type" to data.getStringExtra(EXTRA_MIME_TYPE),
        )
    }
}