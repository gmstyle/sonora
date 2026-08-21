package com.gmstyle.sonora

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Best-effort launch of OEM battery / autostart screens.
 * Falls back to the system ignore-battery-optimization list.
 */
internal object OemBatterySettings {
    fun open(context: Context) {
        val pkg = context.packageName
        val candidates = buildList {
            addAll(xiaomi(pkg))
            addAll(huawei())
            addAll(samsung())
            addAll(oppo())
            addAll(vivo())
            addAll(onePlus())
            add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }

        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(intent)
                return
            } catch (_: Exception) {
                // Try the next OEM / fallback intent.
            }
        }
    }

    private fun xiaomi(pkg: String): List<Intent> =
        listOf(
            Intent().setComponent(
                ComponentName(
                    "com.miui.powerkeeper",
                    "com.miui.powerkeeper.ui.HiddenAppsConfigActivity",
                ),
            ).putExtra("package_name", pkg).putExtra("package_label", "Sonora"),
            Intent().setComponent(
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                ),
            ),
        )

    private fun huawei(): List<Intent> =
        listOf(
            Intent("huawei.intent.action.HSM_PROTECTED_APPS"),
            Intent().setComponent(
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity",
                ),
            ),
            Intent().setComponent(
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
                ),
            ),
        )

    private fun samsung(): List<Intent> =
        listOf(
            Intent("com.samsung.android.sm.ACTION_BATTERY"),
            Intent().setComponent(
                ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                ),
            ),
            Intent().setComponent(
                ComponentName(
                    "com.samsung.android.sm",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                ),
            ),
        )

    private fun oppo(): List<Intent> =
        listOf(
            Intent().setComponent(
                ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity",
                ),
            ),
            Intent().setComponent(
                ComponentName(
                    "com.coloros.oppoguardelf",
                    "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity",
                ),
            ),
        )

    private fun vivo(): List<Intent> =
        listOf(
            Intent().setComponent(
                ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                ),
            ),
        )

    private fun onePlus(): List<Intent> =
        listOf(
            Intent().setComponent(
                ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                ),
            ),
        )
}
