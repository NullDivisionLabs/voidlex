package com.voidtunnel.voidtunnel

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class XrayRuntimeTest {
    @Test
    fun `detects xray startup marker`() {
        assertTrue(
            XrayRuntime.isXrayStartedLine("[Warning] core: Xray 25.3.6 started"),
        )
    }

    @Test
    fun `ignores non-ready xray log lines`() {
        assertFalse(XrayRuntime.isXrayStartedLine("Xray 25.3.6"))
        assertFalse(
            XrayRuntime.isXrayStartedLine("[Info] infra/conf/serial: Reading config: /tmp/config.json"),
        )
        assertFalse(
            XrayRuntime.isXrayStartedLine("2026/04/24 from tcp:127.0.0.1 accepted tcp:example.com:443"),
        )
    }

    @Test
    fun `explains unsupported xray tun inbound`() {
        val message = XrayRuntime.configTestFailureMessage(
            mode = XrayRuntimeMode.TUN,
            exitCode = 23,
            rawOutput = "failed to parse inbound: unknown protocol: tun",
        )

        assertTrue(message.contains("VoidTunnel-patched xray-core"))
        assertTrue(message.contains("protocol \"tun\""))
        assertTrue(message.contains("unknown protocol: tun"))
    }

    @Test
    fun `applies xray geodata asset environment aliases`() {
        val assetDirectory = File("build/test-xray-assets")
        val environment = mutableMapOf(
            "XRAY_LOCATION_ASSET" to "/old",
            "xray.location.asset" to "/old",
        )

        XrayRuntime.applyXrayAssetEnvironment(
            environment,
            assetDirectory,
        )

        assertEquals(assetDirectory.absolutePath, environment["XRAY_LOCATION_ASSET"])
        assertEquals(assetDirectory.absolutePath, environment["xray.location.asset"])
    }
}
