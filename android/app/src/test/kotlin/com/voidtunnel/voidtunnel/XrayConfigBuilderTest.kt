package com.voidtunnel.voidtunnel

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class XrayConfigBuilderTest {
    @Test
    fun `builds grpc service name and authority for xray`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "grpc.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "grpc",
            transportPath = "/",
            transportServiceName = "grpc",
            transportHost = "edge.example.com",
            tlsEnabled = true,
            tlsSni = "grpc.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
        )

        val grpc = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("outbounds")
            .getJSONObject(0)
            .getJSONObject("streamSettings")
            .getJSONObject("grpcSettings")

        assertEquals("grpc", grpc.getString("serviceName"))
        assertEquals("edge.example.com", grpc.getString("authority"))
    }

    @Test
    fun `builds xhttp stream settings for xray`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "xhttp.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "xhttp",
            transportPath = "/bridge",
            transportServiceName = "",
            transportHost = "cdn.example.com",
            tlsEnabled = true,
            tlsSni = "xhttp.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "h2,http/1.1",
            transportMode = "auto",
        )

        val root = JSONObject(XrayConfigBuilder.build(config))
        assertEquals("none", root.getJSONObject("log").getString("access"))

        val proxy = root.getJSONArray("outbounds").getJSONObject(0)
        val stream = proxy.getJSONObject("streamSettings")

        assertEquals("xhttp", stream.getString("network"))
        val xhttp = stream.getJSONObject("xhttpSettings")
        assertEquals("/bridge", xhttp.getString("path"))
        assertEquals("cdn.example.com", xhttp.getString("host"))
        assertEquals("auto", xhttp.getString("mode"))

        val tls = stream.getJSONObject("tlsSettings")
        assertEquals("xhttp.example.com", tls.getString("serverName"))
        assertTrue(tls.getJSONArray("alpn").length() >= 2)
    }

    @Test
    fun `builds reality settings for xhttp outbound`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "64.188.112.220",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "xhttp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            transportMode = "auto",
            tlsEnabled = true,
            tlsSni = "github.com",
            tlsInsecure = false,
            flow = "",
            security = "reality",
            realityPbk = "public-key",
            realitySid = "ac13d6cdc0e0cce8",
            realitySpiderX = "/",
            fingerprint = "firefox",
            alpn = "",
        )

        val root = JSONObject(XrayConfigBuilder.build(config))
        val stream = root.getJSONArray("outbounds")
            .getJSONObject(0)
            .getJSONObject("streamSettings")

        assertEquals("xhttp", stream.getString("network"))
        assertEquals("reality", stream.getString("security"))
        assertFalse(stream.has("tlsSettings"))

        val reality = stream.getJSONObject("realitySettings")
        assertEquals("github.com", reality.getString("serverName"))
        assertEquals("firefox", reality.getString("fingerprint"))
        assertEquals("public-key", reality.getString("publicKey"))
        assertFalse(reality.has("password"))
        assertEquals("ac13d6cdc0e0cce8", reality.getString("shortId"))
        assertEquals("/", reality.getString("spiderX"))
    }

    @Test
    fun `preserves explicit none fingerprint for reality`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "64.188.112.220",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "xhttp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            transportMode = "auto",
            tlsEnabled = true,
            tlsSni = "github.com",
            tlsInsecure = false,
            flow = "",
            security = "reality",
            realityPbk = "public-key",
            realitySid = "ac13d6cdc0e0cce8",
            realitySpiderX = "/",
            fingerprint = "none",
            alpn = "",
        )

        val reality = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("outbounds")
            .getJSONObject(0)
            .getJSONObject("streamSettings")
            .getJSONObject("realitySettings")

        assertEquals("none", reality.getString("fingerprint"))
    }

    @Test
    fun `does not invent optional reality fingerprint or spiderX`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "64.188.112.220",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "grpc",
            transportPath = "/",
            transportServiceName = "grpc",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "twitch.tv",
            tlsInsecure = false,
            flow = "",
            security = "reality",
            realityPbk = "public-key",
            realitySid = "bb47001994bd2014",
            realitySpiderX = "",
            fingerprint = "",
            alpn = "",
        )

        val reality = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("outbounds")
            .getJSONObject(0)
            .getJSONObject("streamSettings")
            .getJSONObject("realitySettings")

        assertFalse(reality.has("fingerprint"))
        assertFalse(reality.has("spiderX"))
        assertFalse(reality.getBoolean("allowInsecure"))
    }

    @Test
    fun `fragment settings add freedom outbound and proxy dialer`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "frag.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "frag.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            fragmentSettings = XrayFragmentSettings(
                enabled = true,
                packets = "tlshello",
                length = "50-100",
                interval = "10-20",
                maxSplit = "100-200",
                noiseEnabled = true,
                noiseType = "rand",
                noisePacket = "10-20",
                noiseDelay = "10-16",
                noiseApplyTo = "ip",
            ),
        )

        val outbounds = JSONObject(XrayConfigBuilder.build(config)).getJSONArray("outbounds")
        assertEquals(4, outbounds.length())

        val proxy = outbounds.getJSONObject(0)
        assertEquals("proxy", proxy.getString("tag"))
        assertEquals(
            "fragment",
            proxy.getJSONObject("streamSettings")
                .getJSONObject("sockopt")
                .getString("dialerProxy"),
        )

        val fragment = outbounds.getJSONObject(3)
        assertEquals("fragment", fragment.getString("tag"))
        assertEquals("freedom", fragment.getString("protocol"))

        val settings = fragment.getJSONObject("settings")
        val fragmentSettings = settings.getJSONObject("fragment")
        assertEquals("tlshello", fragmentSettings.getString("packets"))
        assertEquals("50-100", fragmentSettings.getString("length"))
        assertEquals("10-20", fragmentSettings.getString("interval"))
        assertEquals("100-200", fragmentSettings.getString("maxSplit"))

        val noise = settings.getJSONArray("noises").getJSONObject(0)
        assertEquals("rand", noise.getString("type"))
        assertEquals("10-20", noise.getString("packet"))
        assertEquals("10-16", noise.getString("delay"))
        assertEquals("ip", noise.getString("applyTo"))
    }

    @Test
    fun `multiplex settings add mux object to proxy outbound`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "mux.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "mux.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            multiplexSettings = XrayMultiplexSettings(
                enabled = true,
                tcpConcurrency = 16,
                xudpConcurrency = -1,
                quicBehavior = "skip",
            ),
        )

        val proxy = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("outbounds")
            .getJSONObject(0)
        val mux = proxy.getJSONObject("mux")

        assertTrue(mux.getBoolean("enabled"))
        assertEquals(16, mux.getInt("concurrency"))
        assertEquals(-1, mux.getInt("xudpConcurrency"))
        assertEquals("skip", mux.getString("xudpProxyUDP443"))
    }

    @Test
    fun `adds local http proxy inbound for external ip probe`() {
        val config = ServerConfig(
            isGlobalProxy = false,
            server = "probe.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "probe.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
        )

        val root = JSONObject(XrayConfigBuilder.build(config))
        val inbounds = root.getJSONArray("inbounds")
        val probeInbound = (0 until inbounds.length())
            .map { inbounds.getJSONObject(it) }
            .first { it.getString("tag") == "external-ip-probe-in" }

        assertEquals("http", probeInbound.getString("protocol"))
        assertEquals(RuntimePorts.XRAY_SOCKS_HOST, probeInbound.getString("listen"))
        assertEquals(RuntimePorts.XRAY_HTTP_PROXY_PORT, probeInbound.getInt("port"))

        val rules = root.getJSONObject("routing").getJSONArray("rules")
        val probeRule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .first {
                it.optJSONArray("inboundTag")?.getString(0) == "external-ip-probe-in"
            }
        assertEquals("proxy", probeRule.getString("outboundTag"))
    }

    @Test
    fun `builds experimental xray tun inbound without socks inbound`() {
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = true,
            server = "tun.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
        )

        val root = JSONObject(XrayTunConfigBuilder.build(config))
        val inbounds = root.getJSONArray("inbounds")
        val inbound = inbounds.getJSONObject(0)

        assertEquals("tun-in", inbound.getString("tag"))
        assertEquals("tun", inbound.getString("protocol"))
        assertFalse(inbound.has("listen"))
        assertFalse(inbound.getJSONObject("settings").has("udp"))
        assertEquals(0, inbound.getJSONObject("settings").getInt("UserLevel"))
        assertEquals(1500, inbound.getJSONObject("settings").getInt("MTU"))
        val sniffing = inbound.getJSONObject("sniffing")
        assertTrue(sniffing.getBoolean("enabled"))
        assertTrue(sniffing.getBoolean("routeOnly"))
        assertTrue(
            (0 until sniffing.getJSONArray("destOverride").length())
                .map { sniffing.getJSONArray("destOverride").getString(it) }
                .containsAll(listOf("http", "tls", "quic")),
        )
        val inboundTags = (0 until inbounds.length())
            .map { inbounds.getJSONObject(it).getString("tag") }
        assertFalse(inboundTags.contains("socks-in"))
        assertTrue(inboundTags.contains("external-ip-probe-in"))

        val dns = root.getJSONObject("dns")
        assertEquals("1.1.1.1", dns.getJSONArray("servers").getString(0))

        val outbounds = root.getJSONArray("outbounds")
        val proxyOutbound = outbounds.getJSONObject(0)
        assertEquals("proxy", proxyOutbound.getString("tag"))

        val quicBlockOutbound = (0 until outbounds.length())
            .map { outbounds.getJSONObject(it) }
            .first { it.getString("tag") == "block-quic" }
        assertEquals("blackhole", quicBlockOutbound.getString("protocol"))

        val rules = root.getJSONObject("routing").getJSONArray("rules")
        val dnsProxyRule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .first { it.optString("port") == "53" }
        assertEquals("field", dnsProxyRule.getString("type"))
        assertEquals("tun-in", dnsProxyRule.getJSONArray("inboundTag").getString(0))
        assertEquals("proxy", dnsProxyRule.getString("outboundTag"))

        val quicBlockRule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .first { it.optString("outboundTag") == "block-quic" }
        assertEquals("field", quicBlockRule.getString("type"))
        assertEquals("tun-in", quicBlockRule.getJSONArray("inboundTag").getString(0))
        assertEquals("udp", quicBlockRule.getString("network"))
        assertEquals("443", quicBlockRule.getString("port"))
        assertEquals("block-quic", quicBlockRule.getString("outboundTag"))
    }

    @Test
    fun `xray tun block udp routes udp to block after dns proxy`() {
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = true,
            server = "tun-block-udp.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun-block-udp.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            tunnelNetworkSettings = TunnelNetworkSettings(blockUdp = true),
        )

        val root = JSONObject(XrayTunConfigBuilder.build(config))
        val outbounds = (0 until root.getJSONArray("outbounds").length())
            .map { root.getJSONArray("outbounds").getJSONObject(it) }
        assertFalse(outbounds.any { it.optString("tag") == "block-quic" })
        assertTrue(outbounds.any { it.optString("tag") == "block" })

        val rules = root.getJSONObject("routing").getJSONArray("rules")
        val ruleList = (0 until rules.length()).map { rules.getJSONObject(it) }
        val dnsRuleIndex = ruleList.indexOfFirst {
            it.optString("port") == "53" && it.optString("outboundTag") == "proxy"
        }
        val udpBlockRuleIndex = ruleList.indexOfFirst {
            it.optString("network") == "udp" &&
                it.optString("outboundTag") == "block"
        }
        assertTrue(dnsRuleIndex >= 0)
        assertTrue(udpBlockRuleIndex > dnsRuleIndex)
        val udpBlockRule = ruleList[udpBlockRuleIndex]
        assertEquals("field", udpBlockRule.getString("type"))
        assertEquals("tun-in", udpBlockRule.getJSONArray("inboundTag").getString(0))
        assertFalse(udpBlockRule.has("port"))
        // Global proxy: no LAN exemption, no QUIC-specific block rule.
        assertFalse(
            ruleList.any { it.optString("outboundTag") == "direct" && it.optString("network") == "udp" },
        )
    }

    @Test
    fun `xray tun block udp lets LAN udp go direct in non-global mode`() {
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = false,
            server = "tun-block-udp-lan.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun-block-udp-lan.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            tunnelNetworkSettings = TunnelNetworkSettings(blockUdp = true),
        )

        val root = JSONObject(XrayTunConfigBuilder.build(config))
        val rules = root.getJSONObject("routing").getJSONArray("rules")
        val ruleList = (0 until rules.length()).map { rules.getJSONObject(it) }

        val lanUdpDirectIndex = ruleList.indexOfFirst {
            it.optString("network") == "udp" &&
                it.optString("outboundTag") == "direct" &&
                it.has("ip")
        }
        val udpBlockIndex = ruleList.indexOfFirst {
            it.optString("network") == "udp" &&
                it.optString("outboundTag") == "block"
        }
        assertTrue(lanUdpDirectIndex >= 0)
        assertTrue(udpBlockIndex > lanUdpDirectIndex)

        val lanRule = ruleList[lanUdpDirectIndex]
        val ips = (0 until lanRule.getJSONArray("ip").length())
            .map { lanRule.getJSONArray("ip").getString(it) }
        // Sanity: standard private ranges show up here.
        assertTrue(ips.contains("192.168.0.0/16"))
        assertTrue(ips.contains("10.0.0.0/8"))
    }

    @Test
    fun `xray tun block udp runs after user routing rules`() {
        // A user rule that explicitly directs UDP/443 to the proxy must
        // win over the trailing UDP block — otherwise the toggle silently
        // overrides the user's intent.
        val userRules = "[{" +
            "\"network\":\"udp\"," +
            "\"port\":\"443\"," +
            "\"outboundTag\":\"proxy\"" +
        "}]"
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = true,
            server = "tun-block-udp-user.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun-block-udp-user.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            userRoutingRulesJson = userRules,
            tunnelNetworkSettings = TunnelNetworkSettings(blockUdp = true),
        )

        val root = JSONObject(XrayTunConfigBuilder.build(config))
        val rules = root.getJSONObject("routing").getJSONArray("rules")
        val ruleList = (0 until rules.length()).map { rules.getJSONObject(it) }

        val userRuleIndex = ruleList.indexOfFirst {
            it.optString("outboundTag") == "proxy" &&
                it.optString("port") == "443" &&
                it.optJSONArray("network")?.optString(0) == "udp"
        }
        val udpBlockIndex = ruleList.indexOfFirst {
            it.optString("network") == "udp" &&
                it.optString("outboundTag") == "block"
        }
        assertTrue(userRuleIndex >= 0)
        assertTrue(udpBlockIndex >= 0)
        assertTrue(userRuleIndex < udpBlockIndex)
    }

    @Test
    fun `xray tun config honors local dns and packet analysis settings`() {
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = true,
            server = "tun-local-dns.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun-local-dns.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            tunnelNetworkSettings = TunnelNetworkSettings(
                useLocalDns = true,
                mtu = 1600,
                packetAnalysisEnabled = false,
            ),
        )

        val root = JSONObject(XrayTunConfigBuilder.build(config))
        assertEquals("localhost", root.getJSONObject("dns").getJSONArray("servers").getString(0))
        val inbound = root.getJSONArray("inbounds").getJSONObject(0)
        assertEquals(1600, inbound.getJSONObject("settings").getInt("MTU"))
        assertFalse(inbound.has("sniffing"))
    }

    @Test
    fun `xray tun config uses custom dns server when enabled`() {
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = true,
            server = "tun-custom-dns.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun-custom-dns.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            tunnelNetworkSettings = TunnelNetworkSettings(
                xrayTunDnsEnabled = true,
                xrayTunDnsServer = "9.9.9.9",
            ),
        )

        val servers = JSONObject(XrayTunConfigBuilder.build(config))
            .getJSONObject("dns")
            .getJSONArray("servers")
        assertEquals("9.9.9.9", servers.getString(0))
    }

    @Test
    fun `xray tun config ignores custom dns when toggle is off`() {
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = true,
            server = "tun-default-dns.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun-default-dns.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            tunnelNetworkSettings = TunnelNetworkSettings(
                xrayTunDnsEnabled = false,
                xrayTunDnsServer = "9.9.9.9",
            ),
        )

        val servers = JSONObject(XrayTunConfigBuilder.build(config))
            .getJSONObject("dns")
            .getJSONArray("servers")
        assertEquals("1.1.1.1", servers.getString(0))
    }

    @Test
    fun `xray tun config prefers local dns over custom dns`() {
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = true,
            server = "tun-local-over-custom.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun-local-over-custom.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            tunnelNetworkSettings = TunnelNetworkSettings(
                useLocalDns = true,
                xrayTunDnsEnabled = true,
                xrayTunDnsServer = "9.9.9.9",
            ),
        )

        val servers = JSONObject(XrayTunConfigBuilder.build(config))
            .getJSONObject("dns")
            .getJSONArray("servers")
        assertEquals("localhost", servers.getString(0))
    }

    @Test
    fun `socks inbound enables sniffing for domain routing`() {
        val config = ServerConfig(
            isGlobalProxy = false,
            server = "sniff.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "sniff.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
        )

        val inbound = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("inbounds")
            .getJSONObject(0)
        val sniffing = inbound.getJSONObject("sniffing")
        val overrides = (0 until sniffing.getJSONArray("destOverride").length())
            .map { sniffing.getJSONArray("destOverride").getString(it) }

        assertTrue(sniffing.getBoolean("enabled"))
        assertTrue(sniffing.getBoolean("routeOnly"))
        assertTrue(overrides.containsAll(listOf("http", "tls", "quic")))
    }

    @Test
    fun `packet analysis disabled omits socks inbound sniffing`() {
        val config = ServerConfig(
            isGlobalProxy = false,
            server = "no-sniff.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "no-sniff.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            tunnelNetworkSettings = TunnelNetworkSettings(packetAnalysisEnabled = false),
        )

        val inbound = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("inbounds")
            .getJSONObject(0)

        assertFalse(inbound.has("sniffing"))
    }

    @Test
    fun `server resolving adds sockopt domain strategy`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "resolve.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "resolve.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            tunnelNetworkSettings = TunnelNetworkSettings(
                serverResolvingEnabled = true,
            ),
        )

        val root = JSONObject(XrayConfigBuilder.build(config))
        val sockopt = root.getJSONArray("outbounds")
            .getJSONObject(0)
            .getJSONObject("streamSettings")
            .getJSONObject("sockopt")
        assertEquals("UseIP", sockopt.getString("domainStrategy"))
    }

    @Test
    fun `injects user routing rules and skips invalid ones`() {
        val rulesJson = """
            [
              {"__name__":"Block QUIC","type":"field","port":"443","network":["udp"],"outboundTag":"block"},
              {"__name__":"VK direct","type":"field","domain":["geosite:vk"],"outboundTag":"direct"},
              {"__name__":"Bad outbound","type":"field","domain":["geosite:test"],"outboundTag":"unknown"},
              {"__name__":"No matchers","type":"field","outboundTag":"proxy"}
            ]
        """.trimIndent()

        val config = ServerConfig(
            isGlobalProxy = false,
            server = "rules.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "rules.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            userRoutingRulesJson = rulesJson,
        )

        val root = JSONObject(XrayConfigBuilder.build(config))

        val blockOutbound = (0 until root.getJSONArray("outbounds").length())
            .map { root.getJSONArray("outbounds").getJSONObject(it) }
            .first { it.getString("tag") == "block" }
        assertEquals("blackhole", blockOutbound.getString("protocol"))

        val rules = root.getJSONObject("routing").getJSONArray("rules")
        val byTag = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .groupBy { it.optString("outboundTag") }

        assertEquals(1, byTag["block"]?.size)
        assertEquals("443", byTag["block"]!![0].getString("port"))
        assertEquals("udp", byTag["block"]!![0].getJSONArray("network").getString(0))

        assertTrue(
            byTag["direct"].orEmpty().any {
                it.optJSONArray("domain")?.getString(0) == "geosite:vk"
            },
        )

        // Invalid outboundTag and matcher-less rules must be dropped before
        // the config reaches Xray's config test, otherwise the tunnel never
        // comes up.
        assertFalse(byTag.keys.contains("unknown"))
        val proxyRules = byTag["proxy"].orEmpty()
        assertTrue(
            proxyRules.none {
                !it.has("domain") &&
                    !it.has("inboundTag") &&
                    !it.has("ip") &&
                    !it.has("port") &&
                    !it.has("network") &&
                    !it.has("protocol")
            },
        )
    }

    @Test
    fun `global proxy takes priority over user direct rules`() {
        val rulesJson = """
            [
              {"__name__":"Ads block","type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block"},
              {"__name__":"RU direct","type":"field","domain":["geosite:category-gov-ru"],"outboundTag":"direct"},
              {"__name__":"AI proxy","type":"field","domain":["domain:example.ai"],"outboundTag":"proxy"}
            ]
        """.trimIndent()

        val config = ServerConfig(
            isGlobalProxy = true,
            server = "global.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "global.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            userRoutingRulesJson = rulesJson,
        )

        val rules = JSONObject(XrayConfigBuilder.build(config))
            .getJSONObject("routing")
            .getJSONArray("rules")
        val routeRules = (0 until rules.length()).map { rules.getJSONObject(it) }

        assertTrue(routeRules.any { it.optString("outboundTag") == "block" })
        assertTrue(routeRules.any { it.optString("outboundTag") == "proxy" })
        assertFalse(routeRules.any { it.optString("outboundTag") == "direct" })
    }

    @Test
    fun `proxy-selected app routing takes priority over user direct rules`() {
        val rulesJson = """
            [
              {"__name__":"Ads block","type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block"},
              {"__name__":"RU direct","type":"field","domain":["geosite:category-gov-ru"],"outboundTag":"direct"},
              {"__name__":"AI proxy","type":"field","domain":["domain:example.ai"],"outboundTag":"proxy"}
            ]
        """.trimIndent()

        val config = ServerConfig(
            isGlobalProxy = false,
            server = "per-app.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "per-app.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            appRoutingMode = AppRoutingMode.PROXY_SELECTED,
            appRoutingPackages = listOf("org.telegram.messenger"),
            userRoutingRulesJson = rulesJson,
        )

        val rules = JSONObject(XrayConfigBuilder.build(config))
            .getJSONObject("routing")
            .getJSONArray("rules")
        val routeRules = (0 until rules.length()).map { rules.getJSONObject(it) }

        assertTrue(
            routeRules.any {
                it.optString("outboundTag") == "block" &&
                    it.optJSONArray("domain")?.getString(0) == "geosite:category-ads-all"
            },
        )
        assertTrue(
            routeRules.any {
                it.optString("outboundTag") == "proxy" &&
                    it.optJSONArray("domain")?.getString(0) == "domain:example.ai"
            },
        )
        assertTrue(
            routeRules.any {
                it.optString("outboundTag") == "proxy" &&
                    !it.has("domain") &&
                    !it.has("ip") &&
                    !it.has("port") &&
                    !it.has("network") &&
                    !it.has("protocol")
            },
        )
        assertFalse(routeRules.any { it.optString("outboundTag") == "direct" })
    }

    @Test
    fun `socks inbound requires password auth when credentials are configured`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "auth.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "auth.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            proxyUser = "void-user",
            proxyPassword = "secret-pass",
        )

        val socks = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("inbounds")
            .getJSONObject(0)
        val settings = socks.getJSONObject("settings")

        assertEquals("password", settings.getString("auth"))
        val account = settings.getJSONArray("accounts").getJSONObject(0)
        assertEquals("void-user", account.getString("user"))
        assertEquals("secret-pass", account.getString("pass"))
        assertTrue(settings.getBoolean("udp"))
    }

    @Test
    fun `external ip probe inbound enforces basic auth when credentials are configured`() {
        val config = ServerConfig(
            isGlobalProxy = false,
            server = "probe.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "probe.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            proxyUser = "u",
            proxyPassword = "p",
        )

        val inbounds = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("inbounds")
        val probe = (0 until inbounds.length())
            .map { inbounds.getJSONObject(it) }
            .first { it.getString("tag") == "external-ip-probe-in" }
        val account = probe.getJSONObject("settings")
            .getJSONArray("accounts")
            .getJSONObject(0)

        assertEquals("u", account.getString("user"))
        assertEquals("p", account.getString("pass"))
    }

    @Test
    fun `rejects hysteria2 protocol in xray config`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "hy2.example.com",
            serverPort = 443,
            protocol = "hysteria2",
            uuid = "secret-auth",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "edge.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
        )

        assertThrows(IllegalArgumentException::class.java) {
            XrayConfigBuilder.build(config)
        }
    }

    @Test
    fun `inbounds fall back to noauth when credentials are blank`() {
        val config = ServerConfig(
            isGlobalProxy = true,
            server = "legacy.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "legacy.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
        )

        val inbounds = JSONObject(XrayConfigBuilder.build(config))
            .getJSONArray("inbounds")
        val socks = inbounds.getJSONObject(0)
        val socksSettings = socks.getJSONObject("settings")
        assertEquals("noauth", socksSettings.getString("auth"))
        assertFalse(socksSettings.has("accounts"))

        val probe = (0 until inbounds.length())
            .map { inbounds.getJSONObject(it) }
            .first { it.getString("tag") == "external-ip-probe-in" }
        assertFalse(probe.getJSONObject("settings").has("accounts"))
    }

    @Test
    fun `experimental xray tun config also enforces probe auth when credentials are configured`() {
        val config = ServerConfig(
            tunEngineMode = TunEngineMode.XRAY,
            isGlobalProxy = true,
            server = "tun.example.com",
            serverPort = 443,
            uuid = "00000000-0000-4000-8000-000000000000",
            transport = "tcp",
            transportPath = "/",
            transportServiceName = "",
            transportHost = "",
            tlsEnabled = true,
            tlsSni = "tun.example.com",
            tlsInsecure = false,
            flow = "",
            security = "tls",
            realityPbk = "",
            realitySid = "",
            fingerprint = "",
            alpn = "",
            proxyUser = "tun-user",
            proxyPassword = "tun-pass",
        )

        val inbounds = JSONObject(XrayTunConfigBuilder.build(config))
            .getJSONArray("inbounds")
        val probe = (0 until inbounds.length())
            .map { inbounds.getJSONObject(it) }
            .first { it.getString("tag") == "external-ip-probe-in" }
        val account = probe.getJSONObject("settings")
            .getJSONArray("accounts")
            .getJSONObject(0)
        assertEquals("tun-user", account.getString("user"))
        assertEquals("tun-pass", account.getString("pass"))
    }
}
