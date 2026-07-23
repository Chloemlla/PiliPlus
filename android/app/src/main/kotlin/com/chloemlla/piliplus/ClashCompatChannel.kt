package com.chloemlla.piliplus

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.getSystemService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Detect ClashMeta install/VPN state for zero-config traffic adaptation.
 * Events: "vpnChanged" with map { clashInstalled, vpnActive, clashVpnRunning, adapted }.
 */
internal class ClashCompatChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var lastVpnActive: Boolean? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        stopNetworkWatch()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getStatus" -> result.success(buildStatus())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("clash_compat_error", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startNetworkWatch()
        emitStatus()
    }

    override fun onCancel(arguments: Any?) {
        stopNetworkWatch()
        eventSink = null
    }

    private fun buildStatus(): Map<String, Any?> {
        val clashInstalled = isClashInstalled()
        val vpnActive = isVpnActive()
        val partner = queryPartnerStatus()
        val clashVpnRunning = partner?.get("vpnRunning") as? Boolean
            ?: (clashInstalled && vpnActive)
        return mapOf(
            "clashInstalled" to clashInstalled,
            "vpnActive" to vpnActive,
            "clashVpnRunning" to clashVpnRunning,
            "clashPackage" to partner?.get("package"),
            "profileName" to partner?.get("name"),
        )
    }

    private fun emitStatus() {
        val sink = eventSink ?: return
        val status = buildStatus()
        mainHandler.post {
            sink.success(status)
        }
    }

    private fun startNetworkWatch() {
        if (networkCallback != null) return
        val cm = context.getSystemService<ConnectivityManager>() ?: return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = onNetworkMaybeChanged()
            override fun onLost(network: Network) = onNetworkMaybeChanged()
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities,
            ) = onNetworkMaybeChanged()
        }
        networkCallback = callback
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_VPN)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        runCatching {
            cm.registerNetworkCallback(request, callback)
        }.onFailure {
            // Fallback: listen to default network changes
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    cm.registerDefaultNetworkCallback(callback)
                }
            }
        }
    }

    private fun stopNetworkWatch() {
        val callback = networkCallback ?: return
        networkCallback = null
        val cm = context.getSystemService<ConnectivityManager>() ?: return
        runCatching { cm.unregisterNetworkCallback(callback) }
    }

    private fun onNetworkMaybeChanged() {
        val vpnActive = isVpnActive()
        if (lastVpnActive == vpnActive) return
        lastVpnActive = vpnActive
        emitStatus()
    }

    private fun isVpnActive(): Boolean {
        val cm = context.getSystemService<ConnectivityManager>() ?: return false
        val networks = cm.allNetworks
        for (network in networks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                return true
            }
        }
        return false
    }

    private fun isClashInstalled(): Boolean {
        val pm = context.packageManager
        return CLASH_PACKAGES.any { pkg ->
            try {
                pm.getApplicationInfo(pkg, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    private fun queryPartnerStatus(): Map<String, Any?>? {
        val resolver = context.contentResolver
        for (pkg in CLASH_PACKAGES) {
            val uri = Uri.Builder()
                .scheme("content")
                .authority("$pkg.status")
                .build()
            val bundle = runCatching {
                resolver.call(uri, METHOD_PARTNER_STATUS, null, null)
            }.getOrNull() ?: continue
            return mapOf(
                "running" to (bundle.getBoolean("running", false)),
                "vpnRunning" to (bundle.getBoolean("vpnRunning", false)),
                "name" to bundle.getString("name"),
                "package" to (bundle.getString("package") ?: pkg),
            )
        }
        return null
    }

    companion object {
        const val METHOD_CHANNEL = "pili_plus/clash_compat"
        const val EVENT_CHANNEL = "pili_plus/clash_compat_events"
        private const val METHOD_PARTNER_STATUS = "partnerStatus"

        private val CLASH_PACKAGES = listOf(
            "com.github.metacubex.clash",
            "com.github.metacubex.clash.meta",
            "com.github.metacubex.clash.alpha",
        )
    }
}
