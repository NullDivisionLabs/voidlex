package com.voidlex.voidlex

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.SystemClock
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runInterruptible
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withTimeout
import java.io.File
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/** Bound only by our activity. Extends VpnService to reuse the platform adapter;
 * never registers as an Android VPN and never opens a TUN. Runs in :probe. */
internal class UrlProbeService : VpnService() {
    companion object {
        const val START = 1
        const val CANCEL = 2
        const val RESULT = 3
        const val STARTUP_TIMEOUT_MS = 10_000L
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val slots = Semaphore(2)
    private val libboxSlot = Mutex()
    private val jobs = ConcurrentHashMap<String, Job>()
    private val resources = ConcurrentHashMap<String, Resources>()
    private val messenger = Messenger(Handler(Looper.getMainLooper()) { message ->
        when (message.what) {
            START -> startProbe(message.data, message.replyTo)
            CANCEL -> cancelAll()
        }
        true
    })

    override fun onBind(intent: Intent): IBinder = messenger.binder
    override fun onCreate() {
        super.onCreate()
        // Recover temporary configs left by an OS kill of the previous probe process.
        File(cacheDir, "url-probes").listFiles()?.forEach { directory ->
            if (runCatching { UUID.fromString(directory.name) }.isSuccess) {
                runCatching { directory.deleteRecursively() }
            }
        }
    }
    override fun onUnbind(intent: Intent): Boolean { cancelAll(); return false }
    override fun onDestroy() { cancelAll(); scope.cancel(); super.onDestroy() }

    private fun cancelAll() {
        jobs.values.forEach { it.cancel() }
        resources.values.forEach { it.close() }
    }

    private fun startProbe(data: Bundle, reply: Messenger?) {
        val id = data.getString("requestId") ?: return
        if (reply == null || jobs.containsKey(id)) return
        val job = scope.launch(start = kotlinx.coroutines.CoroutineStart.LAZY) {
            var status = "error"
            var detail: String? = null
            var latency: Long? = null
            try {
                slots.withPermit {
                    val url = data.getString("url") ?: UrlProbeHttp.DEFAULT_URL
                    require(UrlProbeHttp.validUrl(url))
                    val config = VpnServiceConfigParser.parse(Intent().apply {
                        data.getBundle("config")?.let(::putExtras)
                    }) ?: error("Invalid node configuration")
                    if (XrayConfigBuilder.usesDirectLibbox(config)) {
                        libboxSlot.withLock { latency = probe(id, config, url, true) }
                    } else {
                        latency = probe(id, config, url, false)
                    }
                    status = "ok"
                }
            } catch (_: kotlinx.coroutines.TimeoutCancellationException) {
                status = "error"
                detail = "Probe core startup timed out"
            } catch (_: CancellationException) {
                status = "cancelled"
            } catch (_: SocketTimeoutException) {
                status = "timeout"
                detail = "URL request timed out"
            } catch (error: Exception) {
                detail = when {
                    error is IllegalStateException && error.message?.startsWith("HTTP ") == true -> error.message
                    else -> "Proxy URL request or core startup failed"
                }
            } finally {
                resources.remove(id)?.close()
                jobs.remove(id)
                val result = Bundle().apply {
                    putString("requestId", id)
                    putString("status", status)
                    detail?.let { putString("detail", it) }
                    latency?.let { putLong("latencyMs", it) }
                }
                runCatching { reply.send(Message.obtain(null, RESULT).apply { this.data = result }) }
            }
        }
        jobs[id] = job
        job.start()
    }

    private suspend fun probe(id: String, config: ServerConfig, url: String, libbox: Boolean): Long {
        val directory = File(cacheDir, "url-probes/${UUID.randomUUID()}")
        check(directory.mkdirs())
        val owned = Resources(directory)
        resources[id] = owned
        try {
            val port = ServerSocket(0, 1, java.net.InetAddress.getByName("127.0.0.1")).use { it.localPort }
            val json = UrlProbeConfigBuilder.build(config, port)
            withTimeout(STARTUP_TIMEOUT_MS) {
                if (libbox) {
                    val runtime = LibboxTunRuntime(this@UrlProbeService, scope, probeMode = true) { owned.close() }
                    owned.setRuntime(runtime)
                    check(runInterruptible { runtime.startProbe(json, directory) })
                    check(runtime.awaitReady(STARTUP_TIMEOUT_MS))
                    runInterruptible { waitForPort(port, owned) }
                } else {
                    val configFile = File(directory, "config.json").apply { writeText(json) }
                    val binary = File(applicationInfo.nativeLibraryDir, "libxray.so")
                    check(binary.isFile) { "Xray binary unavailable" }
                    val builder = ProcessBuilder(binary.absolutePath, "run", "-config", configFile.absolutePath)
                        .directory(directory).redirectErrorStream(true)
                    XrayRuntime.applyXrayAssetEnvironment(builder.environment(), GeoDataManager.assetDirectory(this@UrlProbeService))
                    val process = builder.start()
                    owned.setProcess(process)
                    val started = AtomicBoolean(false)
                    thread(isDaemon = true, name = "url-probe-core-output") {
                        runCatching {
                            process.inputStream.bufferedReader().useLines { lines ->
                                lines.forEach { if (XrayRuntime.isXrayStartedLine(it)) started.set(true) }
                            }
                        }
                    }
                    runInterruptible {
                        while (!started.get()) {
                            check(process.isAlive && !owned.closed.get()) { "Core exited" }
                            Thread.sleep(25)
                        }
                        waitForPort(port, owned)
                    }
                }
            }
            // Both requests use the same outbound instance, including mux state.
            runInterruptible { UrlProbeHttp.request(url, port, owned::register) }
            return runInterruptible { UrlProbeHttp.request(url, port, owned::register) }
        } finally {
            owned.close()
            resources.remove(id, owned)
        }
    }

    private fun waitForPort(port: Int, owned: Resources) {
        val deadline = SystemClock.elapsedRealtime() + STARTUP_TIMEOUT_MS
        while (SystemClock.elapsedRealtime() < deadline) {
            check(!owned.closed.get())
            if (runCatching {
                Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), 100) }
            }.isSuccess) return
            Thread.sleep(25)
        }
        error("Probe core startup timed out")
    }

    private class Resources(private val directory: File) {
        val closed = AtomicBoolean(false)
        private val connections = mutableListOf<HttpURLConnection>()
        private var process: Process? = null
        private var runtime: LibboxTunRuntime? = null

        @Synchronized fun register(connection: HttpURLConnection) {
            if (closed.get()) { connection.disconnect(); throw CancellationException() }
            connections.add(connection)
        }
        @Synchronized fun setProcess(value: Process) {
            if (closed.get()) { value.destroy(); throw CancellationException() }
            process = value
        }
        @Synchronized fun setRuntime(value: LibboxTunRuntime) {
            if (closed.get()) throw CancellationException()
            runtime = value
        }
        @Synchronized fun close() {
            if (!closed.compareAndSet(false, true)) return
            process?.let { child ->
                runCatching {
                    child.destroy()
                    if (!child.waitFor(500, java.util.concurrent.TimeUnit.MILLISECONDS)) child.destroyForcibly()
                }.onFailure { runCatching { child.destroyForcibly() } }
            }
            connections.forEach { runCatching { it.disconnect() } }
            runCatching { runtime?.stop() }
            runCatching { directory.deleteRecursively() }
        }
    }
}
