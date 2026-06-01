package com.voidlex.voidlex

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Foreground service that runs Xray as a local SOCKS5 + HTTP proxy
 * **without** establishing a system VPN — so Android does not show the
 * VPN key icon and no `BIND_VPN_SERVICE` permission is required.
 *
 * Mirrors [VoidVpnService] scaffolding (foreground notification, mutex,
 * generation guard, event bridge) but skips the `VpnService.Builder()` /
 * TUN setup entirely. Apps that want to use the tunnel must be configured
 * to talk to `127.0.0.1:10808` / `:10809` (or to the device's LAN address
 * when hotspot-bind is enabled).
 */
internal class VoidProxyService : Service() {

    companion object {
        private const val TAG = "VoidProxyService"
        private const val FOREGROUND_NOTIFICATION_ID = 2
        private const val NOTIFICATION_CHANNEL_ID = "void_lex_proxy_channel"
        const val ACTION_DISCONNECT = "ACTION_DISCONNECT_PROXY"
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val lifecycleMutex = Mutex()
    private lateinit var xrayRuntime: XrayRuntime

    @Volatile
    private var runtimeGeneration = 0

    @Volatile
    private var serverConfig: ServerConfig? = null

    @Volatile
    private var tunnelEverStarted = false

    @Volatile
    private var terminalErrorEmitted = false

    private var startJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        AppLogBridge.install(applicationContext)
        xrayRuntime = XrayRuntime(this, serviceScope)
        AppLogger.d(TAG, "ProxyService onCreate")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            requestStop()
            return START_NOT_STICKY
        }

        val parsed = VpnServiceConfigParser.parse(intent)
        if (parsed == null) {
            AppLogger.e(TAG, "No server config for proxy mode")
            terminalErrorEmitted = true
            VpnRuntimeState.markError("No server config provided")
            VpnEventBridge.emit("error", "No server config provided")
            stopSelf()
            return START_NOT_STICKY
        }

        // Proxy-only mode requires hotspot bind so callers from other apps
        // / devices can reach the inbound. The parser already forces this
        // when runMode == PROXY_ONLY but be defensive.
        val config = parsed.copy(
            runMode = RunMode.PROXY_ONLY,
            hotspotBindEnabled = true,
        )
        serverConfig = config

        val generation = nextGeneration()
        prepareStartState(config)
        setupForeground(config)
        startRuntime(config, generation)
        return START_NOT_STICKY
    }

    private fun startRuntime(config: ServerConfig, generation: Int) {
        startJob?.cancel()
        startJob = serviceScope.launch {
            lifecycleMutex.withLock {
                if (!isCurrentGeneration(generation)) return@withLock

                val started = xrayRuntime.start(
                    config = config,
                    mode = XrayRuntimeMode.SOCKS,
                )
                if (!isCurrentGeneration(generation)) {
                    xrayRuntime.stop(waitForExit = true)
                    return@withLock
                }
                if (!started) {
                    terminalErrorEmitted = true
                    val reason = xrayRuntime.failureReason() ?: "Xray runtime is unavailable"
                    VpnRuntimeState.markError(reason)
                    VpnEventBridge.emit("error", reason)
                    stopForegroundCompat()
                    stopSelf()
                    return@withLock
                }
                VpnRuntimeState.markConnected(config)
                VpnEventBridge.emit("connected")
                AppLogger.i(TAG, "Proxy-only runtime up: socks=${RuntimePorts.XRAY_SOCKS_PORT}, http=${RuntimePorts.XRAY_HTTP_PROXY_PORT}")
            }
        }
    }

    private fun requestStop() {
        nextGeneration()
        serviceScope.launch {
            lifecycleMutex.withLock {
                xrayRuntime.stop(waitForExit = true)
                if (!terminalErrorEmitted) {
                    VpnRuntimeState.markDisconnected()
                    VpnEventBridge.emit("disconnected")
                }
                stopForegroundCompat()
                stopSelf()
            }
        }
    }

    private fun prepareStartState(config: ServerConfig) {
        tunnelEverStarted = true
        terminalErrorEmitted = false
        VpnRuntimeState.markConnecting(config)
        VpnEventBridge.emit("connecting")
    }

    private fun nextGeneration(): Int = synchronized(this) {
        runtimeGeneration += 1
        runtimeGeneration
    }

    private fun isCurrentGeneration(generation: Int): Boolean = runtimeGeneration == generation

    private fun setupForeground(config: ServerConfig) {
        ensureNotificationChannel()
        val notification = buildNotification(staticContent(config))
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

    private fun stopForegroundCompat() {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Void//Lex Proxy",
                NotificationManager.IMPORTANCE_LOW,
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun staticContent(config: ServerConfig): String {
        return "Proxy active • ${config.server} • :${RuntimePorts.XRAY_SOCKS_PORT}"
    }

    private val cachedLargeIcon: android.graphics.Bitmap? by lazy {
        runCatching {
            BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        }.getOrNull()
    }

    private fun buildNotification(text: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        cachedLargeIcon?.let { builder.setLargeIcon(it) }
        return builder
            .setContentTitle("Void//Lex • Proxy")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ContextCompat.getColor(this, R.color.brand_blue))
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        runCatching {
            xrayRuntime.stop(waitForExit = true)
        }
        if (tunnelEverStarted && !terminalErrorEmitted) {
            VpnRuntimeState.markDisconnected()
            VpnEventBridge.emit("disconnected")
        }
        super.onDestroy()
        serviceScope.cancel()
    }
}
