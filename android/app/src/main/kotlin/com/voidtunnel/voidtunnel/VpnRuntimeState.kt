package com.voidtunnel.voidtunnel

import android.os.SystemClock

internal object VpnRuntimeState {
    private const val STATE_DISCONNECTED = "disconnected"
    private const val STATE_CONNECTING = "connecting"
    private const val STATE_CONNECTED = "connected"
    private const val STATE_ERROR = "error"

    @Volatile
    private var state: String = STATE_DISCONNECTED

    @Volatile
    private var message: String? = null

    @Volatile
    private var connectedAtElapsedMillis: Long = 0L

    @Volatile
    private var proxyUser: String = ""

    @Volatile
    private var proxyPassword: String = ""

    fun markConnecting(config: ServerConfig) {
        state = STATE_CONNECTING
        message = null
        connectedAtElapsedMillis = 0L
        proxyUser = config.proxyUser
        proxyPassword = config.proxyPassword
    }

    fun markConnected(config: ServerConfig) {
        state = STATE_CONNECTED
        message = null
        if (connectedAtElapsedMillis <= 0L) {
            connectedAtElapsedMillis = SystemClock.elapsedRealtime()
        }
        proxyUser = config.proxyUser
        proxyPassword = config.proxyPassword
    }

    fun markDisconnected() {
        state = STATE_DISCONNECTED
        message = null
        connectedAtElapsedMillis = 0L
        proxyUser = ""
        proxyPassword = ""
    }

    fun markError(errorMessage: String) {
        state = STATE_ERROR
        message = errorMessage
        connectedAtElapsedMillis = 0L
        proxyUser = ""
        proxyPassword = ""
    }

    fun snapshot(): Map<String, Any?> {
        val currentState = state
        val connectedDurationMillis =
            if (currentState == STATE_CONNECTED && connectedAtElapsedMillis > 0L) {
                (SystemClock.elapsedRealtime() - connectedAtElapsedMillis)
                    .coerceAtLeast(0L)
            } else {
                0L
            }

        return mapOf(
            "state" to currentState,
            "message" to message,
            "connectedDurationMillis" to connectedDurationMillis,
            "proxyUser" to proxyUser,
            "proxyPassword" to proxyPassword,
        )
    }
}
