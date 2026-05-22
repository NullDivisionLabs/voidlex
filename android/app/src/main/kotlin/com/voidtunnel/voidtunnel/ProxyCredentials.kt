package com.voidtunnel.voidtunnel

import java.security.SecureRandom

internal object ProxyCredentials {
    private val rng = SecureRandom()

    fun randomHex(byteLength: Int): String {
        val bytes = ByteArray(byteLength)
        rng.nextBytes(bytes)
        val sb = StringBuilder(byteLength * 2)
        for (b in bytes) {
            sb.append(HEX[(b.toInt() ushr 4) and 0x0F])
            sb.append(HEX[b.toInt() and 0x0F])
        }
        return sb.toString()
    }

    private val HEX = "0123456789abcdef".toCharArray()
}
