package com.voidlex.voidlex

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Generation-safe signal for the first usable libbox default-interface update.
 *
 * The token captured by a network callback belongs to one runtime generation;
 * a late callback therefore cannot make a newer generation appear ready.
 */
internal class LibboxReadinessGate {
    @Volatile
    private var signal: CompletableDeferred<Unit>? = null

    fun reset() {
        val previous = signal
        signal = CompletableDeferred()
        previous?.cancel()
    }

    fun currentToken(): CompletableDeferred<Unit>? = signal

    fun markReady(token: CompletableDeferred<Unit>?) {
        if (token != null && signal === token) {
            token.complete(Unit)
        }
    }

    suspend fun await(timeoutMs: Long): Boolean {
        val expectedSignal = signal ?: return false
        return withTimeoutOrNull(timeoutMs) {
            try {
                expectedSignal.await()
                true
            } catch (error: kotlinx.coroutines.CancellationException) {
                if (expectedSignal.isCancelled) false else throw error
            }
        } ?: false
    }

    fun cancel() {
        val previous = signal
        signal = null
        previous?.cancel()
    }
}

internal object LibboxStartupPolicy {
    const val NETWORK_UNAVAILABLE_ERROR = "vpnLibboxNetworkUnavailable"

    fun decide(isReady: Boolean): LibboxStartupDecision =
        if (isReady) {
            LibboxStartupDecision(publishConnected = true, errorCode = null)
        } else {
            LibboxStartupDecision(
                publishConnected = false,
                errorCode = NETWORK_UNAVAILABLE_ERROR,
            )
        }
}

internal data class LibboxStartupDecision(
    val publishConnected: Boolean,
    val errorCode: String?,
)
