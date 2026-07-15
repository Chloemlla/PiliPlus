package com.chloemlla.piliplus

import android.app.Application
import android.content.Context
import android.os.Build
import android.os.Process
import com.chloemlla.lumen.crash.LumenCrash
import com.chloemlla.lumen.crash.LumenCrashConfig
import java.util.concurrent.Executors

class PiliPlusApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        installLumenCrashSdk()
    }

    override fun onCreate() {
        super.onCreate()
        SealDownloadStatusBridge.install(this)
        installLumenCrashSdk()
        exitCollectionExecutor.execute {
            try {
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
            } catch (_: Exception) {
                // Collection is already off the main thread; priority is best-effort.
            }
            ProcessExitCollector.collect(applicationContext)
        }
    }

    private fun installLumenCrashSdk() {
        if (LumenCrash.isInstalled()) return
        val packageInfo = runCatching {
            packageManager.getPackageInfo(packageName, 0)
        }.getOrNull()
        val versionName = packageInfo?.versionName?.takeIf { it.isNotBlank() } ?: "unknown"
        val versionCode = packageInfo?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                it.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                it.versionCode
            }
        } ?: 0
        val appName = runCatching { getString(R.string.app_name) }.getOrDefault("PiliPlus")
        LumenCrash.install(
            this,
            LumenCrashConfig(
                appDisplayName = appName,
                versionName = versionName,
                versionCode = versionCode,
                commitHash = "unknown",
            ),
        )
    }

    private companion object {
        val exitCollectionExecutor = Executors.newSingleThreadExecutor { task ->
            Thread(task, "PiliPlus-exit-history").apply {
                isDaemon = true
            }
        }
    }
}
