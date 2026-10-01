package com.voidlex.voidlex

import android.app.Application
import android.app.ActivityManager
import android.os.Build
import android.os.Process

class VoidLexApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // The :probe process must not start a second writer for the VPN log.
        val processName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            getProcessName()
        } else {
            (getSystemService(ACTIVITY_SERVICE) as ActivityManager)
                .runningAppProcesses?.firstOrNull { it.pid == Process.myPid() }?.processName
        }
        if (processName?.endsWith(":probe") == true) return
        AppLogBridge.install(this)
    }
}
