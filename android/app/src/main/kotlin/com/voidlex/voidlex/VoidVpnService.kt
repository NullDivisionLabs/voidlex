package com.voidlex.voidlex

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.TrafficStats
import android.os.ParcelFileDescriptor
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.system.Os
import android.system.OsConstants
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

class VoidVpnService : VpnService() {
    companion object {
        private const val TAG = "VoidVpnService"
        private const val XRAY_TUN_DNS = "1.1.1.1"
        private const val XRAY_TUN_IPV6_DNS = "2606:4700:4700::1111"

        const val EXTRA_IS_GLOBAL_PROXY = "isGlobalProxy"
        const val EXTRA_SERVER = "server"
        const val EXTRA_SERVER_PORT = "serverPort"
        const val EXTRA_PROTOCOL = "protocol"
        const val EXTRA_UUID = "uuid"
        const val EXTRA_TRANSPORT = "transport"
        const val EXTRA_TRANSPORT_PATH = "transportPath"
        const val EXTRA_TRANSPORT_SERVICE_NAME = "transportServiceName"
        const val EXTRA_TRANSPORT_HOST = "transportHost"
        const val EXTRA_TRANSPORT_MODE = "transportMode"
        const val EXTRA_XHTTP_PADDING = "xhttpPadding"
        const val EXTRA_XHTTP_MAX_POST_BYTES = "xhttpMaxPostBytes"
        const val EXTRA_XHTTP_MIN_POST_INTERVAL = "xhttpMinPostInterval"
        const val EXTRA_TLS_ENABLED = "tlsEnabled"
        const val EXTRA_TLS_SNI = "tlsSni"
        const val EXTRA_TLS_INSECURE = "tlsInsecure"
        const val EXTRA_FLOW = "flow"
        const val EXTRA_SECURITY = "security"
        const val EXTRA_REALITY_PBK = "realityPbk"
        const val EXTRA_REALITY_SID = "realitySid"
        const val EXTRA_REALITY_SPIDER_X = "realitySpiderX"
        const val EXTRA_FINGERPRINT = "fingerprint"
        const val EXTRA_ALPN = "alpn"
        const val EXTRA_HYSTERIA2_OBFS_PASSWORD = "hysteria2ObfsPassword"
        const val EXTRA_HYSTERIA2_HOP_PORTS = "hysteria2HopPorts"
        const val EXTRA_TUN_ENGINE = "tunEngine"
        const val EXTRA_APP_ROUTING_MODE = "appRoutingMode"
        const val EXTRA_APP_ROUTING_PACKAGES = "appRoutingPackages"
        const val EXTRA_ROUTING_RULES_JSON = "routingRulesJson"
        const val EXTRA_ROUTING_PRESET_ID = "routingPresetId"
        const val EXTRA_ROUTING_PRESET_NAME = "routingPresetName"
        const val EXTRA_ROUTING_PRESET_EDITOR_ID = "routingPresetEditorId"
        const val EXTRA_ROUTING_PRESET_EDITOR_NAME = "routingPresetEditorName"
        const val EXTRA_ROUTING_PRESET_NODE_ID = "routingPresetNodeId"
        const val EXTRA_ROUTING_PRESET_NODE_NAME = "routingPresetNodeName"
        const val EXTRA_ROUTING_PRESET_NODE = "routingPresetNode"
        const val EXTRA_ROUTING_PRESET_MODE = "routingPresetMode"
        const val EXTRA_ROUTING_PRESET_PACKAGE_COUNT = "routingPresetPackageCount"
        const val EXTRA_ROUTING_PRESET_RULE_COUNT = "routingPresetRuleCount"
        const val EXTRA_SHOW_SPEED_IN_NOTIFICATION = "showSpeedInNotification"
        const val EXTRA_PROXY_USER = "proxyUser"
        const val EXTRA_PROXY_PASSWORD = "proxyPassword"
        const val EXTRA_FRAGMENT_ENABLED = "fragmentEnabled"
        const val EXTRA_FRAGMENT_PACKETS = "fragmentPackets"
        const val EXTRA_FRAGMENT_LENGTH = "fragmentLength"
        const val EXTRA_FRAGMENT_INTERVAL = "fragmentInterval"
        const val EXTRA_FRAGMENT_MAX_SPLIT = "fragmentMaxSplit"
        const val EXTRA_FRAGMENT_NOISE_ENABLED = "fragmentNoiseEnabled"
        const val EXTRA_FRAGMENT_NOISE_TYPE = "fragmentNoiseType"
        const val EXTRA_FRAGMENT_NOISE_PACKET = "fragmentNoisePacket"
        const val EXTRA_FRAGMENT_NOISE_DELAY = "fragmentNoiseDelay"
        const val EXTRA_FRAGMENT_NOISE_APPLY_TO = "fragmentNoiseApplyTo"
        const val EXTRA_MUX_ENABLED = "muxEnabled"
        const val EXTRA_MUX_TCP_CONCURRENCY = "muxTcpConcurrency"
        const val EXTRA_MUX_XUDP_CONCURRENCY = "muxXudpConcurrency"
        const val EXTRA_MUX_QUIC_BEHAVIOR = "muxQuicBehavior"
        const val EXTRA_USE_LOCAL_DNS = "useLocalDns"
        const val EXTRA_SERVER_RESOLVING_ENABLED = "serverResolvingEnabled"
        const val EXTRA_PACKET_ANALYSIS_ENABLED = "packetAnalysisEnabled"
        const val EXTRA_BLOCK_UDP = "blockUdp"
        const val EXTRA_NETWORK_STACK = "networkStack"
        const val EXTRA_TUN_MTU = "tunMtu"
        const val EXTRA_IP_MODE = "ipMode"
        const val EXTRA_XRAY_TUN_DNS_ENABLED = "xrayTunDnsEnabled"
        const val EXTRA_XRAY_TUN_DNS_SERVER = "xrayTunDnsServer"
        const val EXTRA_KEEP_AWAKE = "keepAwake"
        const val EXTRA_VERBOSE_XRAY_LOGS = "verboseXrayLogs"
        const val EXTRA_KILL_SWITCH_ENABLED = "killSwitchEnabled"
        const val EXTRA_RUN_MODE = "runMode"
        const val EXTRA_HOTSPOT_BIND_ENABLED = "hotspotBindEnabled"
        const val EXTRA_HTTP_PROXY_AUTH_ENABLED = "httpProxyAuthEnabled"
        const val EXTRA_SNIFFING_ROUTE_ONLY = "sniffingRouteOnly"
        const val EXTRA_POLICY_HANDSHAKE_SEC = "policyHandshakeSec"
        const val EXTRA_POLICY_CONN_IDLE_SEC = "policyConnIdleSec"
        const val EXTRA_POLICY_UPLINK_ONLY_SEC = "policyUplinkOnlySec"
        const val EXTRA_POLICY_DOWNLINK_ONLY_SEC = "policyDownlinkOnlySec"
        const val EXTRA_POLICY_MAX_TCP_CONNS = "policyMaxTcpConns"
        const val EXTRA_POLICY_MAX_UDP_CONNS = "policyMaxUdpConns"

        const val ACTION_UPDATE_SPEED_PREF = "ACTION_UPDATE_SPEED_PREF"
        const val ACTION_UPDATE_KEEP_AWAKE_PREF = "ACTION_UPDATE_KEEP_AWAKE_PREF"
        const val ACTION_UPDATE_KILL_SWITCH_PREF = "ACTION_UPDATE_KILL_SWITCH_PREF"

        private const val FOREGROUND_NOTIFICATION_ID = 1
        // Cap on stale ongoing notifications. Even when the speed line is
        // identical second-to-second (e.g. idle UDP keepalive at 0 B/s),
        // we still re-post once every ~5s so the OS doesn't garbage-collect
        // or age out the foreground notification.
        private const val NOTIF_REFRESH_INTERVAL_MS = 5_000L

        // Pause between teardown of the previous session and openTun() of
        // the next one. The dominant constraint here is libbox: its Go
        // runtime tears down tun-inbound routing state asynchronously from
        // our own service-level cleanup. If the new establish() lands
        // before that finishes, residual routing state on the same UID can
        // silently block egress for the new session — exactly the symptom
        // we saw on rapid main↔global↔main switches in the background.
        // 1.5 s comfortably covers what we observed needing manual ~10 s
        // retries on; raising it further only hurts UX. Stop requests bump
        // tunnelGeneration and break out of this wait early.
        private const val RUNTIME_RESTART_SETTLE_MS = 1_500L

        // Upper bound on how long we wait for libbox's first successful
        // updateDefaultInterface callback before flipping the UI to
        // "connected". libbox's command server returns from
        // startOrReloadService as soon as the TUN inbound is up, but its
        // route engine and platform NetworkCallback take a tick longer to
        // be fully wired against the freshly-established VPN. Without this
        // grace period the user can see "connected" while the first
        // outbound packets are still being dropped, which feels like the
        // pre-fix bug even though it usually resolves itself shortly.
        // In practice tunRuntime.awaitReady fires within ~50–200 ms and
        // we never reach this timeout on a healthy device; the bound exists
        // only as a safety net. Engine-specific because xray TUN doesn't
        // share libbox's wiring.
        private const val LIBBOX_WARMUP_TIMEOUT_MS = 1_000L
        private const val UNDERLYING_NETWORK_REFRESH_INTERVAL_MS = 5_000L
        private const val UNDERLYING_NETWORK_XRAY_RESTART_COOLDOWN_MS = 10_000L
        private const val XRAY_PROCESS_REBIND_SETTLE_MS = 250L

        @Volatile
        private var lastRuntimeCleanupElapsedMillis = 0L
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lifecycleMutex = Mutex()
    private lateinit var xrayRuntime: XrayRuntime
    private lateinit var tunRuntime: LibboxTunRuntime
    private val connectivityManager by lazy {
        getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }
    private var serverConfig: ServerConfig? = null
    private var xrayTunFileDescriptor: ParcelFileDescriptor? = null
    private var xrayTunFailureReason: String? = null
    private val connectedEventEmitted = AtomicBoolean(false)
    private val disconnectedEventEmitted = AtomicBoolean(false)
    @Volatile
    private var tunnelEverStarted = false
    @Volatile
    private var tunnelGeneration = 0
    @Volatile
    private var terminalErrorEmitted = false

    @Volatile
    private var showSpeedInNotification = false

    @Volatile
    private var killSwitchEnabled = false

    @Volatile
    private var killSwitchInterface: android.os.ParcelFileDescriptor? = null

    private var speedPollJob: Job? = null
    private var lastUidRx: Long = -1L
    private var lastUidTx: Long = -1L
    private var lastTrafficAtElapsed: Long = 0L
    private var underlyingNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var lastUnderlyingSelection: UnderlyingNetworkResolver.Selection? = null
    private var lastAppliedXrayUnderlyingNetwork: Network? = null
    private var lastUnderlyingRefreshAtElapsed: Long = 0L
    private var lastNetworkTriggeredXrayRestartAtElapsed: Long = 0L
    private var wakeLock: PowerManager.WakeLock? = null
    private var keepAwake = false

    override fun onCreate() {
        super.onCreate()
        AppLogBridge.install(applicationContext)
        xrayRuntime = XrayRuntime(this, serviceScope)
        tunRuntime = LibboxTunRuntime(
            service = this,
            scope = serviceScope,
            onStopRequested = ::requestRuntimeStopTunnel,
        )
        AppLogger.d(TAG, "Service onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        AppLogger.d(TAG, "onStartCommand action=${intent?.action}")

        if (intent?.action == "ACTION_DISCONNECT") {
            requestStopTunnel()
            return START_NOT_STICKY
        }

        if (intent?.action == ACTION_UPDATE_SPEED_PREF) {
            applySpeedPreferenceChange(
                intent.getBooleanExtra(EXTRA_SHOW_SPEED_IN_NOTIFICATION, false),
            )
            return START_STICKY
        }

        if (intent?.action == ACTION_UPDATE_KEEP_AWAKE_PREF) {
            applyKeepAwakePreferenceChange(
                intent.getBooleanExtra(EXTRA_KEEP_AWAKE, false),
            )
            return START_STICKY
        }

        if (intent?.action == ACTION_UPDATE_KILL_SWITCH_PREF) {
            killSwitchEnabled = intent.getBooleanExtra(EXTRA_KILL_SWITCH_ENABLED, false)
            AppLogger.i(TAG, "Kill switch toggled live: $killSwitchEnabled")
            return START_STICKY
        }

        serverConfig = VpnServiceConfigParser.parse(intent)
        val config = serverConfig
        if (config == null) {
            AppLogger.e(TAG, "No server config received — cannot start")
            terminalErrorEmitted = true
            VpnRuntimeState.markError("No server config provided")
            VpnEventBridge.emit("error", "No server config provided")
            requestControlSurfacesUpdate()
            stopSelf()
            return START_NOT_STICKY
        }

        showSpeedInNotification = intent?.getBooleanExtra(
            EXTRA_SHOW_SPEED_IN_NOTIFICATION,
            false,
        ) ?: false
        killSwitchEnabled = config.killSwitchEnabled

        val generation = nextTunnelGeneration()
        prepareStartState(config)
        setupForeground(config)
        // A fresh tunnel start replaces any block-all interface left behind
        // by the previous session's kill switch — the new VpnService.Builder
        // call inside the runtime supersedes our placeholder PFD.
        closeKillSwitchInterfaceLocked()
        startTunnel(config, generation)
        return START_NOT_STICKY
    }

    /// Installs a VpnService that routes 0.0.0.0/0 + ::/0 into a dead-end
    /// (no outbounds), effectively blocking all internet traffic until
    /// either the user reconnects (a fresh Builder() replaces this PFD)
    /// or explicitly disconnects (ACTION_DISCONNECT closes it).
    private fun installKillSwitchInterfaceLocked(): Boolean {
        if (prepare(this) != null) {
            AppLogger.w(TAG, "Cannot install kill switch: VPN permission missing")
            return false
        }
        return runCatching {
            val builder = Builder()
                .setSession("Void//Lex Kill Switch")
                .setMtu(1500)
                .addAddress("198.18.0.1", 32)
                .addAddress("fdfe:dcba:9876::1", 128)
                .addRoute("0.0.0.0", 0)
                .addRoute("::", 0)
                .setBlocking(true)
            addDisallowedApplicationSafe(builder, packageName)
            SystemCommunicationBypass.addDisallowedApplications(builder)
            val pfd = builder.establish()
                ?: error("kill-switch Builder.establish returned null")
            killSwitchInterface?.runCatching { close() }
            killSwitchInterface = pfd
            AppLogger.i(TAG, "Kill switch interface installed (fd=${pfd.fd})")
            true
        }.onFailure {
            AppLogger.w(TAG, "Failed to install kill switch interface", it)
        }.getOrDefault(false)
    }

    private fun closeKillSwitchInterfaceLocked() {
        killSwitchInterface?.runCatching { close() }
        killSwitchInterface = null
    }

    private fun startTunnel(config: ServerConfig, generation: Int) {
        serviceScope.launch {
            lifecycleMutex.withLock {
                if (!isCurrentGeneration(generation)) {
                    return@withLock
                }

                // Cross-engine cleanup. Each runtime's own start() already
                // tears down its previous instance (xrayRuntime.start waits for
                // the old process to exit, tunRuntime.start closes libbox), so
                // same-engine restarts are handled. The gap is the "other"
                // engine from a previous run:
                //   LIBBOX → XRAY leaves libbox command server + PFD alive
                //            because tunRuntime.start is never called again.
                //   XRAY → LIBBOX leaves xrayTunFileDescriptor open because
                //            openXrayTunLocked (which also closes it) is only
                //            invoked on the XRAY branch.
                // Tearing these down here is safe: on first start both calls
                // are no-ops; on same-engine restart they still are (tunRuntime
                // was never active in XRAY mode, and the PFD is null in LIBBOX
                // mode). We deliberately do NOT touch xrayRuntime here — its
                // own start() does a wait-for-exit stop, and double-stopping
                // here would null its handles and skip that wait, racing the
                // new SOCKS inbound against the old process on port 10808.
                val cleanedRuntime = stopRuntimesLocked(removeForeground = false)
                if (!waitForRuntimeCleanupSettle(generation, cleanedRuntime)) {
                    return@withLock
                }

                val isHysteria2 = XrayConfigBuilder.isHysteria2(config)
                if (isHysteria2 && config.tunEngineMode == TunEngineMode.XRAY) {
                    emitStartupErrorLocked(
                        "Hysteria2 requires the libbox TUN engine; switch the engine in settings.",
                    )
                    return@withLock
                }

                val xrayTunFd = if (config.tunEngineMode == TunEngineMode.XRAY) {
                    openXrayTunLocked(config) ?: run {
                        emitStartupErrorLocked(
                            xrayTunFailureReason ?: "Failed to establish Android TUN for Xray",
                        )
                        return@withLock
                    }
                } else {
                    null
                }

                if (!isHysteria2) {
                    val started = xrayRuntime.start(
                        config = config,
                        mode = when (config.tunEngineMode) {
                            TunEngineMode.LIBBOX -> XrayRuntimeMode.SOCKS
                            TunEngineMode.XRAY -> XrayRuntimeMode.TUN
                        },
                        tunFd = xrayTunFd,
                    )
                    if (!isCurrentGeneration(generation)) {
                        stopRuntimesLocked(removeForeground = false)
                        return@withLock
                    }
                    if (!started) {
                        emitStartupErrorLocked(
                            xrayRuntime.failureReason() ?: "Xray runtime is unavailable",
                        )
                        return@withLock
                    }
                }

                if (config.tunEngineMode == TunEngineMode.LIBBOX) {
                    val tunStarted = tunRuntime.start(
                        isGlobalProxy = config.isGlobalProxy,
                        generation = generation,
                        appRoutingMode = config.appRoutingMode,
                        appRoutingPackages = config.appRoutingPackages,
                        proxyUser = config.proxyUser,
                        proxyPassword = config.proxyPassword,
                        tunnelNetworkSettings = config.tunnelNetworkSettings,
                        proxyServer = if (isHysteria2) config else null,
                    )
                    if (!isCurrentGeneration(generation)) {
                        stopRuntimesLocked(removeForeground = false)
                        return@withLock
                    }
                    if (!tunStarted) {
                        emitStartupErrorLocked(
                            tunRuntime.failureReason() ?: "TUN bridge is unavailable",
                        )
                        return@withLock
                    }
                    val warmupStart = SystemClock.elapsedRealtime()
                    val warmupReady = tunRuntime.awaitReady(LIBBOX_WARMUP_TIMEOUT_MS)
                    val warmupElapsed = SystemClock.elapsedRealtime() - warmupStart
                    AppLogger.i(
                        TAG,
                        "libbox warmup: ready=$warmupReady elapsed=${warmupElapsed}ms",
                    )
                    if (!isCurrentGeneration(generation)) {
                        stopRuntimesLocked(removeForeground = false)
                        return@withLock
                    }
                } else {
                    AppLogger.i(TAG, "Using experimental Xray TUN engine")
                }

                wireSpeedTelemetry()
                startUnderlyingNetworkMonitorLocked(config, generation)
                updateWakeLockLocked(config.keepAwake)

                if (connectedEventEmitted.compareAndSet(false, true)) {
                    VpnRuntimeState.markConnected(config)
                    AppLogger.i(TAG, "VPN confirmed connected by ${config.tunEngineMode.wireName} engine")
                    VpnEventBridge.emit("connected")
                    requestControlSurfacesUpdate()
                }
            }
        }
    }
    private fun requestStopTunnel() {
        AppLogger.i(TAG, "Stop requested")
        nextTunnelGeneration()
        serviceScope.launch {
            lifecycleMutex.withLock {
                stopTunnelLocked(emitDisconnected = true)
            }
        }
    }

    private fun requestRuntimeStopTunnel(runtimeGeneration: Int) {
        serviceScope.launch {
            lifecycleMutex.withLock {
                if (!isCurrentGeneration(runtimeGeneration)) {
                    AppLogger.d(
                        TAG,
                        "Ignoring stale runtime stop for generation=$runtimeGeneration, current=$tunnelGeneration",
                    )
                    return@withLock
                }
                // Loose-mode kill switch: a runtime-initiated stop means the
                // tunnel dropped unexpectedly (network change, libbox/xray
                // exit). Replace the live tun with a block-all placeholder
                // so traffic doesn't leak while we wait for the user to
                // reconnect or explicitly disconnect.
                if (killSwitchEnabled) {
                    AppLogger.w(TAG, "Kill switch engaged after runtime stop")
                    stopRuntimesLocked(removeForeground = false)
                    val installed = installKillSwitchInterfaceLocked()
                    if (installed) {
                        VpnRuntimeState.markError("Tunnel down — internet blocked")
                        VpnEventBridge.emit("error", "Tunnel down — internet blocked")
                        terminalErrorEmitted = true
                        postForegroundNotificationText(
                            "Internet blocked • tap app to reconnect",
                        )
                        return@withLock
                    }
                    // Do not fall through to a normal disconnect — that would
                    // tear down the VPN slot and restore cleartext routing.
                    val failureMessage =
                        "Tunnel down — kill switch could not block traffic"
                    AppLogger.e(TAG, failureMessage)
                    VpnRuntimeState.markError(failureMessage)
                    VpnEventBridge.emit("error", failureMessage)
                    terminalErrorEmitted = true
                    postForegroundNotificationText(
                        "Tunnel down • open app to reconnect safely",
                    )
                    return@withLock
                }
                nextTunnelGeneration()
                stopTunnelLocked(emitDisconnected = true)
            }
        }
    }

    private fun stopTunnelLocked(emitDisconnected: Boolean) {
        val cleanedRuntime = stopRuntimesLocked(removeForeground = true)
        AppLogger.i(TAG, "VPN runtime stopped: cleaned=$cleanedRuntime")
        if (!terminalErrorEmitted) {
            VpnRuntimeState.markDisconnected()
        }
        if (emitDisconnected && !terminalErrorEmitted && disconnectedEventEmitted.compareAndSet(false, true)) {
            VpnEventBridge.emit("disconnected")
        }
        requestControlSurfacesUpdate()
        stopSelf()
    }

    private fun stopRuntimesLocked(removeForeground: Boolean): Boolean {
        clearSpeedTelemetryLocked()
        stopUnderlyingNetworkMonitorLocked()
        releaseWakeLockLocked()
        val stoppedLibbox = tunRuntime.stop()
        val stoppedXray = xrayRuntime.stop(waitForExit = true)
        val closedXrayTun = closeXrayTunLocked()
        if (removeForeground) {
            closeKillSwitchInterfaceLocked()
        }
        val cleanedRuntime = stoppedLibbox || stoppedXray || closedXrayTun
        if (cleanedRuntime) {
            lastRuntimeCleanupElapsedMillis = SystemClock.elapsedRealtime()
        }
        if (!removeForeground) {
            return cleanedRuntime
        }
        removeForegroundNotification()
        return cleanedRuntime
    }

    private suspend fun waitForRuntimeCleanupSettle(
        generation: Int,
        cleanedRuntime: Boolean,
    ): Boolean {
        val now = SystemClock.elapsedRealtime()
        val lastCleanup = lastRuntimeCleanupElapsedMillis
        val waitMs = when {
            cleanedRuntime -> RUNTIME_RESTART_SETTLE_MS
            lastCleanup > 0L -> RUNTIME_RESTART_SETTLE_MS - (now - lastCleanup)
            else -> 0L
        }.coerceAtLeast(0L)
        if (waitMs > 0L) {
            AppLogger.i(TAG, "Waiting ${waitMs}ms for Android VPN cleanup before restart")
            delay(waitMs)
        }
        return isCurrentGeneration(generation)
    }

    private fun startUnderlyingNetworkMonitorLocked(config: ServerConfig, generation: Int) {
        stopUnderlyingNetworkMonitorLocked()
        val initialSelection = findUnderlyingNetworkSelection()
        lastUnderlyingSelection = initialSelection
        refreshXrayUnderlyingNetworkLocked(config, initialSelection, force = true)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                scheduleUnderlyingNetworkEvaluation(generation, "available")
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities,
            ) {
                scheduleUnderlyingNetworkEvaluation(generation, "capabilities")
            }

            override fun onLost(network: Network) {
                scheduleUnderlyingNetworkEvaluation(generation, "lost")
            }
        }
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()

        runCatching {
            connectivityManager.registerNetworkCallback(request, callback)
            underlyingNetworkCallback = callback
            AppLogger.i(
                TAG,
                "Underlying network monitor started: " +
                    selectionLabel(initialSelection),
            )
        }.onFailure {
            AppLogger.w(TAG, "Failed to register underlying network monitor", it)
        }
    }

    private fun stopUnderlyingNetworkMonitorLocked() {
        val callback = underlyingNetworkCallback
        underlyingNetworkCallback = null
        if (callback != null) {
            runCatching {
                connectivityManager.unregisterNetworkCallback(callback)
            }.onFailure {
                AppLogger.w(TAG, "Failed to unregister underlying network monitor", it)
            }
        }
        lastUnderlyingSelection = null
        lastAppliedXrayUnderlyingNetwork = null
        lastUnderlyingRefreshAtElapsed = 0L
        lastNetworkTriggeredXrayRestartAtElapsed = 0L
    }

    private fun scheduleUnderlyingNetworkEvaluation(generation: Int, reason: String) {
        serviceScope.launch {
            lifecycleMutex.withLock {
                if (!isCurrentGeneration(generation)) return@withLock
                handleUnderlyingNetworkChangedLocked(generation, reason)
            }
        }
    }

    private suspend fun handleUnderlyingNetworkChangedLocked(
        generation: Int,
        reason: String,
    ) {
        val config = serverConfig ?: return
        if (!connectedEventEmitted.get()) return
        val previous = lastUnderlyingSelection
        val current = findUnderlyingNetworkSelection()

        if (current == null) {
            if (previous != null) {
                AppLogger.w(TAG, "Underlying network lost after $reason")
            }
            lastUnderlyingSelection = null
            refreshXrayUnderlyingNetworkLocked(config, null, force = false)
            return
        }

        val networkChanged = previous?.network != current.network
        val transportChanged = previous != null && previous.transport != current.transport
        if (networkChanged || transportChanged) {
            AppLogger.i(
                TAG,
                "Underlying network changed after $reason: " +
                    "${selectionLabel(previous)} -> ${selectionLabel(current)}",
            )
        }
        lastUnderlyingSelection = current
        refreshXrayUnderlyingNetworkLocked(config, current, force = networkChanged)

        if (transportChanged) {
            restartXrayForTransportChangeLocked(
                config = config,
                generation = generation,
                previous = previous,
                current = current,
            )
        }
    }

    private suspend fun restartXrayForTransportChangeLocked(
        config: ServerConfig,
        generation: Int,
        previous: UnderlyingNetworkResolver.Selection?,
        current: UnderlyingNetworkResolver.Selection,
    ) {
        if (config.tunEngineMode != TunEngineMode.LIBBOX) return
        if (XrayConfigBuilder.isHysteria2(config)) return

        val now = SystemClock.elapsedRealtime()
        val sinceLastRestart = now - lastNetworkTriggeredXrayRestartAtElapsed
        if (
            lastNetworkTriggeredXrayRestartAtElapsed > 0L &&
            sinceLastRestart < UNDERLYING_NETWORK_XRAY_RESTART_COOLDOWN_MS
        ) {
            AppLogger.i(
                TAG,
                "Skipping Xray network-change restart: cooldown ${sinceLastRestart}ms, " +
                    "${selectionLabel(previous)} -> ${selectionLabel(current)}",
            )
            return
        }
        lastNetworkTriggeredXrayRestartAtElapsed = now

        AppLogger.i(
            TAG,
            "Restarting Xray SOCKS runtime after underlying transport change: " +
                "${selectionLabel(previous)} -> ${selectionLabel(current)}",
        )
        val stopped = xrayRuntime.stop(waitForExit = true)
        if (stopped) {
            delay(XRAY_PROCESS_REBIND_SETTLE_MS)
        }
        if (!isCurrentGeneration(generation)) return

        val started = xrayRuntime.start(
            config = config,
            mode = XrayRuntimeMode.SOCKS,
        )
        if (!isCurrentGeneration(generation)) {
            xrayRuntime.stop(waitForExit = true)
            return
        }
        if (!started) {
            emitStartupErrorLocked(
                xrayRuntime.failureReason()
                    ?: "Xray runtime failed after network change",
            )
        }
    }

    private fun refreshXrayUnderlyingNetworkLocked(
        config: ServerConfig,
        selection: UnderlyingNetworkResolver.Selection?,
        force: Boolean,
    ) {
        if (config.tunEngineMode != TunEngineMode.XRAY) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val now = SystemClock.elapsedRealtime()
        val selectedNetwork = selection?.network
        val sameNetwork = selectedNetwork == lastAppliedXrayUnderlyingNetwork
        if (
            !force &&
            sameNetwork &&
            now - lastUnderlyingRefreshAtElapsed < UNDERLYING_NETWORK_REFRESH_INTERVAL_MS
        ) {
            return
        }

        runCatching {
            if (selectedNetwork == null) {
                setUnderlyingNetworks(null)
            } else {
                setUnderlyingNetworks(arrayOf(selectedNetwork))
            }
            lastAppliedXrayUnderlyingNetwork = selectedNetwork
            lastUnderlyingRefreshAtElapsed = now
        }.onFailure {
            AppLogger.w(TAG, "Failed to refresh Xray underlying network", it)
        }
    }

    private fun openXrayTunLocked(config: ServerConfig): Int? {
        closeXrayTunLocked()
        xrayTunFailureReason = null
        val networkSettings = config.tunnelNetworkSettings.normalized()

        if (prepare(this) != null) {
            xrayTunFailureReason = "Missing VPN permission"
            return null
        }

        return runCatching {
            val builder = Builder()
                .setSession("Void//Lex Xray")
                .setMtu(networkSettings.mtu)

            val (ipv4Dns, ipv6Dns) = resolveXrayTunDnsServers(networkSettings)
            if (networkSettings.ipMode.usesIpv4) {
                builder
                    .addAddress(TunAddressDefaults.IPV4_ADDRESS, TunAddressDefaults.IPV4_PREFIX)
                    .addDnsServer(ipv4Dns)
                    .addRoute("0.0.0.0", 0)
            }
            if (networkSettings.ipMode.usesIpv6) {
                builder
                    .addAddress(TunAddressDefaults.IPV6_ADDRESS, TunAddressDefaults.IPV6_PREFIX)
                    .addDnsServer(ipv6Dns)
                    .addRoute("::", 0)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                findUnderlyingNetwork()?.let { builder.setUnderlyingNetworks(arrayOf(it)) }
            }

            applyAppRoutingToBuilder(
                builder = builder,
                mode = if (config.isGlobalProxy) AppRoutingMode.OFF else config.appRoutingMode,
                packages = if (config.isGlobalProxy) emptyList() else config.appRoutingPackages,
            )

            val pfd = builder.establish() ?: error("VpnService.Builder.establish returned null")
            clearCloseOnExec(pfd)
            xrayTunFileDescriptor = pfd
            AppLogger.i(TAG, "Xray TUN established: fd=${pfd.fd}")
            pfd.fd
        }.onFailure {
            xrayTunFailureReason = it.message ?: "Failed to establish Android TUN for Xray"
            AppLogger.e(TAG, "Failed to establish Android TUN for Xray", it)
            closeXrayTunLocked()
        }.getOrNull()
    }

    /// Picks the DNS servers to install on the Xray TUN interface. When the
    /// user has supplied a custom DNS in settings we substitute it for the
    /// matching IP family and keep the built-in fallback for the other one;
    /// this lets a user override IPv4 DNS without breaking IPv6 dual-stack.
    private fun resolveXrayTunDnsServers(settings: TunnelNetworkSettings): Pair<String, String> {
        if (!settings.hasCustomXrayTunDns) {
            return XRAY_TUN_DNS to XRAY_TUN_IPV6_DNS
        }
        val custom = settings.xrayTunDnsServer.trim()
        val isIpv6 = custom.contains(':')
        return if (isIpv6) {
            XRAY_TUN_DNS to custom
        } else {
            custom to XRAY_TUN_IPV6_DNS
        }
    }

    private fun applyAppRoutingToBuilder(
        builder: Builder,
        mode: AppRoutingMode,
        packages: List<String>,
    ) {
        val sanitized = packages
            .filter {
                it.isNotBlank() &&
                    it != packageName &&
                    !SystemCommunicationBypass.isProtectedPackage(it)
            }
            .distinct()

        when (mode) {
            AppRoutingMode.PROXY_SELECTED -> {
                if (sanitized.isEmpty()) {
                    // No apps explicitly selected — fall back to "exclude self" so
                    // the tunnel still functions instead of silently routing nothing.
                    addDisallowedApplicationSafe(builder, packageName)
                    SystemCommunicationBypass.addDisallowedApplications(builder)
                    return
                }
                sanitized.forEach { addAllowedApplicationSafe(builder, it) }
            }
            AppRoutingMode.BYPASS_SELECTED -> {
                addDisallowedApplicationSafe(builder, packageName)
                SystemCommunicationBypass.addDisallowedApplications(builder)
                sanitized.forEach { addDisallowedApplicationSafe(builder, it) }
            }
            AppRoutingMode.OFF -> {
                addDisallowedApplicationSafe(builder, packageName)
                SystemCommunicationBypass.addDisallowedApplications(builder)
            }
        }
    }

    private fun addAllowedApplicationSafe(builder: Builder, pkg: String) {
        runCatching { builder.addAllowedApplication(pkg) }.onFailure {
            AppLogger.w(TAG, "addAllowedApplication failed for $pkg", it)
        }
    }

    private fun addDisallowedApplicationSafe(builder: Builder, pkg: String) {
        runCatching { builder.addDisallowedApplication(pkg) }.onFailure {
            AppLogger.w(TAG, "addDisallowedApplication failed for $pkg", it)
        }
    }

    private fun closeXrayTunLocked(): Boolean {
        val pfd = xrayTunFileDescriptor
        val hadTun = pfd != null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            runCatching {
                setUnderlyingNetworks(null)
            }.onFailure {
                AppLogger.w(TAG, "Failed to clear Xray underlying networks", it)
            }
        }
        runCatching {
            pfd?.close()
        }.onFailure {
            AppLogger.e(TAG, "Error closing Xray TUN file descriptor", it)
        }
        xrayTunFileDescriptor = null
        return hadTun
    }

    private fun clearCloseOnExec(pfd: ParcelFileDescriptor) {
        runCatching {
            val flags = Os.fcntlInt(pfd.fileDescriptor, OsConstants.F_GETFD, 0)
            Os.fcntlInt(
                pfd.fileDescriptor,
                OsConstants.F_SETFD,
                flags and OsConstants.FD_CLOEXEC.inv(),
            )
        }.onFailure {
            AppLogger.w(TAG, "Failed to clear close-on-exec on Xray TUN fd", it)
        }
    }

    private fun findUnderlyingNetwork(): Network? =
        findUnderlyingNetworkSelection()?.network

    private fun findUnderlyingNetworkSelection(): UnderlyingNetworkResolver.Selection? =
        UnderlyingNetworkResolver.findSelection(connectivityManager)

    private fun selectionLabel(selection: UnderlyingNetworkResolver.Selection?): String {
        if (selection == null) return "none"
        return "${selection.transport.name.lowercase(Locale.US)}:${selection.network}"
    }

    private fun updateWakeLockLocked(enabled: Boolean) {
        keepAwake = enabled
        if (!enabled) {
            releaseWakeLockLocked()
            return
        }
        if (wakeLock?.isHeld == true) return
        runCatching {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val lock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$packageName:vpn",
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
            wakeLock = lock
            AppLogger.i(TAG, "VPN wake lock acquired")
        }.onFailure {
            wakeLock = null
            AppLogger.w(TAG, "Failed to acquire VPN wake lock", it)
        }
    }

    private fun releaseWakeLockLocked() {
        val lock = wakeLock
        wakeLock = null
        runCatching {
            if (lock?.isHeld == true) {
                lock.release()
                AppLogger.i(TAG, "VPN wake lock released")
            }
        }.onFailure {
            AppLogger.w(TAG, "Failed to release VPN wake lock", it)
        }
        keepAwake = false
    }

    private fun removeForegroundNotification() {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        }.onFailure {
            AppLogger.w(TAG, "Failed to stop foreground notification", it)
        }
    }

    override fun onRevoke() {
        requestStopTunnel()
    }

    override fun onDestroy() {
        runCatching {
            clearSpeedTelemetryLocked()
            stopUnderlyingNetworkMonitorLocked()
            releaseWakeLockLocked()
            tunRuntime.stop()
            xrayRuntime.stop(waitForExit = true)
            closeXrayTunLocked()
            closeKillSwitchInterfaceLocked()
        }.onFailure {
            AppLogger.w(TAG, "Runtime cleanup failed during service destroy", it)
        }
        if (
            tunnelEverStarted &&
            !terminalErrorEmitted &&
            disconnectedEventEmitted.compareAndSet(false, true)
        ) {
            VpnRuntimeState.markDisconnected()
            VpnEventBridge.emit("disconnected")
            requestControlSurfacesUpdate()
        }
        super.onDestroy()
        serviceScope.cancel()
    }

    private fun nextTunnelGeneration(): Int = synchronized(this) {
        tunnelGeneration += 1
        tunnelGeneration
    }

    private fun isCurrentGeneration(generation: Int): Boolean = tunnelGeneration == generation

    private fun prepareStartState(config: ServerConfig) {
        connectedEventEmitted.set(false)
        disconnectedEventEmitted.set(false)
        terminalErrorEmitted = false
        tunnelEverStarted = true
        VpnRuntimeState.markConnecting(config)
        VpnEventBridge.emit("connecting")
        requestControlSurfacesUpdate()
    }

    private fun emitStartupErrorLocked(message: String) {
        terminalErrorEmitted = true
        VpnRuntimeState.markError(message)
        VpnEventBridge.emit("error", message)
        requestControlSurfacesUpdate()
        stopTunnelLocked(emitDisconnected = false)
    }

    private fun setupForeground(config: ServerConfig) {
        ensureNotificationChannel()
        val notification = buildForegroundNotification(staticContentText(config))
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                FOREGROUND_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(FOREGROUND_NOTIFICATION_ID, notification)
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "void_lex_channel"
            val channel = NotificationChannel(
                channelId,
                "Void//Lex",
                NotificationManager.IMPORTANCE_LOW,
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun staticContentText(config: ServerConfig) =
        "Connection active \u2022 ${config.server}"

    // The notification large icon is decoded from R.mipmap.ic_launcher once
    // per service lifecycle. Previously every call to
    // postForegroundNotificationText() re-decoded it from the APK, which
    // fired once per second under speedPollJob — each call goes through the
    // resource manager, opens the PNG stream, and allocates a fresh
    // ARGB_8888 bitmap of the mipmap's native size.
    private val cachedLargeIcon: android.graphics.Bitmap? by lazy {
        runCatching {
            BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        }.getOrNull()
    }

    private fun buildForegroundNotification(contentText: String): Notification {
        ensureNotificationChannel()
        val channelId = "void_lex_channel"
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        cachedLargeIcon?.let { builder.setLargeIcon(it) }

        return builder
            .setContentTitle("Void//Lex")
            .setContentText(contentText)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ContextCompat.getColor(this, R.color.brand_blue))
            .setOngoing(true)
            .build()
    }

    private fun postForegroundNotificationText(text: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(FOREGROUND_NOTIFICATION_ID, buildForegroundNotification(text))
    }

    private fun clearSpeedTelemetryLocked() {
        speedPollJob?.cancel()
        speedPollJob = null
        lastUidRx = -1L
        lastUidTx = -1L
        lastTrafficAtElapsed = 0L
        VpnSpeedBridge.reset()
    }

    /**
     * Polls per-UID byte counters once per second. Always streams the
     * instantaneous up/down rate to [VpnSpeedBridge] (consumed by the TV
     * throughput widget on the Flutter side). When the user has enabled
     * the in-notification speed readout, also republishes the foreground
     * notification text with the same numbers.
     *
     * `TrafficStats.getUid{Rx,Tx}Bytes(myUid)` reports our process group's
     * underlying network usage — i.e. the encrypted tunnel traffic that
     * Xray pushes to the remote server, regardless of whether the local
     * TUN bridge is run by libbox or Xray's own TUN inbound. That value
     * is what the user expects as "connection speed".
     */
    private fun wireSpeedTelemetry() {
        speedPollJob?.cancel()
        lastUidRx = -1L
        lastUidTx = -1L
        lastTrafficAtElapsed = 0L
        var lastPostedText: String? = null
        var lastPostedAt: Long = 0L
        speedPollJob = serviceScope.launch {
            while (isActive) {
                val sample = sampleUidTraffic()
                if (sample != null) {
                    VpnSpeedBridge.emit(sample.downBps, sample.upBps)
                    if (showSpeedInNotification) {
                        val srv = serverConfig?.server
                        if (srv != null) {
                            val text = "$srv \u2022 ${formatTrafficLine(sample)}"
                            val now = SystemClock.elapsedRealtime()
                            // Skip the NotificationManager.notify Binder hop
                            // when the rendered line hasn't actually changed,
                            // but still refresh once every
                            // NOTIF_REFRESH_INTERVAL_MS so the notification
                            // doesn't go stale on long-idle sessions (some
                            // OEM launchers age out unchanged ongoing
                            // notifications).
                            val shouldPost = text != lastPostedText ||
                                (now - lastPostedAt) >= NOTIF_REFRESH_INTERVAL_MS
                            if (shouldPost) {
                                lastPostedText = text
                                lastPostedAt = now
                                mainHandler.post {
                                    if (!showSpeedInNotification) return@post
                                    postForegroundNotificationText(text)
                                }
                            }
                        }
                    }
                }
                delay(1_000)
            }
        }
    }

    private data class UidTrafficSample(val downBps: Double, val upBps: Double)

    private fun sampleUidTraffic(): UidTrafficSample? {
        val uid = Process.myUid()
        val rx = TrafficStats.getUidRxBytes(uid)
        val tx = TrafficStats.getUidTxBytes(uid)
        val unsupported = TrafficStats.UNSUPPORTED.toLong()
        if (rx == unsupported || tx == unsupported) {
            return null
        }
        val now = SystemClock.elapsedRealtime()
        if (lastUidRx < 0L) {
            lastUidRx = rx
            lastUidTx = tx
            lastTrafficAtElapsed = now
            return UidTrafficSample(downBps = 0.0, upBps = 0.0)
        }
        val dtSec = (now - lastTrafficAtElapsed) / 1000.0
        if (dtSec <= 0) {
            return null
        }
        val drx = (rx - lastUidRx).coerceAtLeast(0)
        val dtx = (tx - lastUidTx).coerceAtLeast(0)
        lastUidRx = rx
        lastUidTx = tx
        lastTrafficAtElapsed = now
        return UidTrafficSample(downBps = drx / dtSec, upBps = dtx / dtSec)
    }

    private fun formatTrafficLine(sample: UidTrafficSample): String {
        return "\u2191 ${formatBps(sample.upBps)} \u2193 ${formatBps(sample.downBps)}"
    }

    private fun formatBps(bps: Double): String {
        if (bps < 1000.0) {
            return "${bps.toInt()} B/s"
        }
        val kb = bps / 1000.0
        if (kb < 1000.0) {
            // Pin to Locale.US so the rendered notification reads "1.5 KB/s"
            // on a German/Russian ROM instead of "1,5 KB/s", which would
            // also break any downstream parser that expects ASCII numerics.
            return String.format(Locale.US, "%.1f KB/s", kb)
        }
        val mb = kb / 1000.0
        return String.format(Locale.US, "%.2f MB/s", mb)
    }

    private fun applySpeedPreferenceChange(enabled: Boolean) {
        showSpeedInNotification = enabled
        val cfg = serverConfig ?: return
        serviceScope.launch {
            lifecycleMutex.withLock {
                // Speed polling must keep running regardless of the
                // notification preference — the TV throughput widget
                // depends on the same stream. We restart the poll loop so
                // the per-second cadence picks up the new pref on the
                // next tick, and reset the foreground notification text
                // to the static line when the user turned the toggle off
                // (otherwise it would still display the last live rate).
                clearSpeedTelemetryLocked()
                if (!showSpeedInNotification) {
                    postForegroundNotificationText(staticContentText(cfg))
                }
                wireSpeedTelemetry()
            }
        }
    }

    private fun applyKeepAwakePreferenceChange(enabled: Boolean) {
        serviceScope.launch {
            lifecycleMutex.withLock {
                keepAwake = enabled
                serverConfig = serverConfig?.copy(keepAwake = enabled)
                if (connectedEventEmitted.get()) {
                    updateWakeLockLocked(enabled)
                }
            }
        }
    }

    private fun requestControlSurfacesUpdate() {
        QuickSettingsTileUpdater.requestUpdate(applicationContext)
        VoidLexWidgetUpdater.requestUpdate(applicationContext)
    }

}
