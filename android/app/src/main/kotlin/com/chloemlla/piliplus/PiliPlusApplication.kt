package com.chloemlla.piliplus

import android.app.Application
import android.content.Context
import android.os.Process
import com.chloemlla.lumen.crash.LumenCrash
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
        // installSafely matches lumen-crash-core host guidance: integrity stays
        // fail-closed inside install, while a failed install path cannot kill startup.
        val appName = runCatching { getString(R.string.app_name) }.getOrDefault("PiliPlus")
        LumenCrash.installSafely(this) {
            appDisplayName = appName
            // Flutter BuildConfig commit hash is not available this early; keep unknown.
            commitHash = "unknown"
            // Capture-only host: Flutter owns product crash UI / share.
            pasteUploadEnabled = false
        }
        if (LumenCrash.isInstalled()) {
            LumenCrash.recordBreadcrumb("LumenCrash installed (piliplus host)")
        }
    }

    private companion object {
        val exitCollectionExecutor = Executors.newSingleThreadExecutor { task ->
            Thread(task, "PiliPlus-exit-history").apply {
                isDaemon = true
            }
        }
    }
}
