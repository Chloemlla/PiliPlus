package com.chloemlla.piliplus

import android.content.Context
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
                "acknowledgeReports" -> {
                    val recordIds = call.argument<List<*>>("recordIds")
                        ?.filterIsInstance<String>()
                        ?: emptyList()
                    NativeCrashStore.acknowledge(context, recordIds)
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

    private companion object {
        const val CHANNEL_NAME = "pili_plus/native_crash"
    }
}
