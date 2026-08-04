package com.chloemlla.piliplus

import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.edit
import androidx.core.content.getSystemService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Detect ClashMeta install/VPN state for zero-config traffic adaptation.
 *
 * Binds this process to the active VPN network while auto-adapt + Clash routing
 * are enabled so Flutter/Dio/media_kit sockets cannot escape the tunnel via
 * non-VPN network requests. Clears binding when Clash is off or adapt is disabled.
 *
 * Events: status map with clashInstalled / vpnActive / clashVpnRunning / etc.
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
    private var lastVpnNetwork: Network? = null
    private var boundVpnNetwork: Network? = null
    private var lastPartnerStatusAvailable: Boolean? = null
    private var partnerWatchHandler: Handler? = null
    private val partnerWatchRunnable = Runnable { checkPartnerStatus() }
    private var partnerWatchRunning = false
    private var partnerWatchIntervalMs = PARTNER_WATCH_INITIAL_MS

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        stopNetworkWatch()
        stopPartnerWatch()
        clearProcessNetworkBinding()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getStatus" -> {
                    // Always re-evaluate binding so cold refresh also sticks process.
                    val status = buildStatus()
                    applyVpnProcessBinding(status)
                    result.success(buildStatus())
                }
                "setAutoAdaptEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error(
                            "invalid_args",
                            "Missing boolean argument 'enabled'",
                            null,
                        )
                        return
                    }
                    setAutoAdaptEnabled(enabled)
                    result.success(buildStatus())
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("clash_compat_error", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startNetworkWatch()
        startPartnerWatch()
        // Apply binding for current state as soon as Dart starts listening.
        applyVpnProcessBinding(buildStatus())
        emitStatus()
    }

    override fun onCancel(arguments: Any?) {
        // Keep network watch + process binding alive even if Flutter cancels
        // the event stream; only dispose() tears them down.
        stopPartnerWatch()
        eventSink = null
    }

    private fun buildStatus(): Map<String, Any?> {
        val clashInstalled = isClashInstalled()
        val vpnActive = isVpnActive()
        val partner = queryPartnerStatus()
        val partnerStatusAvailable = partner != null
        // Prefer provider truth when available so a non-Clash VPN is not treated
        // as "Clash routing". When the partner was previously reachable but is
        // now gone, the Clash process was killed — do not use the fallback
        // heuristic because the VPN network may still be briefly active.
        val clashVpnRunning =
            if (partnerStatusAvailable) {
                partner?.get("vpnRunning") as? Boolean ?: false
            } else if (lastPartnerStatusAvailable == true) {
                false
            } else {
                clashInstalled && vpnActive
            }
        val autoAdaptEnabled = isAutoAdaptEnabled()
        val processBound = boundVpnNetwork != null
        return mapOf(
            "clashInstalled" to clashInstalled,
            "vpnActive" to vpnActive,
            "clashVpnRunning" to clashVpnRunning,
            "partnerAppAutoAdapt" to (
                partner?.get("partnerAppAutoAdapt") as? Boolean
                    ?: partner?.get("piliPlusAutoAdapt") as? Boolean
                    ?: true
                ),
            "partnerStatusAvailable" to partnerStatusAvailable,
            "profileName" to partner?.get("name"),
            "clashPackage" to partner?.get("package"),
            "processBound" to processBound,
            "autoAdaptEnabled" to autoAdaptEnabled,
        )
    }

    private fun isClashVpnRouting(status: Map<String, Any?>): Boolean =
        status["clashVpnRunning"] == true

    private fun emitStatus() {
        val status = buildStatus()
        // Always re-evaluate process binding on every status rebuild so VPN
        // Network handle replacements and auto-adapt toggles are applied —
        // even when no EventChannel sink is attached yet.
        applyVpnProcessBinding(status)
        val snapshot = buildStatus()
        val sink = eventSink ?: return
        mainHandler.post {
            sink.success(snapshot)
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
        val cm = context.getSystemService<ConnectivityManager>()
        val vpnActive = isVpnActive()
        val vpnNetwork = cm?.let { findVpnNetwork(it) }
        // Re-evaluate when VPN goes up/down *or* the underlying Network handle
        // is replaced (Clash restart / re-establish) so process binding follows.
        if (lastVpnActive == vpnActive && lastVpnNetwork == vpnNetwork) return
        val wasActive = lastVpnActive == true
        lastVpnActive = vpnActive
        lastVpnNetwork = vpnNetwork
        // Restart partner watch when VPN becomes active (Clash may have started).
        if (vpnActive && !wasActive && !partnerWatchRunning) {
            startPartnerWatch()
        }
        emitStatus()
    }

    /**
     * Periodically check whether the Clash partner status provider is still
     * reachable. When a previously available partner disappears (process killed)
     * without the VPN network being torn down first, the ConnectivityManager
     * callback alone would miss the event and the Dart side would never learn
     * that Clash stopped routing.
     *
     * Uses adaptive polling: aggressive (2s) initially, backing off to 5s then
     * 10s once the partner has been stable for several cycles.
     */
    private fun checkPartnerStatus() {
        partnerWatchRunning = false
        val available = queryPartnerStatus() != null
        val changed = lastPartnerStatusAvailable != null &&
            lastPartnerStatusAvailable != available
        lastPartnerStatusAvailable = available
        if (changed) {
            // Partner became available or unavailable — reset interval for
            // aggressive re-check.
            partnerWatchIntervalMs = PARTNER_WATCH_INITIAL_MS
            emitStatus()
            if (available) {
                schedulePartnerWatch()
            }
            return
        }
        // Keep polling while the partner is still reachable, with adaptive
        // backoff: after a stable cycle, lengthen the interval.
        if (available) {
            partnerWatchIntervalMs = (partnerWatchIntervalMs * 1.5).toLong()
                .coerceAtMost(PARTNER_WATCH_MAX_MS)
            schedulePartnerWatch()
        }
    }

    private fun schedulePartnerWatch() {
        if (partnerWatchRunning) return
        partnerWatchRunning = true
        val handler = partnerWatchHandler ?: Handler(Looper.getMainLooper()).also {
            partnerWatchHandler = it
        }
        handler.postDelayed(partnerWatchRunnable, partnerWatchIntervalMs)
    }

    private fun startPartnerWatch() {
        lastPartnerStatusAvailable = queryPartnerStatus() != null
        if (lastPartnerStatusAvailable == true) {
            schedulePartnerWatch()
        }
    }

    private fun stopPartnerWatch() {
        partnerWatchRunning = false
        partnerWatchHandler?.removeCallbacks(partnerWatchRunnable)
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
            // Check apiVersion for forward compatibility. If the schema is
            // newer than what we understand, we can still read the fields we
            // know about (older clients already omit unknown fields gracefully).
            val apiVersion = bundle.getInt("apiVersion", 0)
            return mapOf(
                "apiVersion" to apiVersion,
                "running" to bundle.getBoolean("running", false),
                "vpnRunning" to bundle.getBoolean("vpnRunning", false),
                "partnerAppAutoAdapt" to bundle.getBoolean(
                    "partnerAppAutoAdapt",
                    bundle.getBoolean("piliPlusAutoAdapt", true),
                ),
                "piliPlusAutoAdapt" to bundle.getBoolean("piliPlusAutoAdapt", true),
                "name" to bundle.getString("name"),
                "package" to (bundle.getString("package") ?: pkg),
                "mode" to bundle.getString("mode"),
                "selectedNode" to bundle.getString("selectedNode"),
                "upTotal" to bundle.getLong("upTotal", 0L),
                "downTotal" to bundle.getLong("downTotal", 0L),
            )
        }
        return null
    }

    private fun prefs(): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun isAutoAdaptEnabled(): Boolean =
        prefs().getBoolean(KEY_AUTO_ADAPT, true)

    private fun setAutoAdaptEnabled(enabled: Boolean) {
        prefs().edit { putBoolean(KEY_AUTO_ADAPT, enabled) }
        // Rebind immediately so toggle takes effect without waiting for VPN event.
        // emitStatus applies binding even when the EventChannel sink is null.
        emitStatus()
    }

    /**
     * Bind (or unbind) this process to the active VPN network while Clash is
     * routing and auto-adapt is enabled. Without this, non-VPN network
     * requests / allowBypass paths can let Dart IO leave the tunnel.
     */
    private fun applyVpnProcessBinding(status: Map<String, Any?>) {
        val cm = context.getSystemService<ConnectivityManager>() ?: return
        val autoAdapt = status["autoAdaptEnabled"] == true
        if (!autoAdapt || !isClashVpnRouting(status)) {
            clearProcessNetworkBinding(cm)
            return
        }
        val vpn = findVpnNetwork(cm)
        if (vpn == null) {
            // Status says routing but no VPN Network is visible yet — drop any
            // stale binding so we do not stick to a dead Network handle.
            clearProcessNetworkBinding(cm)
            return
        }
        if (boundVpnNetwork == vpn) return
        runCatching {
            cm.bindProcessToNetwork(vpn)
            boundVpnNetwork = vpn
        }.onFailure {
            boundVpnNetwork = null
        }
    }

    private fun clearProcessNetworkBinding(cm: ConnectivityManager? = null) {
        val manager = cm ?: context.getSystemService<ConnectivityManager>() ?: return
        if (boundVpnNetwork == null && manager.boundNetworkForProcess == null) return
        runCatching { manager.bindProcessToNetwork(null) }
        boundVpnNetwork = null
    }

    private fun findVpnNetwork(cm: ConnectivityManager): Network? {
        for (network in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                return network
            }
        }
        return null
    }

    companion object {
        const val METHOD_CHANNEL = "pili_plus/clash_compat"
        const val EVENT_CHANNEL = "pili_plus/clash_compat_events"
        private const val METHOD_PARTNER_STATUS = "partnerStatus"
        private const val PREFS = "clash_partner_compat"
        private const val KEY_AUTO_ADAPT = "clash_auto_adapt"
        private const val PARTNER_WATCH_INITIAL_MS = 2000L
        private const val PARTNER_WATCH_MAX_MS = 10000L

        private val CLASH_PACKAGES = listOf(
            "com.github.metacubex.clash",
            "com.github.metacubex.clash.meta",
            "com.github.metacubex.clash.alpha",
        )
    }
}
