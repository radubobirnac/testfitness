package com.radubobirnac.testfitness

import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val clockChannel = "com.testfitness/clock"
    private val timerServiceChannel = "com.testfitness/timer_service"
    private val powerStatusChannel = "com.testfitness/power_status"

    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            Log.d("MainActivity", "Starting onCreate")
            super.onCreate(savedInstanceState)
            Log.d("MainActivity", "Successfully completed onCreate")
        } catch (e: Exception) {
            // Log the error including stacktrace
            Log.e("MainActivity", "Error in onCreate: ${e.message}", e)
            e.stackTrace.forEach {
                Log.e("MainActivity", "StackTrace: $it")
            }

            // Show a toast message
            try {
                Toast.makeText(
                    this,
                    "Error starting app: ${e.message}",
                    Toast.LENGTH_LONG
                ).show()
            } catch (toastError: Exception) {
                Log.e("MainActivity", "Error showing toast", toastError)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            clockChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            timerServiceChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val endEpochMs = getLongArg(call, "endEpochMs")
                    val totalDurationMs = getLongArg(call, "totalDurationMs")
                    val remainingMs = getLongArg(call, "remainingMs")
                    RestTimerForegroundService.start(
                        applicationContext,
                        endEpochMs,
                        totalDurationMs,
                        remainingMs
                    )
                    result.success(true)
                }
                "update" -> {
                    val endEpochMs = getLongArg(call, "endEpochMs")
                    val totalDurationMs = getLongArg(call, "totalDurationMs")
                    val remainingMs = getLongArg(call, "remainingMs")
                    RestTimerForegroundService.update(
                        applicationContext,
                        endEpochMs,
                        totalDurationMs,
                        remainingMs
                    )
                    result.success(true)
                }
                "stop" -> {
                    RestTimerForegroundService.stop(applicationContext)
                    result.success(true)
                }
                "isRunning" -> result.success(RestTimerForegroundService.isRunning())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            powerStatusChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPowerStatus" -> result.success(buildPowerStatus())
                else -> result.notImplemented()
            }
        }
    }

    private fun getLongArg(call: MethodCall, key: String): Long {
        val value = call.argument<Number>(key)
        return value?.toLong() ?: 0L
    }

    private fun buildPowerStatus(): Map<String, Any?> {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val ignoringBatteryOptimizations =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                powerManager.isIgnoringBatteryOptimizations(packageName)
            } else {
                null
            }
        val deviceIdleMode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                powerManager.isDeviceIdleMode
            } else {
                null
            }
        val powerSaveMode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                powerManager.isPowerSaveMode
            } else {
                null
            }

        val activityManager =
            getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val backgroundRestricted =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                activityManager.isBackgroundRestricted
            } else {
                null
            }

        var standbyBucket: Int? = null
        var standbyBucketLabel: String? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val usageStats =
                getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            standbyBucket = usageStats.appStandbyBucket
            standbyBucketLabel = when (standbyBucket) {
                UsageStatsManager.STANDBY_BUCKET_ACTIVE -> "ACTIVE"
                UsageStatsManager.STANDBY_BUCKET_WORKING_SET -> "WORKING_SET"
                UsageStatsManager.STANDBY_BUCKET_FREQUENT -> "FREQUENT"
                UsageStatsManager.STANDBY_BUCKET_RARE -> "RARE"
                UsageStatsManager.STANDBY_BUCKET_RESTRICTED -> "RESTRICTED"
                else -> standbyBucket?.toString()
            }
        }

        return mapOf(
            "ignoringBatteryOptimizations" to ignoringBatteryOptimizations,
            "deviceIdleMode" to deviceIdleMode,
            "powerSaveMode" to powerSaveMode,
            "backgroundRestricted" to backgroundRestricted,
            "appStandbyBucket" to standbyBucket,
            "appStandbyBucketLabel" to standbyBucketLabel,
            "foregroundServiceRunning" to RestTimerForegroundService.isRunning()
        )
    }
}
