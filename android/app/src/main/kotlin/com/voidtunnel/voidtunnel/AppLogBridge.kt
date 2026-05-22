package com.voidtunnel.voidtunnel

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

internal object AppLogBridge {
    private const val PREFS_NAME = "void_app_logs"
    private const val KEY_CLEARED_AT = "clearedAt"
    private const val KEY_RETENTION = "retention"
    private const val LOG_FILE_NAME = "void-app-log.txt"
    private const val RETENTION_HOUR = "hour"
    private const val RETENTION_DAY = "day"
    private const val RETENTION_WEEK = "week"
    private const val RETENTION_FOREVER = "forever"
    private const val MAX_LINES = 4000
    private const val MAX_LOGCAT_READ_LINES = 12000
    private const val MAX_CHARS = 600_000
    private const val MAX_FILE_CHARS = 1_200_000
    private const val FLUSH_INTERVAL_MS = 1_000L
    private const val MAX_PENDING_BEFORE_FLUSH = 256
    private const val ONE_DAY_MS = 24L * 60 * 60 * 1000
    private const val ONE_YEAR_MS = 365L * ONE_DAY_MS
    private val processLinePattern = Regex("""^\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3}\s+(\d+)\s+""")
    private val priorityLinePattern = Regex("""^\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3}\s+\d+\s+\d+\s+([A-Z])\s+""")
    private val threadtimeFormat = ThreadLocal.withInitial<SimpleDateFormat> {
        SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US)
    }

    @Volatile
    private var appContext: Context? = null
    // Levels actively persisted. Disabled levels short-circuit append() so
    // we don't pay the buildEntry()/disk-flush cost for messages that the
    // user has explicitly excluded from the log viewer.
    // Default keeps everything (legacy behaviour) until the Flutter side
    // pushes its real selection through setActivePriorities().
    @Volatile
    private var activePriorities: Set<Char> = setOf('V', 'D', 'I', 'W', 'E', 'F', 'A')

    // The hot path (AppLogger calls into append from every coroutine and from
    // Xray's log-reader thread) must not block on disk I/O. We keep two
    // structures under one short-lived lock:
    //   - `ring`: bounded tail of the most recent lines, served back to the
    //             UI on read() without touching the file.
    //   - `pending`: lines that have not yet been written through.
    // A periodic coroutine drains `pending` to disk in batches; large
    // bursts (Xray startup, etc.) trigger an opportunistic urgent flush
    // when `pending` crosses MAX_PENDING_BEFORE_FLUSH.
    private val bufferLock = Any()
    private val ring = ArrayDeque<String>(MAX_LINES)
    private val pending = ArrayDeque<String>(MAX_PENDING_BEFORE_FLUSH)
    private val fileLock = Any()
    private val flusherScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    @Volatile
    private var flushJob: Job? = null

    fun install(context: Context) {
        appContext = context.applicationContext
        startFlusherIfNeeded()
    }

    fun setActiveLevels(levels: Set<String>) {
        // Always allow F/A (fatal/assert) through — losing those would mask
        // genuine bugs even when the user runs with "errors only" off.
        val priorities = prioritiesFor(levels).toMutableSet()
        priorities += 'F'
        priorities += 'A'
        activePriorities = priorities
    }

    fun append(priority: Char, tag: String, message: String, throwable: Throwable? = null) {
        if (appContext == null) return
        val normalized = priority.uppercaseChar()
        if (normalized !in activePriorities) return
        val entry = buildEntry(priority, tag, message, throwable)
        val urgent: Boolean
        synchronized(bufferLock) {
            ring.addLast(entry)
            while (ring.size > MAX_LINES) ring.removeFirst()
            pending.addLast(entry)
            urgent = pending.size >= MAX_PENDING_BEFORE_FLUSH
        }
        if (urgent) {
            flusherScope.launch { flushPending() }
        }
    }

    /// Returns log lines newer than [sinceEpochMs] (parsed from the line's
    /// own threadtime stamp). The UI poller passes the timestamp of the
    /// newest line it has already shown, so we don't re-marshal the whole
    /// buffer on every refresh. `sinceEpochMs <= 0` falls back to a full
    /// snapshot. Filtering by [levels] still applies.
    fun readSince(
        context: Context,
        levels: Set<String>,
        sinceEpochMs: Long,
        retention: String? = null,
    ): String {
        if (sinceEpochMs <= 0L) {
            return read(context, levels, retention)
        }
        install(context)
        if (levels.isEmpty()) return ""
        val allowedPriorities = prioritiesFor(levels)
        if (allowedPriorities.isEmpty()) return ""
        val effectiveRetention = normalizeRetention(retention ?: storedRetention(context))

        // Drain pending so the in-memory ring matches what's on disk.
        flushPending()

        val snapshot = synchronized(bufferLock) { ring.toList() }
        val cutoff = maxOf(sinceEpochMs, retentionCutoffMillis(effectiveRetention))
        val tail = snapshot
            .asSequence()
            .filter { line ->
                val stampMs = parseThreadtimeMillis(line) ?: return@filter false
                stampMs > cutoff
            }
            .filter { line -> shouldShowLine(line, allowedPriorities) }
            .toList()
        return tail.joinToString("\n").takeLast(MAX_CHARS).trimEnd()
    }

    fun read(context: Context, levels: Set<String>, retention: String? = null): String {
        install(context)
        if (levels.isEmpty()) return ""
        val allowedPriorities = prioritiesFor(levels)
        if (allowedPriorities.isEmpty()) return ""
        val effectiveRetention = normalizeRetention(retention ?: storedRetention(context))

        // Push anything sitting in `pending` to disk so the snapshot we hand
        // back is internally consistent with what a subsequent process would
        // read from the file.
        flushPending()
        pruneStoredLogs(context, effectiveRetention)

        val stored = readStoredLogs(context, allowedPriorities, effectiveRetention)
        if (stored.isNotBlank()) {
            return stored
        }

        val pid = android.os.Process.myPid()
        val raw = readLogcatForPid(pid)
        return filterLogLines(
            raw,
            allowedPriorities,
            clearedAt(context),
            retentionCutoffMillis(effectiveRetention),
        )
    }

    fun setRetention(context: Context, retention: String?) {
        install(context)
        val normalized = normalizeRetention(retention)
        context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_RETENTION, normalized)
            .apply()
        trimInMemoryBuffers(retentionCutoffMillis(normalized))
        flushPending()
        pruneStoredLogs(context, normalized)
    }

    fun clear(context: Context) {
        install(context)
        context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_CLEARED_AT, System.currentTimeMillis())
            .apply()
        synchronized(bufferLock) {
            ring.clear()
            pending.clear()
        }
        synchronized(fileLock) {
            runCatching { logFile(context).delete() }
        }
        runCatching { runCommand(listOf("logcat", "-c"), timeoutSeconds = 2) }
    }

    private fun startFlusherIfNeeded() {
        if (flushJob?.isActive == true) return
        flushJob = flusherScope.launch {
            while (isActive) {
                delay(FLUSH_INTERVAL_MS)
                flushPending()
            }
        }
    }

    private fun flushPending() {
        val context = appContext ?: return
        val batch: List<String>
        synchronized(bufferLock) {
            if (pending.isEmpty()) return
            batch = ArrayList(pending)
            pending.clear()
        }
        synchronized(fileLock) {
            runCatching {
                val file = logFile(context)
                file.parentFile?.mkdirs()
                file.appendText(batch.joinToString(separator = "\n", postfix = "\n"))
                trimLogFile(context, file)
            }
        }
    }

    private fun buildEntry(
        priority: Char,
        tag: String,
        message: String,
        throwable: Throwable?,
    ): String {
        val stamp = formatDeviceThreadtime(Date())
        val pid = android.os.Process.myPid()
        val tid = android.os.Process.myTid()
        val normalizedPriority = priority.uppercaseChar()
        val throwableText = throwable
            ?.let(android.util.Log::getStackTraceString)
            ?.trimEnd()
            .orEmpty()
        val payload = buildString {
            append(message)
            if (throwableText.isNotBlank()) {
                if (length > 0) append('\n')
                append(throwableText)
            }
        }
        return payload.lineSequence()
            .joinToString("\n") { line ->
                "$stamp $pid $tid $normalizedPriority $tag: $line"
            }
    }

    private fun readStoredLogs(
        context: Context,
        allowedPriorities: Set<Char>,
        retention: String,
    ): String {
        val raw = synchronized(fileLock) {
            runCatching {
                val file = logFile(context)
                if (file.isFile) file.readText() else ""
            }.getOrDefault("")
        }
        return filterLogLines(
            raw,
            allowedPriorities,
            clearedAt(context),
            retentionCutoffMillis(retention),
        )
    }

    private fun filterLogLines(
        raw: String,
        allowedPriorities: Set<Char>,
        clearedAt: Long,
        retentionCutoff: Long,
    ): String {
        val cutoff = maxOf(clearedAt, retentionCutoff)
        val lines = raw.lineSequence()
            .filter { line ->
                cutoff <= 0L || (parseThreadtimeMillis(line) ?: Long.MAX_VALUE) >= cutoff
            }
            .filter { line -> shouldShowLine(line, allowedPriorities) }
            .toList()
            .takeLast(MAX_LINES)

        return lines.joinToString("\n").takeLast(MAX_CHARS).trimEnd()
    }

    private fun clearedAt(context: Context): Long {
        return context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(KEY_CLEARED_AT, 0L)
    }

    private fun storedRetention(context: Context): String {
        return normalizeRetention(
            context
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_RETENTION, null),
        )
    }

    private fun logFile(context: Context): File {
        return File(context.filesDir, LOG_FILE_NAME)
    }

    private fun pruneStoredLogs(context: Context, retention: String = storedRetention(context)) {
        synchronized(fileLock) {
            runCatching { trimLogFile(context, logFile(context), retention) }
        }
    }

    private fun trimLogFile(
        context: Context,
        file: File,
        retention: String = storedRetention(context),
    ) {
        if (!file.isFile) return
        val cutoff = maxOf(clearedAt(context), retentionCutoffMillis(retention))
        val raw = file.readText()
        val timeTrimmed = if (cutoff > 0L) {
            raw.lineSequence()
                .filter { line ->
                    (parseThreadtimeMillis(line) ?: Long.MAX_VALUE) >= cutoff
                }
                .joinToString("\n")
        } else {
            raw
        }
        val sizeTrimmed = if (timeTrimmed.length > MAX_FILE_CHARS) {
            val tail = timeTrimmed.takeLast(MAX_CHARS)
            tail.substringAfter('\n', tail)
        } else {
            timeTrimmed
        }
        if (sizeTrimmed.isBlank()) {
            file.delete()
        } else if (sizeTrimmed != raw) {
            file.writeText(sizeTrimmed.trimEnd() + "\n")
        }
    }

    private fun readLogcatForPid(pid: Int): String {
        val pidOutput = runCatching {
            runCommand(
                listOf(
                    "logcat",
                    "-d",
                    "-t",
                    MAX_LOGCAT_READ_LINES.toString(),
                    "-v",
                    "threadtime",
                    "--pid",
                    pid.toString(),
                ),
                timeoutSeconds = 4,
            )
        }.getOrNull()

        if (!pidOutput.isNullOrBlank()) {
            return pidOutput
        }

        val raw = runCatching {
            runCommand(
                listOf(
                    "logcat",
                    "-d",
                    "-t",
                    MAX_LOGCAT_READ_LINES.toString(),
                    "-v",
                    "threadtime",
                ),
                timeoutSeconds = 4,
            )
        }.getOrDefault("")

        return raw.lineSequence()
            .filter { line ->
                processLinePattern.find(line)?.groupValues?.getOrNull(1)?.toIntOrNull() == pid ||
                    line.startsWith("---------")
            }
            .joinToString("\n")
    }

    private fun runCommand(command: List<String>, timeoutSeconds: Long): String {
        val process = ProcessBuilder(command)
            .redirectErrorStream(true)
            .start()
        if (!process.waitFor(timeoutSeconds, TimeUnit.SECONDS)) {
            process.destroyForcibly()
            return "Log command timed out: ${command.joinToString(" ")}"
        }
        return process.inputStream.bufferedReader().use { it.readText() }
    }

    private fun shouldShowLine(line: String, allowedPriorities: Set<Char>): Boolean {
        if (line.startsWith("---------")) return true
        val priority = priorityLinePattern.find(line)?.groupValues?.getOrNull(1)?.firstOrNull()
        return priority != null && allowedPriorities.contains(priority)
    }

    private fun prioritiesFor(levels: Set<String>): Set<Char> {
        val normalized = levels.map { it.lowercase(Locale.US) }.toSet()
        val priorities = mutableSetOf<Char>()
        if ("debug" in normalized) {
            priorities += 'V'
            priorities += 'D'
        }
        if ("info" in normalized) {
            priorities += 'I'
        }
        if ("warning" in normalized || "warnings" in normalized || "warn" in normalized) {
            priorities += 'W'
        }
        if ("error" in normalized || "errors" in normalized) {
            priorities += 'E'
            priorities += 'F'
            priorities += 'A'
        }
        return priorities
    }

    private fun normalizeRetention(retention: String?): String {
        return when (retention?.lowercase(Locale.US)) {
            RETENTION_HOUR -> RETENTION_HOUR
            RETENTION_DAY -> RETENTION_DAY
            RETENTION_WEEK -> RETENTION_WEEK
            RETENTION_FOREVER -> RETENTION_FOREVER
            else -> RETENTION_DAY
        }
    }

    private fun retentionCutoffMillis(retention: String): Long {
        val maxAgeMillis = when (normalizeRetention(retention)) {
            RETENTION_HOUR -> TimeUnit.HOURS.toMillis(1)
            RETENTION_DAY -> TimeUnit.DAYS.toMillis(1)
            RETENTION_WEEK -> TimeUnit.DAYS.toMillis(7)
            else -> return 0L
        }
        return System.currentTimeMillis() - maxAgeMillis
    }

    private fun trimInMemoryBuffers(cutoff: Long) {
        if (cutoff <= 0L) return
        fun isFresh(entry: String): Boolean =
            (parseThreadtimeMillis(entry) ?: Long.MAX_VALUE) >= cutoff
        synchronized(bufferLock) {
            while (ring.isNotEmpty() && !isFresh(ring.first())) {
                ring.removeFirst()
            }
            while (pending.isNotEmpty() && !isFresh(pending.first())) {
                pending.removeFirst()
            }
        }
    }

    private fun formatDeviceThreadtime(date: Date): String {
        return checkNotNull(threadtimeFormat.get()).apply {
            timeZone = TimeZone.getDefault()
        }.format(date)
    }

    private fun parseThreadtimeMillis(line: String): Long? {
        if (line.length < 18) return null
        val stamp = line.substring(0, 18)
        val deviceTimeZone = TimeZone.getDefault()
        val year = Calendar.getInstance(deviceTimeZone).get(Calendar.YEAR)
        val parsed = runCatching {
            SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).apply {
                timeZone = deviceTimeZone
            }
                .parse("$year-$stamp")
                ?.time
        }.getOrNull() ?: return null

        // logcat's threadtime format omits the year. A line written in
        // December that we read in January would otherwise be tagged with
        // the new year and end up ~11 months in the future — wide enough
        // to break clearedAt/retention cutoffs. When the timestamp lands
        // more than a day ahead of wall-clock, back it off by a year.
        return if (parsed > System.currentTimeMillis() + ONE_DAY_MS) {
            parsed - ONE_YEAR_MS
        } else {
            parsed
        }
    }
}
