package com.gmstyle.sonora

import android.app.UiModeManager
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import androidx.annotation.Keep
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceFragmentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        DRAWABLE_IDS
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gmstyle.sonora/android_tv"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTv" -> result.success(isAndroidTvDevice())
                "tvDiagnostics" -> result.success(androidTvDiagnostics())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gmstyle.sonora/battery"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openManufacturerBatterySettings" -> {
                    try {
                        OemBatterySettings.open(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("BATTERY_SETTINGS", e.message, null)
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        startActivity(
                            Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("BLUETOOTH_SETTINGS", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gmstyle.sonora/device_abi"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getSupportedAbis") {
                result.success(android.os.Build.SUPPORTED_ABIS.toList())
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gmstyle.sonora/apk_installer"
        ).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.error("INVALID_ARGS", "filePath is required", null)
                    return@setMethodCallHandler
                }
                try {
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file not found: $filePath", null)
                        return@setMethodCallHandler
                    }
                    val uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}",
                        file
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Hybrid STBs / Google TV boxes often omit FEATURE_LEANBACK or report a
     * non-television uiMode while still being remote-only. Combine several
     * signals so Sonora still opens [TvShell] on those devices.
     */
    private fun isAndroidTvDevice(): Boolean {
        val signals = androidTvDiagnostics()
        return signals["result"] as Boolean
    }

    private fun androidTvDiagnostics(): Map<String, Any> {
        val pm = packageManager
        val uiModeManager = getSystemService(UI_MODE_SERVICE) as? UiModeManager
        val uiModeTelevision =
            uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
        val configTelevision =
            (resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK) ==
                Configuration.UI_MODE_TYPE_TELEVISION
        val leanback = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        val leanbackOnly =
            pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK_ONLY)
        val touchscreen = pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
        val faketouch = pm.hasSystemFeature(PackageManager.FEATURE_FAKETOUCH)
        val characteristicsTv = hasTvBuildCharacteristic()
        // Remote-first boxes: no real touchscreen (faketouch alone is OK for
        // "touch-capable remote" shells that still need D-pad UI).
        val remoteOnly = !touchscreen
        val result =
            uiModeTelevision ||
                configTelevision ||
                leanback ||
                leanbackOnly ||
                characteristicsTv ||
                remoteOnly
        return mapOf(
            "uiModeTelevision" to uiModeTelevision,
            "configTelevision" to configTelevision,
            "leanback" to leanback,
            "leanbackOnly" to leanbackOnly,
            "touchscreen" to touchscreen,
            "faketouch" to faketouch,
            "characteristicsTv" to characteristicsTv,
            "remoteOnly" to remoteOnly,
            "result" to result,
            "model" to android.os.Build.MODEL,
            "device" to android.os.Build.DEVICE,
        )
    }

    private fun hasTvBuildCharacteristic(): Boolean {
        return try {
            val clazz = Class.forName("android.os.SystemProperties")
            val get = clazz.getMethod(
                "get",
                String::class.java,
                String::class.java,
            )
            val raw = get.invoke(null, "ro.build.characteristics", "") as String
            raw.split(',').any { it.trim().equals("tv", ignoreCase = true) }
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        @Keep
        @JvmField
        val DRAWABLE_IDS = intArrayOf(
            R.drawable.ic_shuffle,
            R.drawable.ic_repeat,
            R.drawable.ic_favorite,
            R.drawable.ic_favorite_border,
            R.drawable.ic_timer,
        )
    }
}