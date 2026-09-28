package com.voidlex.voidlex

/** State for a live tunnel; all calls are serialized by the service lifecycle mutex. */
internal class UnderlyingNetworkRecovery<T>(initial: T?) {
    var network: T? = initial
        private set
    var pending = false
        private set
    var attempts = 0
        private set
    private var changedAt = 0L
    private var attemptedAt: Long? = null

    fun observe(current: T?, now: Long): Boolean {
        if (network == current) return false
        network = current
        pending = true
        attempts = 0
        changedAt = now
        return true
    }

    fun delayMillis(now: Long): Long? {
        if (!pending || network == null || attempts >= MAX_ATTEMPTS) return null
        val stableAt = changedAt + SETTLE_MS
        val retryAt = attemptedAt?.plus(COOLDOWN_MS) ?: stableAt
        return (maxOf(stableAt, retryAt) - now).coerceAtLeast(0L)
    }

    fun attempted(now: Long) {
        attempts++
        attemptedAt = now
    }

    fun recovered() {
        pending = false
        attempts = 0
    }

    companion object {
        const val MAX_ATTEMPTS = 3
        const val SETTLE_MS = 1_000L
        const val COOLDOWN_MS = 10_000L
    }
}
