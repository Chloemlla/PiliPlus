package com.chloemlla.piliplus

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

@androidx.annotation.OptIn(markerClass = [ExperimentalGetImage::class])
class QrScannerActivity : ComponentActivity() {
    private val analyzerExecutor = Executors.newSingleThreadExecutor()
    private val processing = AtomicBoolean(false)
    private val delivered = AtomicBoolean(false)
    private val destroyed = AtomicBoolean(false)
    private val scanner: BarcodeScanner = QrBarcodeDecoder.createScanner()

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var imageAnalysis: ImageAnalysis? = null
    private lateinit var statusText: TextView
    private lateinit var torchButton: TextView
    private var torchEnabled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContentView())
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
        imageAnalysis?.clearAnalyzer()
        cameraProvider?.unbindAll()
        scanner.close()
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
                    analysis.setAnalyzer(analyzerExecutor) { imageProxy ->
                        val mediaImage = imageProxy.image
                        if (mediaImage == null || !processing.compareAndSet(false, true)) {
                            imageProxy.close()
                            return@setAnalyzer
                        }
                        val image = InputImage.fromMediaImage(
                            mediaImage,
                            imageProxy.imageInfo.rotationDegrees,
                        )
                        scanner.process(image)
                            .addOnSuccessListener { barcodes ->
                                if (destroyed.get() || isFinishing || isDestroyed) {
                                    return@addOnSuccessListener
                                }
                                val rawValue = barcodes.firstNotNullOfOrNull {
                                    it.rawValue?.takeIf(String::isNotBlank)
                                }
                                if (rawValue != null) finishWithResult(rawValue)
                            }
                            .addOnFailureListener {
                                if (!destroyed.get() && !isFinishing && !isDestroyed) {
                                    runOnUiThread {
                                        statusText.text = "识别失败，请调整距离后重试"
                                    }
                                }
                            }
                            .addOnCompleteListener {
                                processing.set(false)
                                imageProxy.close()
                            }
                    }
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
                    finishWithError(
                        "camera_unavailable",
                        exception.message ?: "无法连接相机",
                    )
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun toggleTorch() {
        val activeCamera = camera ?: return
        torchEnabled = !torchEnabled
        activeCamera.cameraControl.enableTorch(torchEnabled)
        torchButton.text = if (torchEnabled) "关闭手电筒" else "手电筒"
    }

    private fun finishWithResult(value: String) {
        if (destroyed.get() || isFinishing || isDestroyed ||
            !delivered.compareAndSet(false, true)
        ) return
        imageAnalysis?.clearAnalyzer()
        cameraProvider?.unbindAll()
        setResult(Activity.RESULT_OK, Intent().putExtra(EXTRA_QR_VALUE, value))
        finish()
    }

    private fun finishWithError(code: String, message: String) {
        if (!delivered.compareAndSet(false, true)) return
        setResult(
            RESULT_ERROR,
            Intent()
                .putExtra(EXTRA_ERROR_CODE, code)
                .putExtra(EXTRA_ERROR_MESSAGE, message),
        )
        finish()
    }

    private fun cancelScan() {
        if (!delivered.compareAndSet(false, true)) return
        imageAnalysis?.clearAnalyzer()
        cameraProvider?.unbindAll()
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
