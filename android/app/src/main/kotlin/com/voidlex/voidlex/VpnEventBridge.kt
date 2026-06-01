package com.voidlex.voidlex

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges VPN state updates from [VoidVpnService] to the Flutter side.
 *
 * Kept as a process-wide singleton so the service (same process) can push
 * events without holding a direct reference to the FlutterEngine.
 *
 * Events are delivered on the main thread as required by Flutter platform
 * channels. A small FIFO buffer retains the last few events so if the
 * Flutter listener connects slightly after the service fires its first
 * event, we don't drop it.
 */
object VpnEventBridge : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private const val MAX_BUFFER = 16

    @Volatile
    private var sink: EventChannel.EventSink? = null
    private val buffer: ArrayDeque<Map<String, Any?>> = ArrayDeque()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        // Replay buffered events so the Flutter side catches up on state.
        synchronized(buffer) {
            for (event in buffer) {
                events?.success(event)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun emit(state: String, message: String? = null) {
        emit(state = state, message = message, extras = emptyMap())
    }

    /**
     * Emits an event with arbitrary key/value extras alongside the standard
     * `state`/`message` fields. Used by surfaces that need to push richer
     * payloads (e.g. widget-initiated preference changes).
     */
    fun emit(state: String, message: String? = null, extras: Map<String, Any?>) {
        val event: Map<String, Any?> = buildMap {
            put("state", state)
            put("message", message)
            for ((key, value) in extras) {
                if (key == "state" || key == "message") continue
                put(key, value)
            }
        }
        synchronized(buffer) {
            buffer.addLast(event)
            while (buffer.size > MAX_BUFFER) {
                buffer.removeFirst()
            }
        }
        mainHandler.post {
            sink?.success(event)
        }
    }
}
