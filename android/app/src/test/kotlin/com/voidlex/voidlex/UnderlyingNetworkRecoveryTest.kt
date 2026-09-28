package com.voidlex.voidlex

import org.junit.Assert.*
import org.junit.Test

class UnderlyingNetworkRecoveryTest {
    @Test fun `wifi loss then cellular schedules recovery after settling`() {
        val recovery = UnderlyingNetworkRecovery("wifi:148")
        recovery.observe(null, 100)
        assertNull(recovery.delayMillis(100))
        recovery.observe("cellular:153", 235)
        assertEquals(1000L, recovery.delayMillis(235))
        assertEquals(0L, recovery.delayMillis(1235))
    }

    @Test fun `same transport new network and same network returning both recover`() {
        val recovery = UnderlyingNetworkRecovery("cellular:1")
        assertTrue(recovery.observe("cellular:2", 100))
        recovery.recovered()
        recovery.observe(null, 200)
        recovery.observe("cellular:2", 300)
        assertTrue(recovery.pending)
        assertEquals(1000L, recovery.delayMillis(300))
    }

    @Test fun `rapid changes settle on latest network without duplicate callbacks postponing`() {
        val recovery = UnderlyingNetworkRecovery("wifi:1")
        recovery.observe("cellular:2", 100)
        recovery.observe("wifi:3", 500)
        assertFalse(recovery.observe("wifi:3", 900))
        assertEquals(600L, recovery.delayMillis(900))
        assertEquals("wifi:3", recovery.network)
    }

    @Test fun `cooldown defers next change instead of discarding it`() {
        val recovery = UnderlyingNetworkRecovery("wifi:1")
        recovery.observe("cellular:2", 100)
        recovery.attempted(1100)
        recovery.recovered()
        recovery.observe("wifi:3", 2000)
        assertEquals(9100L, recovery.delayMillis(2000))
        assertEquals(0L, recovery.delayMillis(11100))
    }

    @Test fun `failures stop at three attempts and loss waits for a new network`() {
        val recovery = UnderlyingNetworkRecovery("wifi:1")
        recovery.observe("cellular:2", 100)
        repeat(3) { recovery.attempted(1100L + it * 10000L) }
        assertNull(recovery.delayMillis(40000))
        recovery.observe(null, 41000)
        assertNull(recovery.delayMillis(50000))
        recovery.observe("cellular:3", 51000)
        assertEquals(1000L, recovery.delayMillis(51000))
        recovery.recovered()
        assertNull(recovery.delayMillis(60000))
    }
}
