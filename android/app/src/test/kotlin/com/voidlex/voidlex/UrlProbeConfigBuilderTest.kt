package com.voidlex.voidlex

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class UrlProbeConfigBuilderTest {
    @Test fun `VLESS probe isolates port and rules while retaining outbound fields`() {
        for (security in listOf("tls", "reality")) {
            for (fingerprint in listOf("", "hellosafari_16_0", "hellochrome_120", "helloios_14", "imported-profile")) {
                val config = base().copy(
                    transport = "xhttp", transportMode = "packet-up",
                    transportPath = "/probe", transportHost = "front.example.com",
                    security = security, fingerprint = fingerprint,
                    xhttpRawExtraJson = "{\"scMaxConcurrentPosts\":4}",
                    detourServer = base().copy(server = "entry.example.com"),
                    userRoutingRulesJson = "[{\"type\":\"field\",\"outboundTag\":\"direct\"}]",
                    hotspotBindEnabled = true, httpProxyAuthEnabled = true,
                )
                val root = JSONObject(UrlProbeConfigBuilder.build(config, 23111))
                val inbounds = root.getJSONArray("inbounds")
                assertEquals(1, inbounds.length())
                val inbound = inbounds.getJSONObject(0)
                assertEquals(23111, inbound.getInt("port"))
                assertEquals("127.0.0.1", inbound.getString("listen"))
                assertEquals("http", inbound.getString("protocol"))
                assertFalse(inbound.getJSONObject("settings").has("accounts"))
                val proxy = root.getJSONArray("outbounds").getJSONObject(0)
                val endpoint = proxy.getJSONObject("settings").getJSONArray("vnext").getJSONObject(0)
                assertEquals(config.server, endpoint.getString("address"))
                assertEquals(config.uuid, endpoint.getJSONArray("users").getJSONObject(0).getString("id"))
                assertFalse(proxy.has("proxySettings"))
                val stream = proxy.getJSONObject("streamSettings")
                val tls = stream.getJSONObject(if (security == "tls") "tlsSettings" else "realitySettings")
                if (fingerprint.isNotEmpty()) assertEquals(fingerprint, tls.getString("fingerprint"))
                assertEquals("packet-up", stream.getJSONObject("xhttpSettings").getString("mode"))
                assertEquals(4, stream.getJSONObject("xhttpSettings").getJSONObject("extra").getInt("scMaxConcurrentPosts"))
                val firstRule = root.getJSONObject("routing").getJSONArray("rules").getJSONObject(0)
                assertEquals("proxy", firstRule.getString("outboundTag"))
            }
        }
    }

    @Test fun `Hysteria2 and Naive probes use real direct libbox outbound with no tun`() {
        val hy2 = base().copy(protocol = "hysteria2", uuid = "hy2-password",
            hysteria2ObfsType = "salamander", hysteria2ObfsPassword = "mask",
            hysteria2RawTlsJson = "{\"pin_sha256\":[\"pin\"]}")
        val naive = base().copy(protocol = "naive", naiveUsername = "user",
            naivePassword = "password", naiveQuic = true)
        for (config in listOf(hy2, naive)) {
            val root = JSONObject(UrlProbeConfigBuilder.build(config, 23112))
            val inbound = root.getJSONArray("inbounds").getJSONObject(0)
            assertEquals("http", inbound.getString("type"))
            assertEquals(23112, inbound.getInt("listen_port"))
            assertFalse(inbound.has("auto_route"))
            assertEquals(1, root.getJSONArray("outbounds").length())
            val proxy = root.getJSONArray("outbounds").getJSONObject(0)
            assertEquals(config.protocol, proxy.getString("type"))
            assertEquals(config.server, proxy.getString("server"))
            assertEquals("proxy", root.getJSONObject("route").getString("final"))
            assertFalse(root.getJSONObject("route").has("rules"))
            if (config.protocol == "hysteria2") {
                assertEquals("hy2-password", proxy.getString("password"))
                assertEquals("mask", proxy.getJSONObject("obfs").getString("password"))
                assertEquals("pin", proxy.getJSONObject("tls").getJSONArray("pin_sha256").getString(0))
            } else {
                assertEquals("user", proxy.getString("username"))
                assertEquals("password", proxy.getString("password"))
                assertTrue(proxy.getBoolean("quic"))
            }
        }
    }

    private fun base() = ServerConfig(isGlobalProxy = false, server = "node.example.com",
        serverPort = 443, uuid = "00000000-0000-0000-0000-000000000000",
        transport = "tcp", transportPath = "/", transportServiceName = "",
        transportHost = "", tlsEnabled = true, tlsSni = "sni.example.com",
        tlsInsecure = false, flow = "", security = "tls", realityPbk = "key",
        realitySid = "01", fingerprint = "chrome", alpn = "h2")
}
