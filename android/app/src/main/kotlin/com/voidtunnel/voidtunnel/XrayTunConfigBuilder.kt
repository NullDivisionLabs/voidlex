package com.voidtunnel.voidtunnel

import org.json.JSONArray
import org.json.JSONObject

internal object XrayTunConfigBuilder {
    private const val TUN_INBOUND_TAG = "tun-in"
    private const val TUN_NAME = "voidtun0"
    private const val BLOCK_QUIC_TAG = "block-quic"
    private const val PROXY_OUTBOUND_TAG = "proxy"

    fun build(config: ServerConfig): String {
        val networkSettings = config.tunnelNetworkSettings.normalized()
        return XrayConfigBuilder.buildWithInbounds(
            config = config,
            inbounds = JSONArray().put(buildTunInbound(config)),
            extraOutbounds = buildExtraOutbounds(networkSettings),
            leadingRoutingRules = buildLeadingRoutingRules(networkSettings),
            trailingRoutingRules = buildTrailingRoutingRules(config, networkSettings),
            dns = XrayConfigBuilder.buildDns(networkSettings),
        )
    }

    private fun buildExtraOutbounds(settings: TunnelNetworkSettings): JSONArray {
        return JSONArray().apply {
            if (!settings.blockUdp) {
                put(buildQuicBlockOutbound())
            }
        }
    }

    private fun buildLeadingRoutingRules(settings: TunnelNetworkSettings): JSONArray {
        return JSONArray().apply {
            put(buildDnsProxyRule())
            if (!settings.blockUdp) {
                put(buildQuicBlockRule())
            }
        }
    }

    /// UDP block lives in the trailing slot for two reasons:
    ///   * it must run AFTER user routing rules so a user-defined "let
    ///     destination X over UDP through" rule can override it;
    ///   * when the config also installs a "private IP → direct" fallback,
    ///     we need to keep LAN UDP (mDNS, SSDP, NTP-to-router, multicast,
    ///     local DNS) reachable. Since Xray has no "ipNotIn" matcher, we
    ///     bake the LAN bypass into this trailing slot ahead of the block.
    private fun buildTrailingRoutingRules(
        config: ServerConfig,
        settings: TunnelNetworkSettings,
    ): JSONArray {
        return JSONArray().apply {
            if (!settings.blockUdp) return@apply
            if (XrayConfigBuilder.usesPrivateIpDirectFallback(config)) {
                put(buildLanUdpDirectRule())
            }
            put(buildUdpBlockRule())
        }
    }

    private fun buildTunInbound(config: ServerConfig): JSONObject {
        val networkSettings = config.tunnelNetworkSettings.normalized()
        return JSONObject().apply {
            put("tag", TUN_INBOUND_TAG)
            put("protocol", "tun")
            put("port", 0)
            put("settings", JSONObject().apply {
                put("name", TUN_NAME)
                put("MTU", networkSettings.mtu)
                put("UserLevel", 0)
            })
            if (networkSettings.packetAnalysisEnabled) {
                put("sniffing", XrayConfigBuilder.buildSniffing())
            }
        }
    }

    private fun buildQuicBlockOutbound(): JSONObject {
        return JSONObject().apply {
            put("tag", BLOCK_QUIC_TAG)
            put("protocol", "blackhole")
            put("settings", JSONObject().apply {
                put("response", JSONObject().apply {
                    put("type", "none")
                })
            })
        }
    }

    private fun buildQuicBlockRule(): JSONObject {
        return JSONObject().apply {
            put("type", "field")
            put("inboundTag", JSONArray().put(TUN_INBOUND_TAG))
            put("network", "udp")
            put("port", "443")
            put("outboundTag", BLOCK_QUIC_TAG)
        }
    }

    private fun buildUdpBlockRule(): JSONObject {
        return JSONObject().apply {
            put("type", "field")
            put("inboundTag", JSONArray().put(TUN_INBOUND_TAG))
            put("network", "udp")
            put("outboundTag", XrayConfigBuilder.BLOCK_TAG)
        }
    }

    private fun buildLanUdpDirectRule(): JSONObject {
        return JSONObject().apply {
            put("type", "field")
            put("inboundTag", JSONArray().put(TUN_INBOUND_TAG))
            put("network", "udp")
            put("ip", JSONArray(XrayConfigBuilder.privateIpRanges))
            put("outboundTag", XrayConfigBuilder.DIRECT_TAG)
        }
    }

    private fun buildDnsProxyRule(): JSONObject {
        return JSONObject().apply {
            put("type", "field")
            put("inboundTag", JSONArray().put(TUN_INBOUND_TAG))
            put("port", "53")
            put("outboundTag", PROXY_OUTBOUND_TAG)
        }
    }
}
