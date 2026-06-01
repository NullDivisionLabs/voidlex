package com.voidlex.voidlex

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class QuickSettingsVpnConfigStoreTest {
    private val entry = QuickSettingsVpnConfigStore.StoredServer(
        name = "Entry",
        address = "entry.example.com",
        port = 443,
        protocol = "vless",
        uuid = "entry-uuid",
        transport = "tcp",
        security = "tls",
        transportPath = "/",
        transportServiceName = "",
        transportHost = "",
        transportMode = "",
        xhttpPadding = "",
        xhttpMaxPostBytes = "",
        xhttpMinPostInterval = "",
        sni = "",
        alpn = "",
        flow = "",
        fingerprint = "",
        realityPublicKey = "",
        realityShortId = "",
        realitySpiderX = "",
        tlsInsecure = false,
        hysteria2ObfsPassword = "",
        hysteria2HopPorts = "",
    )

    private val exit = entry.copy(
        name = "Exit",
        address = "exit.example.com",
        uuid = "exit-uuid",
    )

    @Test
    fun resolveTunnelServers_usesExitAsOuterWhenExitDiffersFromEntry() {
        val resolved = QuickSettingsVpnConfigStore.resolveTunnelServers(
            servers = listOf(entry, exit),
            selectedName = "Entry",
            exitNodeName = "Exit",
        )

        assertNotNull(resolved)
        assertEquals("Entry", resolved!!.entry.name)
        assertEquals("Exit", resolved.outer.name)
        assertTrue(resolved.isBridge)
    }

    @Test
    fun resolveTunnelServers_singleHopWhenExitMatchesEntry() {
        val resolved = QuickSettingsVpnConfigStore.resolveTunnelServers(
            servers = listOf(entry),
            selectedName = "Entry",
            exitNodeName = "Entry",
        )

        assertNotNull(resolved)
        assertEquals("Entry", resolved!!.entry.name)
        assertEquals("Entry", resolved.outer.name)
        assertFalse(resolved.isBridge)
    }

    @Test
    fun resolveTunnelServers_singleHopWhenExitUnknown() {
        val resolved = QuickSettingsVpnConfigStore.resolveTunnelServers(
            servers = listOf(entry),
            selectedName = "Entry",
            exitNodeName = "Missing",
        )

        assertNotNull(resolved)
        assertFalse(resolved!!.isBridge)
    }

    @Test
    fun resolveTunnelServers_singleHopWhenNoExitWithMultipleServers() {
        // Regression: with no exit node set, the widget must NOT invent a
        // bridge to whatever server happens to be first in the list. This is
        // the exact bug that killed traffic — the UI built single-hop while
        // the widget bridged to the list's first server. `exit` is first here
        // and differs from the selected `entry`, so a naive firstOrNull
        // fallback would wrongly bridge to it.
        val resolved = QuickSettingsVpnConfigStore.resolveTunnelServers(
            servers = listOf(exit, entry),
            selectedName = "Entry",
            exitNodeName = null,
        )

        assertNotNull(resolved)
        assertEquals("Entry", resolved!!.entry.name)
        assertEquals("Entry", resolved.outer.name)
        assertFalse(resolved.isBridge)
    }

    @Test
    fun resolveTunnelServers_singleHopWhenExitUnknownWithMultipleServers() {
        // Same as above but the persisted exit name points at a node that no
        // longer exists. Strict resolution → single-hop, never a stray bridge.
        val resolved = QuickSettingsVpnConfigStore.resolveTunnelServers(
            servers = listOf(exit, entry),
            selectedName = "Entry",
            exitNodeName = "DeletedNode",
        )

        assertNotNull(resolved)
        assertEquals("Entry", resolved!!.entry.name)
        assertEquals("Entry", resolved.outer.name)
        assertFalse(resolved.isBridge)
    }

    @Test
    fun resolveTunnelServers_returnsNullWhenServersEmpty() {
        // No servers at all → nothing to fall back to → null.
        assertNull(
            QuickSettingsVpnConfigStore.resolveTunnelServers(
                servers = emptyList(),
                selectedName = null,
                exitNodeName = null,
            ),
        )
    }

    @Test
    fun resolveTunnelServers_fallsBackToFirstServerWhenSelectionMissing() {
        // selectedName == null mirrors the UI behaviour of auto-selecting
        // the first available server. The widget reuses that fallback so
        // a tap after a fresh install (or after the previously-selected
        // node was removed) still produces a usable start config.
        val resolved = QuickSettingsVpnConfigStore.resolveTunnelServers(
            servers = listOf(entry, exit),
            selectedName = null,
            exitNodeName = null,
        )
        assertNotNull(resolved)
        assertEquals("Entry", resolved!!.entry.name)
        assertFalse(resolved.isBridge)
    }
}
