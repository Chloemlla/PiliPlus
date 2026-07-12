package com.chloemlla.piliplus

import android.app.Application
import android.os.Process
import java.util.concurrent.Executors

class PiliPlusApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        SealDownloadStatusBridge.install(this)
        NativeCrashHandler.install(this)
        exitCollectionExecutor.execute {
            try {
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
            } catch (_: Exception) {
                // Collection is already off the main thread; priority is best-effort.
            }
            ProcessExitCollector.collect(applicationContext)
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
