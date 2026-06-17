package com.voidlex.voidlex

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

internal object QuickSettingsVpnConfigStore {
    private const val TAG = "QSVpnConfigStore"
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val FLUTTER_PREFIX = "flutter."

    private const val KEY_SERVERS = "void.servers"
    private const val KEY_SUBSCRIPTIONS = "void.subscriptions"
    private const val KEY_SELECTED = "void.selectedName"
    private const val KEY_EXIT_NODE = "void.exitNodeName"
    private const val KEY_GLOBAL_PROXY = "void.globalProxy"
    private const val KEY_KILL_SWITCH_ENABLED = "void.killSwitchEnabled"
    private const val KEY_RUN_MODE = "void.runMode"
    private const val KEY_HOTSPOT_BIND_ENABLED = "void.hotspotBindEnabled"
    private const val KEY_HTTP_PROXY_AUTH_ENABLED = "void.httpProxyAuthEnabled"
    private const val KEY_SNIFFING_ROUTE_ONLY = "void.sniffingRouteOnly"
    private const val KEY_VERBOSE_XRAY_LOGS = "void.verboseXrayLogs"
    private const val KEY_CONNECTION_POLICY = "void.connectionPolicy"
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
        val runMode: RunMode,
        /** False in proxy-only mode — no [VpnService.prepare] prompt is required. */
        val requiresVpnPermission: Boolean,
    )

    /** Mirrors [MainActivity.handleStopVpn] when mode is unknown. */
    internal data class TunnelServers(
        val entry: StoredServer,
        val outer: StoredServer,
        val isBridge: Boolean,
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
        AppLogger.i(TAG, "saveGlobalProxy value=$value")
        flutterPrefs(context)
            .edit()
            .putBoolean(FLUTTER_PREFIX + KEY_GLOBAL_PROXY, value)
            .apply()
        // Notify Flutter (when alive) so VpnController's in-memory
        // _isGlobalProxy stays in sync with what the widget just wrote.
        // Without this, the next Flutter-initiated start would clobber
        // the widget's value with its stale cache.
        VpnEventBridge.emit(
            state = "globalProxyChanged",
            extras = mapOf("globalProxy" to value),
        )
    }

    fun currentRunMode(context: Context): RunMode {
        val prefs = flutterPrefs(context)
        return RunMode.fromWire(prefs.string(KEY_RUN_MODE))
    }

    /**
     * Dumps every wire-level field the parser will read off the intent.
     * Used in the widget path to diff against [VpnServiceConfigParser]'s
     * "Parsed VPN config" log line when a server connects but doesn't
     * pass traffic. Reality fields are surfaced as `present/empty` rather
     * than their raw values to keep secrets out of logs.
     */
    private fun describeStoredServer(server: StoredServer): String {
        return "name=${server.name} address=${server.address}:${server.port} " +
            "protocol=${server.protocol} transport=${server.transport} " +
            "security=${server.security} tlsEnabled=${server.tlsEnabled} " +
            "tlsInsecure=${server.tlsInsecure} " +
            "sni=${server.effectiveSni} flow=${server.flow.ifBlank { "-" }} " +
            "encryption=${server.vlessEncryption.ifBlank { "none" }} " +
            "alpn=${server.alpn.ifBlank { "-" }} " +
            "fingerprint=${server.fingerprint.ifBlank { "-" }} " +
            "pbk=${if (server.realityPublicKey.isNotBlank()) "present" else "empty"} " +
            "sidLen=${server.realityShortId.length} " +
            "spx=${if (server.realitySpiderX.isNotBlank()) "present" else "empty"} " +
            "mldsa=${if (server.realityMldsa65Verify.isNotBlank()) "present" else "empty"} " +
            "uuid=${if (server.uuid.isNotBlank()) "present" else "empty"} " +
            "transportPath=${server.transportPath} " +
            "transportHost=${server.transportHost.ifBlank { "-" }} " +
            "transportMode=${server.transportMode.ifBlank { "-" }} " +
            "transportSvc=${server.transportServiceName.ifBlank { "-" }} " +
            "xhttpPad=${if (server.xhttpPadding.isNotBlank()) server.xhttpPadding else "default"} " +
            "xhttpMaxPost=${if (server.xhttpMaxPostBytes.isNotBlank()) server.xhttpMaxPostBytes else "default"} " +
            "xhttpMinInt=${if (server.xhttpMinPostInterval.isNotBlank()) server.xhttpMinPostInterval else "default"} " +
            "hy2Obfs=${server.hysteria2ObfsType.ifBlank { if (server.hysteria2ObfsPassword.isBlank()) "-" else "salamander" }} " +
            "hy2Hop=${server.hysteria2HopPorts.ifBlank { "-" }} " +
            "naiveUser=${if (server.naiveUsername.isNotBlank()) "present" else "empty"} " +
            "naivePass=${if (server.naivePassword.isNotBlank()) "present" else "empty"} " +
            "naiveQuic=${server.naiveQuic} " +
            "naiveCc=${server.naiveQuicCongestionControl.ifBlank { "-" }} " +
            "naiveHeaders=${if (server.naiveExtraHeadersJson == "{}") "empty" else "present"}"
    }

    /**
     * Builds stop intents for the currently active transport mode.
     *
     * IMPORTANT: in widget-driven restart flows we must avoid emitting an
     * unrelated "disconnected" from the other service, otherwise
     * VpnRuntimeState.awaitTerminal() can resolve too early and we restart
     * before the real runtime teardown has settled.
     */
    fun buildStopIntents(context: Context, runMode: RunMode? = null): List<Intent> {
        return when (runMode ?: currentRunMode(context)) {
            RunMode.PROXY_ONLY -> {
                listOf(
                    Intent(context, VoidProxyService::class.java).apply {
                        action = VoidProxyService.ACTION_DISCONNECT
                    },
                )
            }
            else -> {
                listOf(
                    Intent(context, VoidVpnService::class.java).apply {
                        action = "ACTION_DISCONNECT"
                    },
                )
            }
        }
    }

    fun buildStartConfig(context: Context): TileStartConfig? {
        val prefs = flutterPrefs(context)
        val servers = loadServers(prefs)
        val tunnel = resolveTunnelServers(
            servers = servers,
            selectedName = prefs.string(KEY_SELECTED),
            exitNodeName = prefs.string(KEY_EXIT_NODE),
        ) ?: return null
        val entry = tunnel.entry
        val outer = tunnel.outer
        val isGlobalProxy = prefs.boolean(KEY_GLOBAL_PROXY, false)
        val tunEngineMode = TunEngineMode.fromWire(prefs.string(KEY_TUN_ENGINE_MODE))
        val runMode = RunMode.fromWire(prefs.string(KEY_RUN_MODE))
        val naiveRestriction = NaiveRuntimeConstraints.validationError(
            protocol = outer.protocol,
            detourProtocol = entry.protocol.takeIf { tunnel.isBridge },
            tunEngineMode = tunEngineMode,
            runMode = runMode,
            isBridge = tunnel.isBridge,
        )
        if (naiveRestriction != null) {
            AppLogger.w(TAG, "Rejecting NaiveProxy quick start: $naiveRestriction")
            return null
        }

        val presets = loadRoutingPresets(prefs)
        val mainPreset = presets.firstOrNull { it.isMain } ?: StoredRoutingPreset.main()
        val editorPreset = presets.firstOrNull {
            it.id == prefs.string(KEY_SELECTED_ROUTING_PRESET)
        } ?: mainPreset
        // Routing preset follows the ENTRY hop — same as [VpnController._invokeStart].
        val explicitPreset = explicitPresetForServer(presets, entry.name)
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
        val connectionPolicy = parseConnectionPolicy(prefs.string(KEY_CONNECTION_POLICY))
        val (proxyUser, proxyPassword) = resolveProxyAuth(context, prefs)

        val serviceClass = if (runMode == RunMode.PROXY_ONLY) {
            VoidProxyService::class.java
        } else {
            VoidVpnService::class.java
        }
        val intent = Intent(context, serviceClass).apply {
            putExtra(VoidVpnService.EXTRA_IS_GLOBAL_PROXY, isGlobalProxy)
            putExtra(VoidVpnService.EXTRA_TUN_ENGINE, tunEngineMode.wireName)
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
            putExtra(VoidVpnService.EXTRA_ROUTING_PRESET_NODE, entry.name)
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
            applyConnectionModeExtras(
                prefs = prefs,
                runMode = runMode,
                connectionPolicy = connectionPolicy,
            )
            putServerExtras(outer)
            if (tunnel.isBridge) {
                putServerExtras(entry, extraPrefix = "ENTRY")
            }
            putFragmentExtras(fragmentSettings)
            putMultiplexExtras(multiplexSettings)
            putNetworkExtras(networkSettings)
        }

        AppLogger.i(
            TAG,
            "buildStartConfig: node=${entry.name} outer=${outer.name} " +
                "bridge=${tunnel.isBridge} runMode=${runMode.wireName} " +
                "global=$isGlobalProxy tunEngine=${tunEngineMode.wireName} " +
                "preset=${effectivePreset.name}/${effectivePreset.id} " +
                "appRoutingMode=${appRoutingPolicy.mode} " +
                "appRoutingPackages=${appRoutingPolicy.activePackages().size}",
        )
        AppLogger.i(TAG, "buildStartConfig OUTER: ${describeStoredServer(outer)}")
        if (tunnel.isBridge) {
            AppLogger.i(TAG, "buildStartConfig ENTRY: ${describeStoredServer(entry)}")
        }
        return TileStartConfig(
            intent = intent,
            selectedNodeName = entry.name,
            runMode = runMode,
            requiresVpnPermission = runMode != RunMode.PROXY_ONLY,
        )
    }

    internal fun resolveTunnelServers(
        servers: List<StoredServer>,
        selectedName: String?,
        exitNodeName: String?,
    ): TunnelServers? {
        val entry = resolveSelectedServer(servers, selectedName) ?: return null
        // The exit hop must resolve STRICTLY: no exit name (single-hop) or an
        // exit name that no longer matches any server means there is no bridge.
        // We must NOT reuse resolveSelectedServer here — its `firstOrNull`
        // fallback would invent a bridge to whatever server happens to be first
        // in the list whenever exitNodeName is null/unknown, which is exactly
        // the widget-vs-UI mismatch that broke traffic. See VpnController's
        // `exitServer` getter (strict, returns null when unset/unknown).
        val exitCandidate = resolveExitServer(servers, exitNodeName)
        val bridgeExit = exitCandidate?.takeUnless {
            normalizeName(it.name) == normalizeName(entry.name)
        }
        val outer = bridgeExit ?: entry
        return TunnelServers(
            entry = entry,
            outer = outer,
            isBridge = bridgeExit != null,
        )
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

    /**
     * Resolves the bridge EXIT hop strictly by name. Unlike
     * [resolveSelectedServer], this never falls back to the first server: a
     * null/blank exit name means single-hop, and an exit name that matches no
     * known server also means single-hop. This mirrors
     * `VpnController.exitServer` in Dart so the widget builds the same tunnel
     * the in-app UI does.
     */
    private fun resolveExitServer(
        servers: List<StoredServer>,
        exitNodeName: String?,
    ): StoredServer? {
        val normalized = normalizeName(exitNodeName) ?: return null
        return servers.firstOrNull { normalizeName(it.name) == normalized }
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

    private fun Intent.applyConnectionModeExtras(
        prefs: SharedPreferences,
        runMode: RunMode,
        connectionPolicy: ConnectionPolicy,
    ) {
        val policy = connectionPolicy.normalized()
        putExtra(
            VoidVpnService.EXTRA_KILL_SWITCH_ENABLED,
            prefs.boolean(KEY_KILL_SWITCH_ENABLED, false),
        )
        putExtra(VoidVpnService.EXTRA_RUN_MODE, runMode.wireName)
        putExtra(
            VoidVpnService.EXTRA_HOTSPOT_BIND_ENABLED,
            prefs.boolean(KEY_HOTSPOT_BIND_ENABLED, false) ||
                runMode == RunMode.PROXY_ONLY,
        )
        putExtra(
            VoidVpnService.EXTRA_HTTP_PROXY_AUTH_ENABLED,
            prefs.boolean(KEY_HTTP_PROXY_AUTH_ENABLED, false),
        )
        putExtra(
            VoidVpnService.EXTRA_SNIFFING_ROUTE_ONLY,
            prefs.boolean(KEY_SNIFFING_ROUTE_ONLY, true),
        )
        putExtra(
            VoidVpnService.EXTRA_VERBOSE_XRAY_LOGS,
            prefs.boolean(KEY_VERBOSE_XRAY_LOGS, false),
        )
        putExtra(VoidVpnService.EXTRA_POLICY_HANDSHAKE_SEC, policy.handshakeSeconds)
        putExtra(VoidVpnService.EXTRA_POLICY_CONN_IDLE_SEC, policy.connIdleSeconds)
        putExtra(VoidVpnService.EXTRA_POLICY_UPLINK_ONLY_SEC, policy.uplinkOnlySeconds)
        putExtra(
            VoidVpnService.EXTRA_POLICY_DOWNLINK_ONLY_SEC,
            policy.downlinkOnlySeconds,
        )
        putExtra(VoidVpnService.EXTRA_POLICY_MAX_TCP_CONNS, policy.maxTcpConnections)
        putExtra(VoidVpnService.EXTRA_POLICY_MAX_UDP_CONNS, policy.maxUdpConnections)
    }

    private fun parseConnectionPolicy(raw: String?): ConnectionPolicy {
        val json = parseObject(raw) ?: return ConnectionPolicy.DEFAULT
        return ConnectionPolicy(
            handshakeSeconds = optInt(json, "handshakeSeconds", ConnectionPolicy.DEFAULT.handshakeSeconds),
            connIdleSeconds = optInt(json, "connIdleSeconds", ConnectionPolicy.DEFAULT.connIdleSeconds),
            uplinkOnlySeconds = optInt(
                json,
                "uplinkOnlySeconds",
                ConnectionPolicy.DEFAULT.uplinkOnlySeconds,
            ),
            downlinkOnlySeconds = optInt(
                json,
                "downlinkOnlySeconds",
                ConnectionPolicy.DEFAULT.downlinkOnlySeconds,
            ),
            maxTcpConnections = optInt(
                json,
                "maxTcpConnections",
                ConnectionPolicy.DEFAULT.maxTcpConnections,
            ),
            maxUdpConnections = optInt(
                json,
                "maxUdpConnections",
                ConnectionPolicy.DEFAULT.maxUdpConnections,
            ),
        ).normalized()
    }

    private fun Intent.putServerExtras(server: StoredServer, extraPrefix: String = "") {
        val prefix = if (extraPrefix.isBlank()) {
            ""
        } else {
            "${extraPrefix.uppercase()}_"
        }
        putExtra(prefix + VoidVpnService.EXTRA_SERVER, server.address)
        putExtra(prefix + VoidVpnService.EXTRA_SERVER_PORT, server.port)
        putExtra(prefix + VoidVpnService.EXTRA_PROTOCOL, server.protocol)
        putExtra(prefix + VoidVpnService.EXTRA_UUID, server.uuid)
        putExtra(prefix + VoidVpnService.EXTRA_TRANSPORT, server.transport)
        putExtra(prefix + VoidVpnService.EXTRA_TRANSPORT_PATH, server.transportPath)
        putExtra(
            prefix + VoidVpnService.EXTRA_TRANSPORT_SERVICE_NAME,
            server.transportServiceName,
        )
        putExtra(prefix + VoidVpnService.EXTRA_TRANSPORT_HOST, server.transportHost)
        putExtra(prefix + VoidVpnService.EXTRA_TRANSPORT_MODE, server.transportMode)
        putExtra(prefix + VoidVpnService.EXTRA_XHTTP_PADDING, server.xhttpPadding)
        putExtra(
            prefix + VoidVpnService.EXTRA_XHTTP_MAX_POST_BYTES,
            server.xhttpMaxPostBytes,
        )
        putExtra(
            prefix + VoidVpnService.EXTRA_XHTTP_MIN_POST_INTERVAL,
            server.xhttpMinPostInterval,
        )
        putExtra(prefix + VoidVpnService.EXTRA_TLS_ENABLED, server.tlsEnabled)
        putExtra(prefix + VoidVpnService.EXTRA_TLS_SNI, server.effectiveSni)
        putExtra(prefix + VoidVpnService.EXTRA_TLS_INSECURE, server.tlsInsecure)
        putExtra(prefix + VoidVpnService.EXTRA_FLOW, server.flow)
        putExtra(prefix + VoidVpnService.EXTRA_VLESS_ENCRYPTION, server.vlessEncryption)
        putExtra(prefix + VoidVpnService.EXTRA_SECURITY, server.security)
        putExtra(prefix + VoidVpnService.EXTRA_REALITY_PBK, server.realityPublicKey)
        putExtra(prefix + VoidVpnService.EXTRA_REALITY_SID, server.realityShortId)
        putExtra(prefix + VoidVpnService.EXTRA_REALITY_SPIDER_X, server.realitySpiderX)
        putExtra(
            prefix + VoidVpnService.EXTRA_REALITY_MLDSA65_VERIFY,
            server.realityMldsa65Verify,
        )
        putExtra(prefix + VoidVpnService.EXTRA_FINGERPRINT, server.fingerprint)
        putExtra(prefix + VoidVpnService.EXTRA_ALPN, server.alpn)
        putExtra(prefix + VoidVpnService.EXTRA_HYSTERIA2_OBFS_TYPE, server.hysteria2ObfsType)
        putExtra(
            prefix + VoidVpnService.EXTRA_HYSTERIA2_OBFS_PASSWORD,
            server.hysteria2ObfsPassword,
        )
        putExtra(
            prefix + VoidVpnService.EXTRA_HYSTERIA2_OBFS_MIN_PACKET_SIZE,
            server.hysteria2ObfsMinPacketSize,
        )
        putExtra(
            prefix + VoidVpnService.EXTRA_HYSTERIA2_OBFS_MAX_PACKET_SIZE,
            server.hysteria2ObfsMaxPacketSize,
        )
        putExtra(prefix + VoidVpnService.EXTRA_HYSTERIA2_HOP_PORTS, server.hysteria2HopPorts)
        putExtra(prefix + VoidVpnService.EXTRA_HYSTERIA2_HOP_INTERVAL, server.hysteria2HopInterval)
        putExtra(
            prefix + VoidVpnService.EXTRA_HYSTERIA2_HOP_INTERVAL_MAX,
            server.hysteria2HopIntervalMax,
        )
        putExtra(prefix + VoidVpnService.EXTRA_HYSTERIA2_UP_MBPS, server.hysteria2UpMbps)
        putExtra(prefix + VoidVpnService.EXTRA_HYSTERIA2_DOWN_MBPS, server.hysteria2DownMbps)
        putExtra(prefix + VoidVpnService.EXTRA_HYSTERIA2_NETWORK, server.hysteria2Network)
        putExtra(prefix + VoidVpnService.EXTRA_HYSTERIA2_BBR_PROFILE, server.hysteria2BbrProfile)
        putExtra(prefix + VoidVpnService.EXTRA_NAIVE_USERNAME, server.naiveUsername)
        putExtra(prefix + VoidVpnService.EXTRA_NAIVE_PASSWORD, server.naivePassword)
        putExtra(prefix + VoidVpnService.EXTRA_NAIVE_QUIC, server.naiveQuic)
        putExtra(
            prefix + VoidVpnService.EXTRA_NAIVE_QUIC_CONGESTION_CONTROL,
            server.naiveQuicCongestionControl,
        )
        putExtra(
            prefix + VoidVpnService.EXTRA_NAIVE_INSECURE_CONCURRENCY,
            server.naiveInsecureConcurrency,
        )
        putExtra(
            prefix + VoidVpnService.EXTRA_NAIVE_EXTRA_HEADERS_JSON,
            server.naiveExtraHeadersJson,
        )
        putExtra(prefix + VoidVpnService.EXTRA_NAIVE_UDP_OVER_TCP, server.naiveUdpOverTcp)
        putExtra(
            prefix + VoidVpnService.EXTRA_NAIVE_UDP_OVER_TCP_VERSION,
            server.naiveUdpOverTcpVersion,
        )
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

    internal data class StoredServer(
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
        val xhttpPadding: String,
        val xhttpMaxPostBytes: String,
        val xhttpMinPostInterval: String,
        val sni: String,
        val alpn: String,
        val flow: String,
        val vlessEncryption: String = "",
        val fingerprint: String,
        val realityPublicKey: String,
        val realityShortId: String,
        val realitySpiderX: String,
        val realityMldsa65Verify: String = "",
        val tlsInsecure: Boolean,
        val hysteria2ObfsType: String = "",
        val hysteria2ObfsPassword: String,
        val hysteria2ObfsMinPacketSize: Int = 0,
        val hysteria2ObfsMaxPacketSize: Int = 0,
        val hysteria2HopPorts: String,
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
    ) {
        val tlsEnabled: Boolean
            get() = security == "tls" || security == "reality"

        val effectiveSni: String
            get() = sni.ifBlank { address }

        val isNaive: Boolean
            get() = protocol == "naive"

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
                    xhttpPadding = optString(json, "xhttpPadding"),
                    xhttpMaxPostBytes = optString(json, "xhttpMaxPostBytes"),
                    xhttpMinPostInterval = optString(json, "xhttpMinPostInterval"),
                    sni = optString(json, "sni"),
                    alpn = optString(json, "alpn"),
                    flow = optString(json, "flow"),
                    vlessEncryption = optString(json, "vlessEncryption"),
                    fingerprint = optString(json, "fingerprint"),
                    realityPublicKey = optString(json, "realityPublicKey"),
                    realityShortId = optString(json, "realityShortId"),
                    realitySpiderX = optString(json, "realitySpiderX"),
                    realityMldsa65Verify = optString(json, "realityMldsa65Verify"),
                    tlsInsecure = json.optBoolean("tlsInsecure", false),
                    hysteria2ObfsType = optString(json, "hysteria2ObfsType"),
                    hysteria2ObfsPassword = optString(json, "hysteria2ObfsPassword"),
                    hysteria2ObfsMinPacketSize = optInt(json, "hysteria2ObfsMinPacketSize", 0),
                    hysteria2ObfsMaxPacketSize = optInt(json, "hysteria2ObfsMaxPacketSize", 0),
                    hysteria2HopPorts = optString(json, "hysteria2HopPorts"),
                    hysteria2HopInterval = optString(json, "hysteria2HopInterval"),
                    hysteria2HopIntervalMax = optString(json, "hysteria2HopIntervalMax"),
                    hysteria2UpMbps = optInt(json, "hysteria2UpMbps", 0),
                    hysteria2DownMbps = optInt(json, "hysteria2DownMbps", 0),
                    hysteria2Network = optString(json, "hysteria2Network"),
                    hysteria2BbrProfile = optString(json, "hysteria2BbrProfile"),
                    naiveUsername = optString(json, "naiveUsername"),
                    naivePassword = optString(json, "naivePassword"),
                    naiveQuic = json.optBoolean("naiveQuic", false),
                    naiveQuicCongestionControl =
                        optString(json, "naiveQuicCongestionControl"),
                    naiveInsecureConcurrency = optInt(json, "naiveInsecureConcurrency", 0),
                    naiveExtraHeadersJson =
                        json.optJSONObject("naiveExtraHeaders")?.toString() ?: "{}",
                    naiveUdpOverTcp = json.optBoolean("naiveUdpOverTcp", false),
                    naiveUdpOverTcpVersion = optInt(json, "naiveUdpOverTcpVersion", 0),
                )
            }

            private fun normalizeProtocol(raw: String): String {
                return when (raw.trim().lowercase(Locale.ROOT).replace("-", "").replace("_", "")) {
                    "hysteria", "hysteria2", "hy2" -> "hysteria2"
                    "naive", "naiveproxy" -> "naive"
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
