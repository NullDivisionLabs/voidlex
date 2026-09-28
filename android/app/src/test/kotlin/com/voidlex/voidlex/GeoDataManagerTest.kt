package com.voidlex.voidlex

import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class GeoDataManagerTest {
    @Test
    fun `bounded copy accepts geodata at max size`() {
        val output = CountingOutputStream()

        val copied = GeoDataManager.copyBounded(
            input = FixedLengthInputStream(GeoDataManager.MAX_GEODATA_BYTES),
            output = output,
            kind = GeoDataManager.Kind.GEOSITE,
        )

        assertEquals(GeoDataManager.MAX_GEODATA_BYTES, copied)
        assertEquals(GeoDataManager.MAX_GEODATA_BYTES, output.bytesWritten)
    }

    @Test
    fun `bounded copy rejects unknown length geodata above max size`() {
        val output = CountingOutputStream()

        val exception = assertThrows(IOException::class.java) {
            GeoDataManager.copyBounded(
                input = FixedLengthInputStream(GeoDataManager.MAX_GEODATA_BYTES + 1L),
                output = output,
                kind = GeoDataManager.Kind.GEOSITE,
            )
        }

        assertTrue(exception.message.orEmpty().contains("exceeds"))
        assertEquals(GeoDataManager.MAX_GEODATA_BYTES, output.bytesWritten)
    }

    @Test
    fun `bounded copy rejects known length geodata before writing`() {
        val output = CountingOutputStream()

        val exception = assertThrows(IOException::class.java) {
            GeoDataManager.copyBounded(
                input = FixedLengthInputStream(1L),
                output = output,
                kind = GeoDataManager.Kind.GEOIP,
                totalBytes = GeoDataManager.MAX_GEODATA_BYTES + 1L,
            )
        }

        assertTrue(exception.message.orEmpty().contains("exceeds"))
        assertEquals(0L, output.bytesWritten)
    }

    private class FixedLengthInputStream(
        private var remainingBytes: Long,
    ) : InputStream() {
        override fun read(): Int {
            if (remainingBytes <= 0L) return -1
            remainingBytes--
            return 0
        }

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            if (remainingBytes <= 0L) return -1
            val count = minOf(length.toLong(), remainingBytes).toInt()
            remainingBytes -= count
            return count
        }
    }

    private class CountingOutputStream : OutputStream() {
        var bytesWritten = 0L
            private set

        override fun write(value: Int) {
            bytesWritten++
        }

        override fun write(buffer: ByteArray, offset: Int, length: Int) {
            bytesWritten += length
        }
    }
}
