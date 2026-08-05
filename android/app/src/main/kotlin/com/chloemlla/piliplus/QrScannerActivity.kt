package com.chloemlla.piliplus

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.core.content.ContextCompat
import com.huawei.hms.hmsscankit.RemoteView
import com.huawei.hms.ml.scan.HmsScan
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Camera QR scanner backed by Huawei HMS Scan Kit [RemoteView].
 *
 * Scan Kit free/public SDK path (`com.huawei.hms:scanplus`) does not require
 * `agconnect-services.json` or the AGConnect Gradle plugin. Recognition works
 * without a full HMS Core account on generic Android devices; optional HMS Core
 * on Huawei devices may still accelerate decoding when present.
 */
class QrScannerActivity : ComponentActivity() {
    private val delivered = AtomicBoolean(false)
    private val destroyed = AtomicBoolean(false)

    private var remoteView: RemoteView? = null
    private lateinit var statusText: TextView
    private lateinit var torchButton: TextView
    private var torchEnabled = false
    private var lightControlVisible = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    cancelScan()
                }
            },
        )
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            finishWithError("permission_denied", "未获得相机权限")
            return
        }
        try {
            setContentView(buildContentView(savedInstanceState))
        } catch (exception: Exception) {
            finishWithScannerError("camera_unavailable", "无法打开扫码界面", exception)
            return
        } catch (error: LinkageError) {
            finishWithScannerError("camera_unavailable", "扫码界面组件不可用", error)
            return
        }
    }

    override fun onStart() {
        super.onStart()
        try {
            remoteView?.onStart()
        } catch (error: Throwable) {
            finishWithScannerError("camera_unavailable", "无法启动扫码预览", error)
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            remoteView?.onResume()
        } catch (error: Throwable) {
            finishWithScannerError("camera_unavailable", "无法恢复扫码预览", error)
        }
    }

    override fun onPause() {
        try {
            remoteView?.onPause()
        } catch (_: Throwable) {
            // Best-effort pause while tearing down.
        }
        super.onPause()
    }

    override fun onStop() {
        try {
            remoteView?.onStop()
        } catch (_: Throwable) {
            // Best-effort stop while tearing down.
        }
        super.onStop()
    }

    override fun onDestroy() {
        destroyed.set(true)
        try {
            remoteView?.onDestroy()
        } catch (_: Throwable) {
            // RemoteView may already be released after OEM/camera failures.
        }
        remoteView = null
        super.onDestroy()
    }

    private fun buildContentView(savedInstanceState: Bundle?): FrameLayout {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        val previewHost = FrameLayout(this)
        root.addView(previewHost, matchParentLayoutParams())
        root.addView(QrScanOverlayView(this), matchParentLayoutParams())

        val closeButton = actionButton("关闭").apply {
            setOnClickListener { cancelScan() }
        }
        root.addView(
            closeButton,
            FrameLayout.LayoutParams(wrapContent, wrapContent, Gravity.TOP or Gravity.START).apply {
                setMargins(dp(16), dp(18), 0, 0)
            },
        )

        torchButton = actionButton("手电筒").apply {
            isEnabled = false
            alpha = 0.5f
            setOnClickListener { toggleTorch() }
        }
        root.addView(
            torchButton,
            FrameLayout.LayoutParams(wrapContent, wrapContent, Gravity.TOP or Gravity.END).apply {
                setMargins(0, dp(18), dp(16), 0)
            },
        )

        statusText = TextView(this).apply {
            text = "将 B 站网页登录二维码放入框内"
            setTextColor(Color.WHITE)
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(12), dp(24), dp(12))
        }
        root.addView(
            statusText,
            FrameLayout.LayoutParams(matchParent, wrapContent, Gravity.BOTTOM).apply {
                setMargins(dp(16), 0, dp(16), dp(36))
            },
        )

        remoteView = createRemoteView(savedInstanceState).also { view ->
            previewHost.addView(
                view,
                FrameLayout.LayoutParams(matchParent, matchParent),
            )
        }
        return root
    }

    private fun createRemoteView(savedInstanceState: Bundle?): RemoteView {
        val metrics = resources.displayMetrics
        val scanFrameSize = (SCAN_FRAME_SIZE_DP * metrics.density).toInt()
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val rect = Rect(
            width / 2 - scanFrameSize / 2,
            height / 2 - scanFrameSize / 2,
            width / 2 + scanFrameSize / 2,
            height / 2 + scanFrameSize / 2,
        )
        val view = RemoteView.Builder()
            .setContext(this)
            .setBoundingBox(rect)
            .setFormat(HmsScan.QRCODE_SCAN_TYPE)
            .build()
        view.setOnLightVisibleCallback { visible ->
            if (destroyed.get() || isFinishing || isDestroyed) return@setOnLightVisibleCallback
            lightControlVisible = visible || torchEnabled
            torchButton.isEnabled = lightControlVisible
            torchButton.alpha = if (lightControlVisible) 1f else 0.5f
        }
        view.setOnResultCallback { results ->
            val value = results
                ?.firstOrNull()
                ?.originalValue
                ?.takeIf(String::isNotBlank)
            if (value != null) {
                finishWithResult(value)
            }
        }
        view.onCreate(savedInstanceState)
        // Torch may be available even before low-light callback fires.
        torchButton.isEnabled = true
        torchButton.alpha = 1f
        lightControlVisible = true
        return view
    }

    private fun toggleTorch() {
        val view = remoteView ?: return
        try {
            view.switchLight()
            torchEnabled = view.lightStatus
            torchButton.text = if (torchEnabled) "关闭手电筒" else "手电筒"
        } catch (exception: Exception) {
            torchEnabled = false
            torchButton.text = "手电筒"
            statusText.text = exception.message ?: "无法控制手电筒"
        } catch (error: LinkageError) {
            finishWithScannerError("scanner_unavailable", "手电筒组件不可用", error)
        }
    }

    private fun finishWithScannerError(code: String, fallback: String, error: Throwable) {
        Log.e(TAG, fallback, error)
        if (Looper.myLooper() == Looper.getMainLooper()) {
            finishWithError(code, fallback)
        } else {
            runOnUiThread { finishWithError(code, fallback) }
        }
    }

    private fun finishWithResult(value: String) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            runOnUiThread { finishWithResult(value) }
            return
        }
        if (destroyed.get() || isFinishing || isDestroyed ||
            !delivered.compareAndSet(false, true)
        ) return
        setResult(Activity.RESULT_OK, Intent().putExtra(EXTRA_QR_VALUE, value))
        finish()
    }

    private fun finishWithError(code: String, message: String) {
        if (destroyed.get() || isFinishing || isDestroyed ||
            !delivered.compareAndSet(false, true)
        ) return
        setResult(
            RESULT_ERROR,
            Intent()
                .putExtra(EXTRA_ERROR_CODE, code)
                .putExtra(EXTRA_ERROR_MESSAGE, message),
        )
        finish()
    }

    private fun cancelScan() {
        if (destroyed.get() || isFinishing || isDestroyed ||
            !delivered.compareAndSet(false, true)
        ) return
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    private fun actionButton(label: String) = TextView(this).apply {
        text = label
        setTextColor(Color.WHITE)
        textSize = 15f
        gravity = Gravity.CENTER
        setPadding(dp(16), dp(10), dp(16), dp(10))
        background = GradientDrawable().apply {
            setColor(0x88000000.toInt())
            cornerRadius = dp(22).toFloat()
        }
    }

    private fun matchParentLayoutParams() = FrameLayout.LayoutParams(matchParent, matchParent)
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_QR_VALUE = "qr_value"
        const val EXTRA_ERROR_CODE = "error_code"
        const val EXTRA_ERROR_MESSAGE = "error_message"
        const val RESULT_ERROR = Activity.RESULT_FIRST_USER + 1

        private const val TAG = "QrScannerActivity"
        private const val SCAN_FRAME_SIZE_DP = 240
        private const val matchParent = ViewGroup.LayoutParams.MATCH_PARENT
        private const val wrapContent = ViewGroup.LayoutParams.WRAP_CONTENT
    }
}
