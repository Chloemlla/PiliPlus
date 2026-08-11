package com.chloemlla.piliplus

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class SynapseClientDetectChannel(
    private val applicationContext: android.content.Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSynapseClientInstalled" -> result.success(isInstalled())
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun isInstalled(): Boolean {
        val pm = applicationContext.packageManager
        return SYNAPSE_PACKAGES.any { packageName ->
            try {
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
    }

    private companion object {
        const val CHANNEL_NAME = "pili_plus/synapse_client_detect"
        val SYNAPSE_PACKAGES = listOf(
            "com.chloemlla.synapse.mobile",
            "com.synapse.mobile",
        )
    }
}