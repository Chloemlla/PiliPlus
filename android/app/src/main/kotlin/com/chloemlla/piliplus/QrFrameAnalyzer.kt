package com.chloemlla.piliplus

import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy

internal class QrFrameAnalyzer(
    private val onResult: (String) -> Unit,
    private val onRecoverableFailure: () -> Unit,
    private val onFatalFailure: (String, String, Throwable) -> Unit,
) : ImageAnalysis.Analyzer {
    private val decoder = ZxingQrDecoder()

    @Volatile
    private var closed = false

    override fun analyze(imageProxy: ImageProxy) {
        if (closed) {
            imageProxy.close()
            return
        }
        try {
            val rawValue = decoder.decode(imageProxy)
            if (!closed && rawValue != null) onResult(rawValue)
        } catch (exception: Exception) {
            if (!closed) onRecoverableFailure()
        } catch (error: LinkageError) {
            if (!closed) {
                onFatalFailure("scanner_unavailable", "二维码识别组件不可用", error)
            }
        } finally {
            imageProxy.close()
        }
    }

    fun close() {
        closed = true
    }
}
