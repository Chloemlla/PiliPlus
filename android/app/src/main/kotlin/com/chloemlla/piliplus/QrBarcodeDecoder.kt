package com.chloemlla.piliplus

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal object QrBarcodeDecoder {
    private val options = BarcodeScannerOptions.Builder()
        .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
        .build()

    fun createScanner(): BarcodeScanner = BarcodeScanning.getClient(options)

    fun decodeImage(
        context: Context,
        uri: Uri,
        onSuccess: (String?) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val executor = Executors.newSingleThreadExecutor()
        val mainExecutor = ContextCompat.getMainExecutor(context)
        val cleaned = AtomicBoolean(false)
        var bitmap: android.graphics.Bitmap? = null
        var scanner: BarcodeScanner? = null
        fun cleanup() {
            if (!cleaned.compareAndSet(false, true)) return
            bitmap?.recycle()
            scanner?.close()
            executor.shutdown()
        }
        executor.execute {
            try {
                val decodedBitmap = decodeSampledBitmap(context, uri)
                val activeScanner = createScanner()
                bitmap = decodedBitmap
                scanner = activeScanner
                activeScanner.process(InputImage.fromBitmap(decodedBitmap, 0))
                    .addOnSuccessListener(mainExecutor) { barcodes ->
                        onSuccess(
                            barcodes.firstNotNullOfOrNull {
                                it.rawValue?.takeIf(String::isNotBlank)
                            },
                        )
                    }
                    .addOnFailureListener(mainExecutor) { onError(it) }
                    .addOnCompleteListener(mainExecutor) { cleanup() }
            } catch (error: OutOfMemoryError) {
                mainExecutor.execute { onError(error) }
                cleanup()
            } catch (exception: Exception) {
                mainExecutor.execute { onError(exception) }
                cleanup()
            }
        }
    }

    private fun decodeSampledBitmap(context: Context, uri: Uri) =
        BitmapFactory.Options().let { bounds ->
            bounds.inJustDecodeBounds = true
            val boundsStream = context.contentResolver.openInputStream(uri)
                ?: throw IOException("无法读取所选图片")
            boundsStream.use {
                BitmapFactory.decodeStream(it, null, bounds)
            }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
                throw IOException("图片格式无效")
            }

            var sampleSize = 1
            while (bounds.outWidth / sampleSize > MAX_IMAGE_DIMENSION ||
                bounds.outHeight / sampleSize > MAX_IMAGE_DIMENSION
            ) {
                sampleSize *= 2
            }
            val options = BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888
            }
            context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, options)
            } ?: throw IOException("无法解码所选图片")
        }

    private const val MAX_IMAGE_DIMENSION = 2048
}
