package com.chloemlla.piliplus

import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.atomic.AtomicBoolean

@androidx.annotation.OptIn(markerClass = [ExperimentalGetImage::class])
internal class QrFrameAnalyzer(
    private val scanner: BarcodeScanner,
    private val onResult: (String) -> Unit,
    private val onRecoverableFailure: () -> Unit,
    private val onFatalFailure: (String, String, Throwable) -> Unit,
) : ImageAnalysis.Analyzer {
    private val processing = AtomicBoolean(false)
    private val closed = AtomicBoolean(false)
    private val scannerClosed = AtomicBoolean(false)

    override fun analyze(imageProxy: ImageProxy) {
        if (!processing.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }
        val mediaImage = imageProxy.image
        if (closed.get() || mediaImage == null) {
            processing.set(false)
            imageProxy.close()
            if (closed.get()) closeScanner()
            return
        }

        try {
            val image = InputImage.fromMediaImage(
                mediaImage,
                imageProxy.imageInfo.rotationDegrees,
            )
            scanner.process(image)
                .addOnSuccessListener { barcodes ->
                    if (closed.get()) return@addOnSuccessListener
                    val rawValue = barcodes.firstNotNullOfOrNull { barcode ->
                        barcode.rawValue?.takeIf {
                            barcode.format == Barcode.FORMAT_QR_CODE &&
                                it.isNotBlank()
                        }
                    }
                    if (rawValue != null) onResult(rawValue)
                }
                .addOnFailureListener {
                    if (!closed.get()) onRecoverableFailure()
                }
                .addOnCompleteListener {
                    processing.set(false)
                    imageProxy.close()
                    if (closed.get()) closeScanner()
                }
        } catch (exception: Exception) {
            failFrame(imageProxy, "scan_failed", "相机画面处理失败", exception)
        } catch (error: LinkageError) {
            failFrame(imageProxy, "scanner_unavailable", "二维码识别组件不可用", error)
        }
    }

    private fun failFrame(
        imageProxy: ImageProxy,
        code: String,
        fallback: String,
        error: Throwable,
    ) {
        processing.set(false)
        imageProxy.close()
        if (closed.get()) {
            closeScanner()
        } else {
            onFatalFailure(code, fallback, error)
        }
    }

    fun close() {
        closed.set(true)
        if (!processing.get()) closeScanner()
    }

    private fun closeScanner() {
        if (!scannerClosed.compareAndSet(false, true)) return
        try {
            scanner.close()
        } catch (_: Exception) {
            // Scanner cleanup must not terminate the app process.
        } catch (_: LinkageError) {
            // Native scanner cleanup must not terminate the app process.
        }
    }
}
