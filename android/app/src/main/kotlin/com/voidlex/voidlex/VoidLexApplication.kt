package com.voidlex.voidlex

import android.app.Application

class VoidLexApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppLogBridge.install(this)
    }
}
