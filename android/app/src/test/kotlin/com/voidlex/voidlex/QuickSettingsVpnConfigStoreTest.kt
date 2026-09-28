package com.voidlex.voidlex

import org.json.JSONObject
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
        xPaddingBytes = "",
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

    @Test
    fun storedServer_parsesNaiveQuickSettingsFields() {
        val stored = QuickSettingsVpnConfigStore.StoredServer.fromJson(
            JSONObject().apply {
                put("name", "Naive")
                put("address", "naive.example.com")
                put("port", 443)
                put("protocol", "naiveproxy")
                put("security", "tls")
                put("naiveUsername", "user")
                put("naivePassword", "pass")
                put("naiveQuic", true)
                put("naiveQuicCongestionControl", "bbr")
                put("naiveInsecureConcurrency", 4)
                put("naiveExtraHeaders", JSONObject().put("X-Edge", "void"))
                put("naiveUdpOverTcp", true)
                put("naiveUdpOverTcpVersion", 2)
            },
        )

        assertNotNull(stored)
        assertTrue(stored!!.isNaive)
        assertEquals("naive", stored.protocol)
        assertEquals("user", stored.naiveUsername)
        assertEquals("pass", stored.naivePassword)
        assertTrue(stored.naiveQuic)
        assertEquals("bbr", stored.naiveQuicCongestionControl)
        assertEquals(4, stored.naiveInsecureConcurrency)
        assertEquals("""{"X-Edge":"void"}""", stored.naiveExtraHeadersJson)
        assertTrue(stored.naiveUdpOverTcp)
        assertEquals(2, stored.naiveUdpOverTcpVersion)
        assertEquals("naive.example.com", stored.effectiveSni)
    }

    @Test
    fun storedServer_preservesHysteria2RawJsonForQuickSettings() {
        val stored = QuickSettingsVpnConfigStore.StoredServer.fromJson(
            JSONObject().apply {
                put("name", "Gecko")
                put("address", "hy2.example.com")
                put("port", 443)
                put("protocol", "hysteria2")
                put("uuid", "secret")
                put("hysteria2ObfsType", "gecko")
                put("hysteria2ObfsPassword", "mask")
                put("hysteria2RawOutbound", JSONObject("""{"custom":[1,true]}"""))
                put("hysteria2RawObfs", JSONObject("""{"custom_obfs":{"enabled":true}}"""))
                put("hysteria2RawTls", JSONObject("""{"custom_tls":["x",2]}"""))
            },
        )

        assertNotNull(stored)
        assertEquals("gecko", stored!!.hysteria2ObfsType)
        assertTrue(
            JSONObject(stored.hysteria2RawOutboundJson)
                .getJSONArray("custom")
                .getBoolean(1),
        )
        assertTrue(
            JSONObject(stored.hysteria2RawObfsJson)
                .getJSONObject("custom_obfs")
                .getBoolean("enabled"),
        )
        assertEquals(
            2,
            JSONObject(stored.hysteria2RawTlsJson)
                .getJSONArray("custom_tls")
                .getInt(1),
        )
    }

    @Test
    fun storedServer_parsesXhttpFieldsAndLegacyPaddingForQuickSettings() {
        val stored = QuickSettingsVpnConfigStore.StoredServer.fromJson(
            JSONObject().apply {
                put("name", "XHTTP")
                put("address", "cdn.example.com")
                put("port", 443)
                put("protocol", "vless")
                put("transport", "xhttp")
                put("xPaddingObfsMode", false)
                put("xPaddingPlacement", "query-in-header")
                put("xPaddingKey", "v")
                put("xPaddingHeader", "Referer")
                put("xPaddingMethod", "tokenish")
                put("xhttpPadding", "100-1000")
                put("sessionIDPlacement", "query")
                put("sessionIDKey", "sid")
                put("seqPlacement", "query")
                put("seqKey", "n")
                put("xhttpRawSettings", JSONObject().put("futureTop", 1))
                put("xhttpRawExtra", JSONObject().put("futureExtra", true))
            },
        )

        assertNotNull(stored)
        assertEquals(false, stored!!.xPaddingObfsMode)
        assertEquals("query-in-header", stored.xPaddingPlacement)
        assertEquals("v", stored.xPaddingKey)
        assertEquals("Referer", stored.xPaddingHeader)
        assertEquals("tokenish", stored.xPaddingMethod)
        assertEquals("100-1000", stored.xPaddingBytes)
        assertEquals("query", stored.sessionIDPlacement)
        assertEquals("sid", stored.sessionIDKey)
        assertEquals("query", stored.seqPlacement)
        assertEquals("n", stored.seqKey)
        assertEquals(1, JSONObject(stored.xhttpRawSettingsJson).getInt("futureTop"))
        assertTrue(JSONObject(stored.xhttpRawExtraJson).getBoolean("futureExtra"))
    }
}
