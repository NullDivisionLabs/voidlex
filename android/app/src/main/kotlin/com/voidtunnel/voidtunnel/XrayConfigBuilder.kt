package com.voidtunnel.voidtunnel

import org.json.JSONArray
import org.json.JSONObject

internal object XrayConfigBuilder {
    private const val DEFAULT_LOG_LEVEL = "warning"
    // Verbose mode for diagnostic captures. "info" is enough to surface
    // dial / TLS / Reality auth failure strings; "debug" is mostly internal
    // routing chatter that would drown the user's logcat. We pick "info"
    // deliberately — it gives us the strings we need without the noise.
    private const val VERBOSE_LOG_LEVEL = "info"
    private const val DISABLED_LOG_TARGET = "none"
    private const val SOCKS_INBOUND_TAG = "socks-in"
    private const val EXTERNAL_IP_PROBE_INBOUND_TAG = "external-ip-probe-in"
    private const val OUTBOUND_TAG = "proxy"
    private const val ENTRY_OUTBOUND_TAG = "bridge-entry"
    private const val FRAGMENT_OUTBOUND_TAG = "fragment"
    internal const val DIRECT_TAG = "direct"
    private const val REMOTE_DNS_SERVER = "1.1.1.1"
    private const val REMOTE_IPV6_DNS_SERVER = "2606:4700:4700::1111"
    internal const val BLOCK_TAG = "block"
    private val USER_RULE_OUTBOUND_TAGS = setOf(OUTBOUND_TAG, DIRECT_TAG, BLOCK_TAG)

    // xhttp transport mimicry defaults. These are applied when the user
    // hasn't pinned an explicit value, so a plain "xhttp/reality" server
    // entry already comes out of the builder with browser-like HTTP
    // semantics rather than the bare path/host pair we used to emit. The
    // motivation is DPI white-list regimes (notably mobile operators in
    // RU/IR) that drop xhttp because the on-wire pattern is unique:
    //   - "auto" mode falls back to packet-up, whose POST <path>/<uuid>/<seq>
    //     rhythm is a known signature; stream-up looks like an ordinary
    //     long HTTP/2 upload, so it's our safer default.
    //   - Without xPaddingBytes the per-record sizes are too uniform.
    //   - Without HTTP headers (UA, Accept, …) the request looks unlike
    //     anything a real browser would send.
    // Each value is also exposed as a ServerConfig field so a user / share
    // link can override it server-side if their server-side config expects
    // something specific.
    private const val DEFAULT_XHTTP_MODE = "stream-up"
    private const val DEFAULT_XHTTP_PADDING = "100-1000"
    private const val DEFAULT_XHTTP_MAX_POST_BYTES = "500000-1000000"
    private const val DEFAULT_XHTTP_MIN_POST_INTERVAL = "10-50"
    // Stable Chrome UA. We deliberately don't randomize this per-connection:
    // the TLS ClientHello fingerprint (uTLS) and the HTTP UA must agree, so
    // the UA must match what uTLS' Chrome profile would actually emit.
    private const val DEFAULT_XHTTP_USER_AGENT =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    // When the user hasn't picked a uTLS fingerprint and the transport is
    // xhttp, we lean on "chrome" rather than the historical "firefox" —
    // Firefox + h2-POST cadence is a much rarer combination in the wild
    // and easier to single out from background HTTPS.
    private const val DEFAULT_XHTTP_FINGERPRINT = "chrome"

    internal val privateIpRanges = listOf(
        "127.0.0.0/8",
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "169.254.0.0/16",
        "::1/128",
        "fc00::/7",
        "fe80::/10",
    )

    fun build(config: ServerConfig): String {
        return buildWithInbounds(
            config = config,
            inbounds = JSONArray().put(buildSocksInbound(config)),
        )
    }

    internal fun buildWithInbounds(
        config: ServerConfig,
        inbounds: JSONArray,
        extraOutbounds: JSONArray = JSONArray(),
        leadingRoutingRules: JSONArray = JSONArray(),
        trailingRoutingRules: JSONArray = JSONArray(),
        dns: JSONObject? = null,
    ): String {
        val bridgeEntry = resolveBridgeEntry(config)
        val proxySelectedAppRoutingActive =
            !config.isGlobalProxy && isProxySelectedAppRoutingActive(config)
        val allowUserDirectRules = !config.isGlobalProxy && !proxySelectedAppRoutingActive
        return JSONObject().apply {
            put("log", buildLog(config))
            if (dns != null) {
                put("dns", dns)
            }
            put("inbounds", buildRuntimeInbounds(config, inbounds))
            require(!isHysteria2(config)) {
                "Hysteria2 must not reach XrayConfigBuilder; route it through libbox instead."
            }
            put("outbounds", JSONArray().apply {
                val usesFragment = config.fragmentSettings.enabled
                // Bridge mode wraps the exit VLESS payload inside the entry
                // hop's outbound. The exit (`proxy`) outbound dials through
                // bridge-entry via sockopt.dialerProxy; only the entry then
                // takes the optional fragment detour, because fragmentation
                // belongs on the first-hop dial that actually leaves the
                // device.
                val proxyDetourTag = when {
                    bridgeEntry != null -> ENTRY_OUTBOUND_TAG
                    usesFragment -> FRAGMENT_OUTBOUND_TAG
                    else -> null
                }
                put(
                    buildVlessOutbound(
                        config = config,
                        tag = OUTBOUND_TAG,
                        detourTag = proxyDetourTag,
                    )
                )
                if (bridgeEntry != null) {
                    val entryDetourTag = if (usesFragment) FRAGMENT_OUTBOUND_TAG else null
                    put(
                        buildVlessOutbound(
                            config = bridgeEntry,
                            tag = ENTRY_OUTBOUND_TAG,
                            detourTag = entryDetourTag,
                        )
                    )
                }
                put(JSONObject().apply {
                    put("tag", DIRECT_TAG)
                    put("protocol", "freedom")
                    put("settings", JSONObject())
                })
                put(JSONObject().apply {
                    put("tag", BLOCK_TAG)
                    put("protocol", "blackhole")
                    put("settings", JSONObject())
                })
                if (usesFragment) {
                    put(buildFragmentOutbound(config.fragmentSettings))
                }
                appendAll(extraOutbounds)
            })
            put("routing", JSONObject().apply {
                put("domainStrategy", "AsIs")
                put("rules", JSONArray().apply {
                    put(buildExternalIpProbeRouteRule())
                    appendAll(leadingRoutingRules)
                    appendAll(
                        parseUserRoutingRules(
                            rulesJson = config.userRoutingRulesJson,
                            allowDirectRules = allowUserDirectRules,
                        ),
                    )
                    // Trailing rules run AFTER user rules so a user-defined
                    // routing rule can override builder-injected fallbacks
                    // (e.g. the UDP block can be exempted for specific
                    // destinations). They still run BEFORE the private-IP /
                    // catch-all fallbacks below — builders are expected to
                    // bake LAN bypass into their trailing rules when needed.
                    appendAll(trailingRoutingRules)
                    if (proxySelectedAppRoutingActive) {
                        put(buildProxyCatchAllRule())
                    } else if (!config.isGlobalProxy) {
                        put(JSONObject().apply {
                            put("type", "field")
                            put("ip", JSONArray(privateIpRanges))
                            put("outboundTag", DIRECT_TAG)
                        })
                    }
                })
            })
        }.toString(2)
    }

    private fun buildRuntimeInbounds(
        config: ServerConfig,
        baseInbounds: JSONArray,
    ): JSONArray {
        return JSONArray().apply {
            appendAll(baseInbounds)
            put(buildExternalIpProbeInbound(config))
        }
    }

    /// Translates the user's stored rule set into Xray's `routing.rules`
    /// format. We only forward rules whose `outboundTag` resolves to one of
    /// the outbound tags this builder actually emits — anything else would
    /// fail Xray's config test and stop the tunnel from coming up.
    internal fun parseUserRoutingRules(
        rulesJson: String,
        allowDirectRules: Boolean = true,
    ): JSONArray {
        if (rulesJson.isBlank()) return JSONArray()
        val parsed = runCatching { JSONArray(rulesJson) }.getOrNull() ?: return JSONArray()
        val output = JSONArray()
        for (index in 0 until parsed.length()) {
            val raw = parsed.optJSONObject(index) ?: continue
            val outboundTag = raw.optString("outboundTag")
                .ifBlank { raw.optString("outbound") }
            if (outboundTag.isBlank() || outboundTag !in USER_RULE_OUTBOUND_TAGS) continue
            if (!allowDirectRules && outboundTag == DIRECT_TAG) continue
            val rule = JSONObject()
            rule.put("type", "field")
            copyArrayField(raw, "domain", rule)
            copyArrayField(raw, "ip", rule)
            copyArrayField(raw, "network", rule)
            copyArrayField(raw, "protocol", rule)
            val portValue = raw.opt("port")
            if (portValue is String && portValue.isNotBlank()) {
                rule.put("port", portValue)
            } else if (portValue is Number) {
                rule.put("port", portValue.toString())
            }
            // Drop rules with no matchers — they would otherwise route
            // every flow through the user's `outboundTag` and shadow the
            // built-in private-IP / proxy fallbacks.
            if (!rule.has("domain") &&
                !rule.has("ip") &&
                !rule.has("network") &&
                !rule.has("protocol") &&
                !rule.has("port")
            ) continue
            rule.put("outboundTag", outboundTag)
            output.put(rule)
        }
        return output
    }

    private fun isProxySelectedAppRoutingActive(config: ServerConfig): Boolean {
        return config.appRoutingMode == AppRoutingMode.PROXY_SELECTED &&
            config.appRoutingPackages.any { it.isNotBlank() }
    }

    /// True when the routing tail will install a "private IP → direct"
    /// fallback. Trailing-rule builders (e.g. the UDP block in
    /// XrayTunConfigBuilder) use this to decide whether they need to bake
    /// their own LAN bypass on top — so LAN UDP can still go direct even
    /// when the global UDP block is on.
    internal fun usesPrivateIpDirectFallback(config: ServerConfig): Boolean {
        return !config.isGlobalProxy && !isProxySelectedAppRoutingActive(config)
    }

    private fun buildProxyCatchAllRule(): JSONObject {
        return JSONObject().apply {
            put("type", "field")
            put("outboundTag", OUTBOUND_TAG)
        }
    }

    private fun copyArrayField(source: JSONObject, key: String, destination: JSONObject) {
        val value = source.opt(key) ?: return
        when (value) {
            is JSONArray -> {
                if (value.length() == 0) return
                destination.put(key, value)
            }
            is String -> {
                if (value.isBlank()) return
                destination.put(key, JSONArray().put(value))
            }
        }
    }

    private fun buildLog(config: ServerConfig): JSONObject {
        return JSONObject().apply {
            put(
                "loglevel",
                if (config.verboseXrayLogs) VERBOSE_LOG_LEVEL else DEFAULT_LOG_LEVEL,
            )
            // Xray access logs can produce hundreds of "accepted" lines per minute on Android TUN.
            // Keep warnings/errors, but avoid flooding logcat and Flutter's debug connection.
            put("access", DISABLED_LOG_TARGET)
        }
    }

    private fun JSONArray.appendAll(values: JSONArray) {
        for (index in 0 until values.length()) {
            put(values.get(index))
        }
    }

    internal fun buildSniffing(): JSONObject {
        return JSONObject().apply {
            put("enabled", true)
            put("destOverride", JSONArray().apply {
                put("http")
                put("tls")
                put("quic")
            })
            put("routeOnly", true)
        }
    }

    internal fun buildDns(settings: TunnelNetworkSettings): JSONObject {
        val normalized = settings.normalized()
        val server = when {
            normalized.useLocalDns -> "localhost"
            normalized.hasCustomXrayTunDns -> normalized.xrayTunDnsServer.trim()
            else -> remoteDnsServer(normalized.ipMode)
        }
        return JSONObject().apply {
            put("servers", JSONArray().put(server))
        }
    }

    private fun remoteDnsServer(ipMode: TunnelIpMode): String {
        return if (ipMode == TunnelIpMode.IPV6) {
            REMOTE_IPV6_DNS_SERVER
        } else {
            REMOTE_DNS_SERVER
        }
    }

    private fun buildSocksInbound(config: ServerConfig): JSONObject {
        val hasAuth = config.proxyUser.isNotEmpty() && config.proxyPassword.isNotEmpty()
        return JSONObject().apply {
            put("tag", SOCKS_INBOUND_TAG)
            put("port", RuntimePorts.XRAY_SOCKS_PORT)
            put("listen", RuntimePorts.XRAY_SOCKS_HOST)
            put("protocol", "socks")
            put("settings", JSONObject().apply {
                put("udp", true)
                if (hasAuth) {
                    // Require username/password on the local SOCKS5 inbound
                    // so that other apps and DNS-rebinding-style attacks
                    // from a browser on the same device cannot piggy-back on
                    // the active tunnel.
                    put("auth", "password")
                    put("accounts", JSONArray().put(JSONObject().apply {
                        put("user", config.proxyUser)
                        put("pass", config.proxyPassword)
                    }))
                } else {
                    put("auth", "noauth")
                }
            })
            if (config.tunnelNetworkSettings.packetAnalysisEnabled) {
                put("sniffing", buildSniffing())
            }
        }
    }

    private fun buildExternalIpProbeInbound(config: ServerConfig): JSONObject {
        val hasAuth = config.proxyUser.isNotEmpty() && config.proxyPassword.isNotEmpty()
        return JSONObject().apply {
            put("tag", EXTERNAL_IP_PROBE_INBOUND_TAG)
            put("port", RuntimePorts.XRAY_HTTP_PROXY_PORT)
            put("listen", RuntimePorts.XRAY_SOCKS_HOST)
            put("protocol", "http")
            put("settings", JSONObject().apply {
                if (hasAuth) {
                    put("accounts", JSONArray().put(JSONObject().apply {
                        put("user", config.proxyUser)
                        put("pass", config.proxyPassword)
                    }))
                }
            })
        }
    }

    private fun buildExternalIpProbeRouteRule(): JSONObject {
        return JSONObject().apply {
            put("type", "field")
            put("inboundTag", JSONArray().put(EXTERNAL_IP_PROBE_INBOUND_TAG))
            put("outboundTag", OUTBOUND_TAG)
        }
    }

    private fun buildFragmentOutbound(settings: XrayFragmentSettings): JSONObject {
        val normalized = settings.normalized()
        return JSONObject().apply {
            put("tag", FRAGMENT_OUTBOUND_TAG)
            put("protocol", "freedom")
            put("settings", JSONObject().apply {
                put("domainStrategy", "AsIs")
                put("fragment", JSONObject().apply {
                    put("packets", normalized.packets)
                    put("length", normalized.length)
                    put("interval", normalized.interval)
                    put("maxSplit", normalized.maxSplit)
                })
                if (normalized.noiseEnabled) {
                    put("noises", JSONArray().put(JSONObject().apply {
                        put("type", normalized.noiseType)
                        put("packet", normalized.noisePacket)
                        put("delay", normalized.noiseDelay)
                        put("applyTo", normalized.noiseApplyTo)
                    }))
                }
            })
        }
    }

    private fun buildMux(settings: XrayMultiplexSettings): JSONObject {
        val normalized = settings.normalized()
        return JSONObject().apply {
            put("enabled", normalized.enabled)
            put("concurrency", normalized.tcpConcurrency)
            put("xudpConcurrency", normalized.xudpConcurrency)
            put("xudpProxyUDP443", normalized.quicBehavior)
        }
    }

    private fun buildVlessOutbound(
        config: ServerConfig,
        tag: String,
        detourTag: String?,
    ): JSONObject {
        val stream = buildStreamSettings(config)
        return JSONObject().apply {
            put("tag", tag)
            put("protocol", "vless")
            put("settings", JSONObject().apply {
                put("vnext", JSONArray().put(JSONObject().apply {
                    put("address", config.server)
                    put("port", config.serverPort)
                    put("users", JSONArray().put(JSONObject().apply {
                        put("id", config.uuid)
                        if (config.flow.isNotBlank()) {
                            put("flow", config.flow)
                        }
                        put("encryption", "none")
                    }))
                }))
            })
            put("streamSettings", stream)
            // Both the bridge-entry chain and the fragment chain hook in
            // through sockopt.dialerProxy. proxySettings here looks plausible
            // ("dial the exit through the entry outbound") and Xray accepts
            // the config — but in practice the exit's TLS/Reality/xhttp
            // handshake never reaches the entry tunnel: traffic comes up but
            // nothing flows. dialerProxy threads the actual TCP dial through
            // the entry outbound, which is what makes the chain carry data.
            if (detourTag != null || config.tunnelNetworkSettings.serverResolvingEnabled) {
                val sockopt = stream.getOrPutJSONObject("sockopt")
                if (detourTag != null) {
                    sockopt.put("dialerProxy", detourTag)
                }
                if (config.tunnelNetworkSettings.serverResolvingEnabled) {
                    sockopt.put("domainStrategy", "UseIP")
                }
            }
            if (tag == OUTBOUND_TAG && config.multiplexSettings.enabled) {
                put("mux", buildMux(config.multiplexSettings))
            }
        }
    }

    private fun JSONObject.getOrPutJSONObject(key: String): JSONObject {
        val existing = optJSONObject(key)
        if (existing != null) return existing
        return JSONObject().also { put(key, it) }
    }

    /// Returns the bridge entry hop when [config] carries a separate first
    /// hop; null when running single-node. The entry inherits the outer
    /// tunnel network settings so DNS / sockopt knobs apply consistently.
    private fun resolveBridgeEntry(config: ServerConfig): ServerConfig? {
        val entry = config.detourServer ?: return null
        if (isSameServer(config, entry)) return null
        return entry.copy(
            tunnelNetworkSettings = config.tunnelNetworkSettings,
            detourServer = null,
        )
    }

    private fun isSameServer(left: ServerConfig, right: ServerConfig): Boolean {
        return left.server == right.server &&
            left.serverPort == right.serverPort &&
            left.protocol == right.protocol &&
            left.uuid == right.uuid &&
            left.transport == right.transport &&
            left.transportPath == right.transportPath &&
            left.transportServiceName == right.transportServiceName &&
            left.transportHost == right.transportHost &&
            left.transportMode == right.transportMode &&
            left.xhttpPadding == right.xhttpPadding &&
            left.xhttpMaxPostBytes == right.xhttpMaxPostBytes &&
            left.xhttpMinPostInterval == right.xhttpMinPostInterval &&
            left.tlsEnabled == right.tlsEnabled &&
            left.tlsSni == right.tlsSni &&
            left.tlsInsecure == right.tlsInsecure &&
            left.flow == right.flow &&
            left.security == right.security &&
            left.realityPbk == right.realityPbk &&
            left.realitySid == right.realitySid &&
            left.realitySpiderX == right.realitySpiderX &&
            left.fingerprint == right.fingerprint &&
            left.alpn == right.alpn
    }

    internal fun isHysteria2(config: ServerConfig): Boolean {
        return config.protocol.equals("hysteria2", ignoreCase = true) ||
            config.protocol.equals("hy2", ignoreCase = true)
    }

    private fun buildStreamSettings(config: ServerConfig): JSONObject {
        val network = when (config.transport) {
            "grpc" -> "grpc"
            "ws" -> "ws"
            "httpupgrade" -> "httpupgrade"
            "http" -> "http"
            "xhttp" -> "xhttp"
            else -> "tcp"
        }
        val isXhttp = network == "xhttp"
        // Force a chrome-class uTLS fingerprint when running xhttp without
        // an explicit user choice; xhttp's HTTP semantics imply h2, and
        // the surrounding HTTPS traffic in the wild is overwhelmingly
        // chrome-shaped. See DEFAULT_XHTTP_FINGERPRINT.
        val effectiveFingerprint = when {
            config.fingerprint.isNotBlank() -> config.fingerprint
            isXhttp -> DEFAULT_XHTTP_FINGERPRINT
            else -> ""
        }
        return JSONObject().apply {
            put("network", network)
            if (config.security == "reality") {
                put("security", "reality")
                put("realitySettings", JSONObject().apply {
                    put("serverName", config.tlsSni.ifBlank { config.server })
                    if (effectiveFingerprint.isNotBlank()) {
                        put("fingerprint", effectiveFingerprint)
                    }
                    put("publicKey", config.realityPbk)
                    put("shortId", config.realitySid)
                    if (config.realitySpiderX.isNotBlank()) {
                        put("spiderX", config.realitySpiderX)
                    }
                    // xhttp negotiates HTTP/2 internally, but advertising
                    // ONLY h2 in the ClientHello is itself a distinguishing
                    // signature — real Chrome/Firefox always offer
                    // ["h2", "http/1.1"]. We list both so the handshake
                    // looks like a normal browser request; h2 is first so
                    // the server still picks it.
                    if (isXhttp) {
                        put("alpn", JSONArray().put("h2").put("http/1.1"))
                    }
                    put("allowInsecure", config.tlsInsecure)
                })
            } else if (config.tlsEnabled) {
                put("security", "tls")
                put("tlsSettings", JSONObject().apply {
                    put("serverName", config.tlsSni)
                    put("allowInsecure", config.tlsInsecure)
                    if (effectiveFingerprint.isNotBlank()) {
                        put("fingerprint", effectiveFingerprint)
                    }
                    val alpnArray = when {
                        config.alpn.isNotBlank() -> JSONArray().apply {
                            config.alpn.split(",")
                                .map { it.trim() }
                                .filter { it.isNotEmpty() }
                                .forEach(::put)
                        }
                        // Same reason as the Reality branch: list both h2
                        // and http/1.1 so the ClientHello looks like a
                        // stock browser; xhttp will still pick h2.
                        isXhttp -> JSONArray().put("h2").put("http/1.1")
                        else -> null
                    }
                    if (alpnArray != null) {
                        put("alpn", alpnArray)
                    }
                })
            } else {
                put("security", "none")
            }

            when (network) {
                "grpc" -> put("grpcSettings", JSONObject().apply {
                    if (config.transportServiceName.isNotBlank()) {
                        put("serviceName", config.transportServiceName)
                    }
                    if (config.transportHost.isNotBlank()) {
                        put("authority", config.transportHost)
                    }
                })
                "ws" -> put("wsSettings", JSONObject().apply {
                    put("path", config.transportPath.ifBlank { "/" })
                    if (config.transportHost.isNotBlank()) {
                        put("headers", JSONObject().apply {
                            put("Host", config.transportHost)
                        })
                    }
                })
                "httpupgrade" -> put("httpupgradeSettings", JSONObject().apply {
                    put("path", config.transportPath.ifBlank { "/" })
                    if (config.transportHost.isNotBlank()) {
                        put("host", config.transportHost)
                    }
                })
                "xhttp" -> put("xhttpSettings", buildXhttpSettings(config))
                "http" -> put("httpSettings", JSONObject().apply {
                    put("path", config.transportPath.ifBlank { "/" })
                    if (config.transportHost.isNotBlank()) {
                        put("host", JSONArray().put(config.transportHost))
                    }
                })
            }
        }
    }

    /// Builds the xhttpSettings block with browser-mimicking defaults.
    /// stream-up is forced when the user hasn't picked a mode — see
    /// DEFAULT_XHTTP_MODE for rationale. The extra.headers block makes the
    /// underlying h2 requests look like an ordinary upload from a real
    /// Chrome instance instead of the bare path-only requests Xray emits
    /// by default, which DPI white-lists tend to single out.
    private fun buildXhttpSettings(config: ServerConfig): JSONObject {
        return JSONObject().apply {
            put("path", config.transportPath.ifBlank { "/" })
            put("mode", config.transportMode.ifBlank { DEFAULT_XHTTP_MODE })
            if (config.transportHost.isNotBlank()) {
                put("host", config.transportHost)
            }
            put("extra", buildXhttpExtra(config))
        }
    }

    private fun buildXhttpExtra(config: ServerConfig): JSONObject {
        return JSONObject().apply {
            put(
                "xPaddingBytes",
                config.xhttpPadding.ifBlank { DEFAULT_XHTTP_PADDING },
            )
            // The gRPC-style "Content-Type: application/grpc" header is
            // what a stock Xray client used to volunteer over xhttp; on
            // strict white-list DPI it triggers the gRPC-detection path
            // and the connection is dropped before any payload moves.
            // Suppressing it lets the request look like a vanilla h2
            // upload.
            put("noGRPCHeader", true)
            put(
                "scMaxEachPostBytes",
                config.xhttpMaxPostBytes.ifBlank { DEFAULT_XHTTP_MAX_POST_BYTES },
            )
            put(
                "scMinPostsIntervalMs",
                config.xhttpMinPostInterval.ifBlank { DEFAULT_XHTTP_MIN_POST_INTERVAL },
            )
            put("headers", JSONObject().apply {
                put("User-Agent", DEFAULT_XHTTP_USER_AGENT)
                put("Accept", "*/*")
                put("Accept-Language", "en-US,en;q=0.9")
                put("Accept-Encoding", "gzip, deflate, br")
                put("Cache-Control", "no-cache")
                put("Pragma", "no-cache")
            })
        }
    }

}
