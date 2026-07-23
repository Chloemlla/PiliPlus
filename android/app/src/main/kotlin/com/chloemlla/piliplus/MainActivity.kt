package com.chloemlla.piliplus

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.WindowManager.LayoutParams
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private var credentialResult: MethodChannel.Result? = null
    private var qrScannerChannel: QrScannerChannel? = null
    private var nativeCrashChannel: NativeCrashChannel? = null
    private var sealDownloadChannel: SealDownloadChannel? = null
    private var clashCompatChannel: ClashCompatChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeMediaService.attachFlutterEngine(this, flutterEngine)
        qrScannerChannel = QrScannerChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        nativeCrashChannel = NativeCrashChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        sealDownloadChannel = SealDownloadChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        clashCompatChannel = ClashCompatChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pili_plus/android_credential_auth"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "confirmDeviceCredential" -> confirmDeviceCredential(
                    call.argument<String>("title") ?: "验证身份",
                    call.argument<String>("description") ?: "",
                    result
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        qrScannerChannel?.dispose()
        qrScannerChannel = null
        nativeCrashChannel?.dispose()
        nativeCrashChannel = null
        sealDownloadChannel?.dispose()
        sealDownloadChannel = null
        clashCompatChannel?.dispose()
        clashCompatChannel = null
        NativeMediaService.detachFlutterEngine()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        AndroidMmkv.initialize(applicationContext)
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onDestroy() {
        stopService(Intent(this, com.ryanheise.audioservice.AudioService::class.java))
        stopService(Intent(this, NativeMediaService::class.java))
        super.onDestroy()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (qrScannerChannel?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        if (sealDownloadChannel?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        if (requestCode == CREDENTIAL_REQUEST_CODE) {
            credentialResult?.success(resultCode == Activity.RESULT_OK)
            credentialResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }

    private fun confirmDeviceCredential(
        title: String,
        description: String,
        result: MethodChannel.Result
    ) {
        if (credentialResult != null) {
            result.error("in_progress", "已有系统验证正在进行", null)
            return
        }

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (keyguardManager == null) {
            result.error("unavailable", "系统验证不可用", null)
            return
        }
        if (!keyguardManager.isDeviceSecure) {
            result.error("not_configured", "请先设置系统锁屏密码或PIN", null)
            return
        }

        val intent = keyguardManager.createConfirmDeviceCredentialIntent(title, description)
        if (intent == null) {
            result.error("unavailable", "系统验证不可用", null)
            return
        }

        credentialResult = result
        try {
            startActivityForResult(intent, CREDENTIAL_REQUEST_CODE)
        } catch (e: Exception) {
            credentialResult = null
            result.error("unavailable", e.message, null)
        }
    }

    companion object {
        private const val CREDENTIAL_REQUEST_CODE = 0x7001
    }
}

