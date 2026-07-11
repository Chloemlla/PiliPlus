package com.chloemlla.piliplus

import android.graphics.Bitmap
import androidx.camera.core.ImageProxy
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.ReaderException
import com.google.zxing.common.HybridBinarizer

internal class ZxingQrDecoder {
    private val reader = MultiFormatReader().apply { setHints(hints) }
    private var luminance = ByteArray(0)

    fun decode(imageProxy: ImageProxy): String? {
        val plane = imageProxy.planes.firstOrNull() ?: return null
        val crop = imageProxy.cropRect
        val width = crop.width()
        val height = crop.height()
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val buffer = plane.buffer.duplicate()
        val baseOffset = buffer.position()
        val lastIndex = baseOffset +
            (crop.bottom - 1) * rowStride +
            (crop.right - 1) * pixelStride
        if (width <= 0 || height <= 0 || lastIndex >= buffer.limit()) return null
        val requiredSize = width * height
        if (luminance.size != requiredSize) luminance = ByteArray(requiredSize)

        for (row in 0 until height) {
            val rowOffset = baseOffset +
                (crop.top + row) * rowStride +
                crop.left * pixelStride
            val targetOffset = row * width
            for (column in 0 until width) {
                luminance[targetOffset + column] =
                    buffer.get(rowOffset + column * pixelStride)
            }
        }

        return decode(
            PlanarYUVLuminanceSource(
                luminance,
                width,
                height,
                0,
                0,
                width,
                height,
                false,
            ),
        )
    }

    fun decode(bitmap: Bitmap): String? {
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        return decode(RGBLuminanceSource(width, height, pixels))
    }

    private fun decode(source: com.google.zxing.LuminanceSource): String? {
        return try {
            reader.decodeWithState(BinaryBitmap(HybridBinarizer(source)))
                .text
                .takeIf(String::isNotBlank)
        } catch (_: ReaderException) {
            null
        } finally {
            reader.reset()
        }
    }

    private companion object {
        val hints = mapOf(
            DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE),
            DecodeHintType.TRY_HARDER to true,
            DecodeHintType.CHARACTER_SET to Charsets.UTF_8.name(),
        )
    }
}
