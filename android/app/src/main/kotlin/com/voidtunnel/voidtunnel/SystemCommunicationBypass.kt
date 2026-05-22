package com.voidtunnel.voidtunnel

import android.content.pm.PackageManager
import android.net.VpnService

internal object SystemCommunicationBypass {
    private const val TAG = "SystemCommunicationBypass"

    val packageNames: Set<String> = linkedSetOf(
        "com.android.stk",
        "com.android.phone",
        "com.android.server.telecom",
        "com.android.providers.telephony",
        "com.google.android.ims",
        "com.google.android.dialer",
        "com.samsung.android.dialer",
        "com.sec.ims",
        "com.samsung.advp.imssettings",
        "com.miui.voiceassist",
        "com.android.incallui",
        "com.huawei.ims",
        "com.android.emergency",
        "com.android.cellbroadcastreceiver",
        "com.google.android.cellbroadcastservice",
    )

    fun isProtectedPackage(packageName: String): Boolean = packageName in packageNames

    fun addDisallowedApplications(builder: VpnService.Builder) {
        packageNames.forEach { packageName ->
            runCatching { builder.addDisallowedApplication(packageName) }
                .onFailure { error ->
                    if (error !is PackageManager.NameNotFoundException) {
                        AppLogger.w(TAG, "addDisallowedApplication failed for $packageName", error)
                    }
                }
        }
    }
}
