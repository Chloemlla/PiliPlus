package com.chloemlla.piliplus

import android.content.Context
import android.net.Uri
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors

internal object QrBarcodeDecoder {
    fun decodeImage(
        context: Context,
        uri: Uri,
        onSuccess: (String?) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val appContext = context.applicationContext
        val executor = Executors.newSingleThreadExecutor()
        val mainExecutor = ContextCompat.getMainExecutor(context)
        executor.execute {
            var scanner: BarcodeScanner? = null
            try {
                val inputImage = InputImage.fromFilePath(appContext, uri)
                val options = BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                    .build()
                val client = BarcodeScanning.getClient(options)
                scanner = client
                client.process(inputImage).addOnSuccessListener(mainExecutor) { barcodes ->
                    val value = barcodes.firstOrNull { it.format == Barcode.FORMAT_QR_CODE }?.rawValue
                        ?: barcodes.firstOrNull()?.rawValue
                    onSuccess(value?.takeIf(String::isNotBlank))
                    client.close()
                }.addOnFailureListener(mainExecutor) { e ->
                    onError(e)
                    client.close()
                }
                scanner = null
            } catch (error: Throwable) {
                runCatching { scanner?.close() }
                mainExecutor.execute { onError(error) }
            } finally {
                executor.shutdown()
            }
        }
    }
}
