package com.voidlex.voidlex

import android.content.Context
import android.net.Uri
import android.os.Build
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

internal object GeoDataManager {
    private const val TAG = "GeoDataManager"
    private const val ASSET_DIRECTORY_NAME = "xray-assets"
    private const val CONNECT_TIMEOUT_MS = 15_000
    private const val READ_TIMEOUT_MS = 30_000

    internal enum class Kind(val wireName: String, val fileName: String) {
        GEOIP("geoip", "geoip.dat"),
        GEOSITE("geosite", "geosite.dat");

        companion object {
            fun fromWire(raw: String?): Kind {
                return entries.firstOrNull { it.wireName == raw }
                    ?: throw IllegalArgumentException("Unknown geodata kind: $raw")
            }
        }
    }

    fun assetDirectory(context: Context): File {
        return File(context.filesDir, ASSET_DIRECTORY_NAME)
    }

    fun ensureBundledDefaults(context: Context) {
        Kind.entries.forEach { ensureBundledDefault(context, it) }
    }

    fun getStatus(context: Context): List<Map<String, Any?>> {
        ensureBundledDefaults(context)
        return Kind.entries.map { buildStatus(context, it) }
    }

    fun download(
        context: Context,
        kindRaw: String?,
        urlRaw: String?,
        onProgress: ((kind: Kind, percent: Int) -> Unit)? = null,
    ): Map<String, Any?> {
        val kind = Kind.fromWire(kindRaw)
        val urlText = urlRaw?.trim().orEmpty()
        if (urlText.isBlank()) {
            throw IllegalArgumentException("URL is empty")
        }
        val url = URL(urlText)
        if (url.protocol != "https" && url.protocol != "http") {
            throw IllegalArgumentException("Only HTTP and HTTPS URLs are supported")
        }

        val connection = (url.openConnection() as HttpURLConnection).apply {
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            instanceFollowRedirects = true
            requestMethod = "GET"
        }

        try {
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IOException("Download failed: HTTP $code")
            }
            connection.inputStream.use { input ->
                replaceWithInput(
                    context,
                    kind,
                    input,
                    totalBytes = connection.contentLengthLong,
                    onProgress = onProgress,
                )
            }
        } finally {
            connection.disconnect()
        }

        return buildStatus(context, kind)
    }

    fun installFromUri(context: Context, kindRaw: String?, uri: Uri): Map<String, Any?> {
        val kind = Kind.fromWire(kindRaw)
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IOException("Unable to open selected file")
        input.use { replaceWithInput(context, kind, it) }
        return buildStatus(context, kind)
    }

    fun buildStatus(context: Context, kind: Kind): Map<String, Any?> {
        val file = targetFile(context, kind)
        val installed = file.isFile
        return mapOf(
            "kind" to kind.wireName,
            "fileName" to kind.fileName,
            "installed" to installed,
            "fileSize" to if (installed) file.length() else 0L,
            "modifiedAtMillis" to if (installed) file.lastModified() else 0L,
        )
    }

    private fun ensureBundledDefault(context: Context, kind: Kind) {
        val target = targetFile(context, kind)
        if (target.isFile && target.length() > 0L) {
            return
        }
        val attempted = mutableListOf<String>()
        for (assetPath in bundledAssetCandidates(kind.fileName)) {
            attempted += assetPath
            val copied = runCatching {
                context.assets.open(assetPath).use { input ->
                    replaceWithInput(context, kind, input)
                }
                true
            }.getOrElse { false }
            if (copied) {
                AppLogger.i(TAG, "Installed bundled ${kind.fileName} from $assetPath")
                return
            }
        }
        // Aggregate the misses into one warning instead of one debug line per
        // path — `bundledAssetCandidates` lists 10+ paths and most of them
        // never resolve. The user-facing UI surfaces "not installed" on the
        // GeoData screen so they can download manually.
        AppLogger.w(
            TAG,
            "No bundled ${kind.fileName} asset found; tried ${attempted.size} path(s)",
        )
    }

    private fun bundledAssetCandidates(fileName: String): List<String> {
        // geoip.dat / geosite.dat are ABI-independent. The canonical path is
        // `xray/<fileName>`; the per-ABI variants below remain only so that
        // installs holding the pre-relocation layout still find their data
        // until the next geodata refresh writes the new path.
        val abiCandidates = buildList {
            Build.SUPPORTED_ABIS?.forEach { add(it) }
            add("arm64-v8a")
            add("armeabi-v7a")
            add("x86_64")
            add("x86")
        }.distinct()

        return buildList {
            add("xray/$fileName")
            add(fileName)
            abiCandidates.forEach { abi ->
                add("xray/$abi/$fileName")
                add("$abi/xray/$fileName")
            }
        }
    }

    private fun replaceWithInput(
        context: Context,
        kind: Kind,
        input: InputStream,
        totalBytes: Long = -1L,
        onProgress: ((kind: Kind, percent: Int) -> Unit)? = null,
    ) {
        val directory = assetDirectory(context)
        if (!directory.exists() && !directory.mkdirs()) {
            throw IOException("Unable to create geodata directory")
        }

        val temp = File.createTempFile("${kind.wireName}-", ".tmp", directory)
        var completed = false
        try {
            temp.outputStream().use { output ->
                if (totalBytes > 0L) {
                    onProgress?.invoke(kind, 0)
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var downloaded = 0L
                    var lastPercent = -1
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        output.write(buffer, 0, read)
                        downloaded += read
                        // Cap at 99 so 100% is only emitted after replaceFile completes
                        val percent = ((downloaded * 100L) / totalBytes)
                            .toInt()
                            .coerceIn(0, 99)
                        if (percent != lastPercent) {
                            lastPercent = percent
                            onProgress?.invoke(kind, percent)
                        }
                    }
                } else {
                    // Content-Length unknown: signal indeterminate with -1
                    onProgress?.invoke(kind, -1)
                    input.copyTo(output)
                }
            }
            if (temp.length() <= 0L) {
                throw IOException("${kind.fileName} is empty")
            }
            replaceFile(temp, targetFile(context, kind))
            onProgress?.invoke(kind, 100)
            completed = true
        } finally {
            if (!completed) {
                temp.delete()
            }
        }
    }

    private fun replaceFile(temp: File, target: File) {
        val backup = File(target.parentFile, "${target.name}.previous")
        if (backup.exists() && !backup.delete()) {
            throw IOException("Unable to clear previous ${target.name} backup")
        }

        val hadPrevious = target.exists()
        if (hadPrevious && !target.renameTo(backup)) {
            throw IOException("Unable to prepare previous ${target.name} backup")
        }

        try {
            if (!temp.renameTo(target)) {
                temp.copyTo(target, overwrite = false)
                temp.delete()
            }
            if (!target.isFile || target.length() <= 0L) {
                throw IOException("Installed ${target.name} is empty")
            }
            target.setLastModified(System.currentTimeMillis())
            if (backup.exists()) {
                backup.delete()
            }
        } catch (e: Exception) {
            target.delete()
            if (hadPrevious && backup.exists()) {
                backup.renameTo(target)
            }
            throw e
        }
    }

    private fun targetFile(context: Context, kind: Kind): File {
        return File(assetDirectory(context), kind.fileName)
    }
}
