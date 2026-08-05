package com.chloemlla.piliplus

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.core.content.ContextCompat
import com.huawei.hms.hmsscankit.ScanUtil
import com.huawei.hms.ml.scan.HmsScan
import com.huawei.hms.ml.scan.HmsScanAnalyzerOptions
import java.io.IOException
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
            var bitmap: android.graphics.Bitmap? = null
            try {
                bitmap = decodeSampledBitmap(appContext, uri)
                val options = HmsScanAnalyzerOptions.Creator()
                    .setHmsScanTypes(HmsScan.QRCODE_SCAN_TYPE)
                    .setPhotoMode(true)
                    .create()
                val results = ScanUtil.decodeWithBitmap(appContext, bitmap, options)
                val value = results
                    ?.firstOrNull()
                    ?.originalValue
                    ?.takeIf(String::isNotBlank)
                mainExecutor.execute { onSuccess(value) }
            } catch (error: OutOfMemoryError) {
                mainExecutor.execute { onError(error) }
            } catch (exception: Exception) {
                mainExecutor.execute { onError(exception) }
            } catch (error: LinkageError) {
                mainExecutor.execute { onError(error) }
            } finally {
                bitmap?.recycle()
                executor.shutdown()
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
