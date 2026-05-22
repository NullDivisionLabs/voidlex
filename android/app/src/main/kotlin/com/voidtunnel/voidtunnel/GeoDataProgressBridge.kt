package com.voidtunnel.voidtunnel

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object GeoDataProgressBridge : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun emit(kind: String, percent: Int) {
        val event = mapOf(
            "kind" to kind,
            "percent" to if (percent < 0) -1 else percent.coerceIn(0, 100),
        )
        mainHandler.post { sink?.success(event) }
    }
}
