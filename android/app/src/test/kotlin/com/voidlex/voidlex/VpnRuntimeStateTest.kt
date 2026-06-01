package com.voidlex.voidlex

import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.system.measureTimeMillis

/**
 * Covers the bits of [VpnRuntimeState] the home-screen widget relies on
 * (awaitTerminal + recentlyHadRuntime). These are pure-singleton operations
 * so we have to reset state between cases.
 */
class VpnRuntimeStateTest {

    @After
    fun resetState() {
        // markDisconnected clears the in-memory snapshot, but the activity
        // flag stays set from any previous mark{Connecting,Connected}.
        // Reset both via reflection so each test sees a clean slate.
        VpnRuntimeState.markDisconnected()
        clearActivityFlag()
    }

    private fun clearActivityFlag() {
        val flag = VpnRuntimeState::class.java.getDeclaredField("hasHadActivity")
        flag.isAccessible = true
        flag.setBoolean(VpnRuntimeState, false)
        val ts = VpnRuntimeState::class.java.getDeclaredField("lastActivityElapsedMillis")
        ts.isAccessible = true
        ts.setLong(VpnRuntimeState, 0L)
    }

    @Test
    fun `awaitTerminal returns immediately when state is already disconnected`() {
        VpnRuntimeState.markDisconnected()

        val elapsed = measureTimeMillis {
            val settled = runBlocking { VpnRuntimeState.awaitTerminal(5_000L) }
            assertTrue("expected terminal", settled)
        }
        // 50ms is the poll interval — initial check skips polling entirely.
        assertTrue("returned too slowly: ${elapsed}ms", elapsed < 50L)
    }

    @Test
    fun `awaitTerminal returns immediately when state is error`() {
        VpnRuntimeState.markError("boom")

        val settled = runBlocking { VpnRuntimeState.awaitTerminal(5_000L) }
        assertTrue(settled)
    }

    @Test
    fun `awaitTerminal times out when state stays connected`() {
        val dummyConfig = makeServerConfig()
        VpnRuntimeState.markConnected(dummyConfig)

        val elapsed = measureTimeMillis {
            val settled = runBlocking { VpnRuntimeState.awaitTerminal(200L) }
            assertFalse("should have timed out", settled)
        }
        assertTrue("timed out too fast: ${elapsed}ms", elapsed >= 150L)
    }

    @Test
    fun `recentlyHadRuntime is true while connected`() {
        VpnRuntimeState.markConnected(makeServerConfig())
        assertTrue(VpnRuntimeState.recentlyHadRuntime(1_000L))
    }

    @Test
    fun `recentlyHadRuntime is true while connecting`() {
        VpnRuntimeState.markConnecting(makeServerConfig())
        assertTrue(VpnRuntimeState.recentlyHadRuntime(1_000L))
    }

    @Test
    fun `recentlyHadRuntime stays true within the window after disconnect`() {
        VpnRuntimeState.markConnecting(makeServerConfig())
        VpnRuntimeState.markDisconnected()
        // Activity timestamp set by markConnecting, state="disconnected".
        assertTrue(VpnRuntimeState.recentlyHadRuntime(5_000L))
    }

    @Test
    fun `recentlyHadRuntime is false on a fresh process`() {
        // @After clears the activity flag, so this is the cold-start state.
        assertFalse(VpnRuntimeState.recentlyHadRuntime(5_000L))
    }

    @Test
    fun `snapshot exposes expected keys`() {
        VpnRuntimeState.markConnected(makeServerConfig())
        val snapshot = VpnRuntimeState.snapshot()
        assertEquals("connected", snapshot["state"])
        assertTrue(snapshot.containsKey("connectedDurationMillis"))
        assertTrue(snapshot.containsKey("proxyUser"))
        assertTrue(snapshot.containsKey("proxyPassword"))
    }

    private fun makeServerConfig(): ServerConfig {
        return ServerConfig(
            tunEngineMode = TunEngineMode.LIBBOX,
            isGlobalProxy = false,
            server = "test.example.com",
            serverPort = 443,
            protocol = "vless",
            uuid = "00000000-0000-0000-0000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            transportMode = "",
            xhttpPadding = "",
            xhttpMaxPostBytes = "",
            xhttpMinPostInterval = "",
            tlsEnabled = true,
            tlsSni = "test.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            realitySpiderX = "",
            fingerprint = "",
            alpn = "",
            hysteria2ObfsPassword = "",
            hysteria2HopPorts = "",
            proxyUser = "u",
            proxyPassword = "p",
        )
    }
}
