package com.voidtunnel.voidtunnel

internal object AppLogger {
    fun d(tag: String, message: String, throwable: Throwable? = null): Int {
        AppLogBridge.append('D', tag, message, throwable)
        return if (throwable == null) {
            android.util.Log.d(tag, message)
        } else {
            android.util.Log.d(tag, message, throwable)
        }
    }

    fun i(tag: String, message: String, throwable: Throwable? = null): Int {
        AppLogBridge.append('I', tag, message, throwable)
        return if (throwable == null) {
            android.util.Log.i(tag, message)
        } else {
            android.util.Log.i(tag, message, throwable)
        }
    }

    fun w(tag: String, message: String, throwable: Throwable? = null): Int {
        AppLogBridge.append('W', tag, message, throwable)
        return if (throwable == null) {
            android.util.Log.w(tag, message)
        } else {
            android.util.Log.w(tag, message, throwable)
        }
    }

    fun e(tag: String, message: String, throwable: Throwable? = null): Int {
        AppLogBridge.append('E', tag, message, throwable)
        return if (throwable == null) {
            android.util.Log.e(tag, message)
        } else {
            android.util.Log.e(tag, message, throwable)
        }
    }
}
