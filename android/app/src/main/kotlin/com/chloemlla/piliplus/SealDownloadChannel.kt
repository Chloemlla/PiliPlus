package com.chloemlla.piliplus

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class SealDownloadChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var statusReceiver: BroadcastReceiver? = null

    init {
        channel.setMethodCallHandler(this)
        registerStatusReceiver()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isInstalled" -> result.success(resolveSealPackage() != null)
            "delegateDownload" -> delegateDownload(call, result)
            "openContentUri" -> openContentUri(call, result)
            "shareContentUri" -> shareContentUri(call, result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != DOWNLOAD_REQUEST_CODE) return false
        val payload = buildStatusMap(data).toMutableMap()
        if (payload["status"] == null) {
            payload["status"] = when (resultCode) {
                Activity.RESULT_OK -> "needs_ui"
                else -> "rejected"
            }
        }
        if (resultCode == Activity.RESULT_CANCELED && payload["status"] == "needs_ui") {
            payload["status"] = "rejected"
        }
        payload["result_code"] = resultCode
        payload["source"] = "activity_result"
        emitStatus(payload)
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        unregisterStatusReceiver()
    }

    private fun delegateDownload(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")?.trim().orEmpty()
        if (url.isEmpty()) {
            result.error("invalid_url", "下载链接为空", null)
            return
        }
        val sealPackage = resolveSealPackage()
        if (sealPackage == null) {
            result.error("not_installed", "请先安装 Seal", null)
            return
        }

        val extractAudio = call.argument<Boolean>("extractAudio") ?: false
        val autoStart = call.argument<Boolean>("autoStart") ?: false
        val openUi = call.argument<Boolean>("openUi") ?: true
        val requestId = call.argument<String>("requestId")

        val intent = Intent(ACTION_DOWNLOAD).apply {
            setPackage(sealPackage)
            type = "text/plain"
            putExtra(EXTRA_PROTOCOL_VERSION, PROTOCOL_VERSION)
            putExtra(EXTRA_URL, url)
            putExtra(EXTRA_EXTRACT_AUDIO, extractAudio)
            putExtra(EXTRA_AUTO_START, autoStart)
            putExtra(EXTRA_OPEN_UI, openUi)
            if (!requestId.isNullOrEmpty()) {
                putExtra(EXTRA_CALLER_REQUEST_ID, requestId)
            }
        }

        try {
            activity.startActivityForResult(intent, DOWNLOAD_REQUEST_CODE)
            result.success(
                mapOf(
                    "status" to "launched",
                    "caller_request_id" to requestId,
                    "seal_package" to sealPackage,
                ),
            )
        } catch (_: ActivityNotFoundException) {
            result.error("not_installed", "请先安装 Seal", null)
        } catch (e: Exception) {
            result.error("launch_failed", e.message ?: "无法启动 Seal", null)
        }
    }

    private fun openContentUri(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")?.trim().orEmpty()
        if (uriString.isEmpty()) {
            result.error("invalid_uri", "文件地址为空", null)
            return
        }
        val mimeType = call.argument<String>("mimeType")
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(uriString), mimeType?.ifEmpty { null } ?: "*/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("open_failed", e.message ?: "无法打开文件", null)
        }
    }

    private fun shareContentUri(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")?.trim().orEmpty()
        if (uriString.isEmpty()) {
            result.error("invalid_uri", "文件地址为空", null)
            return
        }
        val mimeType = call.argument<String>("mimeType")?.ifEmpty { null } ?: "*/*"
        val displayName = call.argument<String>("displayName")
        try {
            val uri = Uri.parse(uriString)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                if (!displayName.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_SUBJECT, displayName)
                    putExtra(Intent.EXTRA_TEXT, displayName)
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            activity.startActivity(Intent.createChooser(intent, displayName ?: "分享文件"))
            result.success(true)
        } catch (e: Exception) {
            result.error("share_failed", e.message ?: "无法分享文件", null)
        }
    }

    private fun registerStatusReceiver() {
        if (statusReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != ACTION_DOWNLOAD_STATUS) return
                val payload = buildStatusMap(intent).toMutableMap()
                payload["source"] = "broadcast"
                emitStatus(payload)
            }
        }
        statusReceiver = receiver
        val filter = IntentFilter(ACTION_DOWNLOAD_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            activity.registerReceiver(receiver, filter)
        }
    }

    private fun unregisterStatusReceiver() {
        val receiver = statusReceiver ?: return
        try {
            activity.unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
        statusReceiver = null
    }

    private fun emitStatus(payload: Map<String, Any?>) {
        activity.runOnUiThread {
            channel.invokeMethod("onDownloadStatus", payload)
        }
    }

    private fun resolveSealPackage(): String? {
        val pm = activity.packageManager
        for (packageName in SEAL_PACKAGES) {
            if (isPackageInstalled(pm, packageName)) {
                return packageName
            }
        }
        return null
    }

    private fun isPackageInstalled(pm: PackageManager, packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun buildStatusMap(data: Intent?): Map<String, Any?> {
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

    private companion object {
        const val CHANNEL_NAME = "pili_plus/seal_download"
        const val DOWNLOAD_REQUEST_CODE = 0x7201

        const val ACTION_DOWNLOAD = "com.chloemlla.seal.action.DOWNLOAD"
        const val ACTION_DOWNLOAD_STATUS = "com.chloemlla.seal.action.DOWNLOAD_STATUS"

        const val PROTOCOL_VERSION = 1
        const val EXTRA_PROTOCOL_VERSION = "protocol_version"
        const val EXTRA_URL = "url"
        const val EXTRA_EXTRACT_AUDIO = "extract_audio"
        const val EXTRA_AUTO_START = "auto_start"
        const val EXTRA_OPEN_UI = "open_ui"
        const val EXTRA_CALLER_REQUEST_ID = "caller_request_id"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_IDS = "task_ids"
        const val EXTRA_STATUS = "status"
        const val EXTRA_ERROR_CODE = "error_code"
        const val EXTRA_ERROR_MESSAGE = "error_message"
        const val EXTRA_CONTENT_URI = "content_uri"
        const val EXTRA_DISPLAY_NAME = "display_name"
        const val EXTRA_MIME_TYPE = "mime_type"

        val SEAL_PACKAGES = listOf(
            "com.chloemlla.seal",
            "com.chloemlla.seal.debug",
            "com.chloemlla.seal.preview",
        )
    }
}
