package com.chloemlla.piliplus

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.ClipData
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Seal L2/L3 download delegate channel.
 *
 * Status broadcasts are owned by [SealDownloadStatusBridge] (Application scope).
 * This channel handles launch + open/share only.
 */
internal class SealDownloadChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, SealDownloadStatusBridge.CHANNEL_NAME)
    private var pendingTaskActionResult: MethodChannel.Result? = null

    init {
        // Attach early so queued Application-level events can flush to Dart.
        SealDownloadStatusBridge.attachChannel(channel)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readyForStatus" -> {
                SealDownloadStatusBridge.onDartReady()
                result.success(true)
            }
            "isInstalled" -> result.success(resolveSealPackage() != null)
            "delegateDownload" -> delegateDownload(call, result)
            "taskAction" -> taskAction(call, result)
            "openContentUri" -> openContentUri(call, result)
            "shareContentUri" -> shareContentUri(call, result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == TASK_ACTION_REQUEST_CODE) {
            val pending = pendingTaskActionResult
            pendingTaskActionResult = null
            if (pending == null) return true
            val payload = SealDownloadStatusBridge.buildStatusMap(data).toMutableMap()
            payload["result_code"] = resultCode
            if (resultCode == Activity.RESULT_OK) {
                pending.success(payload)
            } else {
                val errorCode = payload["error_code"]?.toString() ?: "internal_error"
                val errorMessage =
                    payload["error_message"]?.toString() ?: "Seal task action failed"
                pending.error(errorCode, errorMessage, payload)
            }
            return true
        }
        if (requestCode != DOWNLOAD_REQUEST_CODE) return false
        val payload = SealDownloadStatusBridge.buildStatusMap(data).toMutableMap()
        if (payload["status"] == null) {
            // Seal sometimes closes UI without extras; treat OK as needs_ui opened.
            payload["status"] = when (resultCode) {
                Activity.RESULT_OK -> "needs_ui"
                else -> "rejected"
            }
            if (resultCode == Activity.RESULT_OK) {
                payload.putIfAbsent("error_code", "ok")
            }
        }
        payload["result_code"] = resultCode
        payload["source"] = "activity_result"
        SealDownloadStatusBridge.emitActivityResult(payload)
        return true
    }

    fun dispose() {
        pendingTaskActionResult?.error(
            "activity_detached",
            "PiliPlus activity detached before Seal returned the task action result",
            null,
        )
        pendingTaskActionResult = null
        channel.setMethodCallHandler(null)
        // Keep Application receiver alive; only detach this messenger if it is ours.
        SealDownloadStatusBridge.detachChannel(channel)
    }

    private fun delegateDownload(call: MethodCall, result: MethodChannel.Result) {
        val rawUrls = call.argument<List<*>>("urls")
        val urlsFromList = rawUrls
            ?.mapNotNull { it?.toString()?.trim() }
            ?.filter { it.isNotEmpty() }
            .orEmpty()
        val singleUrl = call.argument<String>("url")?.trim().orEmpty()
        val urls = when {
            urlsFromList.isNotEmpty() -> urlsFromList
            singleUrl.isNotEmpty() -> listOf(singleUrl)
            else -> emptyList()
        }
        if (urls.isEmpty()) {
            result.error("invalid_url", "下载链接为空", null)
            return
        }
        val url = urls.first()
        val sealPackage = resolveSealPackage()
        if (sealPackage == null) {
            result.error("not_installed", "请先安装 Seal", null)
            return
        }

        val extractAudio = call.argument<Boolean>("extractAudio") ?: false
        val autoStart = call.argument<Boolean>("autoStart") ?: false
        val openUi = call.argument<Boolean>("openUi") ?: true
        val requestId = call.argument<String>("requestId")
        val stripSegments = call.argument<Boolean>("stripSegments") ?: false
        val keepSections = call.argument<String>("keepSections")?.trim().orEmpty()
        val cookiesFormat = call.argument<String>("cookiesFormat")?.trim().orEmpty()
        val cookies = call.argument<String>("cookies")
        val cookiesMid = call.argument<Number>("cookiesMid")?.toLong()
            ?: call.argument<String>("cookiesMid")?.toLongOrNull()
        val cookiesDomainHint = call.argument<String>("cookiesDomainHint")?.trim().orEmpty()
        val useCookies = call.argument<Boolean>("useCookies")
        val cookiesRequired = call.argument<Boolean>("cookiesRequired") ?: false
        val hasCookies = !cookies.isNullOrBlank()
        // Strip concat/status semantics require v3; cookie-only remains v2.
        val protocolVersion =
            if (stripSegments || keepSections.isNotEmpty()) {
                PROTOCOL_VERSION_V3
            } else if (hasCookies) {
                PROTOCOL_VERSION_V2
            } else {
                PROTOCOL_VERSION
            }

        val intent = Intent(ACTION_DOWNLOAD).apply {
            // Prefer QuickDownloadActivity so extract_audio maps to the dialog type UI.
            // Avoid ambiguous resolve that may open MainActivity with the last global type.
            component = ComponentName(sealPackage, "com.chloemlla.seal.QuickDownloadActivity")
            setPackage(sealPackage)
            type = "text/plain"
            putExtra(EXTRA_PROTOCOL_VERSION, protocolVersion)
            putExtra(EXTRA_URL, url)
            // Seal multi-URL batch protocol (single URL still sent as EXTRA_URL for compat).
            putExtra(EXTRA_URLS, urls.toTypedArray())
            putExtra(EXTRA_EXTRACT_AUDIO, extractAudio)
            putExtra(EXTRA_AUTO_START, autoStart)
            putExtra(EXTRA_OPEN_UI, openUi)
            // Fallback only; Seal prefers Activity.callingPackage.
            putExtra(EXTRA_CALLER_PACKAGE, activity.packageName)
            if (!requestId.isNullOrEmpty()) {
                putExtra(EXTRA_CALLER_REQUEST_ID, requestId)
            }
            if (stripSegments) {
                putExtra(EXTRA_STRIP_SEGMENTS, true)
            }
            if (keepSections.isNotEmpty()) {
                putExtra(EXTRA_KEEP_SECTIONS, keepSections)
            }
            if (hasCookies) {
                putExtra(EXTRA_COOKIES_FORMAT, cookiesFormat.ifEmpty { "json_map" })
                putExtra(EXTRA_COOKIES, cookies)
                if (cookiesMid != null && cookiesMid > 0L) {
                    putExtra(EXTRA_COOKIES_MID, cookiesMid)
                }
                putExtra(
                    EXTRA_COOKIES_DOMAIN_HINT,
                    cookiesDomainHint.ifEmpty { ".bilibili.com" },
                )
                putExtra(EXTRA_USE_COOKIES, useCookies ?: true)
                if (cookiesRequired) {
                    putExtra(EXTRA_COOKIES_REQUIRED, true)
                }
            }
        }

        try {
            // Must use Activity.startActivityForResult so Seal can resolve callingPackage
            // for directed DOWNLOAD_STATUS broadcasts.
            activity.startActivityForResult(intent, DOWNLOAD_REQUEST_CODE)
            result.success(
                mapOf(
                    "status" to "launched",
                    "caller_request_id" to requestId,
                    "seal_package" to sealPackage,
                    "caller_package" to activity.packageName,
                ),
            )
        } catch (_: ActivityNotFoundException) {
            result.error("not_installed", "请先安装 Seal", null)
        } catch (e: Exception) {
            result.error("launch_failed", e.message ?: "无法启动 Seal", null)
        }
    }

    private fun taskAction(call: MethodCall, result: MethodChannel.Result) {
        if (pendingTaskActionResult != null) {
            result.error("action_in_progress", "另一个 Seal 任务操作尚未完成", null)
            return
        }
        val action = call.argument<String>("action")?.trim()?.lowercase().orEmpty()
        if (action !in TASK_ACTIONS) {
            result.error("unsupported_action", "Seal 不支持任务操作：$action", null)
            return
        }
        val taskId = call.argument<String>("taskId")?.trim()?.takeIf { it.isNotEmpty() }
        val requestId =
            call.argument<String>("requestId")?.trim()?.takeIf { it.isNotEmpty() }
        if (taskId == null && requestId == null) {
            result.error("task_not_found", "下载任务标识为空", null)
            return
        }
        val sealPackage = resolveSealPackage()
        if (sealPackage == null) {
            result.error("not_installed", "请先安装 Seal", null)
            return
        }
        val intent =
            Intent(ACTION_CONTROL_DOWNLOAD).apply {
                component =
                    ComponentName(
                        sealPackage,
                        "com.chloemlla.seal.ExternalDownloadControlActivity",
                    )
                setPackage(sealPackage)
                putExtra(EXTRA_PROTOCOL_VERSION, PROTOCOL_VERSION_V3)
                putExtra(EXTRA_CONTROL_ACTION, action)
                taskId?.let { putExtra(EXTRA_TASK_ID, it) }
                requestId?.let { putExtra(EXTRA_CALLER_REQUEST_ID, it) }
            }
        pendingTaskActionResult = result
        try {
            // The Seal control surface authorizes only Activity.callingPackage.
            activity.startActivityForResult(intent, TASK_ACTION_REQUEST_CODE)
        } catch (_: ActivityNotFoundException) {
            pendingTaskActionResult = null
            result.error("not_installed", "当前 Seal 版本不支持下载任务控制", null)
        } catch (error: Exception) {
            pendingTaskActionResult = null
            result.error("launch_failed", error.message ?: "无法控制 Seal 下载任务", null)
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
                val uri = Uri.parse(uriString)
                val resolvedMime = mimeType?.ifEmpty { null } ?: "*/*"
                setDataAndType(uri, resolvedMime)
                // Explicit URI grant surface for Android 17+ share/open hardening.
                clipData = ClipData.newUri(activity.contentResolver, "open", uri)
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
                // Do not rely on implicit URI grants for ACTION_SEND.
                clipData = ClipData.newUri(activity.contentResolver, displayName ?: "share", uri)
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

    private companion object {
        const val DOWNLOAD_REQUEST_CODE = 0x7201
        const val TASK_ACTION_REQUEST_CODE = 0x7202

        const val ACTION_DOWNLOAD = "com.chloemlla.seal.action.DOWNLOAD"
        const val ACTION_CONTROL_DOWNLOAD = "com.chloemlla.seal.action.CONTROL_DOWNLOAD"
        const val PROTOCOL_VERSION = 1
        const val PROTOCOL_VERSION_V2 = 2
        const val PROTOCOL_VERSION_V3 = 3
        const val EXTRA_PROTOCOL_VERSION = "protocol_version"
        const val EXTRA_URL = "url"
        const val EXTRA_URLS = "urls"
        const val EXTRA_EXTRACT_AUDIO = "extract_audio"
        const val EXTRA_AUTO_START = "auto_start"
        const val EXTRA_OPEN_UI = "open_ui"
        const val EXTRA_CALLER_REQUEST_ID = "caller_request_id"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_CONTROL_ACTION = "control_action"
        const val EXTRA_CALLER_PACKAGE = "caller_package"
        const val EXTRA_STRIP_SEGMENTS = "strip_segments"
        const val EXTRA_KEEP_SECTIONS = "keep_sections"
        const val EXTRA_COOKIES_FORMAT = "cookies_format"
        const val EXTRA_COOKIES = "cookies"
        const val EXTRA_COOKIES_MID = "cookies_mid"
        const val EXTRA_COOKIES_DOMAIN_HINT = "cookies_domain_hint"
        const val EXTRA_USE_COOKIES = "use_cookies"
        const val EXTRA_COOKIES_REQUIRED = "cookies_required"

        val TASK_ACTIONS = setOf("pause", "resume", "retry", "delete")

        val SEAL_PACKAGES = listOf(
            "com.chloemlla.seal",
            "com.chloemlla.seal.debug",
            "com.chloemlla.seal.preview",
        )
    }
}
