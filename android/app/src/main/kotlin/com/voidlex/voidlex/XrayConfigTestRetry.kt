package com.voidlex.voidlex

internal object XrayConfigTestRetry {
    /** null is a timeout whose child process has already exited. */
    fun run(
        shouldContinue: () -> Boolean,
        attempt: () -> Boolean?,
        onRetry: () -> Unit,
    ): Boolean {
        repeat(2) { index ->
            if (!shouldContinue()) return false
            val result = attempt()
            if (result != null) return result
            if (index == 0 && shouldContinue()) onRetry()
        }
        return false
    }
}
