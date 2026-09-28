package com.voidlex.voidlex

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class NaiveRuntimeConstraintsTest {
    @Test
    fun `allows single-hop libbox tun`() {
        assertNull(
            DirectLibboxRuntimeConstraints.validationError(
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
            DirectLibboxRuntimeConstraints.validationError(
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
            DirectLibboxRuntimeConstraints.validationError(
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
            DirectLibboxRuntimeConstraints.validationError(
                protocol = "vless",
                detourProtocol = "naiveproxy",
                tunEngineMode = TunEngineMode.LIBBOX,
                runMode = RunMode.TUN,
                isBridge = true,
            ),
        )
    }

    @Test
    fun `allows single-hop hysteria2`() {
        assertNull(
            DirectLibboxRuntimeConstraints.validationError(
                protocol = "hysteria2",
                tunEngineMode = TunEngineMode.LIBBOX,
                runMode = RunMode.TUN,
                isBridge = false,
            ),
        )
    }

    @Test
    fun `rejects hysteria2 outside libbox tun mode`() {
        assertNotNull(
            DirectLibboxRuntimeConstraints.validationError(
                protocol = "hysteria2",
                tunEngineMode = TunEngineMode.XRAY,
                runMode = RunMode.TUN,
                isBridge = false,
            ),
        )
        assertNotNull(
            DirectLibboxRuntimeConstraints.validationError(
                protocol = "hysteria2",
                tunEngineMode = TunEngineMode.LIBBOX,
                runMode = RunMode.PROXY_ONLY,
                isBridge = false,
            ),
        )
    }

    @Test
    fun `rejects bridge when either hop is hysteria2`() {
        assertNotNull(
            DirectLibboxRuntimeConstraints.validationError(
                protocol = "vless",
                detourProtocol = "hy2",
                tunEngineMode = TunEngineMode.LIBBOX,
                runMode = RunMode.TUN,
                isBridge = true,
            ),
        )
        assertNotNull(
            DirectLibboxRuntimeConstraints.validationError(
                protocol = "hysteria2",
                detourProtocol = "vless",
                tunEngineMode = TunEngineMode.LIBBOX,
                runMode = RunMode.TUN,
                isBridge = true,
            ),
        )
    }
}
