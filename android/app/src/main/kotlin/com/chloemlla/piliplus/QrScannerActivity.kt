package com.chloemlla.piliplus

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class QrScannerActivity : ComponentActivity() {
    private val analyzerExecutor = Executors.newSingleThreadExecutor()
    private val delivered = AtomicBoolean(false)
    private val destroyed = AtomicBoolean(false)

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var scanner: BarcodeScanner? = null
    private var frameAnalyzer: QrFrameAnalyzer? = null
    private lateinit var statusText: TextView
    private lateinit var torchButton: TextView
    private var torchEnabled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            setContentView(buildContentView())
        } catch (exception: Exception) {
            finishWithScannerError("camera_unavailable", "无法打开扫码界面", exception)
            return
        } catch (error: LinkageError) {
            finishWithScannerError("camera_unavailable", "扫码界面组件不可用", error)
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            finishWithError("permission_denied", "未获得相机权限")
            return
        }
        startCamera()
    }

    override fun onDestroy() {
        destroyed.set(true)
        releaseCamera()
        frameAnalyzer?.close()
        frameAnalyzer = null
        try {
            scanner?.close()
        } catch (_: Exception) {
            // The Activity is already being destroyed; do not crash during cleanup.
        } catch (_: LinkageError) {
            // Native scanner cleanup must not terminate the app process.
        }
        scanner = null
        analyzerExecutor.shutdownNow()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        cancelScan()
    }

    private fun buildContentView(): FrameLayout {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        val previewView = PreviewView(this).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
            id = PREVIEW_VIEW_ID
        }
        root.addView(previewView, matchParentLayoutParams())
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
        return root
    }

    private fun startCamera() {
        val previewView = findViewById<PreviewView>(PREVIEW_VIEW_ID)
        try {
            val providerFuture = ProcessCameraProvider.getInstance(this)
            providerFuture.addListener(
                {
                    if (destroyed.get() || isFinishing || isDestroyed) {
                        return@addListener
                    }
                    try {
                        val provider = providerFuture.get()
                        cameraProvider = provider
                        val preview = Preview.Builder().build().also {
                            it.setSurfaceProvider(previewView.surfaceProvider)
                        }
                        val analysis = ImageAnalysis.Builder()
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                        imageAnalysis = analysis
                        val activeScanner = createScannerOrFinish()
                            ?: return@addListener
                        scanner = activeScanner
                        val analyzer = QrFrameAnalyzer(
                            scanner = activeScanner,
                            onResult = ::finishWithResult,
                            onRecoverableFailure = {
                                runOnUiThread {
                                    if (!destroyed.get() && !isFinishing && !isDestroyed) {
                                        statusText.text = "识别失败，请调整距离后重试"
                                    }
                                }
                            },
                            onFatalFailure = ::finishWithScannerError,
                        )
                        frameAnalyzer = analyzer
                        scanner = null
                        analysis.setAnalyzer(
                            analyzerExecutor,
                            analyzer,
                        )
                        provider.unbindAll()
                        if (destroyed.get() || isFinishing || isDestroyed) {
                            analysis.clearAnalyzer()
                            return@addListener
                        }
                        camera = provider.bindToLifecycle(
                            this,
                            CameraSelector.DEFAULT_BACK_CAMERA,
                            preview,
                            analysis,
                        )
                        val hasFlash = camera?.cameraInfo?.hasFlashUnit() == true
                        torchButton.isEnabled = hasFlash
                        torchButton.alpha = if (hasFlash) 1f else 0.5f
                    } catch (exception: Exception) {
                        bindCameraFailure(exception)
                    } catch (error: LinkageError) {
                        bindCameraFailure(error)
                    }
                },
                ContextCompat.getMainExecutor(this),
            )
        } catch (exception: Exception) {
            finishWithScannerError(
                "camera_unavailable",
                "无法连接相机",
                exception,
            )
        } catch (error: LinkageError) {
            finishWithScannerError(
                "camera_unavailable",
                "相机组件不可用",
                error,
            )
        }
    }

    private fun bindCameraFailure(error: Throwable) {
        finishWithScannerError(
            "camera_unavailable",
            "无法连接相机",
            error,
        )
    }

    private fun createScannerOrFinish(): BarcodeScanner? {
        return try {
            QrBarcodeDecoder.createScanner()
        } catch (exception: Exception) {
            finishWithScannerError(
                "scanner_unavailable",
                "无法初始化二维码识别器",
                exception,
            )
            null
        } catch (error: LinkageError) {
            finishWithScannerError(
                "scanner_unavailable",
                "二维码识别组件不可用",
                error,
            )
            null
        }
    }

    private fun finishWithScannerError(code: String, fallback: String, error: Throwable) {
        val message = error.message?.takeIf(String::isNotBlank) ?: fallback
        if (Looper.myLooper() == Looper.getMainLooper()) {
            finishWithError(code, message)
        } else {
            runOnUiThread { finishWithError(code, message) }
        }
    }

    private fun releaseCamera() {
        try {
            imageAnalysis?.clearAnalyzer()
        } catch (_: Exception) {
            // Continue releasing the remaining camera resources.
        } catch (_: LinkageError) {
            // Continue releasing the remaining camera resources.
        }
        try {
            cameraProvider?.unbindAll()
        } catch (_: Exception) {
            // The provider may already be shutting down after an OEM camera failure.
        } catch (_: LinkageError) {
            // CameraX may be partially initialized after a linkage failure.
        }
        imageAnalysis = null
        camera = null
        cameraProvider = null
    }

    private fun toggleTorch() {
        val activeCamera = camera ?: return
        torchEnabled = !torchEnabled
        try {
            activeCamera.cameraControl.enableTorch(torchEnabled)
            torchButton.text = if (torchEnabled) "关闭手电筒" else "手电筒"
        } catch (exception: Exception) {
            torchEnabled = false
            torchButton.text = "手电筒"
            statusText.text = exception.message ?: "无法控制手电筒"
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
        releaseCamera()
        setResult(Activity.RESULT_OK, Intent().putExtra(EXTRA_QR_VALUE, value))
        finish()
    }

    private fun finishWithError(code: String, message: String) {
        if (destroyed.get() || isFinishing || isDestroyed ||
            !delivered.compareAndSet(false, true)
        ) return
        releaseCamera()
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
        releaseCamera()
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

        private const val PREVIEW_VIEW_ID = 0x7103
        private const val matchParent = ViewGroup.LayoutParams.MATCH_PARENT
        private const val wrapContent = ViewGroup.LayoutParams.WRAP_CONTENT
    }
}
