package com.voidtunnel.voidtunnel

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

internal object QuickSettingsVpnConfigStore {
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val FLUTTER_PREFIX = "flutter."

    private const val KEY_SERVERS = "void.servers"
    private const val KEY_SUBSCRIPTIONS = "void.subscriptions"
    private const val KEY_SELECTED = "void.selectedName"
    private const val KEY_GLOBAL_PROXY = "void.globalProxy"
    private const val KEY_TUN_ENGINE_MODE = "void.tunEngineMode"
    private const val KEY_SHOW_SPEED_IN_NOTIFICATION = "void.showSpeedInNotification"
    private const val KEY_KEEP_AWAKE = "void.keepAwake"
    private const val KEY_APP_ROUTING_MODE = "void.appRoutingMode"
    private const val KEY_APP_ROUTING_PACKAGES = "void.appRoutingPackages"
    private const val KEY_APP_ROUTING_PROXY_PACKAGES = "void.appRoutingProxyPackages"
    private const val KEY_APP_ROUTING_BYPASS_PACKAGES = "void.appRoutingBypassPackages"
    private const val KEY_ROUTING_RULES = "void.routingRules"
    private const val KEY_ROUTING_PRESETS = "void.routingPresets"
    private const val KEY_SELECTED_ROUTING_PRESET = "void.selectedRoutingPreset"
    private const val KEY_CUSTOM_PROXY_AUTH_ENABLED = "void.customProxyAuth.enabled"
    private const val KEY_CUSTOM_PROXY_USER = "void.customProxyAuth.user"
    private const val KEY_CUSTOM_PROXY_PASSWORD = "void.customProxyAuth.password"
    private const val KEY_FRAGMENT_SETTINGS = "void.tunnel.fragmentSettings"
    private const val KEY_MUX_SETTINGS = "void.tunnel.multiplexSettings"
    private const val KEY_NETWORK_SETTINGS = "void.tunnel.networkSettings"

    data class TileStartConfig(
        val intent: Intent,
        val selectedNodeName: String,
    )

    data class WidgetSnapshot(
        val selectedNodeName: String?,
        val selectedAddress: String?,
        val protocol: String?,
        val transport: String?,
        val isGlobalProxy: Boolean,
    )

    fun selectedNodeName(context: Context): String? {
        val prefs = flutterPrefs(context)
        return resolveSelectedServer(loadServers(prefs), prefs.string(KEY_SELECTED))?.name
    }

    fun widgetSnapshot(context: Context): WidgetSnapshot {
        val prefs = flutterPrefs(context)
        val servers = loadServers(prefs)
        val selected = resolveSelectedServer(servers, prefs.string(KEY_SELECTED))
        return WidgetSnapshot(
            selectedNodeName = selected?.name,
            selectedAddress = selected?.address,
            protocol = selected?.protocol,
            transport = selected?.transport,
            isGlobalProxy = prefs.boolean(KEY_GLOBAL_PROXY, false),
        )
    }

    fun saveGlobalProxy(context: Context, value: Boolean) {
        flutterPrefs(context)
            .edit()
            .putBoolean(FLUTTER_PREFIX + KEY_GLOBAL_PROXY, value)
            .apply()
    }

    fun buildStartConfig(context: Context): TileStartConfig? {
        val prefs = flutterPrefs(context)
        val servers = loadServers(prefs)
        val selected = resolveSelectedServer(servers, prefs.string(KEY_SELECTED)) ?: return null
        val isGlobalProxy = prefs.boolean(KEY_GLOBAL_PROXY, false)
        val tunEngineMode = TunEngineMode.fromWire(prefs.string(KEY_TUN_ENGINE_MODE)).wireName

        val presets = loadRoutingPresets(prefs)
        val mainPreset = presets.firstOrNull { it.isMain } ?: StoredRoutingPreset.main()
        val editorPreset = presets.firstOrNull {
            it.id == prefs.string(KEY_SELECTED_ROUTING_PRESET)
        } ?: mainPreset
        val explicitPreset = explicitPresetForServer(presets, selected.name)
        val effectivePreset = explicitPreset ?: mainPreset
        val appRoutingPolicy = if (isGlobalProxy) {
            StoredRoutingPolicy.empty
        } else {
            effectivePreset.appRoutingPolicy
        }
        val routingRulesJson = if (isGlobalProxy) {
            "[]"
        } else {
            encodeRoutingRules(effectivePreset.routingRules)
        }
        val fragmentSettings = parseFragmentSettings(prefs.string(KEY_FRAGMENT_SETTINGS))
        val multiplexSettings = parseMultiplexSettings(prefs.string(KEY_MUX_SETTINGS))
        val networkSettings = parseNetworkSettings(prefs.string(KEY_NETWORK_SETTINGS))
        val (proxyUser, proxyPassword) = resolveProxyAuth(context, prefs)

        val intent = Intent(context, VoidVpnService::class.java).apply {
            putExtra(VoidVpnService.EXTRA_IS_GLOBAL_PROXY, isGlobalProxy)
            putExtra(VoidVpnService.EXTRA_TUN_ENGINE, tunEngineMode)
            putExtra(VoidVpnService.EXTRA_APP_ROUTING_MODE, appRoutingPolicy.mode)
            putExtra(
                VoidVpnService.EXTRA_APP_ROUTING_PACKAGES,
                appRoutingPolicy.activePackages().toTypedArray(),
            )
            putExtra(VoidVpnService.EXTRA_ROUTING_RULES_JSON, routingRulesJson)
            putExtra(VoidVpnService.EXTRA_ROUTING_PRESET_ID, effectivePreset.id)
            putExtra(VoidVpnService.EXTRA_ROUTING_PRESET_NAME, effectivePreset.name)
            putExtra(VoidVpnService.EXTRA_ROUTING_PRESET_EDITOR_ID, editorPreset.id)
            putExtra(VoidVpnService.EXTRA_ROUTING_PRESET_EDITOR_NAME, editorPreset.name)
            putExtra(VoidVpnService.EXTRA_ROUTING_PRESET_NODE_ID, explicitPreset?.id ?: "")
            putExtra(
                VoidVpnService.EXTRA_ROUTING_PRESET_NODE_NAME,
                explicitPreset?.name ?: "",
            )
            putExtra(VoidVpnService.EXTRA_ROUTING_PRESET_NODE, selected.name)
            putExtra(VoidVpnService.EXTRA_ROUTING_PRESET_MODE, appRoutingPolicy.mode)
            putExtra(
                VoidVpnService.EXTRA_ROUTING_PRESET_PACKAGE_COUNT,
                appRoutingPolicy.activePackages().size,
            )
            putExtra(
                VoidVpnService.EXTRA_ROUTING_PRESET_RULE_COUNT,
                effectivePreset.routingRules.size,
            )
            putExtra(
                VoidVpnService.EXTRA_SHOW_SPEED_IN_NOTIFICATION,
                prefs.boolean(KEY_SHOW_SPEED_IN_NOTIFICATION, false),
            )
            putExtra(
                VoidVpnService.EXTRA_KEEP_AWAKE,
                prefs.boolean(KEY_KEEP_AWAKE, false),
            )
            putExtra(VoidVpnService.EXTRA_PROXY_USER, proxyUser)
            putExtra(VoidVpnService.EXTRA_PROXY_PASSWORD, proxyPassword)
            putServerExtras(selected)
            putFragmentExtras(fragmentSettings)
            putMultiplexExtras(multiplexSettings)
            putNetworkExtras(networkSettings)
        }

        return TileStartConfig(intent = intent, selectedNodeName = selected.name)
    }

    private fun flutterPrefs(context: Context): SharedPreferences =
        context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)

    private fun SharedPreferences.string(key: String): String? =
        getString(FLUTTER_PREFIX + key, null)

    private fun SharedPreferences.boolean(key: String, fallback: Boolean): Boolean {
        val prefixedKey = FLUTTER_PREFIX + key
        return if (contains(prefixedKey)) getBoolean(prefixedKey, fallback) else fallback
    }

    private fun loadServers(prefs: SharedPreferences): List<StoredServer> {
        val output = mutableListOf<StoredServer>()
        parseArray(prefs.string(KEY_SERVERS))?.let { array ->
            for (index in 0 until array.length()) {
                array.optJSONObject(index)?.let(StoredServer::fromJson)?.let(output::add)
            }
        }
        parseArray(prefs.string(KEY_SUBSCRIPTIONS))?.let { subscriptions ->
            for (index in 0 until subscriptions.length()) {
                val servers = subscriptions.optJSONObject(index)?.optJSONArray("servers") ?: continue
                for (serverIndex in 0 until servers.length()) {
                    servers.optJSONObject(serverIndex)
                        ?.let(StoredServer::fromJson)
                        ?.let(output::add)
                }
            }
        }
        return output
    }

    private fun resolveSelectedServer(
        servers: List<StoredServer>,
        selectedName: String?,
    ): StoredServer? {
        val normalized = normalizeName(selectedName)
        return if (normalized == null) {
            servers.firstOrNull()
        } else {
            servers.firstOrNull { normalizeName(it.name) == normalized } ?: servers.firstOrNull()
        }
    }

    private fun loadRoutingPresets(prefs: SharedPreferences): List<StoredRoutingPreset> {
        val stored = parseArray(prefs.string(KEY_ROUTING_PRESETS))
        if (stored != null) {
            val decoded = mutableListOf<StoredRoutingPreset>()
            for (index in 0 until stored.length()) {
                stored.optJSONObject(index)
                    ?.let(StoredRoutingPreset::fromJson)
                    ?.let(decoded::add)
            }
            if (decoded.isNotEmpty()) {
                return ensureMainPreset(decoded)
            }
        }

        return listOf(
            StoredRoutingPreset.main(
                appRoutingPolicy = loadLegacyRoutingPolicy(prefs),
                routingRules = loadRoutingRulesFromRaw(prefs.string(KEY_ROUTING_RULES)),
            ),
        )
    }

    private fun ensureMainPreset(presets: List<StoredRoutingPreset>): List<StoredRoutingPreset> {
        val seen = linkedSetOf<String>()
        val output = mutableListOf<StoredRoutingPreset>()
        for (preset in presets) {
            if (!seen.add(preset.id)) continue
            output.add(
                if (preset.isMain) {
                    preset.copy(name = StoredRoutingPreset.MAIN_NAME)
                } else {
                    preset.copy(name = preset.name.ifBlank { "Preset" })
                },
            )
        }
        if (output.none { it.isMain }) {
            output.add(0, StoredRoutingPreset.main())
        }
        val mainIndex = output.indexOfFirst { it.isMain }
        if (mainIndex > 0) {
            val main = output.removeAt(mainIndex)
            output.add(0, main)
        }
        return output
    }

    private fun loadLegacyRoutingPolicy(prefs: SharedPreferences): StoredRoutingPolicy {
        val mode = normalizeRoutingMode(prefs.string(KEY_APP_ROUTING_MODE))
        val rawProxyPackages = prefs.string(KEY_APP_ROUTING_PROXY_PACKAGES)
        val rawBypassPackages = prefs.string(KEY_APP_ROUTING_BYPASS_PACKAGES)
        return if (rawProxyPackages != null || rawBypassPackages != null) {
            StoredRoutingPolicy(
                mode = mode,
                proxyPackages = decodeStringSet(rawProxyPackages),
                bypassPackages = decodeStringSet(rawBypassPackages),
            )
        } else {
            StoredRoutingPolicy.legacy(
                mode = mode,
                packages = decodeStringSet(prefs.string(KEY_APP_ROUTING_PACKAGES)),
            )
        }
    }

    private fun explicitPresetForServer(
        presets: List<StoredRoutingPreset>,
        serverName: String,
    ): StoredRoutingPreset? {
        val normalized = normalizeName(serverName) ?: return null
        return presets.firstOrNull { !it.isMain && normalized in it.serverNames }
    }

    private fun encodeRoutingRules(rules: List<StoredRoutingRule>): String {
        val output = JSONArray()
        for (rule in rules) {
            if (!rule.enabled || !rule.hasMatcher) continue
            output.put(rule.toExportJson())
        }
        return output.toString()
    }

    private fun resolveProxyAuth(
        context: Context,
        prefs: SharedPreferences,
    ): Pair<String, String> {
        if (!prefs.boolean(KEY_CUSTOM_PROXY_AUTH_ENABLED, false)) return "" to ""
        val user = prefs.string(KEY_CUSTOM_PROXY_USER).orEmpty()
        val password = SecurePrefsBridge.get(context, KEY_CUSTOM_PROXY_PASSWORD)
            ?: prefs.string(KEY_CUSTOM_PROXY_PASSWORD).orEmpty()
        return if (user.isNotEmpty() && password.isNotEmpty()) {
            user to password
        } else {
            "" to ""
        }
    }

    private fun Intent.putServerExtras(server: StoredServer) {
        putExtra(VoidVpnService.EXTRA_SERVER, server.address)
        putExtra(VoidVpnService.EXTRA_SERVER_PORT, server.port)
        putExtra(VoidVpnService.EXTRA_PROTOCOL, server.protocol)
        putExtra(VoidVpnService.EXTRA_UUID, server.uuid)
        putExtra(VoidVpnService.EXTRA_TRANSPORT, server.transport)
        putExtra(VoidVpnService.EXTRA_TRANSPORT_PATH, server.transportPath)
        putExtra(VoidVpnService.EXTRA_TRANSPORT_SERVICE_NAME, server.transportServiceName)
        putExtra(VoidVpnService.EXTRA_TRANSPORT_HOST, server.transportHost)
        putExtra(VoidVpnService.EXTRA_TRANSPORT_MODE, server.transportMode)
        putExtra(VoidVpnService.EXTRA_TLS_ENABLED, server.tlsEnabled)
        putExtra(VoidVpnService.EXTRA_TLS_SNI, server.effectiveSni)
        putExtra(VoidVpnService.EXTRA_TLS_INSECURE, server.tlsInsecure)
        putExtra(VoidVpnService.EXTRA_FLOW, server.flow)
        putExtra(VoidVpnService.EXTRA_SECURITY, server.security)
        putExtra(VoidVpnService.EXTRA_REALITY_PBK, server.realityPublicKey)
        putExtra(VoidVpnService.EXTRA_REALITY_SID, server.realityShortId)
        putExtra(VoidVpnService.EXTRA_REALITY_SPIDER_X, server.realitySpiderX)
        putExtra(VoidVpnService.EXTRA_FINGERPRINT, server.fingerprint)
        putExtra(VoidVpnService.EXTRA_ALPN, server.alpn)
        putExtra(VoidVpnService.EXTRA_HYSTERIA2_OBFS_PASSWORD, server.hysteria2ObfsPassword)
        putExtra(VoidVpnService.EXTRA_HYSTERIA2_HOP_PORTS, server.hysteria2HopPorts)
    }

    private fun Intent.putFragmentExtras(settings: XrayFragmentSettings) {
        putExtra(VoidVpnService.EXTRA_FRAGMENT_ENABLED, settings.enabled)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_PACKETS, settings.packets)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_LENGTH, settings.length)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_INTERVAL, settings.interval)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_MAX_SPLIT, settings.maxSplit)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_ENABLED, settings.noiseEnabled)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_TYPE, settings.noiseType)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_PACKET, settings.noisePacket)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_DELAY, settings.noiseDelay)
        putExtra(VoidVpnService.EXTRA_FRAGMENT_NOISE_APPLY_TO, settings.noiseApplyTo)
    }

    private fun Intent.putMultiplexExtras(settings: XrayMultiplexSettings) {
        putExtra(VoidVpnService.EXTRA_MUX_ENABLED, settings.enabled)
        putExtra(VoidVpnService.EXTRA_MUX_TCP_CONCURRENCY, settings.tcpConcurrency)
        putExtra(VoidVpnService.EXTRA_MUX_XUDP_CONCURRENCY, settings.xudpConcurrency)
        putExtra(VoidVpnService.EXTRA_MUX_QUIC_BEHAVIOR, settings.quicBehavior)
    }

    private fun Intent.putNetworkExtras(settings: TunnelNetworkSettings) {
        putExtra(VoidVpnService.EXTRA_USE_LOCAL_DNS, settings.useLocalDns)
        putExtra(VoidVpnService.EXTRA_SERVER_RESOLVING_ENABLED, settings.serverResolvingEnabled)
        putExtra(VoidVpnService.EXTRA_PACKET_ANALYSIS_ENABLED, settings.packetAnalysisEnabled)
        putExtra(VoidVpnService.EXTRA_BLOCK_UDP, settings.blockUdp)
        putExtra(VoidVpnService.EXTRA_NETWORK_STACK, settings.networkStack.wireName)
        putExtra(VoidVpnService.EXTRA_TUN_MTU, settings.mtu)
        putExtra(VoidVpnService.EXTRA_IP_MODE, settings.ipMode.wireName)
        putExtra(VoidVpnService.EXTRA_XRAY_TUN_DNS_ENABLED, settings.xrayTunDnsEnabled)
        putExtra(VoidVpnService.EXTRA_XRAY_TUN_DNS_SERVER, settings.xrayTunDnsServer)
    }

    private fun parseFragmentSettings(raw: String?): XrayFragmentSettings {
        val json = parseObject(raw) ?: return XrayFragmentSettings()
        return XrayFragmentSettings(
            enabled = json.optBoolean("enabled", false),
            packets = json.optString("packets", XrayFragmentSettings.DEFAULT_PACKETS),
            length = json.optString("length", XrayFragmentSettings.DEFAULT_LENGTH),
            interval = json.optString("interval", XrayFragmentSettings.DEFAULT_INTERVAL),
            maxSplit = json.optString("maxSplit", XrayFragmentSettings.DEFAULT_MAX_SPLIT),
            noiseEnabled = json.optBoolean("noiseEnabled", true),
            noiseType = json.optString("noiseType", XrayFragmentSettings.DEFAULT_NOISE_TYPE),
            noisePacket = json.optString("noisePacket", XrayFragmentSettings.DEFAULT_NOISE_PACKET),
            noiseDelay = json.optString("noiseDelay", XrayFragmentSettings.DEFAULT_NOISE_DELAY),
            noiseApplyTo = json.optString(
                "noiseApplyTo",
                XrayFragmentSettings.DEFAULT_NOISE_APPLY_TO,
            ),
        ).normalized()
    }

    private fun parseMultiplexSettings(raw: String?): XrayMultiplexSettings {
        val json = parseObject(raw) ?: return XrayMultiplexSettings()
        return XrayMultiplexSettings(
            enabled = json.optBoolean("enabled", false),
            tcpConcurrency = optInt(json, "tcpConnections", XrayMultiplexSettings.DEFAULT_TCP_CONCURRENCY),
            xudpConcurrency = optInt(
                json,
                "xudpConnections",
                XrayMultiplexSettings.DEFAULT_XUDP_CONCURRENCY,
            ),
            quicBehavior = json.optString(
                "quicBehavior",
                XrayMultiplexSettings.DEFAULT_QUIC_BEHAVIOR,
            ),
        ).normalized()
    }

    private fun parseNetworkSettings(raw: String?): TunnelNetworkSettings {
        val json = parseObject(raw) ?: return TunnelNetworkSettings()
        return TunnelNetworkSettings(
            useLocalDns = json.optBoolean("useLocalDns", false),
            serverResolvingEnabled = json.optBoolean("serverResolvingEnabled", false),
            packetAnalysisEnabled = json.optBoolean("packetAnalysisEnabled", true),
            blockUdp = json.optBoolean("blockUdp", false),
            networkStack = TunnelNetworkStack.fromWire(optString(json, "networkStack")),
            mtu = optInt(json, "mtu", TunnelNetworkSettings.DEFAULT_MTU),
            ipMode = TunnelIpMode.fromWire(optString(json, "ipMode")),
            xrayTunDnsEnabled = json.optBoolean("xrayTunDnsEnabled", false),
            xrayTunDnsServer = optString(json, "xrayTunDnsServer")
                .takeIf { it.isNotBlank() }
                ?: TunnelNetworkSettings.DEFAULT_XRAY_TUN_DNS_SERVER,
        ).normalized()
    }

    private fun loadRoutingRulesFromRaw(raw: String?): List<StoredRoutingRule> {
        val array = parseArray(raw) ?: return emptyList()
        val rules = mutableListOf<StoredRoutingRule>()
        for (index in 0 until array.length()) {
            array.optJSONObject(index)?.let(StoredRoutingRule::fromJson)?.let(rules::add)
        }
        return rules
    }

    private fun decodeStringSet(raw: String?): Set<String> {
        val array = parseArray(raw) ?: return emptySet()
        return array.toStringSet()
    }

    private fun normalizeName(value: String?): String? {
        val normalized = value?.trim()
        return if (normalized.isNullOrEmpty()) null else normalized
    }

    private fun normalizeRoutingMode(raw: String?): String {
        return when (raw?.trim()?.lowercase(Locale.ROOT)) {
            "proxy" -> AppRoutingMode.PROXY_SELECTED.wireName
            "bypass" -> AppRoutingMode.BYPASS_SELECTED.wireName
            else -> AppRoutingMode.OFF.wireName
        }
    }

    private fun parseArray(raw: String?): JSONArray? {
        if (raw.isNullOrBlank()) return null
        return runCatching { JSONArray(raw) }.getOrNull()
    }

    private fun parseObject(raw: String?): JSONObject? {
        if (raw.isNullOrBlank()) return null
        return runCatching { JSONObject(raw) }.getOrNull()
    }

    private fun optInt(json: JSONObject, key: String, fallback: Int): Int {
        return when (val value = json.opt(key)) {
            is Int -> value
            is Number -> value.toInt()
            is String -> value.toIntOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun optString(json: JSONObject, key: String, fallback: String = ""): String {
        val value = json.opt(key)
        return if (value is String) value else fallback
    }

    private fun JSONArray.toStringList(): List<String> {
        val output = mutableListOf<String>()
        for (index in 0 until length()) {
            val value = opt(index)?.toString()?.trim()
            if (!value.isNullOrEmpty()) output.add(value)
        }
        return output
    }

    private fun JSONArray.toStringSet(): Set<String> {
        val output = linkedSetOf<String>()
        for (index in 0 until length()) {
            val value = opt(index)?.toString()?.trim()
            if (!value.isNullOrEmpty()) output.add(value)
        }
        return output
    }

    private data class StoredServer(
        val name: String,
        val address: String,
        val port: Int,
        val protocol: String,
        val uuid: String,
        val transport: String,
        val security: String,
        val transportPath: String,
        val transportServiceName: String,
        val transportHost: String,
        val transportMode: String,
        val sni: String,
        val alpn: String,
        val flow: String,
        val fingerprint: String,
        val realityPublicKey: String,
        val realityShortId: String,
        val realitySpiderX: String,
        val tlsInsecure: Boolean,
        val hysteria2ObfsPassword: String,
        val hysteria2HopPorts: String,
    ) {
        val tlsEnabled: Boolean
            get() = security == "tls" || security == "reality"

        val effectiveSni: String
            get() = sni.ifBlank { address }

        companion object {
            fun fromJson(json: JSONObject): StoredServer? {
                val address = optString(json, "address").trim()
                if (address.isEmpty()) return null
                val security = optString(json, "security", "none")
                    .trim()
                    .lowercase(Locale.ROOT)
                    .ifBlank { "none" }
                return StoredServer(
                    name = optString(json, "name", "Imported VLESS").ifBlank { "Imported VLESS" },
                    address = address,
                    port = optInt(json, "port", 443),
                    protocol = normalizeProtocol(optString(json, "protocol", "vless")),
                    uuid = optString(json, "uuid"),
                    transport = optString(json, "transport", "tcp").ifBlank { "tcp" },
                    security = security,
                    transportPath = optString(json, "transportPath", "/").ifBlank { "/" },
                    transportServiceName = optString(json, "transportServiceName"),
                    transportHost = optString(json, "transportHost"),
                    transportMode = optString(json, "transportMode"),
                    sni = optString(json, "sni"),
                    alpn = optString(json, "alpn"),
                    flow = optString(json, "flow"),
                    fingerprint = optString(json, "fingerprint"),
                    realityPublicKey = optString(json, "realityPublicKey"),
                    realityShortId = optString(json, "realityShortId"),
                    realitySpiderX = optString(json, "realitySpiderX"),
                    tlsInsecure = json.optBoolean("tlsInsecure", false),
                    hysteria2ObfsPassword = optString(json, "hysteria2ObfsPassword"),
                    hysteria2HopPorts = optString(json, "hysteria2HopPorts"),
                )
            }

            private fun normalizeProtocol(raw: String): String {
                return when (raw.trim().lowercase(Locale.ROOT).replace("-", "").replace("_", "")) {
                    "hysteria", "hysteria2", "hy2" -> "hysteria2"
                    else -> "vless"
                }
            }
        }
    }

    private data class StoredRoutingPreset(
        val id: String,
        val name: String,
        val appRoutingPolicy: StoredRoutingPolicy,
        val routingRules: List<StoredRoutingRule>,
        val serverNames: Set<String>,
    ) {
        val isMain: Boolean
            get() = id == MAIN_ID

        companion object {
            const val MAIN_ID = "main"
            const val MAIN_NAME = "Main"

            fun main(
                appRoutingPolicy: StoredRoutingPolicy = StoredRoutingPolicy.empty,
                routingRules: List<StoredRoutingRule> = emptyList(),
            ) = StoredRoutingPreset(
                id = MAIN_ID,
                name = MAIN_NAME,
                appRoutingPolicy = appRoutingPolicy,
                routingRules = routingRules,
                serverNames = emptySet(),
            )

            fun fromJson(json: JSONObject): StoredRoutingPreset? {
                val id = optString(json, "id").trim()
                if (id.isEmpty()) return null
                val mode = normalizeRoutingMode(optString(json, "appRoutingMode"))
                val policy = if (
                    json.has("appRoutingProxyPackages") ||
                    json.has("appRoutingBypassPackages")
                ) {
                    StoredRoutingPolicy(
                        mode = mode,
                        proxyPackages = json.optJSONArray("appRoutingProxyPackages")
                            ?.toStringSet()
                            ?: emptySet(),
                        bypassPackages = json.optJSONArray("appRoutingBypassPackages")
                            ?.toStringSet()
                            ?: emptySet(),
                    )
                } else {
                    StoredRoutingPolicy.legacy(
                        mode = mode,
                        packages = json.optJSONArray("appRoutingPackages")
                            ?.toStringSet()
                            ?: emptySet(),
                    )
                }
                val rules = mutableListOf<StoredRoutingRule>()
                val rawRules = json.opt("routingRules")
                when (rawRules) {
                    is JSONArray -> {
                        for (index in 0 until rawRules.length()) {
                            rawRules.optJSONObject(index)
                                ?.let(StoredRoutingRule::fromJson)
                                ?.let(rules::add)
                        }
                    }
                    is String -> rules.addAll(loadRoutingRulesFromRaw(rawRules))
                }
                val serverNames = json.optJSONArray("serverNames")
                    ?.toStringSet()
                    ?.mapNotNull(::normalizeName)
                    ?.toSet()
                    ?: emptySet()
                return StoredRoutingPreset(
                    id = id,
                    name = if (id == MAIN_ID) MAIN_NAME else optString(json, "name", "Preset"),
                    appRoutingPolicy = policy,
                    routingRules = rules,
                    serverNames = serverNames,
                )
            }
        }
    }

    private data class StoredRoutingPolicy(
        val mode: String,
        val proxyPackages: Set<String> = emptySet(),
        val bypassPackages: Set<String> = emptySet(),
    ) {
        fun activePackages(): Set<String> {
            return when (mode) {
                AppRoutingMode.PROXY_SELECTED.wireName -> proxyPackages
                AppRoutingMode.BYPASS_SELECTED.wireName -> bypassPackages
                else -> emptySet()
            }
        }

        companion object {
            val empty = StoredRoutingPolicy(mode = AppRoutingMode.OFF.wireName)

            fun legacy(mode: String, packages: Set<String>): StoredRoutingPolicy {
                return when (mode) {
                    AppRoutingMode.PROXY_SELECTED.wireName ->
                        StoredRoutingPolicy(mode = mode, proxyPackages = packages)
                    AppRoutingMode.BYPASS_SELECTED.wireName ->
                        StoredRoutingPolicy(mode = mode, bypassPackages = packages)
                    else -> empty
                }
            }
        }
    }

    private data class StoredRoutingRule(
        val name: String,
        val enabled: Boolean,
        val outbound: String,
        val domains: List<String>,
        val ips: List<String>,
        val port: String,
        val networks: List<String>,
        val protocols: List<String>,
    ) {
        val hasMatcher: Boolean
            get() = domains.isNotEmpty() ||
                ips.isNotEmpty() ||
                port.trim().isNotEmpty() ||
                networks.isNotEmpty() ||
                protocols.isNotEmpty()

        fun toExportJson(): JSONObject {
            return JSONObject().apply {
                put("__name__", name)
                put("type", "field")
                put("outboundTag", outbound)
                if (!enabled) put("enabled", false)
                if (domains.isNotEmpty()) put("domain", JSONArray(domains))
                if (ips.isNotEmpty()) put("ip", JSONArray(ips))
                if (port.trim().isNotEmpty()) put("port", port.trim())
                if (networks.isNotEmpty()) put("network", JSONArray(networks))
                if (protocols.isNotEmpty()) put("protocol", JSONArray(protocols))
            }
        }

        companion object {
            fun fromJson(json: JSONObject): StoredRoutingRule? {
                val id = optString(json, "id")
                if (id.isEmpty()) return null
                return StoredRoutingRule(
                    name = optString(json, "name", "Rule"),
                    enabled = json.optBoolean("enabled", true),
                    outbound = normalizeOutbound(optString(json, "outbound")),
                    domains = json.optJSONArray("domains")?.toStringList() ?: emptyList(),
                    ips = json.optJSONArray("ips")?.toStringList() ?: emptyList(),
                    port = optString(json, "port"),
                    networks = json.optJSONArray("networks")?.toStringList() ?: emptyList(),
                    protocols = json.optJSONArray("protocols")?.toStringList() ?: emptyList(),
                )
            }

            private fun normalizeOutbound(raw: String): String {
                return when (raw.trim().lowercase(Locale.ROOT)) {
                    "direct", "freedom" -> "direct"
                    "block", "reject", "blackhole" -> "block"
                    else -> "proxy"
                }
            }
        }
    }
}
