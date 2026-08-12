package com.chloemlla.piliplus

import android.content.Context
import android.net.Uri
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScanning
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
            try {
                val inputImage = InputImage.fromFilePath(appContext, uri)
                val scanner = BarcodeScanning.getClient()
                scanner.process(inputImage).addOnSuccessListener(mainExecutor) { barcodes ->
                    val value = barcodes.firstOrNull { it.format == Barcode.FORMAT_QR_CODE }?.rawValue
                        ?: barcodes.firstOrNull()?.rawValue
                    onSuccess(value?.takeIf(String::isNotBlank))
                    scanner.close()
                }.addOnFailureListener(mainExecutor) { e ->
                    onError(e)
                    scanner.close()
                }
            } catch (error: OutOfMemoryError) {
                mainExecutor.execute { onError(error) }
            } catch (error: Exception) {
                mainExecutor.execute { onError(error) }
            } catch (error: LinkageError) {
                mainExecutor.execute { onError(error) }
            } finally {
                executor.shutdown()
            }
        }
    }
}
