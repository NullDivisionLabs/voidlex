package com.voidtunnel.voidtunnel

import android.app.Application

class VoidTunnelApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppLogBridge.install(this)
    }
}
