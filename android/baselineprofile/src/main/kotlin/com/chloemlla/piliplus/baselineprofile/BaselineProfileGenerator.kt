package com.chloemlla.piliplus.baselineprofile

import android.content.Intent
import android.os.Build
import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.benchmark.macro.junit4.BaselineProfileRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import java.util.regex.Pattern
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@LargeTest
class BaselineProfileGenerator {
    @get:Rule
    val baselineProfileRule = BaselineProfileRule()

    @Test
    fun startup() {
        baselineProfileRule.collect(
            packageName = TARGET_PACKAGE,
            maxIterations = 3,
            stableIterations = 1,
            includeInStartupProfile = true,
        ) {
            // Clean process/task state inside the profile block.
            // Flutter cold starts on GHA emulators often miss framestats confirmation.
            pressHome()
            killProcess()
            device.waitForIdle(IDLE_TIMEOUT_MILLIS)

            pressHome()
            startPiliPlusAndWait()
            dismissBlockingUiIfPresent()
            device.waitForIdle(IDLE_TIMEOUT_MILLIS)
        }
    }

    private fun MacrobenchmarkScope.startPiliPlusAndWait() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val packageManager = context.packageManager
        val launchIntent = (
            packageManager.getLaunchIntentForPackage(TARGET_PACKAGE)
                ?: Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    setPackage(TARGET_PACKAGE)
                    val resolveInfo = packageManager.queryIntentActivities(this, 0).firstOrNull()
                    if (resolveInfo != null) {
                        setClassName(TARGET_PACKAGE, resolveInfo.activityInfo.name)
                    }
                }
            ).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
            )
        }

        var lastError: String? = null
        repeat(LAUNCH_ATTEMPTS) { attempt ->
            if (attempt > 0) {
                pressHome()
                killProcess()
                device.waitForIdle(IDLE_TIMEOUT_MILLIS)
                pressHome()
            }

            // Prefer startActivityAndWait when framestats work. On flaky GHA emulators
            // (especially Flutter first-frame), fall back to package visibility + pid checks.
            runCatching {
                startActivityAndWait(launchIntent)
            }.onFailure { error ->
                lastError = error.message
                runCatching {
                    device.executeShellCommand(
                        "am start -W -n ${launchIntent.component?.flattenToShortString() ?: ""} " +
                            "-a android.intent.action.MAIN " +
                            "-c android.intent.category.LAUNCHER",
                    )
                }.onFailure { shellError ->
                    lastError = "${error.message}; am start failed: ${shellError.message}"
                }
            }

            val deadlineMillis = System.currentTimeMillis() + APP_VISIBLE_TIMEOUT_MILLIS
            var becameVisible = false
            var processStillRunning = false
            while (System.currentTimeMillis() < deadlineMillis) {
                becameVisible = device.hasObject(By.pkg(TARGET_PACKAGE).depth(0))
                processStillRunning = isTargetProcessRunning()
                if (becameVisible && processStillRunning) {
                    device.waitForIdle(IDLE_TIMEOUT_MILLIS)
                    return
                }
                device.waitForIdle(PROCESS_POLL_INTERVAL_MILLIS)
            }
            lastError = "visible=$becameVisible processRunning=$processStillRunning last=$lastError"
        }

        val logSnippet = runCatching {
            device.executeShellCommand(
                "logcat -d -t 120 AndroidRuntime:E flutter:E FlutterJNI:E ActivityManager:I *:S",
            ).trim()
        }.getOrDefault("")

        error(
            "Target package $TARGET_PACKAGE failed to stay running after launch " +
                "(api=${Build.VERSION.SDK_INT}, last=$lastError)" +
                if (logSnippet.isNotEmpty()) " | logcat=$logSnippet" else "",
        )
    }

    private fun MacrobenchmarkScope.isTargetProcessRunning(): Boolean {
        val pidof = device.executeShellCommand("pidof $TARGET_PACKAGE").trim()
        if (pidof.isNotEmpty()) return true
        val ps = device.executeShellCommand("ps -A | grep $TARGET_PACKAGE").trim()
        return ps.isNotEmpty()
    }

    private fun MacrobenchmarkScope.dismissBlockingUiIfPresent() {
        // Startup crash report continue button if a previous run left a report on disk.
        clickIfPresent(
            pattern = Pattern.compile(
                "(?i)Continue|继续|清除并继续|Clear and continue|Clear & continue|知道了|OK|确定",
            ),
            timeoutMillis = FIND_UI_TIMEOUT_MILLIS,
        )
        device.waitForIdle(IDLE_TIMEOUT_MILLIS)
    }

    private fun MacrobenchmarkScope.clickIfPresent(
        pattern: Pattern,
        timeoutMillis: Long,
    ) {
        val target = device.wait(Until.findObject(By.text(pattern)), timeoutMillis)
        target?.click()
        device.waitForIdle(IDLE_TIMEOUT_MILLIS)
    }

    private companion object {
        const val TARGET_PACKAGE = "com.chloemlla.piliplus"
        private const val LAUNCH_ATTEMPTS = 3
        private const val APP_VISIBLE_TIMEOUT_MILLIS = 45_000L
        private const val FIND_UI_TIMEOUT_MILLIS = 2_500L
        private const val IDLE_TIMEOUT_MILLIS = 2_000L
        private const val PROCESS_POLL_INTERVAL_MILLIS = 500L
    }
}
