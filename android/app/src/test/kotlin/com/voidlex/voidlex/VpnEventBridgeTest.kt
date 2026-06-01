package com.voidlex.voidlex

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Verifies the shape of the events the bridge buffers when no Flutter
 * listener is attached. The buffer is the only contract surface visible
 * to unit tests — the actual EventChannel sink delivery happens against
 * a real Flutter engine.
 */
class VpnEventBridgeTest {

    @Test
    fun `emit with message preserves state and message`() {
        clearBuffer()
        VpnEventBridge.emit(state = "connecting", message = "negotiating")
        val event = lastBufferedEvent()
        assertEquals("connecting", event["state"])
        assertEquals("negotiating", event["message"])
        // No extras were passed — the buffer entry should only have the
        // two canonical keys.
        assertEquals(2, event.size)
    }

    @Test
    fun `emit with extras adds payload alongside state`() {
        clearBuffer()
        VpnEventBridge.emit(
            state = "globalProxyChanged",
            extras = mapOf("globalProxy" to true),
        )
        val event = lastBufferedEvent()
        assertEquals("globalProxyChanged", event["state"])
        assertNull(event["message"])
        assertEquals(true, event["globalProxy"])
    }

    @Test
    fun `emit ignores extras that would shadow state and message`() {
        clearBuffer()
        VpnEventBridge.emit(
            state = "globalProxyChanged",
            message = null,
            extras = mapOf(
                "state" to "should-be-ignored",
                "message" to "should-be-ignored-too",
                "globalProxy" to false,
            ),
        )
        val event = lastBufferedEvent()
        assertEquals("globalProxyChanged", event["state"])
        assertNull(event["message"])
        assertEquals(false, event["globalProxy"])
    }

    @Test
    fun `buffer caps at MAX_BUFFER entries`() {
        clearBuffer()
        // Push 20 events; only the most recent 16 should be retained.
        for (i in 0 until 20) {
            VpnEventBridge.emit(state = "tick-$i")
        }
        val buffer = bufferContents()
        assertEquals(16, buffer.size)
        assertEquals("tick-4", buffer.first()["state"])
        assertEquals("tick-19", buffer.last()["state"])
    }

    @Test
    fun `default emit overload accepts null message`() {
        clearBuffer()
        VpnEventBridge.emit("disconnected")
        val event = lastBufferedEvent()
        assertEquals("disconnected", event["state"])
        assertTrue(event.containsKey("message"))
        assertNull(event["message"])
    }

    @Test
    fun `emit overload without extras is empty-extras shorthand`() {
        clearBuffer()
        VpnEventBridge.emit("error", "x")
        val event = lastBufferedEvent()
        assertEquals("error", event["state"])
        assertEquals("x", event["message"])
        assertFalse(event.containsKey("globalProxy"))
    }

    private fun lastBufferedEvent(): Map<String, Any?> {
        val buffer = bufferContents()
        check(buffer.isNotEmpty()) { "expected at least one buffered event" }
        return buffer.last()
    }

    @Suppress("UNCHECKED_CAST")
    private fun bufferContents(): List<Map<String, Any?>> {
        val field = VpnEventBridge::class.java.getDeclaredField("buffer")
        field.isAccessible = true
        return (field.get(VpnEventBridge) as ArrayDeque<Map<String, Any?>>).toList()
    }

    private fun clearBuffer() {
        val field = VpnEventBridge::class.java.getDeclaredField("buffer")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val buffer = field.get(VpnEventBridge) as ArrayDeque<Map<String, Any?>>
        buffer.clear()
    }
}
