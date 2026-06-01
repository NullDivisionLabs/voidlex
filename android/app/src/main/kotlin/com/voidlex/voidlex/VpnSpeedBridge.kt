package com.voidlex.voidlex

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges instantaneous tunnel throughput (`downBps`, `upBps`) from
 * [VoidVpnService] to the Flutter side.
 *
 * Lives next to [VpnEventBridge] as a process-wide singleton so the
 * service can push samples without holding a reference to the
 * FlutterEngine.
 *
 * The most recent sample is cached so a freshly-attached Flutter
 * listener (e.g. the TV home screen rebuilds after a configuration
 * change) immediately receives the latest values instead of having to
 * wait up to one second for the next tick.
 */
object VpnSpeedBridge : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    @Volatile
    private var lastSample: Map<String, Any?>? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        lastSample?.let { events?.success(it) }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun emit(downBps: Double, upBps: Double) {
        val event: Map<String, Any?> = mapOf(
            "downBps" to downBps,
            "upBps" to upBps,
        )
        lastSample = event
        mainHandler.post { sink?.success(event) }
    }

    /**
     * Pushes a zeroed sample and clears the cache. Called when the
     * tunnel stops so the UI immediately falls back to the idle state
     * instead of holding the last live value forever.
     */
    fun reset() {
        lastSample = null
        val event: Map<String, Any?> = mapOf(
            "downBps" to 0.0,
            "upBps" to 0.0,
        )
        mainHandler.post { sink?.success(event) }
    }
}
