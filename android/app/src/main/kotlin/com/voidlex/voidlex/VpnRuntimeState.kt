package com.voidlex.voidlex

import android.os.SystemClock
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull

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

    /**
     * Last time the service entered a non-disconnected state (connecting
     * or connected). Used by the home-screen widget to decide whether a
     * pre-start defensive stop is worth doing: when nothing has been
     * running this process, there's nothing to tear down.
     *
     * `hasHadActivity` is a separate flag so a `SystemClock.elapsedRealtime`
     * of 0 (returned by stubbed Android in unit tests) doesn't collide with
     * the "no activity yet" sentinel.
     */
    @Volatile
    private var lastActivityElapsedMillis: Long = 0L

    @Volatile
    private var hasHadActivity: Boolean = false

    fun markConnecting(config: ServerConfig) {
        state = STATE_CONNECTING
        message = null
        connectedAtElapsedMillis = 0L
        recordActivity()
        proxyUser = config.proxyUser
        proxyPassword = config.proxyPassword
    }

    fun markConnected(config: ServerConfig) {
        state = STATE_CONNECTED
        message = null
        if (connectedAtElapsedMillis <= 0L) {
            connectedAtElapsedMillis = SystemClock.elapsedRealtime()
        }
        recordActivity()
        proxyUser = config.proxyUser
        proxyPassword = config.proxyPassword
    }

    private fun recordActivity() {
        lastActivityElapsedMillis = SystemClock.elapsedRealtime()
        hasHadActivity = true
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

    /**
     * Suspends until the runtime state is terminal (disconnected or error),
     * polling every [pollIntervalMillis]. Returns true if the terminal
     * state was reached within [timeoutMillis], false on timeout.
     *
     * Used by the home-screen widget to mirror [VpnController]'s
     * `stopVpn → waitForStop → start` restart sequence, which has to be
     * driven from native code when Flutter isn't running.
     */
    suspend fun awaitTerminal(
        timeoutMillis: Long,
        pollIntervalMillis: Long = 50L,
    ): Boolean {
        if (isTerminal()) return true
        val result = withTimeoutOrNull(timeoutMillis) {
            while (!isTerminal()) {
                delay(pollIntervalMillis)
            }
            true
        }
        return result == true
    }

    private fun isTerminal(): Boolean {
        val current = state
        return current == STATE_DISCONNECTED || current == STATE_ERROR
    }

    /**
     * Returns true when the runtime is currently active (connecting or
     * connected) or was active within the last [windowMillis]. The widget
     * uses this to decide whether to run a defensive stop+settle before
     * a fresh start: when nothing has been running this process, the
     * defensive dance is wasteful (just emits stray "disconnected" events
     * and adds latency).
     */
    fun recentlyHadRuntime(windowMillis: Long): Boolean {
        val current = state
        if (current == STATE_CONNECTING || current == STATE_CONNECTED) return true
        if (!hasHadActivity) return false
        return SystemClock.elapsedRealtime() - lastActivityElapsedMillis <= windowMillis
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
