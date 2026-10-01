package com.voidlex.voidlex

import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.SocketTimeoutException
import java.net.URI
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** HTTP requests always dial the selected core's private loopback proxy. */
internal object UrlProbeHttp {
    const val DEFAULT_URL = "http://cp.cloudflare.com/"
    const val REQUEST_TIMEOUT_MS = 3000
    private val deadlines = Executors.newSingleThreadScheduledExecutor { task ->
        Thread(task, "url-probe-deadlines").apply { isDaemon = true }
    }

    fun validUrl(url: String): Boolean = runCatching {
        val uri = URI(url)
        uri.scheme in listOf("http", "https") && !uri.host.isNullOrBlank() &&
            uri.rawUserInfo == null && uri.rawFragment == null &&
            (uri.port == -1 || uri.port in 1..65535)
    }.getOrDefault(false)

    fun accepts(url: String, code: Int): Boolean =
        if (url == DEFAULT_URL) code == 204 else code in 200..299

    fun request(url: String, port: Int, register: (HttpURLConnection) -> Unit): Long {
        require(validUrl(url)) { "Invalid HTTP/HTTPS URL" }
        val connection = URI(url).toURL().openConnection(
            Proxy(Proxy.Type.HTTP, InetSocketAddress("127.0.0.1", port)),
        ) as HttpURLConnection
        register(connection)
        connection.connectTimeout = REQUEST_TIMEOUT_MS
        connection.readTimeout = REQUEST_TIMEOUT_MS
        connection.instanceFollowRedirects = false
        connection.requestMethod = "GET"
        connection.setRequestProperty("Cache-Control", "no-cache")
        val expired = AtomicBoolean(false)
        val deadline = deadlines.schedule({
            expired.set(true)
            connection.disconnect()
        }, REQUEST_TIMEOUT_MS.toLong(), TimeUnit.MILLISECONDS)
        val begin = System.nanoTime()
        try {
            val code = connection.responseCode
            check(accepts(url, code)) { "HTTP $code" }
            connection.inputStream.use { stream ->
                val buffer = ByteArray(4096)
                while (stream.read(buffer) != -1) {
                    if (expired.get()) throw SocketTimeoutException()
                }
            }
            if (expired.get()) throw SocketTimeoutException()
            return TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - begin)
        } catch (error: Exception) {
            if (expired.get()) throw SocketTimeoutException("URL request timed out")
            throw error
        } finally {
            deadline.cancel(false)
            // Retain the successful connection in the HTTP pool for the measured GET.
            // The owner disconnects all registered requests after the probe or cancellation.
        }
    }
}
