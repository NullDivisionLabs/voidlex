package com.voidlex.voidlex

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class NaiveRuntimeConstraintsTest {
    @Test
    fun `allows single-hop libbox tun`() {
        assertNull(
            NaiveRuntimeConstraints.validationError(
                protocol = "naive",
                tunEngineMode = TunEngineMode.LIBBOX,
                runMode = RunMode.TUN,
                isBridge = false,
            ),
        )
    }

    @Test
    fun `rejects xray tun`() {
        assertNotNull(
            NaiveRuntimeConstraints.validationError(
                protocol = "naive",
                tunEngineMode = TunEngineMode.XRAY,
                runMode = RunMode.TUN,
                isBridge = false,
            ),
        )
    }

    @Test
    fun `rejects proxy-only`() {
        assertNotNull(
            NaiveRuntimeConstraints.validationError(
                protocol = "naive",
                tunEngineMode = TunEngineMode.LIBBOX,
                runMode = RunMode.PROXY_ONLY,
                isBridge = false,
            ),
        )
    }

    @Test
    fun `rejects bridge when either hop is naive`() {
        assertNotNull(
            NaiveRuntimeConstraints.validationError(
                protocol = "vless",
                detourProtocol = "naiveproxy",
                tunEngineMode = TunEngineMode.LIBBOX,
                runMode = RunMode.TUN,
                isBridge = true,
            ),
        )
    }
}
