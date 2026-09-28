package com.voidlex.voidlex

import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LibboxReadinessGateTest {
    @Test
    fun `becomes ready only for the current generation token`() = runBlocking {
        val gate = LibboxReadinessGate()
        gate.reset()
        val staleToken = gate.currentToken()
        gate.reset()
        val currentToken = gate.currentToken()

        gate.markReady(staleToken)
        assertFalse(gate.await(1))

        gate.markReady(currentToken)
        assertTrue(gate.await(1_000))
    }

    @Test
    fun `returns false when readiness times out`() = runBlocking {
        val gate = LibboxReadinessGate()
        gate.reset()

        assertFalse(gate.await(1))
    }

    @Test
    fun `returns false when stop cancels readiness`() = runBlocking {
        val gate = LibboxReadinessGate()
        gate.reset()
        val result = async { gate.await(1_000) }
        yield()

        gate.cancel()

        assertFalse(result.await())
    }

    @Test
    fun `startup policy cannot publish connected after a readiness timeout`() {
        val ready = LibboxStartupPolicy.decide(isReady = true)
        assertTrue(ready.publishConnected)
        assertNull(ready.errorCode)

        val timedOut = LibboxStartupPolicy.decide(isReady = false)
        assertFalse(timedOut.publishConnected)
        assertEquals(
            LibboxStartupPolicy.NETWORK_UNAVAILABLE_ERROR,
            timedOut.errorCode,
        )
    }
}
