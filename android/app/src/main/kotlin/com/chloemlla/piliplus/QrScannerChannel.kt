package com.chloemlla.piliplus

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class QrScannerChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var pendingResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanCamera" -> launchCamera(result)
            "scanImage" -> launchImagePicker(result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            CAMERA_REQUEST_CODE -> {
                handleCameraResult(resultCode, data)
                true
            }
            IMAGE_REQUEST_CODE -> {
                handleImageResult(resultCode, data)
                true
            }
            else -> false
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingResult?.error("cancelled", "扫码请求已取消", null)
        pendingResult = null
    }

    private fun launchCamera(result: MethodChannel.Result) {
        if (!begin(result)) return
        try {
            activity.startActivityForResult(
                Intent(activity, QrScannerActivity::class.java),
                CAMERA_REQUEST_CODE,
            )
        } catch (exception: Exception) {
            completeError("camera_unavailable", exception.message ?: "无法启动相机")
        }
    }

    private fun launchImagePicker(result: MethodChannel.Result) {
        if (!begin(result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        try {
            activity.startActivityForResult(intent, IMAGE_REQUEST_CODE)
        } catch (exception: Exception) {
            completeError("picker_unavailable", exception.message ?: "无法打开图片选择器")
        }
    }

    private fun begin(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.error("in_progress", "已有扫码请求正在进行", null)
            return false
        }
        pendingResult = result
        return true
    }

    private fun handleCameraResult(resultCode: Int, data: Intent?) {
        when (resultCode) {
            Activity.RESULT_OK -> completeSuccess(
                data?.getStringExtra(QrScannerActivity.EXTRA_QR_VALUE),
            )
            QrScannerActivity.RESULT_ERROR -> completeError(
                data?.getStringExtra(QrScannerActivity.EXTRA_ERROR_CODE) ?: "scan_failed",
                data?.getStringExtra(QrScannerActivity.EXTRA_ERROR_MESSAGE) ?: "扫码失败",
            )
            else -> completeSuccess(null)
        }
    }

    private fun handleImageResult(resultCode: Int, data: Intent?) {
        if (resultCode != Activity.RESULT_OK) {
            completeSuccess(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            completeError("invalid_image", "未能读取所选图片")
            return
        }
        QrBarcodeDecoder.decodeImage(
            activity,
            uri,
            onSuccess = { value ->
                if (value == null) {
                    completeError("not_found", "图片中未识别到二维码")
                } else {
                    completeSuccess(value)
                }
            },
            onError = { exception ->
                completeError("decode_failed", exception.message ?: "图片二维码识别失败")
            },
        )
    }

    private fun completeSuccess(value: String?) {
        val result = pendingResult ?: return
        pendingResult = null
        result.success(value)
    }

    private fun completeError(code: String, message: String) {
        val result = pendingResult ?: return
        pendingResult = null
        result.error(code, message, null)
    }

    private companion object {
        const val CHANNEL_NAME = "pili_plus/android_qr_scanner"
        const val CAMERA_REQUEST_CODE = 0x7101
        const val IMAGE_REQUEST_CODE = 0x7102
    }
}

