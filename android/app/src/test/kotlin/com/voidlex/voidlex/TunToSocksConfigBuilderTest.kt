package com.voidlex.voidlex

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TunToSocksConfigBuilderTest {
    @Test
    fun `routes tun traffic to local xray socks inbound`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(isGlobalProxy = true),
        )

        val inbound = root.getJSONArray("inbounds").getJSONObject(0)
        assertEquals("tun", inbound.getString("type"))
        assertEquals("tun-in", inbound.getString("tag"))
        assertEquals(TunAddressDefaults.IPV4_CIDR, inbound.getJSONArray("address").getString(0))
        assertEquals(1, inbound.getJSONArray("address").length())
        assertEquals(1500, inbound.getInt("mtu"))
        assertEquals("system", inbound.getString("stack"))
        assertTrue(inbound.getBoolean("auto_route"))
        assertFalse(inbound.has("include_package"))
        assertFalse(inbound.has("exclude_package"))

        val proxy = root.getJSONArray("outbounds").getJSONObject(0)
        assertEquals("socks", proxy.getString("type"))
        assertEquals(RuntimePorts.XRAY_SOCKS_HOST, proxy.getString("server"))
        assertEquals(RuntimePorts.XRAY_SOCKS_PORT, proxy.getInt("server_port"))
    }

    @Test
    fun `uses remote dns through xray socks outbound`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(isGlobalProxy = true),
        )

        val dns = root.getJSONObject("dns")
        val server = dns.getJSONArray("servers").getJSONObject(0)
        assertEquals("https", server.getString("type"))
        assertEquals("1.1.1.1", server.getString("server"))
        assertEquals("proxy", server.getString("detour"))
    }

    @Test
    fun `uses local dns when configured`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(
                isGlobalProxy = true,
                tunnelNetworkSettings = TunnelNetworkSettings(useLocalDns = true),
            ),
        )

        val dns = root.getJSONObject("dns")
        val server = dns.getJSONArray("servers").getJSONObject(0)
        assertEquals("local", server.getString("type"))
        assertEquals("dns-local", server.getString("tag"))
        assertEquals("dns-local", dns.getString("final"))
        assertFalse(server.has("detour"))
    }

    @Test
    fun `applies tun stack mtu and mixed ip mode`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(
                isGlobalProxy = true,
                tunnelNetworkSettings = TunnelNetworkSettings(
                    networkStack = TunnelNetworkStack.GVISOR,
                    mtu = 1600,
                    ipMode = TunnelIpMode.MIXED,
                ),
            ),
        )

        val inbound = root.getJSONArray("inbounds").getJSONObject(0)
        val addresses = (0 until inbound.getJSONArray("address").length())
            .map { inbound.getJSONArray("address").getString(it) }

        assertEquals("gvisor", inbound.getString("stack"))
        assertEquals(1600, inbound.getInt("mtu"))
        assertTrue(addresses.contains(TunAddressDefaults.IPV4_CIDR))
        assertTrue(addresses.contains(TunAddressDefaults.IPV6_CIDR))
    }

    @Test
    fun `ipv6 ip mode emits only ipv6 tun address`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(
                isGlobalProxy = true,
                tunnelNetworkSettings = TunnelNetworkSettings(ipMode = TunnelIpMode.IPV6),
            ),
        )

        val addresses = root.getJSONArray("inbounds")
            .getJSONObject(0)
            .getJSONArray("address")

        assertEquals(1, addresses.length())
        assertEquals(TunAddressDefaults.IPV6_CIDR, addresses.getString(0))
    }

    @Test
    fun `packet analysis disabled omits sniff route`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(
                isGlobalProxy = true,
                tunnelNetworkSettings = TunnelNetworkSettings(packetAnalysisEnabled = false),
            ),
        )

        val rules = root.getJSONObject("route").getJSONArray("rules")
        val hasSniffRule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .any { it.optString("action") == "sniff" }
        val hasDnsHijackRule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .any { it.optString("action") == "hijack-dns" }

        assertFalse(hasSniffRule)
        assertTrue(hasDnsHijackRule)
    }

    @Test
    fun `block udp adds block outbound and udp route after dns hijack`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(
                isGlobalProxy = true,
                tunnelNetworkSettings = TunnelNetworkSettings(blockUdp = true),
            ),
        )

        val blockOutbound = (0 until root.getJSONArray("outbounds").length())
            .map { root.getJSONArray("outbounds").getJSONObject(it) }
            .first { it.getString("tag") == "block" }
        assertEquals("block", blockOutbound.getString("type"))

        val rules = root.getJSONObject("route").getJSONArray("rules")
        val ruleList = (0 until rules.length()).map { rules.getJSONObject(it) }
        val dnsRuleIndex = ruleList.indexOfFirst { it.optString("action") == "hijack-dns" }
        val udpBlockRuleIndex = ruleList.indexOfFirst {
            it.optString("inbound") == "tun-in" &&
                it.optString("network") == "udp" &&
                it.optString("outbound") == "block"
        }
        assertTrue(dnsRuleIndex >= 0)
        assertTrue(udpBlockRuleIndex > dnsRuleIndex)
        val udpBlockRule = ruleList[udpBlockRuleIndex]
        assertEquals("route", udpBlockRule.getString("action"))
    }

    @Test
    fun `block udp lets LAN traffic go direct in non-global mode`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(
                isGlobalProxy = false,
                tunnelNetworkSettings = TunnelNetworkSettings(blockUdp = true),
            ),
        )

        val rules = root.getJSONObject("route").getJSONArray("rules")
        val ruleList = (0 until rules.length()).map { rules.getJSONObject(it) }
        val privateIpRuleIndex = ruleList.indexOfFirst { it.optBoolean("ip_is_private") }
        val udpBlockRuleIndex = ruleList.indexOfFirst {
            it.optString("inbound") == "tun-in" &&
                it.optString("network") == "udp" &&
                it.optString("outbound") == "block"
        }
        assertTrue(privateIpRuleIndex >= 0)
        assertTrue(udpBlockRuleIndex >= 0)
        // LAN UDP (mDNS, NTP-to-router, multicast) must escape to direct
        // before being swallowed by the global UDP block.
        assertTrue(privateIpRuleIndex < udpBlockRuleIndex)
    }

    @Test
    fun `dns hijack works even with packet analysis disabled`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(
                isGlobalProxy = true,
                tunnelNetworkSettings = TunnelNetworkSettings(
                    packetAnalysisEnabled = false,
                    blockUdp = true,
                ),
            ),
        )

        val rules = root.getJSONObject("route").getJSONArray("rules")
        val ruleList = (0 until rules.length()).map { rules.getJSONObject(it) }
        // No sniff rule when packet analysis is off — protocol=dns matcher
        // would not fire, so an explicit port=53 hijack must be present
        // (otherwise UDP/53 falls through to the UDP block below).
        assertFalse(ruleList.any { it.optString("action") == "sniff" })
        val portHijack = ruleList.firstOrNull {
            it.optString("action") == "hijack-dns" && it.optInt("port", -1) == 53
        }
        assertEquals("tun-in", portHijack?.optString("inbound"))

        val portHijackIndex = ruleList.indexOf(portHijack)
        val udpBlockIndex = ruleList.indexOfFirst {
            it.optString("network") == "udp" && it.optString("outbound") == "block"
        }
        assertTrue(portHijackIndex >= 0)
        assertTrue(udpBlockIndex > portHijackIndex)
    }

    @Test
    fun `bypass mode routes private IPs direct`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(isGlobalProxy = false),
        )

        val rules = root.getJSONObject("route").getJSONArray("rules")
        val privateRule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .firstOrNull { it.optBoolean("ip_is_private") }

        assertEquals("direct", privateRule?.getString("outbound"))
    }

    @Test
    fun `global mode does not add private IP direct rule`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(isGlobalProxy = true),
        )

        val rules = root.getJSONObject("route").getJSONArray("rules")
        val hasPrivateRule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .any { it.optBoolean("ip_is_private") }

        assertFalse(hasPrivateRule)
    }

    // Per-app routing is enforced via LibboxTunRuntime.buildOverrideOptions,
    // not via include_package/exclude_package fields in the JSON. This single
    // test pins the invariant — the previous version of the suite asserted
    // the same thing across four near-identical scenarios.
    @Test
    fun `app routing never lands in sing-box JSON inbound`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(isGlobalProxy = false),
        )

        val inbound = root.getJSONArray("inbounds").getJSONObject(0)
        assertFalse(inbound.has("include_package"))
        assertFalse(inbound.has("exclude_package"))
    }

    @Test
    fun `local socks outbound carries credentials when configured`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(
                isGlobalProxy = true,
                proxyUser = "void-user",
                proxyPassword = "void-secret",
            ),
        )

        val proxy = root.getJSONArray("outbounds").getJSONObject(0)
        assertEquals("socks", proxy.getString("type"))
        assertEquals("void-user", proxy.getString("username"))
        assertEquals("void-secret", proxy.getString("password"))
    }

    @Test
    fun `local socks outbound omits credentials when blank`() {
        val root = JSONObject(
            TunToSocksConfigBuilder.build(isGlobalProxy = true),
        )

        val proxy = root.getJSONArray("outbounds").getJSONObject(0)
        assertEquals("socks", proxy.getString("type"))
        assertFalse(proxy.has("username"))
        assertFalse(proxy.has("password"))
    }
}
