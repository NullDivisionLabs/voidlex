package com.voidtunnel.voidtunnel

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges incoming `voidtunnel://` deep links from the OS to the Flutter
 * side. Mirrors [VpnEventBridge]:
 *
 *  - The native bridge buffers links emitted before Flutter starts
 *    listening, so the cold-launch URL is never dropped.
 *  - The cold-launch URL is also exposed once via the companion
 *    `void.deeplink` MethodChannel's `consumeInitial` method; the Flutter
 *    side decides which side to consume on.
 *
 * Lives as a process-wide singleton because MainActivity may be recreated
 * (configuration changes, deep-link relaunch) while the same FlutterEngine
 * is in use.
 */
object DeepLinkBridge : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private const val MAX_BUFFER = 8

    @Volatile
    private var sink: EventChannel.EventSink? = null
    private val buffer: ArrayDeque<String> = ArrayDeque()
    private var pendingInitial: String? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        synchronized(buffer) {
            for (link in buffer) {
                events?.success(link)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /**
     * Emit a deep link from native code. If [isInitial] is true the link is
     * also stashed for the next [consumeInitial] call, so a cold-launch URL
     * can be retrieved either through the event stream or the one-shot
     * method, depending on which Flutter listener wins the race.
     */
    fun emit(link: String, isInitial: Boolean = false) {
        if (link.isBlank()) return
        synchronized(buffer) {
            buffer.addLast(link)
            while (buffer.size > MAX_BUFFER) {
                buffer.removeFirst()
            }
            if (isInitial) {
                pendingInitial = link
            }
        }
        mainHandler.post {
            sink?.success(link)
        }
    }

    /**
     * One-shot read of the cold-launch URL. Returns null on subsequent
     * calls until another initial URL is emitted.
     */
    fun consumeInitial(): String? {
        synchronized(buffer) {
            val value = pendingInitial
            pendingInitial = null
            return value
        }
    }
}
