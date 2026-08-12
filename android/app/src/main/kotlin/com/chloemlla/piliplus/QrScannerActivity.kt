package com.chloemlla.piliplus

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
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
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Camera QR scanner backed by Google ML Kit barcode scanning.
 *
 * Camera preview is provided by CameraX [PreviewView]; QR codes are decoded with
 * ML Kit (`com.google.mlkit:barcode-scanning`) and reported back to the Flutter
 * side through the result extras declared in the companion object.
 */
class QrScannerActivity : ComponentActivity() {
    private val delivered = AtomicBoolean(false)
    private val destroyed = AtomicBoolean(false)

    private lateinit var previewView: PreviewView
    private var scanner: BarcodeScanner? = null
    private var camera: Camera? = null
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private lateinit var statusText: TextView
    private lateinit var torchButton: TextView
    private var torchEnabled = false

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
            setContentView(buildContentView())
            bindCamera()
        } catch (exception: Exception) {
            finishWithScannerError("camera_unavailable", "无法打开扫码界面", exception)
            return
        } catch (error: LinkageError) {
            finishWithScannerError("camera_unavailable", "扫码界面组件不可用", error)
            return
        }
    }

    override fun onDestroy() {
        destroyed.set(true)
        scanner?.close()
        analysisExecutor.shutdown()
        super.onDestroy()
    }

    private fun bindCamera() {
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener(
            {
                if (destroyed.get() || isFinishing || isDestroyed) return@addListener
                runCatching { providerFuture.get() }
                    .onFailure {
                        finishWithScannerError("camera_unavailable", "无法启动扫码预览", it)
                    }
                    .onSuccess { provider ->
                        val preview = Preview.Builder().build().also {
                            it.setSurfaceProvider(previewView.surfaceProvider)
                        }
                        val analysis = ImageAnalysis.Builder()
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                            .also { it.setAnalyzer(analysisExecutor, ::analyze) }
                        camera = provider.bindToLifecycle(
                            this,
                            CameraSelector.DEFAULT_BACK_CAMERA,
                            preview,
                            analysis,
                        )
                        val hasFlash = camera?.cameraInfo?.hasFlashUnit() == true
                        torchButton.isEnabled = hasFlash
                        torchButton.alpha = if (hasFlash) 1f else 0.5f
                        scanner = BarcodeScanning.getClient()
                    }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun analyze(image: ImageProxy) {
        if (destroyed.get()) {
            image.close()
            return
        }
        val mediaImage = image.image
        if (mediaImage == null) {
            image.close()
            return
        }
        val input = InputImage.fromMediaImage(mediaImage, image.imageInfo.rotationDegrees)
        val task = scanner?.process(input)
        if (task == null) {
            image.close()
            return
        }
        task.addOnSuccessListener { barcodes ->
            val value = barcodes.firstOrNull { it.format == Barcode.FORMAT_QR_CODE }?.rawValue
                ?: barcodes.firstOrNull()?.rawValue
            if (!value.isNullOrBlank()) {
                runOnUiThread { finishWithResult(value) }
            }
        }.addOnFailureListener {
            // Ignore decode failures; keep scanning.
        }.addOnCompleteListener {
            image.close()
        }
    }

    private fun buildContentView(): FrameLayout {
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

        previewView = PreviewView(this)
        previewHost.addView(previewView, FrameLayout.LayoutParams(matchParent, matchParent))
        return root
    }

    private fun toggleTorch() {
        val cam = camera ?: return
        try {
            if (!cam.cameraInfo.hasFlashUnit()) {
                statusText.text = "此设备不支持手电筒"
                return
            }
            val future = cam.cameraControl.enableTorch(!torchEnabled)
            future.addListener(
                {
                    runCatching { future.get() }
                        .onSuccess {
                            torchEnabled = !torchEnabled
                            torchButton.text = if (torchEnabled) "关闭手电筒" else "手电筒"
                        }
                        .onFailure {
                            statusText.text = "无法控制手电筒"
                        }
                },
                ContextCompat.getMainExecutor(this),
            )
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
        private const val matchParent = ViewGroup.LayoutParams.MATCH_PARENT
        private const val wrapContent = ViewGroup.LayoutParams.WRAP_CONTENT
    }
}
