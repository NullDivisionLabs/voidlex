package com.voidlex.voidlex

import java.net.HttpURLConnection
import java.net.ServerSocket
import java.net.SocketTimeoutException
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.thread
import org.junit.Assert.*
import org.junit.Test

class UrlProbeHttpTest {
    @Test fun `default target requires 204 custom requires 2xx`() {
        assertTrue(UrlProbeHttp.validUrl(UrlProbeHttp.DEFAULT_URL))
        assertFalse(UrlProbeHttp.validUrl("http://user:secret@example.com/"))
        assertFalse(UrlProbeHttp.validUrl("http://example.com/#x"))
        assertFalse(UrlProbeHttp.validUrl("tcp://example.com/"))
        assertTrue(UrlProbeHttp.accepts(UrlProbeHttp.DEFAULT_URL, 204))
        assertFalse(UrlProbeHttp.accepts(UrlProbeHttp.DEFAULT_URL, 200))
        assertTrue(UrlProbeHttp.accepts("https://example.com/check", 200))
        assertFalse(UrlProbeHttp.accepts("https://example.com/check", 301))
    }

    @Test fun `two GETs use the proxy and redirects auth failures and rejection stay errors`() {
        for (status in listOf(204, 200, 301, 407, 502)) {
            ServerSocket(0).use { server ->
                val requests = CopyOnWriteArrayList<String>()
                val connections = mutableListOf<HttpURLConnection>()
                val worker = thread(isDaemon = true) {
                    repeat(if (status == 204) 2 else 1) {
                        server.accept().use { socket ->
                            val reader = socket.getInputStream().bufferedReader()
                            requests.add(reader.readLine())
                            while (!reader.readLine().isNullOrEmpty()) { }
                            socket.getOutputStream().write(("HTTP/1.1 $status Test\r\n" +
                                "Content-Length: 0\r\nConnection: close\r\n" +
                                "Location: http://example.com/redirect\r\n\r\n").toByteArray())
                        }
                    }
                }
                try {
                    if (status == 204) {
                        repeat(2) { assertTrue(UrlProbeHttp.request(UrlProbeHttp.DEFAULT_URL, server.localPort, connections::add) >= 0) }
                    } else {
                        val result = runCatching { UrlProbeHttp.request(UrlProbeHttp.DEFAULT_URL, server.localPort, connections::add) }
                        assertTrue(result.isFailure)
                        assertEquals("HTTP $status", result.exceptionOrNull()?.message)
                    }
                    worker.join(1000)
                    assertEquals(if (status == 204) 2 else 1, requests.size)
                    requests.forEach { assertEquals("GET ${UrlProbeHttp.DEFAULT_URL} HTTP/1.1", it) }
                } finally { connections.forEach { it.disconnect() } }
            }
        }
    }

    @Test fun `three second deadline includes incomplete response body`() {
        ServerSocket(0).use { server ->
            val connections = mutableListOf<HttpURLConnection>()
            val worker = thread(isDaemon = true) {
                server.accept().use { socket ->
                    val reader = socket.getInputStream().bufferedReader()
                    while (!reader.readLine().isNullOrEmpty()) { }
                    socket.getOutputStream().write("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nx".toByteArray())
                    Thread.sleep(3500)
                }
            }
            val begin = System.nanoTime()
            try {
                val result = runCatching { UrlProbeHttp.request("http://example.com/check", server.localPort, connections::add) }
                assertTrue(result.exceptionOrNull() is SocketTimeoutException)
                assertTrue((System.nanoTime() - begin) / 1_000_000 < 4500)
            } finally {
                connections.forEach { it.disconnect() }
                worker.join(1000)
            }
        }
    }
}
