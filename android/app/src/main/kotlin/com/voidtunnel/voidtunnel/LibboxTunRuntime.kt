package com.voidtunnel.voidtunnel

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.IpPrefix
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.Process
import android.system.OsConstants
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.SetupOptions
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.security.KeyStore
import java.util.Base64

internal class LibboxTunRuntime(
    private val service: VpnService,
    private val scope: CoroutineScope,
    private val onStopRequested: (Int) -> Unit,
) : PlatformInterface {
    companion object {
        private const val TAG = "LibboxTunRuntime"
        private const val VPN_PERMISSION_WAIT_MS = 1_500L
    }

    private var fileDescriptor: ParcelFileDescriptor? = null
    private var commandServer: CommandServer? = null
    private val connectivityManager by lazy {
        service.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }
    private val wifiManager by lazy {
        service.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    }
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
    private val defaultNetworkRequest by lazy {
        NetworkRequest.Builder().apply {
            addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.M) {
                removeCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                removeCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)
            }
        }.build()
    }

    @Volatile
    private var underlyingNetwork: Network? = null
    @Volatile
    private var lastFailureReason: String? = null
    @Volatile
    private var activeGeneration = 0
    private var interfaceUpdateListener: InterfaceUpdateListener? = null
    private var interfaceUpdateJob: Job? = null
    private var defaultNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var lastDefaultInterfaceLog: String? = null

    // Fires when libbox has received its first successful default-interface
    // update (interfaceIndex >= 0 and the call into libbox didn't throw).
    // That's the moment libbox's route engine actually knows which underlying
    // interface to use for outbound traffic, i.e. when packets start flowing
    // instead of being dropped. See awaitReady() and VoidVpnService.
    @Volatile
    private var readySignal: CompletableDeferred<Unit>? = null

    private val commandHandler = object : CommandServerHandler {
        override fun writeDebugMessage(message: String?) {
            AppLogger.d(TAG, message ?: "")
        }

        override fun serviceReload() {
            AppLogger.i(TAG, "libbox requested service reload")
        }

        override fun serviceStop() {
            val generation = activeGeneration
            if (generation == 0) {
                AppLogger.d(TAG, "Ignoring libbox service stop outside an active generation")
                return
            }
            AppLogger.i(TAG, "libbox requested service stop for generation=$generation")
            onStopRequested(generation)
        }

        override fun getSystemProxyStatus(): SystemProxyStatus = SystemProxyStatus()

        override fun setSystemProxyEnabled(enabled: Boolean) {
            AppLogger.i(TAG, "Ignoring system proxy toggle request: $enabled")
        }

        override fun triggerNativeCrash() {
            AppLogger.w(TAG, "Ignoring libbox native crash request")
        }
    }

    private val localResolver = LibboxLocalDnsTransport(::requireUnderlyingNetwork)

    fun failureReason(): String? = lastFailureReason

    // Suspends until libbox has been told the underlying interface (i.e.
    // packets can actually flow), or [timeoutMs] elapses. Returns true on
    // signal, false on timeout or if the signal was cancelled by stop().
    // Parent-coroutine cancellation propagates normally. Used in place of
    // a blind sleep after tunRuntime.start so we flip the UI to "connected"
    // only once traffic will really go through.
    suspend fun awaitReady(timeoutMs: Long): Boolean {
        val signal = readySignal ?: return false
        return withTimeoutOrNull(timeoutMs) {
            try {
                signal.await()
                true
            } catch (e: kotlinx.coroutines.CancellationException) {
                if (signal.isCancelled) false else throw e
            }
        } ?: false
    }

    fun start(
        isGlobalProxy: Boolean,
        generation: Int,
        appRoutingMode: AppRoutingMode = AppRoutingMode.OFF,
        appRoutingPackages: List<String> = emptyList(),
        proxyUser: String = "",
        proxyPassword: String = "",
        tunnelNetworkSettings: TunnelNetworkSettings = TunnelNetworkSettings(),
        proxyServer: ServerConfig? = null,
    ): Boolean {
        stop()
        activeGeneration = generation
        readySignal = CompletableDeferred()

        return runCatching {
            val options = SetupOptions()
            options.basePath = service.filesDir.absolutePath
            options.workingPath = service.filesDir.absolutePath
            options.tempPath = service.filesDir.absolutePath
            Libbox.setup(options)
            refreshUnderlyingNetwork()

            val server = Libbox.newCommandServer(commandHandler, this).also {
                it.start()
                commandServer = it
                AppLogger.i(TAG, "libbox TUN command server started")
            }

            val configJson = TunToSocksConfigBuilder.build(
                isGlobalProxy = isGlobalProxy,
                proxyUser = proxyUser,
                proxyPassword = proxyPassword,
                tunnelNetworkSettings = tunnelNetworkSettings,
                proxyServer = proxyServer,
            )
            val overrideOptions = buildOverrideOptions(
                isGlobalProxy = isGlobalProxy,
                appRoutingMode = appRoutingMode,
                appRoutingPackages = appRoutingPackages,
            )
            server.startOrReloadService(configJson, overrideOptions)
            lastFailureReason = null
            AppLogger.i(TAG, "TUN-to-Xray SOCKS bridge started")
            true
        }.onFailure {
            lastFailureReason = it.message ?: "TUN bridge failed to start"
            AppLogger.e(TAG, "Failed to start TUN-to-Xray SOCKS bridge", it)
            stop()
        }.getOrDefault(false)
    }

    fun stop(): Boolean {
        val server = commandServer
        val pfd = fileDescriptor
        val hadRuntime = server != null || pfd != null || defaultNetworkCallback != null

        activeGeneration = 0
        readySignal?.cancel()
        readySignal = null
        closeDefaultInterfaceMonitor(null)
        commandServer = null
        fileDescriptor = null

        runCatching {
            server?.closeService()
            server?.close()
        }.onFailure {
            AppLogger.e(TAG, "Error closing libbox TUN command server", it)
        }

        runCatching {
            pfd?.close()
        }.onFailure {
            AppLogger.e(TAG, "Error closing TUN file descriptor", it)
        }

        return hadRuntime
    }

    override fun openTun(options: TunOptions): Int {
        val granted = runBlocking {
            withTimeoutOrNull(VPN_PERMISSION_WAIT_MS) {
                while (VpnService.prepare(service) != null) {
                    AppLogger.w(TAG, "openTun waiting for VPN permission")
                    delay(50)
                }
                true
            } ?: false
        }
        if (!granted) {
            lastFailureReason = "Missing VPN permission"
            error("android: missing vpn permission")
        }

        val effectiveMtu = options.mtu.coerceIn(
            TunnelNetworkSettings.MIN_MTU,
            TunnelNetworkSettings.MAX_MTU,
        )
        AppLogger.i(
            TAG,
            "openTun called: mtu=${options.mtu}, effectiveMtu=$effectiveMtu, autoRoute=${options.autoRoute}",
        )

        val builder = service.Builder()
            .setSession("VoidTunnel")
            .setMtu(effectiveMtu)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requireUnderlyingNetwork()?.let { builder.setUnderlyingNetworks(arrayOf(it)) }
        }

        val inet4Address = options.inet4Address
        while (inet4Address.hasNext()) {
            val addr = inet4Address.next()
            builder.addAddress(addr.address(), addr.prefix())
        }

        val inet6Address = options.inet6Address
        while (inet6Address.hasNext()) {
            val addr = inet6Address.next()
            builder.addAddress(addr.address(), addr.prefix())
        }

        if (options.autoRoute) {
            val dnsServerAddresses = runCatching {
                readStrings(options.dnsServerAddress)
            }.onFailure {
                AppLogger.w(TAG, "Failed to read libbox DNS server addresses", it)
            }.getOrDefault(emptyList())
            dnsServerAddresses
                .filter { it.isNotBlank() }
                .forEach { dnsServerAddress ->
                    runCatching { builder.addDnsServer(dnsServerAddress) }.onFailure {
                        AppLogger.w(TAG, "addDnsServer failed for $dnsServerAddress", it)
                    }
                }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val inet4RouteAddress = options.inet4RouteAddress
                if (inet4RouteAddress.hasNext()) {
                    while (inet4RouteAddress.hasNext()) {
                        val route = inet4RouteAddress.next()
                        builder.addRoute(IpPrefix(InetAddress.getByName(route.address()), route.prefix()))
                    }
                } else {
                    builder.addRoute("0.0.0.0", 0)
                }

                val inet6RouteAddress = options.inet6RouteAddress
                if (inet6RouteAddress.hasNext()) {
                    while (inet6RouteAddress.hasNext()) {
                        val route = inet6RouteAddress.next()
                        builder.addRoute(IpPrefix(InetAddress.getByName(route.address()), route.prefix()))
                    }
                } else if (options.inet6Address.hasNext()) {
                    builder.addRoute("::", 0)
                }

                val inet4RouteExcludeAddress = options.inet4RouteExcludeAddress
                while (inet4RouteExcludeAddress.hasNext()) {
                    val route = inet4RouteExcludeAddress.next()
                    builder.excludeRoute(IpPrefix(InetAddress.getByName(route.address()), route.prefix()))
                }

                val inet6RouteExcludeAddress = options.inet6RouteExcludeAddress
                while (inet6RouteExcludeAddress.hasNext()) {
                    val route = inet6RouteExcludeAddress.next()
                    builder.excludeRoute(IpPrefix(InetAddress.getByName(route.address()), route.prefix()))
                }
            } else {
                val inet4RouteRange = options.inet4RouteRange
                if (inet4RouteRange.hasNext()) {
                    while (inet4RouteRange.hasNext()) {
                        val route = inet4RouteRange.next()
                        builder.addRoute(route.address(), route.prefix())
                    }
                } else {
                    builder.addRoute("0.0.0.0", 0)
                }

                val inet6RouteRange = options.inet6RouteRange
                if (inet6RouteRange.hasNext()) {
                    while (inet6RouteRange.hasNext()) {
                        val route = inet6RouteRange.next()
                        builder.addRoute(route.address(), route.prefix())
                    }
                }
            }

            val includePackages = readStrings(options.includePackage)
                .filterNot(SystemCommunicationBypass::isProtectedPackage)
            val rawExcludePackages = readStrings(options.excludePackage)
            if (includePackages.isNotEmpty()) {
                AppLogger.i(
                    TAG,
                    "openTun package routing: mode=allow, include=${includePackages.size}",
                )
                includePackages.forEach { packageName ->
                    runCatching { builder.addAllowedApplication(packageName) }.onFailure {
                        AppLogger.e(TAG, "addAllowedApplication failed for $packageName", it)
                    }
                }
            } else {
                val excludePackages = linkedSetOf<String>().apply {
                    add(service.packageName)
                    addAll(SystemCommunicationBypass.packageNames)
                    addAll(rawExcludePackages)
                }
                AppLogger.i(
                    TAG,
                    "openTun package routing: mode=disallow, excludeRaw=${rawExcludePackages.size}, excludeApplied=${excludePackages.size}",
                )
                excludePackages.forEach { packageName ->
                    try {
                        builder.addDisallowedApplication(packageName)
                    } catch (_: PackageManager.NameNotFoundException) {
                    } catch (error: Exception) {
                        AppLogger.e(TAG, "addDisallowedApplication failed for $packageName", error)
                    }
                }
            }
        }

        val pfd = builder.establish() ?: error("Failed to establish TUN")
        val previousPfd = fileDescriptor
        fileDescriptor = pfd
        if (previousPfd != null && previousPfd.fd != pfd.fd) {
            runCatching { previousPfd.close() }.onFailure {
                AppLogger.w(TAG, "Failed to close previous TUN fd during reload", it)
            }
        }
        AppLogger.i(TAG, "TUN established: fd=${pfd.fd}")
        return pfd.fd
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        service.protect(fd)
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    override fun findConnectionOwner(
        p1: Int,
        p2: String?,
        p3: Int,
        p4: String?,
        p5: Int,
    ): ConnectionOwner {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || p2 == null || p4 == null) {
            return ConnectionOwner()
        }

        return try {
            val uid = connectivityManager.getConnectionOwnerUid(
                p1,
                InetSocketAddress(p2, p3),
                InetSocketAddress(p4, p5),
            )
            if (uid == Process.INVALID_UID) {
                return ConnectionOwner()
            }

            ConnectionOwner().apply {
                userId = uid
                userName = service.packageManager.getPackagesForUid(uid)?.firstOrNull() ?: ""
                setAndroidPackageNames(
                    StringArray((service.packageManager.getPackagesForUid(uid)?.toList() ?: emptyList()).iterator()),
                )
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "getConnectionOwnerUid failed", e)
            ConnectionOwner()
        }
    }

    override fun startDefaultInterfaceMonitor(p1: InterfaceUpdateListener?) {
        interfaceUpdateListener = p1
        if (defaultNetworkCallback == null) {
            defaultNetworkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    handleObservedNetwork(network)
                }

                override fun onLost(network: Network) {
                    if (underlyingNetwork == network) {
                        refreshUnderlyingNetwork(excludedNetwork = network)
                    }
                    if (underlyingNetwork == null) {
                        pushDefaultInterfaceUpdate(null)
                    }
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities,
                ) {
                    if (networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                        if (underlyingNetwork == network) {
                            refreshUnderlyingNetwork(excludedNetwork = network)
                            pushDefaultInterfaceUpdate(underlyingNetwork)
                        }
                        return
                    }

                    if (networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                        handleObservedNetwork(network)
                    }
                }

                override fun onLinkPropertiesChanged(
                    network: Network,
                    linkProperties: android.net.LinkProperties,
                ) {
                    handleObservedNetwork(network)
                }
            }
            runCatching {
                registerDefaultNetworkCallbackCompat(defaultNetworkCallback!!)
            }.onFailure {
                AppLogger.e(TAG, "register default network monitor failed", it)
            }
        }
        refreshUnderlyingNetwork()
        AppLogger.i(TAG, "Default network monitor started, underlying=${describeNetwork(underlyingNetwork)}")
        pushDefaultInterfaceUpdate(underlyingNetwork)
    }

    override fun closeDefaultInterfaceMonitor(p1: InterfaceUpdateListener?) {
        if (p1 != null && interfaceUpdateListener !== p1) {
            AppLogger.d(TAG, "Ignoring stale default network monitor close")
            return
        }
        interfaceUpdateListener = null
        interfaceUpdateJob?.cancel()
        interfaceUpdateJob = null
        underlyingNetwork = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            runCatching {
                service.setUnderlyingNetworks(null)
            }.onFailure {
                AppLogger.w(TAG, "Failed to clear underlying networks", it)
            }
        }
        val callback = defaultNetworkCallback ?: return
        defaultNetworkCallback = null
        runCatching {
            connectivityManager.unregisterNetworkCallback(callback)
        }.onFailure {
            AppLogger.e(TAG, "unregisterNetworkCallback failed", it)
        }
    }

    override fun startNeighborMonitor(p1: NeighborUpdateListener?) {
        AppLogger.d(TAG, "Ignoring libbox neighbor monitor start on Android")
    }

    override fun closeNeighborMonitor(p1: NeighborUpdateListener?) {
        AppLogger.d(TAG, "Ignoring libbox neighbor monitor close on Android")
    }

    override fun registerMyInterface(name: String?) {
        AppLogger.d(TAG, "libbox registered own interface: ${name.orEmpty()}")
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val interfaces = mutableListOf<io.nekohasekai.libbox.NetworkInterface>()
        val allNetworks = connectivityManager.allNetworks
        val javaInterfaces = NetworkInterface.getNetworkInterfaces()?.toList().orEmpty()

        for (network in allNetworks) {
            val networkCapabilities = connectivityManager.getNetworkCapabilities(network) ?: continue
            if (networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                continue
            }
            val linkProperties = connectivityManager.getLinkProperties(network) ?: continue
            val javaInterface = javaInterfaces.find { it.name == linkProperties.interfaceName } ?: continue
            val addresses = linkProperties.linkAddresses.map { it.toPrefix() }
            if (addresses.isEmpty()) {
                continue
            }

            val boxInterface = io.nekohasekai.libbox.NetworkInterface().apply {
                name = linkProperties.interfaceName
                index = javaInterface.index
                type = when {
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> {
                        Libbox.InterfaceTypeCellular
                    }
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> {
                        Libbox.InterfaceTypeEthernet
                    }
                    else -> Libbox.InterfaceTypeOther
                }
                metered = !networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
                setDNSServer(StringArray(linkProperties.dnsServers.mapNotNull { it.hostAddress }.iterator()))
                setAddresses(StringArray(addresses.iterator()))
                mtu = linkProperties.mtu.takeIf { it > 0 }
                    ?: runCatching { javaInterface.mtu }.getOrDefault(0)
                flags = computeInterfaceFlags(javaInterface, networkCapabilities)
            }
            interfaces.add(boxInterface)
        }

        return InterfaceArray(interfaces.iterator())
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun clearDNSCache() {}

    override fun readWIFIState(): WIFIState? {
        return runCatching {
            val wifiInfo = wifiManager.connectionInfo ?: return WIFIState("", "")
            var ssid = wifiInfo.ssid ?: return WIFIState("", "")
            if (ssid.isBlank() || ssid == "<unknown ssid>") {
                return WIFIState("", "")
            }
            if (ssid.startsWith("\"") && ssid.endsWith("\"")) {
                ssid = ssid.substring(1, ssid.length - 1)
            }
            WIFIState(ssid, wifiInfo.bssid ?: "")
        }.getOrElse { error ->
            AppLogger.w(TAG, "readWIFIState failed, returning empty state", error)
            WIFIState("", "")
        }
    }

    override fun localDNSTransport(): LocalDNSTransport = localResolver

    override fun systemCertificates(): StringIterator {
        val certificates = mutableListOf<String>()
        runCatching {
            val keyStore = KeyStore.getInstance("AndroidCAStore")
            keyStore.load(null, null)
            val aliases = keyStore.aliases()
            while (aliases.hasMoreElements()) {
                val cert = keyStore.getCertificate(aliases.nextElement()) ?: continue
                certificates.add(
                    "-----BEGIN CERTIFICATE-----\n" +
                        Base64.getMimeEncoder(64, "\n".toByteArray()).encodeToString(cert.encoded) +
                        "\n-----END CERTIFICATE-----",
                )
            }
        }.onFailure {
            AppLogger.e(TAG, "Failed to load Android system certificates", it)
        }
        AppLogger.i(TAG, "Loaded ${certificates.size} Android system certificates")
        return StringArray(certificates.iterator())
    }

    override fun sendNotification(p1: Notification?) {}

    private fun buildOverrideOptions(
        isGlobalProxy: Boolean,
        appRoutingMode: AppRoutingMode,
        appRoutingPackages: List<String>,
    ): OverrideOptions {
        val sanitized = appRoutingPackages
            .filter {
                it.isNotBlank() &&
                    it != service.packageName &&
                    !SystemCommunicationBypass.isProtectedPackage(it)
            }
            .distinct()
        val baseExcludePackages = listOf(service.packageName) + SystemCommunicationBypass.packageNames
        return OverrideOptions().apply {
            setAutoRedirect(false)
            when {
                isGlobalProxy -> {
                    setIncludePackage(StringArray(emptyList<String>().iterator()))
                    setExcludePackage(StringArray(baseExcludePackages.iterator()))
                }
                appRoutingMode == AppRoutingMode.PROXY_SELECTED && sanitized.isNotEmpty() -> {
                    setIncludePackage(StringArray(sanitized.iterator()))
                    setExcludePackage(StringArray(emptyList<String>().iterator()))
                }
                appRoutingMode == AppRoutingMode.BYPASS_SELECTED -> {
                    setIncludePackage(StringArray(emptyList<String>().iterator()))
                    setExcludePackage(StringArray((baseExcludePackages + sanitized).iterator()))
                }
                else -> {
                    setIncludePackage(StringArray(emptyList<String>().iterator()))
                    setExcludePackage(StringArray(baseExcludePackages.iterator()))
                }
            }
        }
    }

    private fun readStrings(iterator: StringIterator?): List<String> {
        if (iterator == null) return emptyList()
        return buildList {
            while (iterator.hasNext()) {
                add(iterator.next())
            }
        }
    }

    private fun pushDefaultInterfaceUpdate(network: Network?) {
        val listener = interfaceUpdateListener ?: return
        interfaceUpdateJob?.cancel()
        interfaceUpdateJob = null

        if (network == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                service.setUnderlyingNetworks(null)
            }
            logDefaultInterfaceUpdate("Default interface update: none")
            listener.updateDefaultInterface("", -1, false, false)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            service.setUnderlyingNetworks(arrayOf(network))
        }

        val linkProperties = connectivityManager.getLinkProperties(network) ?: return
        val interfaceName = linkProperties.interfaceName ?: return
        val expectedListener = listener
        val expectedSignal = readySignal

        interfaceUpdateJob = scope.launch {
            val interfaceIndex = resolveInterfaceIndex(interfaceName)
            if (interfaceUpdateListener !== expectedListener) {
                return@launch
            }
            logDefaultInterfaceUpdate(
                "Default interface update: ${describeNetwork(network)} -> $interfaceName/$interfaceIndex",
            )
            val delivered = runCatching {
                expectedListener.updateDefaultInterface(interfaceName, interfaceIndex, false, false)
            }.onFailure {
                AppLogger.w(TAG, "updateDefaultInterface delivery failed", it)
            }.isSuccess
            if (delivered && interfaceIndex >= 0) {
                expectedSignal?.complete(Unit)
            }
        }
    }

    private fun logDefaultInterfaceUpdate(message: String) {
        if (lastDefaultInterfaceLog == message) {
            return
        }
        lastDefaultInterfaceLog = message
        AppLogger.i(TAG, message)
    }

    private fun refreshUnderlyingNetwork(excludedNetwork: Network? = null) {
        underlyingNetwork = UnderlyingNetworkResolver.find(
            connectivityManager,
            excludedNetwork = excludedNetwork,
        )
    }

    private fun requireUnderlyingNetwork(): Network? {
        val current = underlyingNetwork
        if (current != null) {
            return current
        }

        refreshUnderlyingNetwork()
        return underlyingNetwork
    }

    private fun describeNetwork(network: Network?): String {
        if (network == null) return "null"
        val capabilities = connectivityManager.getNetworkCapabilities(network)
        val linkProperties = connectivityManager.getLinkProperties(network)
        val transports = buildList {
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) add("wifi")
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true) add("cellular")
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true) add("ethernet")
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) add("vpn")
        }.joinToString(",")
        return "network=$network iface=${linkProperties?.interfaceName ?: "?"} " +
            "transports=${transports.ifBlank { "unknown" }}"
    }

    private fun handleObservedNetwork(network: Network) {
        if (!UnderlyingNetworkResolver.isCandidate(connectivityManager, network)) {
            return
        }
        underlyingNetwork = network
        pushDefaultInterfaceUpdate(network)
    }

    private fun registerDefaultNetworkCallbackCompat(callback: ConnectivityManager.NetworkCallback) {
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                connectivityManager.registerBestMatchingNetworkCallback(
                    defaultNetworkRequest,
                    callback,
                    mainHandler,
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P -> {
                connectivityManager.requestNetwork(defaultNetworkRequest, callback, mainHandler)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                connectivityManager.registerDefaultNetworkCallback(callback, mainHandler)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.N -> {
                connectivityManager.registerDefaultNetworkCallback(callback)
            }
            else -> {
                connectivityManager.requestNetwork(defaultNetworkRequest, callback)
            }
        }
    }

    private suspend fun resolveInterfaceIndex(interfaceName: String): Int {
        repeat(10) {
            val interfaceIndex = runCatching {
                NetworkInterface.getByName(interfaceName)?.index ?: -1
            }.getOrDefault(-1)
            if (interfaceIndex >= 0) {
                return interfaceIndex
            }
            delay(100)
        }
        return -1
    }

    private fun computeInterfaceFlags(
        networkInterface: NetworkInterface,
        networkCapabilities: NetworkCapabilities,
    ): Int {
        var interfaceFlags = 0
        if (networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            interfaceFlags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
        }
        if (runCatching { networkInterface.isLoopback }.getOrDefault(false)) {
            interfaceFlags = interfaceFlags or OsConstants.IFF_LOOPBACK
        }
        if (runCatching { networkInterface.isPointToPoint }.getOrDefault(false)) {
            interfaceFlags = interfaceFlags or OsConstants.IFF_POINTOPOINT
        }
        if (runCatching { networkInterface.supportsMulticast() }.getOrDefault(false)) {
            interfaceFlags = interfaceFlags or OsConstants.IFF_MULTICAST
        }
        return interfaceFlags
    }

    private class StringArray(values: Iterator<String>) : StringIterator {
        private val items = values.asSequence().toList()
        private var index = 0

        override fun len(): Int = items.size
        override fun hasNext(): Boolean = index < items.size
        override fun next(): String = items[index++]
    }

    private class InterfaceArray(
        private val iterator: Iterator<io.nekohasekai.libbox.NetworkInterface>,
    ) : NetworkInterfaceIterator {
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): io.nekohasekai.libbox.NetworkInterface = iterator.next()
    }

    private fun android.net.LinkAddress.toPrefix(): String {
        val hostAddress = address.hostAddress?.substringBefore('%') ?: return "$address/$prefixLength"
        return "$hostAddress/$prefixLength"
    }
}
