package com.voidlex.voidlex

import android.content.Intent
import org.json.JSONArray

internal object VpnServiceConfigParser {
    private const val TAG = "VpnServiceConfigParser"

    fun parse(intent: Intent?): ServerConfig? {
        if (intent == null) return null
        val isGlobalProxy = intent.getBooleanExtra(VoidVpnService.EXTRA_IS_GLOBAL_PROXY, false)
        val tunEngineMode = TunEngineMode.fromWire(intent.getStringExtra(VoidVpnService.EXTRA_TUN_ENGINE))
        val appRoutingMode = AppRoutingMode.fromWire(
            intent.getStringExtra(VoidVpnService.EXTRA_APP_ROUTING_MODE),
        )
        val appRoutingPackages = intent
            .getStringArrayExtra(VoidVpnService.EXTRA_APP_ROUTING_PACKAGES)
            ?.filter { it.isNotBlank() }
            ?.distinct()
            ?: emptyList()
        val routingRulesJson =
            intent.getStringExtra(VoidVpnService.EXTRA_ROUTING_RULES_JSON) ?: "[]"
        val routingRulesCount = runCatching { JSONArray(routingRulesJson).length() }
            .getOrDefault(0)
        val routingPresetId = intent.getStringExtra(VoidVpnService.EXTRA_ROUTING_PRESET_ID) ?: ""
        val routingPresetName =
            intent.getStringExtra(VoidVpnService.EXTRA_ROUTING_PRESET_NAME) ?: ""
        val editorPresetId =
            intent.getStringExtra(VoidVpnService.EXTRA_ROUTING_PRESET_EDITOR_ID) ?: ""
        val editorPresetName =
            intent.getStringExtra(VoidVpnService.EXTRA_ROUTING_PRESET_EDITOR_NAME) ?: ""
        val selectedNode =
            intent.getStringExtra(VoidVpnService.EXTRA_ROUTING_PRESET_NODE) ?: ""
        val presetMode =
            intent.getStringExtra(VoidVpnService.EXTRA_ROUTING_PRESET_MODE) ?: ""
        val presetPackageCount =
            intent.getIntExtra(VoidVpnService.EXTRA_ROUTING_PRESET_PACKAGE_COUNT, 0)
        val presetRuleCount =
            intent.getIntExtra(VoidVpnService.EXTRA_ROUTING_PRESET_RULE_COUNT, 0)
        val proxyUser = intent.getStringExtra(VoidVpnService.EXTRA_PROXY_USER)
            ?.takeIf { it.isNotBlank() }
            ?: ProxyCredentials.randomHex(16)
        val proxyPassword = intent.getStringExtra(VoidVpnService.EXTRA_PROXY_PASSWORD)
            ?.takeIf { it.isNotBlank() }
            ?: ProxyCredentials.randomHex(24)
        val fragmentSettings = parseFragmentSettings(intent)
        val multiplexSettings = parseMultiplexSettings(intent)
        val tunnelNetworkSettings = parseTunnelNetworkSettings(intent)
        val keepAwake = intent.getBooleanExtra(VoidVpnService.EXTRA_KEEP_AWAKE, false)
        val verboseXrayLogs =
            intent.getBooleanExtra(VoidVpnService.EXTRA_VERBOSE_XRAY_LOGS, false)
        val killSwitchEnabled =
            intent.getBooleanExtra(VoidVpnService.EXTRA_KILL_SWITCH_ENABLED, false)
        val runMode = RunMode.fromWire(intent.getStringExtra(VoidVpnService.EXTRA_RUN_MODE))
        val hotspotBindEnabled =
            intent.getBooleanExtra(VoidVpnService.EXTRA_HOTSPOT_BIND_ENABLED, false) ||
                runMode == RunMode.PROXY_ONLY
        val httpProxyAuthEnabled =
            intent.getBooleanExtra(VoidVpnService.EXTRA_HTTP_PROXY_AUTH_ENABLED, false)
        val connectionPolicy = parseConnectionPolicy(intent)
        val server = parseServerConfig(intent, isGlobalProxy = isGlobalProxy)
            ?: return null
        // Bridge mode: the outer server above is the EXIT hop. When the
        // Dart side has marked a separate entry node, parse those extras
        // here under the "ENTRY_" prefix. Single-node tunnels send no
        // ENTRY_server extra; parseServerConfig returns null and we run as
        // before.
        val entryServer = parseServerConfig(
            intent = intent,
            isGlobalProxy = isGlobalProxy,
            extraPrefix = "ENTRY_",
        )

        val xhttpExtras = if (server.transport.equals("xhttp", ignoreCase = true)) {
            ", xhttpMode=${server.transportMode.ifBlank { "auto" }}" +
                ", xhttpPad=${server.xhttpPadding.ifBlank { "default" }}" +
                ", xhttpMaxPost=${server.xhttpMaxPostBytes.ifBlank { "default" }}" +
                ", xhttpMinInt=${server.xhttpMinPostInterval.ifBlank { "default" }}"
        } else {
            ""
        }
        AppLogger.i(
            TAG,
            "Parsed VPN config: server=${server.server}:${server.serverPort}, " +
                "entry=${entryServer?.let { "${it.server}:${it.serverPort}" } ?: "-"}, " +
                "entryTransport=${entryServer?.transport ?: "-"}, " +
                "entrySecurity=${entryServer?.security ?: "-"}, " +
                "bridge=${entryServer != null}, " +
                "protocol=${server.protocol}, " +
                "transport=${server.transport}, security=${server.security}, " +
                "sni=${server.tlsSni.ifBlank { "-" }}, " +
                "fp=${server.fingerprint.ifBlank { "-" }}, " +
                "flow=${server.flow.ifBlank { "-" }}, " +
                "pbk=${server.realityPbk.isNotBlank()}, " +
                "sidLen=${server.realitySid.length}" +
                xhttpExtras + ", " +
                "tunEngine=${tunEngineMode.wireName}, " +
                "fragment=${fragmentSettings.enabled}, " +
                "noises=${fragmentSettings.enabled && fragmentSettings.noiseEnabled}, " +
                "mux=${multiplexSettings.enabled}, " +
                "localDns=${tunnelNetworkSettings.useLocalDns}, " +
                "serverResolve=${tunnelNetworkSettings.serverResolvingEnabled}, " +
                "packetAnalysis=${tunnelNetworkSettings.packetAnalysisEnabled}, " +
                "blockUdp=${tunnelNetworkSettings.blockUdp}, " +
                "stack=${tunnelNetworkSettings.networkStack.wireName}, " +
                "mtu=${tunnelNetworkSettings.mtu}, " +
                "ipMode=${tunnelNetworkSettings.ipMode.wireName}, " +
                "xrayTunDns=${if (tunnelNetworkSettings.xrayTunDnsEnabled) tunnelNetworkSettings.xrayTunDnsServer else "default"}, " +
                "keepAwake=$keepAwake, " +
                "verboseXray=$verboseXrayLogs, " +
                "global=$isGlobalProxy, " +
                "preset=${presetLabel(routingPresetName, routingPresetId)}, " +
                "editorPreset=${presetLabel(editorPresetName, editorPresetId)}, " +
                "node=${selectedNode.ifBlank { "-" }}, " +
                "presetRouting=${presetMode.ifBlank { "-" }}($presetPackageCount), " +
                "presetRules=$presetRuleCount, " +
                "appRouting=${appRoutingMode.wireName}(${appRoutingPackages.size}), " +
                "routingRules=$routingRulesCount",
        )

        if (entryServer != null) {
            // Bridge mode: dump the entry hop's Reality params separately so
            // mismatches between widget-built and Flutter-built intents are
            // visible to a quick log diff. Secrets are surfaced as
            // present/empty rather than raw values.
            AppLogger.i(
                TAG,
                "Bridge ENTRY config: server=${entryServer.server}:${entryServer.serverPort}, " +
                    "transport=${entryServer.transport}, security=${entryServer.security}, " +
                    "sni=${entryServer.tlsSni.ifBlank { "-" }}, " +
                    "fp=${entryServer.fingerprint.ifBlank { "-" }}, " +
                    "flow=${entryServer.flow.ifBlank { "-" }}, " +
                    "alpn=${entryServer.alpn.ifBlank { "-" }}, " +
                    "pbk=${entryServer.realityPbk.isNotBlank()}, " +
                    "sidLen=${entryServer.realitySid.length}, " +
                    "tlsInsecure=${entryServer.tlsInsecure}, " +
                    "transportPath=${entryServer.transportPath}, " +
                    "transportHost=${entryServer.transportHost.ifBlank { "-" }}, " +
                    "transportMode=${entryServer.transportMode.ifBlank { "-" }}",
            )
        }

        return server.copy(
            tunEngineMode = tunEngineMode,
            appRoutingMode = appRoutingMode,
            appRoutingPackages = appRoutingPackages,
            userRoutingRulesJson = routingRulesJson,
            proxyUser = proxyUser,
            proxyPassword = proxyPassword,
            fragmentSettings = fragmentSettings,
            multiplexSettings = multiplexSettings,
            tunnelNetworkSettings = tunnelNetworkSettings,
            keepAwake = keepAwake,
            verboseXrayLogs = verboseXrayLogs,
            detourServer = entryServer,
            killSwitchEnabled = killSwitchEnabled,
            runMode = runMode,
            hotspotBindEnabled = hotspotBindEnabled,
            httpProxyAuthEnabled = httpProxyAuthEnabled,
            connectionPolicy = connectionPolicy,
        )
    }

    private fun parseConnectionPolicy(intent: Intent): ConnectionPolicy {
        return ConnectionPolicy(
            handshakeSeconds = intent.getIntExtra(
                VoidVpnService.EXTRA_POLICY_HANDSHAKE_SEC,
                ConnectionPolicy.DEFAULT.handshakeSeconds,
            ),
            connIdleSeconds = intent.getIntExtra(
                VoidVpnService.EXTRA_POLICY_CONN_IDLE_SEC,
                ConnectionPolicy.DEFAULT.connIdleSeconds,
            ),
            uplinkOnlySeconds = intent.getIntExtra(
                VoidVpnService.EXTRA_POLICY_UPLINK_ONLY_SEC,
                ConnectionPolicy.DEFAULT.uplinkOnlySeconds,
            ),
            downlinkOnlySeconds = intent.getIntExtra(
                VoidVpnService.EXTRA_POLICY_DOWNLINK_ONLY_SEC,
                ConnectionPolicy.DEFAULT.downlinkOnlySeconds,
            ),
            maxTcpConnections = intent.getIntExtra(
                VoidVpnService.EXTRA_POLICY_MAX_TCP_CONNS,
                ConnectionPolicy.DEFAULT.maxTcpConnections,
            ),
            maxUdpConnections = intent.getIntExtra(
                VoidVpnService.EXTRA_POLICY_MAX_UDP_CONNS,
                ConnectionPolicy.DEFAULT.maxUdpConnections,
            ),
        ).normalized()
    }

    private fun presetLabel(name: String, id: String): String {
        val cleanName = name.ifBlank { "-" }
        val cleanId = id.ifBlank { "-" }
        return "$cleanName/$cleanId"
    }

    private fun parseFragmentSettings(intent: Intent): XrayFragmentSettings {
        return XrayFragmentSettings(
            enabled = intent.getBooleanExtra(VoidVpnService.EXTRA_FRAGMENT_ENABLED, false),
            packets = intent.getStringExtra(VoidVpnService.EXTRA_FRAGMENT_PACKETS)
                ?: XrayFragmentSettings.DEFAULT_PACKETS,
            length = intent.getStringExtra(VoidVpnService.EXTRA_FRAGMENT_LENGTH)
                ?: XrayFragmentSettings.DEFAULT_LENGTH,
            interval = intent.getStringExtra(VoidVpnService.EXTRA_FRAGMENT_INTERVAL)
                ?: XrayFragmentSettings.DEFAULT_INTERVAL,
            maxSplit = intent.getStringExtra(VoidVpnService.EXTRA_FRAGMENT_MAX_SPLIT)
                ?: XrayFragmentSettings.DEFAULT_MAX_SPLIT,
            noiseEnabled = intent.getBooleanExtra(
                VoidVpnService.EXTRA_FRAGMENT_NOISE_ENABLED,
                true,
            ),
            noiseType = intent.getStringExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_TYPE)
                ?: XrayFragmentSettings.DEFAULT_NOISE_TYPE,
            noisePacket = intent.getStringExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_PACKET)
                ?: XrayFragmentSettings.DEFAULT_NOISE_PACKET,
            noiseDelay = intent.getStringExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_DELAY)
                ?: XrayFragmentSettings.DEFAULT_NOISE_DELAY,
            noiseApplyTo = intent.getStringExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_APPLY_TO)
                ?: XrayFragmentSettings.DEFAULT_NOISE_APPLY_TO,
        ).normalized()
    }

    private fun parseMultiplexSettings(intent: Intent): XrayMultiplexSettings {
        return XrayMultiplexSettings(
            enabled = intent.getBooleanExtra(VoidVpnService.EXTRA_MUX_ENABLED, false),
            tcpConcurrency = intent.getIntExtra(
                VoidVpnService.EXTRA_MUX_TCP_CONCURRENCY,
                XrayMultiplexSettings.DEFAULT_TCP_CONCURRENCY,
            ),
            xudpConcurrency = intent.getIntExtra(
                VoidVpnService.EXTRA_MUX_XUDP_CONCURRENCY,
                XrayMultiplexSettings.DEFAULT_XUDP_CONCURRENCY,
            ),
            quicBehavior = intent.getStringExtra(VoidVpnService.EXTRA_MUX_QUIC_BEHAVIOR)
                ?: XrayMultiplexSettings.DEFAULT_QUIC_BEHAVIOR,
        ).normalized()
    }

    private fun parseTunnelNetworkSettings(intent: Intent): TunnelNetworkSettings {
        return TunnelNetworkSettings(
            useLocalDns = intent.getBooleanExtra(VoidVpnService.EXTRA_USE_LOCAL_DNS, false),
            serverResolvingEnabled = intent.getBooleanExtra(
                VoidVpnService.EXTRA_SERVER_RESOLVING_ENABLED,
                false,
            ),
            packetAnalysisEnabled = intent.getBooleanExtra(
                VoidVpnService.EXTRA_PACKET_ANALYSIS_ENABLED,
                true,
            ),
            blockUdp = intent.getBooleanExtra(VoidVpnService.EXTRA_BLOCK_UDP, false),
            networkStack = TunnelNetworkStack.fromWire(
                intent.getStringExtra(VoidVpnService.EXTRA_NETWORK_STACK),
            ),
            mtu = intent.getIntExtra(
                VoidVpnService.EXTRA_TUN_MTU,
                TunnelNetworkSettings.DEFAULT_MTU,
            ),
            ipMode = TunnelIpMode.fromWire(intent.getStringExtra(VoidVpnService.EXTRA_IP_MODE)),
            xrayTunDnsEnabled = intent.getBooleanExtra(
                VoidVpnService.EXTRA_XRAY_TUN_DNS_ENABLED,
                false,
            ),
            xrayTunDnsServer = intent.getStringExtra(VoidVpnService.EXTRA_XRAY_TUN_DNS_SERVER)
                ?.takeIf { it.isNotBlank() }
                ?: TunnelNetworkSettings.DEFAULT_XRAY_TUN_DNS_SERVER,
            sniffingRouteOnly = intent.getBooleanExtra(
                VoidVpnService.EXTRA_SNIFFING_ROUTE_ONLY,
                true,
            ),
        ).normalized()
    }

    private fun parseServerConfig(
        intent: Intent,
        isGlobalProxy: Boolean,
        extraPrefix: String = "",
    ): ServerConfig? {
        fun key(base: String): String = extraPrefix + base

        val server = intent.getStringExtra(key(VoidVpnService.EXTRA_SERVER)) ?: return null
        if (server.isBlank()) return null

        return ServerConfig(
            tunEngineMode = TunEngineMode.LIBBOX,
            isGlobalProxy = isGlobalProxy,
            server = server,
            serverPort = intent.getIntExtra(key(VoidVpnService.EXTRA_SERVER_PORT), 443),
            protocol = intent.getStringExtra(key(VoidVpnService.EXTRA_PROTOCOL)) ?: "vless",
            uuid = intent.getStringExtra(key(VoidVpnService.EXTRA_UUID)) ?: "",
            transport = intent.getStringExtra(key(VoidVpnService.EXTRA_TRANSPORT)) ?: "tcp",
            transportPath = intent.getStringExtra(key(VoidVpnService.EXTRA_TRANSPORT_PATH)) ?: "/",
            transportServiceName =
                intent.getStringExtra(key(VoidVpnService.EXTRA_TRANSPORT_SERVICE_NAME)) ?: "",
            transportHost = intent.getStringExtra(key(VoidVpnService.EXTRA_TRANSPORT_HOST)) ?: "",
            transportMode = intent.getStringExtra(key(VoidVpnService.EXTRA_TRANSPORT_MODE)) ?: "",
            xhttpPadding =
                intent.getStringExtra(key(VoidVpnService.EXTRA_XHTTP_PADDING)) ?: "",
            xhttpMaxPostBytes =
                intent.getStringExtra(key(VoidVpnService.EXTRA_XHTTP_MAX_POST_BYTES)) ?: "",
            xhttpMinPostInterval =
                intent.getStringExtra(key(VoidVpnService.EXTRA_XHTTP_MIN_POST_INTERVAL)) ?: "",
            tlsEnabled = intent.getBooleanExtra(key(VoidVpnService.EXTRA_TLS_ENABLED), true),
            tlsSni = intent.getStringExtra(key(VoidVpnService.EXTRA_TLS_SNI)) ?: server,
            tlsInsecure = intent.getBooleanExtra(key(VoidVpnService.EXTRA_TLS_INSECURE), false),
            flow = intent.getStringExtra(key(VoidVpnService.EXTRA_FLOW)) ?: "",
            vlessEncryption =
                intent.getStringExtra(key(VoidVpnService.EXTRA_VLESS_ENCRYPTION)) ?: "",
            security = intent.getStringExtra(key(VoidVpnService.EXTRA_SECURITY)) ?: "",
            realityPbk = intent.getStringExtra(key(VoidVpnService.EXTRA_REALITY_PBK)) ?: "",
            realitySid = intent.getStringExtra(key(VoidVpnService.EXTRA_REALITY_SID)) ?: "",
            realitySpiderX =
                intent.getStringExtra(key(VoidVpnService.EXTRA_REALITY_SPIDER_X)) ?: "",
            realityMldsa65Verify =
                intent.getStringExtra(key(VoidVpnService.EXTRA_REALITY_MLDSA65_VERIFY)) ?: "",
            fingerprint = intent.getStringExtra(key(VoidVpnService.EXTRA_FINGERPRINT)) ?: "",
            alpn = intent.getStringExtra(key(VoidVpnService.EXTRA_ALPN)) ?: "",
            hysteria2ObfsType =
                intent.getStringExtra(key(VoidVpnService.EXTRA_HYSTERIA2_OBFS_TYPE)) ?: "",
            hysteria2ObfsPassword =
                intent.getStringExtra(key(VoidVpnService.EXTRA_HYSTERIA2_OBFS_PASSWORD)) ?: "",
            hysteria2ObfsMinPacketSize =
                intent.getIntExtra(key(VoidVpnService.EXTRA_HYSTERIA2_OBFS_MIN_PACKET_SIZE), 0),
            hysteria2ObfsMaxPacketSize =
                intent.getIntExtra(key(VoidVpnService.EXTRA_HYSTERIA2_OBFS_MAX_PACKET_SIZE), 0),
            hysteria2HopPorts =
                intent.getStringExtra(key(VoidVpnService.EXTRA_HYSTERIA2_HOP_PORTS)) ?: "",
            hysteria2HopInterval =
                intent.getStringExtra(key(VoidVpnService.EXTRA_HYSTERIA2_HOP_INTERVAL)) ?: "",
            hysteria2HopIntervalMax =
                intent.getStringExtra(key(VoidVpnService.EXTRA_HYSTERIA2_HOP_INTERVAL_MAX)) ?: "",
            hysteria2UpMbps =
                intent.getIntExtra(key(VoidVpnService.EXTRA_HYSTERIA2_UP_MBPS), 0),
            hysteria2DownMbps =
                intent.getIntExtra(key(VoidVpnService.EXTRA_HYSTERIA2_DOWN_MBPS), 0),
            hysteria2Network =
                intent.getStringExtra(key(VoidVpnService.EXTRA_HYSTERIA2_NETWORK)) ?: "",
            hysteria2BbrProfile =
                intent.getStringExtra(key(VoidVpnService.EXTRA_HYSTERIA2_BBR_PROFILE)) ?: "",
            naiveUsername =
                intent.getStringExtra(key(VoidVpnService.EXTRA_NAIVE_USERNAME)) ?: "",
            naivePassword =
                intent.getStringExtra(key(VoidVpnService.EXTRA_NAIVE_PASSWORD)) ?: "",
            naiveQuic = intent.getBooleanExtra(key(VoidVpnService.EXTRA_NAIVE_QUIC), false),
            naiveQuicCongestionControl =
                intent.getStringExtra(key(VoidVpnService.EXTRA_NAIVE_QUIC_CONGESTION_CONTROL)) ?: "",
            naiveInsecureConcurrency =
                intent.getIntExtra(key(VoidVpnService.EXTRA_NAIVE_INSECURE_CONCURRENCY), 0),
            naiveExtraHeadersJson =
                intent.getStringExtra(key(VoidVpnService.EXTRA_NAIVE_EXTRA_HEADERS_JSON)) ?: "{}",
            naiveUdpOverTcp =
                intent.getBooleanExtra(key(VoidVpnService.EXTRA_NAIVE_UDP_OVER_TCP), false),
            naiveUdpOverTcpVersion =
                intent.getIntExtra(key(VoidVpnService.EXTRA_NAIVE_UDP_OVER_TCP_VERSION), 0),
        )
    }
}
