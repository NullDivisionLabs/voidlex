package com.voidlex.voidlex

internal enum class TunEngineMode(val wireName: String) {
    LIBBOX("libbox"),
    XRAY("xray");

    companion object {
        fun fromWire(raw: String?): TunEngineMode {
            return entries.firstOrNull { it.wireName == raw } ?: LIBBOX
        }
    }
}

internal enum class AppRoutingMode(val wireName: String) {
    OFF("off"),
    PROXY_SELECTED("proxy"),
    BYPASS_SELECTED("bypass");

    companion object {
        fun fromWire(raw: String?): AppRoutingMode {
            return entries.firstOrNull { it.wireName == raw } ?: OFF
        }
    }
}

internal object TunAddressDefaults {
    const val IPV4_ADDRESS = "198.18.0.1"
    const val IPV4_PREFIX = 30
    const val IPV4_CIDR = "198.18.0.1/30"
    const val IPV6_ADDRESS = "fdfe:dcba:9876::1"
    const val IPV6_PREFIX = 126
    const val IPV6_CIDR = "fdfe:dcba:9876::1/126"
}

internal enum class TunnelNetworkStack(val wireName: String) {
    SYSTEM("system"),
    GVISOR("gvisor"),
    MIXED("mixed");

    companion object {
        fun fromWire(raw: String?): TunnelNetworkStack {
            return entries.firstOrNull { it.wireName == raw } ?: SYSTEM
        }
    }
}

internal enum class TunnelIpMode(val wireName: String) {
    IPV4("ipv4"),
    IPV6("ipv6"),
    MIXED("mixed");

    val usesIpv4: Boolean
        get() = this == IPV4 || this == MIXED

    val usesIpv6: Boolean
        get() = this == IPV6 || this == MIXED

    companion object {
        fun fromWire(raw: String?): TunnelIpMode {
            return entries.firstOrNull { it.wireName == raw } ?: IPV4
        }
    }
}

internal data class XrayFragmentSettings(
    val enabled: Boolean = false,
    val packets: String = DEFAULT_PACKETS,
    val length: String = DEFAULT_LENGTH,
    val interval: String = DEFAULT_INTERVAL,
    val maxSplit: String = DEFAULT_MAX_SPLIT,
    val noiseEnabled: Boolean = true,
    val noiseType: String = DEFAULT_NOISE_TYPE,
    val noisePacket: String = DEFAULT_NOISE_PACKET,
    val noiseDelay: String = DEFAULT_NOISE_DELAY,
    val noiseApplyTo: String = DEFAULT_NOISE_APPLY_TO,
) {
    fun normalized(): XrayFragmentSettings {
        return copy(
            packets = packets.ifBlank { DEFAULT_PACKETS },
            length = length.ifBlank { DEFAULT_LENGTH },
            interval = interval.ifBlank { DEFAULT_INTERVAL },
            maxSplit = maxSplit.ifBlank { DEFAULT_MAX_SPLIT },
            noiseType = noiseType.ifBlank { DEFAULT_NOISE_TYPE },
            noisePacket = noisePacket.ifBlank { DEFAULT_NOISE_PACKET },
            noiseDelay = noiseDelay.ifBlank { DEFAULT_NOISE_DELAY },
            noiseApplyTo = noiseApplyTo.ifBlank { DEFAULT_NOISE_APPLY_TO },
        )
    }

    companion object {
        const val DEFAULT_PACKETS = "tlshello"
        const val DEFAULT_LENGTH = "50-100"
        const val DEFAULT_INTERVAL = "10-20"
        const val DEFAULT_MAX_SPLIT = "100-200"
        const val DEFAULT_NOISE_TYPE = "rand"
        const val DEFAULT_NOISE_PACKET = "10-20"
        const val DEFAULT_NOISE_DELAY = "10-16"
        const val DEFAULT_NOISE_APPLY_TO = "ip"
    }
}

internal data class XrayMultiplexSettings(
    val enabled: Boolean = false,
    val tcpConcurrency: Int = DEFAULT_TCP_CONCURRENCY,
    val xudpConcurrency: Int = DEFAULT_XUDP_CONCURRENCY,
    val quicBehavior: String = DEFAULT_QUIC_BEHAVIOR,
) {
    fun normalized(): XrayMultiplexSettings {
        return copy(
            tcpConcurrency = tcpConcurrency.coerceIn(MIN_CONCURRENCY, MAX_TCP_CONCURRENCY),
            xudpConcurrency = xudpConcurrency.coerceIn(MIN_CONCURRENCY, MAX_XUDP_CONCURRENCY),
            quicBehavior = when (quicBehavior) {
                "reject", "allow", "skip" -> quicBehavior
                else -> DEFAULT_QUIC_BEHAVIOR
            },
        )
    }

    companion object {
        const val MIN_CONCURRENCY = -1
        const val MAX_TCP_CONCURRENCY = 128
        const val MAX_XUDP_CONCURRENCY = 1024
        const val DEFAULT_TCP_CONCURRENCY = 8
        const val DEFAULT_XUDP_CONCURRENCY = 8
        const val DEFAULT_QUIC_BEHAVIOR = "reject"
    }
}

internal data class TunnelNetworkSettings(
    val useLocalDns: Boolean = false,
    val serverResolvingEnabled: Boolean = false,
    val packetAnalysisEnabled: Boolean = true,
    val blockUdp: Boolean = false,
    val networkStack: TunnelNetworkStack = TunnelNetworkStack.SYSTEM,
    val mtu: Int = DEFAULT_MTU,
    val ipMode: TunnelIpMode = TunnelIpMode.IPV4,
    val xrayTunDnsEnabled: Boolean = false,
    val xrayTunDnsServer: String = DEFAULT_XRAY_TUN_DNS_SERVER,
    val sniffingRouteOnly: Boolean = true,
) {
    fun normalized(): TunnelNetworkSettings {
        val trimmedDns = xrayTunDnsServer.trim()
        return copy(
            mtu = mtu.coerceIn(MIN_MTU, MAX_MTU),
            xrayTunDnsServer = trimmedDns.ifEmpty { DEFAULT_XRAY_TUN_DNS_SERVER },
        )
    }

    /// True when the Xray TUN engine should override the default upstream
    /// resolver with [xrayTunDnsServer] instead of the hardcoded 1.1.1.1.
    val hasCustomXrayTunDns: Boolean
        get() = xrayTunDnsEnabled && xrayTunDnsServer.trim().isNotEmpty()

    companion object {
        const val MIN_MTU = 1280
        const val MAX_MTU = 9000
        const val DEFAULT_MTU = 1500
        const val DEFAULT_XRAY_TUN_DNS_SERVER = "1.1.1.1"
    }
}

internal enum class RunMode(val wireName: String) {
    TUN("tun"),
    PROXY_ONLY("proxyOnly");

    companion object {
        fun fromWire(raw: String?): RunMode {
            return entries.firstOrNull { it.wireName == raw } ?: TUN
        }
    }
}

internal object NaiveRuntimeConstraints {
    fun validationError(
        protocol: String,
        detourProtocol: String? = null,
        tunEngineMode: TunEngineMode,
        runMode: RunMode,
        isBridge: Boolean,
    ): String? {
        if (!isNaive(protocol) && !isNaive(detourProtocol)) return null
        if (runMode != RunMode.TUN) {
            return "NaiveProxy is not available in proxy-only mode."
        }
        if (tunEngineMode != TunEngineMode.LIBBOX) {
            return "NaiveProxy requires the libbox TUN engine; switch the engine in settings."
        }
        if (isBridge) {
            return "NaiveProxy cannot be used in a two-hop chain."
        }
        return null
    }

    fun isNaive(protocol: String?): Boolean {
        return protocol.equals("naive", ignoreCase = true) ||
            protocol.equals("naiveproxy", ignoreCase = true)
    }
}

internal data class ConnectionPolicy(
    val handshakeSeconds: Int = 4,
    val connIdleSeconds: Int = 60,
    val uplinkOnlySeconds: Int = 2,
    val downlinkOnlySeconds: Int = 5,
    val maxTcpConnections: Int = 256,
    val maxUdpConnections: Int = 128,
) {
    fun normalized(): ConnectionPolicy {
        return copy(
            handshakeSeconds = handshakeSeconds.coerceIn(1, 60),
            connIdleSeconds = connIdleSeconds.coerceIn(5, 3600),
            uplinkOnlySeconds = uplinkOnlySeconds.coerceIn(1, 60),
            downlinkOnlySeconds = downlinkOnlySeconds.coerceIn(1, 60),
            maxTcpConnections = maxTcpConnections.coerceIn(1, 4096),
            maxUdpConnections = maxUdpConnections.coerceIn(1, 4096),
        )
    }

    companion object {
        val DEFAULT = ConnectionPolicy()
    }
}

internal data class ServerConfig(
    val tunEngineMode: TunEngineMode = TunEngineMode.LIBBOX,
    val isGlobalProxy: Boolean,
    val server: String,
    val serverPort: Int,
    val protocol: String = "vless",
    val uuid: String,
    val transport: String,
    val transportPath: String,
    val transportServiceName: String,
    val transportHost: String,
    val transportMode: String = "",
    /// xhttp `extra.xPaddingBytes`. Random range like "100-1000". Blank ⇒
    /// builder substitutes the curated default. Exposed so a user / share
    /// link can pin the padding to a server-side expected value.
    val xhttpPadding: String = "",
    /// xhttp `extra.scMaxEachPostBytes`. Controls per-POST payload cap in
    /// packet-up mode (ignored by stream-up but harmless to send). Blank ⇒
    /// curated default in the builder.
    val xhttpMaxPostBytes: String = "",
    /// xhttp `extra.scMinPostsIntervalMs`. Min spacing between successive
    /// POSTs in packet-up. Blank ⇒ curated default.
    val xhttpMinPostInterval: String = "",
    val tlsEnabled: Boolean,
    val tlsSni: String,
    val tlsInsecure: Boolean,
    val flow: String,
    val vlessEncryption: String = "",
    val security: String,
    val realityPbk: String,
    val realitySid: String,
    val realitySpiderX: String = "",
    val realityMldsa65Verify: String = "",
    val fingerprint: String,
    val alpn: String,
    val hysteria2ObfsType: String = "",
    val hysteria2ObfsPassword: String = "",
    val hysteria2ObfsMinPacketSize: Int = 0,
    val hysteria2ObfsMaxPacketSize: Int = 0,
    val hysteria2HopPorts: String = "",
    val hysteria2HopInterval: String = "",
    val hysteria2HopIntervalMax: String = "",
    val hysteria2UpMbps: Int = 0,
    val hysteria2DownMbps: Int = 0,
    val hysteria2Network: String = "",
    val hysteria2BbrProfile: String = "",
    val naiveUsername: String = "",
    val naivePassword: String = "",
    val naiveQuic: Boolean = false,
    val naiveQuicCongestionControl: String = "",
    val naiveInsecureConcurrency: Int = 0,
    val naiveExtraHeadersJson: String = "{}",
    val naiveUdpOverTcp: Boolean = false,
    val naiveUdpOverTcpVersion: Int = 0,
    val appRoutingMode: AppRoutingMode = AppRoutingMode.OFF,
    val appRoutingPackages: List<String> = emptyList(),
    val userRoutingRulesJson: String = "[]",
    val proxyUser: String = "",
    val proxyPassword: String = "",
    val fragmentSettings: XrayFragmentSettings = XrayFragmentSettings(),
    val multiplexSettings: XrayMultiplexSettings = XrayMultiplexSettings(),
    val tunnelNetworkSettings: TunnelNetworkSettings = TunnelNetworkSettings(),
    val keepAwake: Boolean = false,
    /// When true, the embedded xray-core runs at "debug" log level instead
    /// of the default "warning", and the generated outbound JSON is dumped
    /// to logcat once at startup (with credentials masked). Surfaces info-
    /// level errors that are otherwise hidden — used to diagnose obscure
    /// transport-side failures (DPI tampering, Reality auth failures, etc.).
    val verboseXrayLogs: Boolean = false,
    /// In bridge mode this is the entry hop the client dials first; the
    /// outer [ServerConfig] is then the exit (final) hop. Null for plain
    /// single-node tunnels.
    val detourServer: ServerConfig? = null,
    val killSwitchEnabled: Boolean = false,
    val runMode: RunMode = RunMode.TUN,
    /// When true (or when [runMode] is PROXY_ONLY), the local SOCKS/HTTP
    /// inbounds bind to 0.0.0.0 so other devices on the same Wi-Fi /
    /// hotspot can use this device as a proxy.
    val hotspotBindEnabled: Boolean = false,
    /// When true, the local HTTP proxy on port 10809 also requires
    /// [proxyUser] / [proxyPassword] (it normally accepts any caller when
    /// it's only used for the in-app IP probe).
    val httpProxyAuthEnabled: Boolean = false,
    val connectionPolicy: ConnectionPolicy = ConnectionPolicy.DEFAULT,
)
