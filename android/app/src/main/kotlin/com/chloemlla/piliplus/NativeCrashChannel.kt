package com.chloemlla.piliplus

import android.content.Context
import com.chloemlla.lumen.crash.LumenCrash
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class NativeCrashChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getPendingReports" -> result.success(NativeCrashStore.pendingReports(context))
                "awaitExitHistoryReady" -> {
                    val timeoutMs = (call.argument<Number>("timeoutMs")?.toLong() ?: 2_500L)
                        .coerceIn(0L, 10_000L)
                    val ready = runCatching {
                        ProcessExitCollector.awaitReady(timeoutMs)
                    }.getOrDefault(true)
                    result.success(ready)
                }
                "acknowledgeReports" -> {
                    val recordIds = call.argument<List<*>>("recordIds")
                        ?.filterIsInstance<String>()
                        ?: emptyList()
                    NativeCrashStore.acknowledge(context, recordIds)
                    result.success(null)
                }
                "getLumenPendingReport" -> {
                    val report = LumenCrash.loadPendingReportSafely()
                    result.success(report?.let(::lumenReportMap))
                }
                "clearLumenPendingReport" -> {
                    runCatching { LumenCrash.clearPendingReport() }
                    result.success(null)
                }
                "recordBreadcrumb" -> {
                    val event = call.argument<String>("event")?.trim().orEmpty()
                    if (event.isNotEmpty()) {
                        runCatching { LumenCrash.recordBreadcrumb(event) }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (exception: Exception) {
            result.error("native_crash_store_failed", exception.message, null)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun lumenReportMap(report: com.chloemlla.lumen.crash.CrashReport): Map<String, Any?> {
        return mapOf(
            "recordId" to report.reportId,
            "timestamp" to report.crashedAtMillis,
            "source" to "android_uncaught",
            "severity" to "fatal",
            "module" to moduleFrom(report.exceptionType, report.stackTrace),
            "reason" to "uncaught_exception",
            "exceptionType" to report.exceptionType,
            "message" to report.rootCause,
            "threadName" to report.threadName,
            "processName" to report.processName,
            "stackTrace" to report.stackTrace,
            "systemInfo" to report.systemInfo,
            "recentEvents" to report.recentEvents,
            "authorName" to report.authorName,
            "authorUrl" to report.authorUrl,
            "authorFingerprint" to report.authorFingerprint,
            "capture" to "lumen_crash",
        )
    }

    private fun moduleFrom(exceptionType: String, stackTrace: String): String {
        for (line in stackTrace.lineSequence()) {
            val marker = "com.chloemlla.piliplus."
            val index = line.indexOf(marker)
            if (index < 0) continue
            val className = line.substring(index + marker.length)
                .substringBefore('(')
                .substringBefore('$')
                .substringBefore('#')
                .trim()
            if (className.isEmpty()) continue
            return className.substringBefore('.')
        }
        return exceptionType.substringAfterLast('.').ifBlank { "android" }
    }

    private companion object {
        const val CHANNEL_NAME = "pili_plus/native_crash"
    }
}
