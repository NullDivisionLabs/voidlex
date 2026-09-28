package com.voidlex.voidlex

import org.junit.Assert.*
import org.junit.Test

class XrayConfigTestRetryTest {
    @Test fun `timeout retries once and may succeed`() {
        var attempts = 0
        var retries = 0
        assertTrue(XrayConfigTestRetry.run({ true }, {
            if (++attempts == 1) null else true
        }, { retries++ }))
        assertEquals(2, attempts)
        assertEquals(1, retries)
    }

    @Test fun `invalid config does not retry`() {
        var attempts = 0
        assertFalse(XrayConfigTestRetry.run({ true }, { attempts++; false }, { fail() }))
        assertEquals(1, attempts)
    }

    @Test fun `second timeout terminates and cancellation prevents retry`() {
        var attempts = 0
        assertFalse(XrayConfigTestRetry.run({ true }, { attempts++; null }, {}))
        assertEquals(2, attempts)
        var active = true
        attempts = 0
        assertFalse(XrayConfigTestRetry.run({ active }, {
            attempts++
            active = false
            null
        }, { fail() }))
        assertEquals(1, attempts)
    }
}
