package com.voidtunnel.voidtunnel

import android.content.Context
import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants
import android.os.Build
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

internal enum class XrayRuntimeMode {
    SOCKS,
    TUN,
}

internal class XrayRuntime(
    private val context: Context,
    private val scope: CoroutineScope,
) {
    companion object {
        private const val TAG = "XrayRuntime"
        private const val READY_TIMEOUT_MS = 3_000L
        private const val READY_POLL_MS = 50L
        private const val CONFIG_TEST_TIMEOUT_MS = 5_000L
        private const val PROCESS_STOP_TIMEOUT_MS = 1_500L
        private const val PROCESS_FORCE_STOP_TIMEOUT_MS = 500L
        private const val NATIVE_STOP_TIMEOUT_MS = 500
        private const val REALITY_REAL_CERT_WARNING = "REALITY: received real certificate"
        private const val REALITY_WARNING_SUMMARY_INTERVAL_MS = 15_000L
        // Chunk size for the diagnostic config dump. Logcat truncates
        // single lines around 4 KB; we stay comfortably under that so the
        // capture survives intermediate logging layers.
        private const val LOG_CHUNK_BYTES = 3500
        private const val XRAY_TUN_PATCH_HINT =
            "Package the VoidTunnel-patched xray-core build with protocol \"tun\" " +
                "and XRAY_TUN_FD/xray.tun.fd support."
        private val ACCESS_LOG_PATTERN = Regex(""" from (tcp|udp):.* accepted (tcp|udp):""")

        internal fun isXrayStartedLine(line: String): Boolean {
            return line.contains("[Warning] core: Xray ") && line.endsWith(" started")
        }

        internal fun configTestFailureMessage(
            mode: XrayRuntimeMode,
            exitCode: Int,
            rawOutput: String,
        ): String {
            val compact = compactOutput(rawOutput)
            if (mode == XrayRuntimeMode.TUN && looksLikeUnsupportedTun(rawOutput)) {
                return "Xray TUN config test failed, exitCode=$exitCode: " +
                    "$XRAY_TUN_PATCH_HINT Output: $compact"
            }
            return "Xray config test failed, exitCode=$exitCode: $compact"
        }

        private fun looksLikeUnsupportedTun(rawOutput: String): Boolean {
            val lower = rawOutput.lowercase()
            return lower.contains("tun") &&
                (
                    lower.contains("unknown protocol") ||
                        lower.contains("unsupported protocol") ||
                        lower.contains("unknown inbound") ||
                        lower.contains("not supported")
                    )
        }

        internal fun compactOutput(raw: String): String {
            val compact = raw.lineSequence()
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .toList()
                .takeLast(8)
                .joinToString(" | ")
            return compact.take(1500).ifBlank { "no output" }
        }

        internal fun applyXrayAssetEnvironment(
            environment: MutableMap<String, String>,
            assetDirectory: File,
        ) {
            val assetPath = assetDirectory.absolutePath
            environment["XRAY_LOCATION_ASSET"] = assetPath
            environment["xray.location.asset"] = assetPath
        }
    }

    private data class NativeProcessHandle(
        val pid: Int,
        val output: ParcelFileDescriptor,
    )

    @Volatile
    private var process: Process? = null
    @Volatile
    private var nativeProcess: NativeProcessHandle? = null
    private var logJob: Job? = null
    private var suppressedRealityWarnings = 0
    private var lastRealityWarningSummaryAt = 0L
    @Volatile
    private var lastFailureReason: String? = null

    fun failureReason(): String? = lastFailureReason

    @Synchronized
    fun start(
        config: ServerConfig,
        mode: XrayRuntimeMode = XrayRuntimeMode.SOCKS,
        tunFd: Int? = null,
    ): Boolean {
        stop(waitForExit = true)
        resetLogSuppression()
        if (mode == XrayRuntimeMode.TUN && tunFd == null) {
            lastFailureReason = "Xray TUN mode requires an Android VpnService file descriptor"
            AppLogger.e(TAG, lastFailureReason!!)
            return false
        }
        val xrayBinary = resolveBinary() ?: run {
            val supportedAbis = Build.SUPPORTED_ABIS?.joinToString(", ").orEmpty()
            lastFailureReason =
                "Xray binary not found. Add src/main/jniLibs/<abi>/libxray.so " +
                    "or assets/xray/<abi>/xray for one of: $supportedAbis"
            AppLogger.e(
                TAG,
                "$lastFailureReason (legacy asset layout assets/<abi>/xray/xray is also accepted)",
            )
            return false
        }
        val configFile = File(context.filesDir, "xray-config.json")
        GeoDataManager.ensureBundledDefaults(context)
        val configJson = when (mode) {
            XrayRuntimeMode.SOCKS -> XrayConfigBuilder.build(config)
            XrayRuntimeMode.TUN -> XrayTunConfigBuilder.build(config)
        }
        configFile.writeText(configJson)
        if (config.verboseXrayLogs) {
            dumpGeneratedConfig(configJson)
        }

        // `xray -test -config` takes 0.5-5 s on cold start because it
        // re-parses the config, resolves the geo files, and tears the
        // engine back down. Skip it when neither the JSON nor the binary
        // has changed since the last successful test — most reconnects
        // (auto-reconnect on network change, settings tweaks that don't
        // touch xray fields, app restart with the same selected server)
        // hit this fast path.
        val fingerprint = computeConfigFingerprint(configJson, xrayBinary, mode)
        val skipTest = fingerprint != null &&
            readCachedFingerprint() == fingerprint
        if (skipTest) {
            AppLogger.d(TAG, "Xray config unchanged since last test, skipping -test pass")
        } else if (!testConfig(xrayBinary, configFile, mode)) {
            return false
        } else if (fingerprint != null) {
            writeCachedFingerprint(fingerprint)
        }

        return when (mode) {
            XrayRuntimeMode.SOCKS -> startSocksRuntime(xrayBinary, configFile)
            XrayRuntimeMode.TUN -> startNativeTunRuntime(xrayBinary, configFile, tunFd!!)
        }
    }

    /// Stable fingerprint of "what -test would re-check": the rendered
    /// config JSON plus an identity probe (path + mtime + size) of the
    /// xray binary. Re-installing the app or a binary upgrade invalidates
    /// the cache automatically because the mtime/size shifts.
    private fun computeConfigFingerprint(
        configJson: String,
        binary: File,
        mode: XrayRuntimeMode,
    ): String? = runCatching {
        val digest = java.security.MessageDigest.getInstance("SHA-256")
        digest.update(mode.name.toByteArray(Charsets.UTF_8))
        digest.update(0x1F.toByte())
        digest.update(configJson.toByteArray(Charsets.UTF_8))
        digest.update(0x1F.toByte())
        digest.update(binary.absolutePath.toByteArray(Charsets.UTF_8))
        digest.update(0x1F.toByte())
        digest.update(binary.lastModified().toString().toByteArray(Charsets.UTF_8))
        digest.update(0x1F.toByte())
        digest.update(binary.length().toString().toByteArray(Charsets.UTF_8))
        digest.digest().joinToString("") { "%02x".format(it) }
    }.getOrNull()

    private fun cachedFingerprintFile(): File =
        File(context.filesDir, "xray-config.last-tested-fingerprint")

    private fun readCachedFingerprint(): String? = runCatching {
        val file = cachedFingerprintFile()
        if (file.isFile) file.readText().trim().ifBlank { null } else null
    }.getOrNull()

    private fun writeCachedFingerprint(fingerprint: String) {
        runCatching {
            cachedFingerprintFile().writeText(fingerprint)
        }.onFailure {
            AppLogger.w(TAG, "Failed to cache xray config fingerprint", it)
        }
    }

    private fun startSocksRuntime(xrayBinary: File, configFile: File): Boolean {
        return runCatching {
            val builder = ProcessBuilder(
                xrayBinary.absolutePath,
                "run",
                "-config",
                configFile.absolutePath,
            )
                .redirectErrorStream(true)
            applyXrayAssetEnvironment(builder.environment(), GeoDataManager.assetDirectory(context))
            xrayBinary.parentFile?.let(builder::directory)
            val proc = builder.start()
            process = proc
            val startedSignal = CountDownLatch(1)
            logJob = scope.launch(Dispatchers.IO) {
                try {
                    proc.inputStream.bufferedReader().useLines { lines ->
                        lines.forEach { line ->
                            if (isXrayStartedLine(line)) {
                                startedSignal.countDown()
                            }
                            logXrayLine(line)
                        }
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    // Closing the process during disconnect/reconnect interrupts the blocking read.
                    // That is expected and must not crash the app's coroutine worker.
                    val stillCurrentProcess = process === proc
                    if (stillCurrentProcess && proc.isAlive) {
                        AppLogger.w(TAG, "Xray log reader failed", e)
                    } else {
                        AppLogger.d(TAG, "Xray log reader stopped: ${e.message ?: "closed"}")
                    }
                }
            }
            if (!waitForSocksRuntime(proc, startedSignal)) {
                val exitCode = runCatching { proc.exitValue() }.getOrNull()
                lastFailureReason = if (exitCode != null) {
                    "Xray exited before socks runtime became ready, exitCode=$exitCode"
                } else {
                    "Xray SOCKS runtime did not become ready on " +
                        "${RuntimePorts.XRAY_SOCKS_HOST}:${RuntimePorts.XRAY_SOCKS_PORT}"
                }
                AppLogger.e(TAG, lastFailureReason!!)
                stop()
                return false
            }
            lastFailureReason = null
            true
        }.onFailure {
            lastFailureReason = "Failed to start xray process: ${it.message ?: "unknown error"}"
            AppLogger.e(TAG, "Failed to start xray process", it)
        }.getOrDefault(false)
    }

    private fun startNativeTunRuntime(
        xrayBinary: File,
        configFile: File,
        tunFd: Int,
    ): Boolean {
        return runCatching {
            val workingDirectory = xrayBinary.parentFile?.absolutePath ?: context.filesDir.absolutePath
            AppLogger.i(TAG, "Starting Xray TUN via native launcher")
            val nativeResult = XrayNativeProcess.start(
                xrayBinary.absolutePath,
                configFile.absolutePath,
                workingDirectory,
                GeoDataManager.assetDirectory(context).absolutePath,
                tunFd,
            )
            require(nativeResult.size >= 2) { "Native launcher returned an invalid process handle" }

            val handle = NativeProcessHandle(
                pid = nativeResult[0],
                output = ParcelFileDescriptor.adoptFd(nativeResult[1]),
            )
            nativeProcess = handle
            val startedSignal = CountDownLatch(1)
            AppLogger.i(TAG, "Xray TUN config routes DNS through proxy and UDP/443 to block-quic")
            logJob = scope.launch(Dispatchers.IO) {
                try {
                    ParcelFileDescriptor.AutoCloseInputStream(handle.output).bufferedReader().useLines { lines ->
                        lines.forEach { line ->
                            if (isXrayStartedLine(line)) {
                                startedSignal.countDown()
                            }
                            logXrayLine(line)
                        }
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    val stillCurrentProcess =
                        nativeProcess?.pid == handle.pid && XrayNativeProcess.isAlive(handle.pid)
                    if (stillCurrentProcess) {
                        AppLogger.w(TAG, "Xray native log reader failed", e)
                    } else {
                        AppLogger.d(TAG, "Xray native log reader stopped: ${e.message ?: "closed"}")
                    }
                }
            }

            if (!waitForNativeTunRuntime(handle.pid, startedSignal)) {
                lastFailureReason = if (XrayNativeProcess.isAlive(handle.pid)) {
                    "Xray TUN runtime did not report readiness before timeout"
                } else {
                    "Xray exited before tun runtime became ready"
                }
                AppLogger.e(TAG, lastFailureReason!!)
                stop()
                return false
            }
            lastFailureReason = null
            true
        }.onFailure {
            lastFailureReason = "Failed to start Xray native TUN process: ${it.message ?: "unknown error"}"
            AppLogger.e(TAG, "Failed to start Xray native TUN process", it)
        }.getOrDefault(false)
    }

    private fun logXrayLine(line: String) {
        if (ACCESS_LOG_PATTERN.containsMatchIn(line)) {
            return
        }
        if (line.contains(REALITY_REAL_CERT_WARNING)) {
            logRealityWarningSummary()
            return
        }
        if (isLowValueXrayStartupLine(line)) {
            return
        }
        logWithPriority(line)
    }

    private fun logWithPriority(line: String) {
        when {
            line.contains("[Error]") -> AppLogger.e(TAG, line)
            line.contains("[Warning]") -> AppLogger.w(TAG, line)
            line.contains("[Info]") -> AppLogger.i(TAG, line)
            else -> AppLogger.d(TAG, line)
        }
    }

    private fun logRealityWarningSummary() {
        suppressedRealityWarnings += 1
        val now = System.currentTimeMillis()
        if (lastRealityWarningSummaryAt == 0L ||
            now - lastRealityWarningSummaryAt >= REALITY_WARNING_SUMMARY_INTERVAL_MS
        ) {
            AppLogger.d(
                TAG,
                "Suppressed $suppressedRealityWarnings repeated Reality certificate warnings",
            )
            suppressedRealityWarnings = 0
            lastRealityWarningSummaryAt = now
        }
    }

    private fun resetLogSuppression() {
        suppressedRealityWarnings = 0
        lastRealityWarningSummaryAt = 0L
    }

    /// One-shot diagnostic dump of the generated Xray JSON config. Emitted
    /// only when the user has flipped the "Verbose xray logs" toggle on,
    /// which is intended for capturing logs when a bridge silently fails:
    /// the dump lets us verify on a later log review that the JSON we sent
    /// to xray-core actually contains what we expected (correct
    /// streamSettings, sockopt.dialerProxy, ALPN, etc.).
    ///
    /// Credentials and Reality material are masked to keep the dump safe
    /// to share. We strip:
    ///   - VLESS user id ("id") — auth credential
    ///   - SOCKS inbound accounts (user/pass)
    ///   - Reality publicKey ("publicKey") and shortId — proves server
    ///     identity if leaked
    /// Everything else stays intact because we need to read it.
    private fun dumpGeneratedConfig(configJson: String) {
        val masked = configJson
            .replace(
                Regex("\"id\"\\s*:\\s*\"[^\"]*\""),
                "\"id\":\"<masked-uuid>\"",
            )
            .replace(
                Regex("\"publicKey\"\\s*:\\s*\"[^\"]*\""),
                "\"publicKey\":\"<masked-pbk>\"",
            )
            .replace(
                Regex("\"shortId\"\\s*:\\s*\"[^\"]*\""),
                "\"shortId\":\"<masked-sid>\"",
            )
            .replace(
                Regex("\"user\"\\s*:\\s*\"[^\"]*\""),
                "\"user\":\"<masked>\"",
            )
            .replace(
                Regex("\"pass\"\\s*:\\s*\"[^\"]*\""),
                "\"pass\":\"<masked>\"",
            )
        // Logcat truncates long lines (~4 KB on most ROMs); chunk the dump
        // so the entire JSON survives the trip to a captured logfile.
        AppLogger.i(TAG, "Generated Xray config (sensitive fields masked):")
        masked.chunked(LOG_CHUNK_BYTES).forEachIndexed { index, chunk ->
            AppLogger.i(TAG, "config[$index]: $chunk")
        }
    }

    private fun isLowValueXrayStartupLine(line: String): Boolean {
        return line.startsWith("Xray ") ||
            line == "A unified platform for anti-censorship." ||
            line.contains("[Info] infra/conf/serial: Reading config:") ||
            isXrayStartedLine(line)
    }

    fun stop(waitForExit: Boolean = true): Boolean = stopInternal(waitForExit)

    @Synchronized
    private fun stopInternal(waitForExit: Boolean): Boolean {
        val proc = process
        val nativeHandle = nativeProcess
        val hadRuntime = proc != null || nativeHandle != null
        process = null
        nativeProcess = null
        logJob?.cancel()
        logJob = null
        runCatching {
            proc?.destroy()
            if (waitForExit && proc != null) {
                if (!waitForProcessExit(proc, PROCESS_STOP_TIMEOUT_MS)) {
                    AppLogger.w(TAG, "Xray process did not exit after destroy; forcing stop")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        proc.destroyForcibly()
                    } else {
                        proc.destroy()
                    }
                    waitForProcessExit(proc, PROCESS_FORCE_STOP_TIMEOUT_MS)
                }
            }
            if (nativeHandle != null) {
                XrayNativeProcess.terminate(
                    nativeHandle.pid,
                    if (waitForExit) NATIVE_STOP_TIMEOUT_MS else READY_POLL_MS.toInt(),
                )
                nativeHandle.output.close()
            }
        }
        return hadRuntime
    }

    private fun resolveBinary(): File? {
        // Prefer app native library directory (jniLibs). Files in this
        // location are mapped by the package manager and are typically
        // executable even when app data directories are mounted noexec.
        val nativeLibraryDir = context.applicationInfo.nativeLibraryDir
        if (!nativeLibraryDir.isNullOrBlank()) {
            val nativeCandidates = listOf(
                File(nativeLibraryDir, "xray"),
                File(nativeLibraryDir, "libxray.so"),
            )
            for (candidate in nativeCandidates) {
                if (candidate.exists()) {
                    AppLogger.i(TAG, "Using native library xray candidate: ${candidate.absolutePath}")
                    return candidate
                }
            }
        }

        val direct = File(context.filesDir, "xray")
        if (direct.exists()) {
            direct.setExecutable(true)
            return direct
        }
        val nested = File(context.filesDir, "xray-core/xray")
        if (nested.exists()) {
            nested.setExecutable(true)
            return nested
        }
        val installed = installBundledBinaryFromAssets()
        if (installed != null && installed.exists()) {
            installed.setExecutable(true)
            return installed
        }
        return null
    }

    private fun installBundledBinaryFromAssets(): File? {
        val outputDir = File(context.filesDir, "xray-core")
        if (!outputDir.exists()) {
            outputDir.mkdirs()
        }
        val outputFile = File(outputDir, "xray")

        val primaryAbi = Build.SUPPORTED_ABIS?.firstOrNull()
        if (primaryAbi == null) {
            return null
        }
        val assetPaths = listOf(
            "xray/$primaryAbi/xray",
            "$primaryAbi/xray/xray",
        )
        var missingFailure: Throwable? = null
        var attemptedAssetPath = ""

        for (assetPath in assetPaths) {
            attemptedAssetPath = assetPath
            val installed = runCatching {
                context.assets.open(assetPath).use { input ->
                    outputFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                outputFile.setExecutable(true)
                outputFile
            }.onFailure {
                missingFailure = it
                AppLogger.d(TAG, "No bundled xray asset for $assetPath")
            }.getOrNull()

            if (installed != null) {
                // Verify the output file has execute bit; if not, we likely
                // hit a noexec mount and should force callers to use jniLibs.
                val executable = runCatching {
                    val stat = Os.stat(installed.absolutePath)
                    (stat.st_mode and OsConstants.S_IXUSR) != 0
                }.getOrDefault(false)
                if (!executable) {
                    lastFailureReason =
                        "Installed xray asset for ABI=$primaryAbi but file is not executable. " +
                            "Use jniLibs packaging: src/main/jniLibs/$primaryAbi/libxray.so"
                    AppLogger.e(TAG, lastFailureReason!!)
                    return null
                }
                AppLogger.i(TAG, "Installed bundled xray binary from $assetPath to ${installed.absolutePath}")
                return installed
            }
        }

        lastFailureReason =
            "Missing Xray binary for device ABI '$primaryAbi'. Tried: ${assetPaths.joinToString(", ")}"
        missingFailure?.let { AppLogger.d(TAG, "Last asset lookup failure for $attemptedAssetPath", it) }
        return null
    }

    private fun testConfig(xrayBinary: File, configFile: File, mode: XrayRuntimeMode): Boolean {
        val output = StringBuffer()
        return runCatching {
            val builder = ProcessBuilder(
                xrayBinary.absolutePath,
                "run",
                "-test",
                "-config",
                configFile.absolutePath,
            ).redirectErrorStream(true)
            applyXrayAssetEnvironment(builder.environment(), GeoDataManager.assetDirectory(context))
            xrayBinary.parentFile?.let(builder::directory)

            val proc = builder.start()
            val reader = thread(start = true, isDaemon = true, name = "xray-config-test-reader") {
                runCatching {
                    proc.inputStream.bufferedReader().useLines { lines ->
                        lines.forEach { line ->
                            output.appendLine(line)
                        }
                    }
                }.onFailure {
                    AppLogger.d(TAG, "Xray config test reader stopped: ${it.message ?: "closed"}")
                }
            }

            var exitCode: Int? = null
            val deadline = System.currentTimeMillis() + CONFIG_TEST_TIMEOUT_MS
            while (System.currentTimeMillis() < deadline) {
                exitCode = runCatching { proc.exitValue() }.getOrNull()
                if (exitCode != null) {
                    break
                }
                Thread.sleep(READY_POLL_MS)
            }

            if (exitCode == null) {
                proc.destroy()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && proc.isAlive) {
                    proc.destroyForcibly()
                }
                reader.join(200)
                lastFailureReason = "Xray config test timed out after ${CONFIG_TEST_TIMEOUT_MS}ms"
                AppLogger.e(TAG, lastFailureReason!!)
                false
            } else {
                reader.join(200)
                if (exitCode == 0) {
                    AppLogger.i(TAG, "Xray config test passed")
                    true
                } else {
                    lastFailureReason = configTestFailureMessage(mode, exitCode, output.toString())
                    AppLogger.e(TAG, lastFailureReason!!)
                    false
                }
            }
        }.onFailure {
            lastFailureReason = "Failed to run Xray config test: ${it.message ?: "unknown error"}"
            AppLogger.e(TAG, "Failed to run Xray config test", it)
        }.getOrDefault(false)
    }

    private fun waitForSocksRuntime(proc: Process, startedSignal: CountDownLatch): Boolean {
        val deadline = System.currentTimeMillis() + READY_TIMEOUT_MS
        while (System.currentTimeMillis() < deadline) {
            if (!proc.isAlive) {
                return false
            }
            val remaining = deadline - System.currentTimeMillis()
            val waitMs = READY_POLL_MS.coerceAtMost(remaining)
            val signaled = try {
                startedSignal.await(waitMs, TimeUnit.MILLISECONDS)
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
                return false
            }
            if (signaled) {
                if (!proc.isAlive) {
                    return false
                }
                if (waitForSocksInbound(proc, deadline)) {
                    AppLogger.i(TAG, "Xray SOCKS inbound is ready")
                    return true
                }
                return false
            }
        }
        AppLogger.e(TAG, "Xray SOCKS runtime stayed alive but did not report readiness")
        return false
    }

    private fun waitForSocksInbound(proc: Process, deadline: Long): Boolean {
        // The "Xray ... started" log line we listened for already implies the
        // SOCKS inbound is bound. We probe TCP once as a sanity check — if
        // it fails, the runtime is in an inconsistent state and looping
        // with 50ms retries won't fix that. The previous spin loop was
        // residual from the time we tried to call waitForSocksInbound
        // before the startup-log signal landed.
        if (!proc.isAlive) {
            return false
        }
        val probeTimeoutMs = (deadline - System.currentTimeMillis())
            .coerceIn(50, READY_TIMEOUT_MS)
            .toInt()
        return runCatching {
            Socket().use { socket ->
                socket.connect(
                    InetSocketAddress(
                        RuntimePorts.XRAY_SOCKS_HOST,
                        RuntimePorts.XRAY_SOCKS_PORT,
                    ),
                    probeTimeoutMs,
                )
            }
            true
        }.getOrDefault(false)
    }

    private fun waitForProcessExit(proc: Process, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (!proc.isAlive) {
                return true
            }
            val remaining = deadline - System.currentTimeMillis()
            Thread.sleep(READY_POLL_MS.coerceAtMost(remaining))
        }
        return !proc.isAlive
    }

    private fun waitForNativeTunRuntime(pid: Int, startedSignal: CountDownLatch): Boolean {
        val deadline = System.currentTimeMillis() + READY_TIMEOUT_MS
        while (System.currentTimeMillis() < deadline) {
            if (!XrayNativeProcess.isAlive(pid)) {
                return false
            }
            val remaining = deadline - System.currentTimeMillis()
            val waitMs = READY_POLL_MS.coerceAtMost(remaining)
            val signaled = try {
                startedSignal.await(waitMs, TimeUnit.MILLISECONDS)
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
                return false
            }
            if (signaled) {
                if (!XrayNativeProcess.isAlive(pid)) {
                    return false
                }
                AppLogger.i(TAG, "Xray TUN runtime reported ready")
                return true
            }
        }
        AppLogger.e(TAG, "Xray TUN runtime stayed alive but did not report readiness")
        return false
    }
}
