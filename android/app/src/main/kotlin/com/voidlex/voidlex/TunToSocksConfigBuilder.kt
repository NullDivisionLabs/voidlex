package com.voidlex.voidlex

import org.json.JSONArray
import org.json.JSONObject

internal object TunToSocksConfigBuilder {
    private const val LOG_LEVEL = "info"
    private const val TUN_INBOUND_TAG = "tun-in"
    private const val PROBE_INBOUND_TAG = "probe-in"
    private const val PROXY_OUTBOUND_TAG = "proxy"
    private const val DIRECT_OUTBOUND_TAG = "direct"
    private const val BLOCK_OUTBOUND_TAG = "block"
    private const val DNS_REMOTE_TAG = "dns-remote"
    private const val DNS_LOCAL_TAG = "dns-local"
    private const val REMOTE_DNS_SERVER = "1.1.1.1"
    private const val REMOTE_IPV6_DNS_SERVER = "2606:4700:4700::1111"

    // Per-app routing is applied to libbox via OverrideOptions (see
    // LibboxTunRuntime.buildOverrideOptions); the config JSON itself stays
    // agnostic. excludedPackageName/appRoutingMode/appRoutingPackages used
    // to live in this signature with @Suppress("UNUSED_PARAMETER") — they
    // were never threaded into the JSON.
    fun build(
        isGlobalProxy: Boolean,
        proxyUser: String = "",
        proxyPassword: String = "",
        tunnelNetworkSettings: TunnelNetworkSettings = TunnelNetworkSettings(),
        proxyServer: ServerConfig? = null,
    ): String {
        val useDirectHysteria2 = proxyServer != null && isHysteria2Protocol(proxyServer.protocol)
        val networkSettings = tunnelNetworkSettings.normalized()
        return JSONObject().apply {
            put("log", buildLog())
            put("dns", buildDns(networkSettings))
            put(
                "inbounds",
                buildInbounds(
                    tunnelNetworkSettings = networkSettings,
                    useDirectHysteria2 = useDirectHysteria2,
                    proxyUser = proxyUser,
                    proxyPassword = proxyPassword,
                ),
            )
            put("outbounds", JSONArray().apply {
                if (useDirectHysteria2) {
                    put(buildHysteria2Outbound(proxyServer!!))
                } else {
                    put(buildSocksOutbound(proxyUser, proxyPassword))
                }
                put(JSONObject().apply {
                    put("type", "direct")
                    put("tag", DIRECT_OUTBOUND_TAG)
                })
                if (networkSettings.blockUdp) {
                    put(buildBlockOutbound())
                }
            })
            put(
                "route",
                buildRoute(
                    isGlobalProxy = isGlobalProxy,
                    settings = networkSettings,
                    routeProbeInbound = useDirectHysteria2,
                ),
            )
        }.toString(2)
    }

    private fun isHysteria2Protocol(protocol: String): Boolean {
        return protocol.equals("hysteria2", ignoreCase = true) ||
            protocol.equals("hy2", ignoreCase = true)
    }

    private fun buildLog(): JSONObject {
        return JSONObject().apply {
            put("level", LOG_LEVEL)
            put("timestamp", true)
        }
    }

    private fun buildDns(settings: TunnelNetworkSettings): JSONObject {
        return JSONObject().apply {
            if (settings.useLocalDns) {
                put("servers", JSONArray().put(JSONObject().apply {
                    put("tag", DNS_LOCAL_TAG)
                    put("type", "local")
                }))
                put("final", DNS_LOCAL_TAG)
            } else {
                put("servers", JSONArray().put(JSONObject().apply {
                    put("tag", DNS_REMOTE_TAG)
                    put("type", "https")
                    put("server", remoteDnsServer(settings.ipMode))
                    put("detour", PROXY_OUTBOUND_TAG)
                }))
                put("final", DNS_REMOTE_TAG)
            }
        }
    }

    private fun remoteDnsServer(ipMode: TunnelIpMode): String {
        return if (ipMode == TunnelIpMode.IPV6) {
            REMOTE_IPV6_DNS_SERVER
        } else {
            REMOTE_DNS_SERVER
        }
    }

    private fun buildInbounds(
        tunnelNetworkSettings: TunnelNetworkSettings,
        useDirectHysteria2: Boolean,
        proxyUser: String,
        proxyPassword: String,
    ): JSONArray {
        return JSONArray().apply {
            put(buildTunInbound(tunnelNetworkSettings))
            if (useDirectHysteria2) {
                // When libbox dials Hysteria2 directly, Xray is not running,
                // so the external-IP probe must terminate inside sing-box.
                put(buildProbeInbound(proxyUser, proxyPassword))
            }
        }
    }

    private fun buildTunInbound(
        settings: TunnelNetworkSettings,
    ): JSONObject {
        return JSONObject().apply {
            put("type", "tun")
            put("tag", TUN_INBOUND_TAG)
            put("address", buildTunAddresses(settings.ipMode))
            put("mtu", settings.mtu)
            put("auto_route", true)
            // strict_route is intentionally OFF on Android.
            //
            // sing-box's strict_route installs additional kernel-level
            // policy/firewall rules to suppress traffic that would bypass
            // the TUN. libbox's Go runtime tears those rules down
            // asynchronously from our service-level cleanup. On a rapid
            // restart (preset switch, global-proxy toggle, especially with
            // the app backgrounded so the OS handles teardown faster than
            // libbox's goroutines), the new establish() can land before the
            // previous strict_route rules are gone — they then survive
            // alongside the new ones and silently block egress, leaving the
            // tunnel "connected" with no traffic. Reproduced on libbox in
            // background; xray TUN engine, which doesn't use strict_route,
            // never showed the symptom.
            //
            // Builder.addRoute("0.0.0.0/0") already pushes all IP traffic
            // into the TUN at the Android VpnService layer, which is the
            // actual leak prevention on this platform. strict_route is a
            // belt-and-braces measure originally designed for Linux desktop
            // where additional namespaces/iptables can leak; on Android it
            // adds risk without buying anything.
            put("strict_route", false)
            put("stack", settings.networkStack.wireName)
        }
    }

    private fun buildTunAddresses(ipMode: TunnelIpMode): JSONArray {
        return JSONArray().apply {
            if (ipMode.usesIpv4) put(TunAddressDefaults.IPV4_CIDR)
            if (ipMode.usesIpv6) put(TunAddressDefaults.IPV6_CIDR)
        }
    }

    private fun buildProbeInbound(user: String, password: String): JSONObject {
        return JSONObject().apply {
            put("type", "http")
            put("tag", PROBE_INBOUND_TAG)
            put("listen", RuntimePorts.XRAY_SOCKS_HOST)
            put("listen_port", RuntimePorts.XRAY_HTTP_PROXY_PORT)
            if (user.isNotEmpty() && password.isNotEmpty()) {
                put(
                    "users",
                    JSONArray().put(JSONObject().apply {
                        put("username", user)
                        put("password", password)
                    }),
                )
            }
        }
    }

    private fun buildSocksOutbound(user: String, password: String): JSONObject {
        return JSONObject().apply {
            put("type", "socks")
            put("tag", PROXY_OUTBOUND_TAG)
            put("server", RuntimePorts.XRAY_SOCKS_HOST)
            put("server_port", RuntimePorts.XRAY_SOCKS_PORT)
            put("version", "5")
            // sing-box uses these for SOCKS5 username/password authentication.
            // Both fields are required by Xray once the inbound demands auth,
            // so we only emit them when both are present (otherwise we keep
            // the legacy unauthenticated outbound for backwards compatibility
            // with tests / older configs).
            if (user.isNotEmpty() && password.isNotEmpty()) {
                put("username", user)
                put("password", password)
            }
        }
    }

    private fun buildHysteria2Outbound(server: ServerConfig): JSONObject {
        return JSONObject().apply {
            put("type", "hysteria2")
            put("tag", PROXY_OUTBOUND_TAG)
            put("server", server.server)
            put("server_port", server.serverPort)
            val hopPorts = formatHopPorts(server.hysteria2HopPorts)
            if (hopPorts != null) {
                put("server_ports", hopPorts)
            }
            put("password", server.uuid)
            if (server.hysteria2ObfsPassword.isNotBlank()) {
                put("obfs", JSONObject().apply {
                    put("type", "salamander")
                    put("password", server.hysteria2ObfsPassword)
                })
            }
            put("tls", buildHysteria2Tls(server))
        }
    }

    private fun buildBlockOutbound(): JSONObject {
        return JSONObject().apply {
            put("type", "block")
            put("tag", BLOCK_OUTBOUND_TAG)
        }
    }

    private fun buildHysteria2Tls(server: ServerConfig): JSONObject {
        return JSONObject().apply {
            put("enabled", true)
            put("server_name", server.tlsSni.ifBlank { server.server })
            put("insecure", server.tlsInsecure)
            put("alpn", JSONArray().apply {
                val alpn = server.alpn.ifBlank { "h3" }
                alpn.split(",")
                    .map { it.trim() }
                    .filter { it.isNotEmpty() }
                    .forEach(::put)
            })
        }
    }

    /**
     * Converts our hop-port spec (`"443,8443-8445"`) into sing-box's
     * `server_ports` form (`["443:443", "8443:8445"]`). Returns null when
     * there's nothing to hop across so the caller can omit the field.
     */
    private fun formatHopPorts(raw: String): JSONArray? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return null
        val segments = mutableListOf<String>()
        for (segment in trimmed.split(',')) {
            val piece = segment.trim()
            if (piece.isEmpty()) continue
            val converted = when {
                piece.contains('-') -> {
                    val parts = piece.split('-')
                    if (parts.size != 2) return null
                    val low = parts[0].trim().toIntOrNull()
                    val high = parts[1].trim().toIntOrNull()
                    if (low == null || high == null || low < 1 || high > 65535 || low > high) {
                        return null
                    }
                    "$low:$high"
                }
                else -> {
                    val port = piece.toIntOrNull() ?: return null
                    if (port < 1 || port > 65535) return null
                    "$port:$port"
                }
            }
            segments.add(converted)
        }
        if (segments.isEmpty()) return null
        return JSONArray().apply { segments.forEach(::put) }
    }

    private fun buildRoute(
        isGlobalProxy: Boolean,
        settings: TunnelNetworkSettings,
        routeProbeInbound: Boolean,
    ): JSONObject {
        return JSONObject().apply {
            put("rules", JSONArray().apply {
                if (settings.packetAnalysisEnabled) {
                    put(JSONObject().apply {
                        put("inbound", TUN_INBOUND_TAG)
                        put("action", "sniff")
                    })
                }
                put(JSONObject().apply {
                    put("inbound", TUN_INBOUND_TAG)
                    put("protocol", "dns")
                    put("action", "hijack-dns")
                })
                // The protocol=dns matcher above relies on sniff results.
                // When packetAnalysisEnabled is off we skip the sniff rule,
                // so plain UDP/53 queries would never hijack and — once the
                // UDP block below is in play — they'd be dropped instead of
                // resolved. This explicit port-53 hijack guarantees DNS
                // works regardless of sniffing.
                put(JSONObject().apply {
                    put("inbound", TUN_INBOUND_TAG)
                    put("port", 53)
                    put("action", "hijack-dns")
                })

                if (routeProbeInbound) {
                    put(JSONObject().apply {
                        put("inbound", PROBE_INBOUND_TAG)
                        put("action", "route")
                        put("outbound", PROXY_OUTBOUND_TAG)
                    })
                }

                if (!isGlobalProxy) {
                    put(JSONObject().apply {
                        put("action", "route")
                        put("ip_is_private", true)
                        put("outbound", DIRECT_OUTBOUND_TAG)
                    })
                }

                // UDP block runs AFTER the LAN-direct fallback so local
                // UDP services (mDNS, SSDP, NTP-to-router, multicast) keep
                // working even when the global UDP block is on. In global-
                // proxy mode there is no LAN fallback, so the block applies
                // to everything UDP — which is what the user asked for.
                if (settings.blockUdp) {
                    put(JSONObject().apply {
                        put("inbound", TUN_INBOUND_TAG)
                        put("network", "udp")
                        put("action", "route")
                        put("outbound", BLOCK_OUTBOUND_TAG)
                    })
                }
            })
            put("final", PROXY_OUTBOUND_TAG)
            put("auto_detect_interface", true)
        }
    }
}
