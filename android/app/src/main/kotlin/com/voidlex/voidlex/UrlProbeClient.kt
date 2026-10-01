package com.voidlex.voidlex

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import io.flutter.plugin.common.MethodChannel

/** Messenger IPC keeps probe cores and libbox global state outside the VPN process. */
internal class UrlProbeClient(private val context: Context) : ServiceConnection {
    private data class Pending(val data: Bundle, val result: MethodChannel.Result, val deadline: Runnable)
    private val pending = linkedMapOf<String, Pending>()
    private val handler = Handler(Looper.getMainLooper())
    private var remote: Messenger? = null
    private var bound = false
    private val replies = Messenger(Handler(Looper.getMainLooper()) { message ->
        if (message.what == UrlProbeService.RESULT) {
            val data = message.data
            val id = data.getString("requestId")
            val request = pending.remove(id)
            request?.let { handler.removeCallbacks(it.deadline) }
            request?.result?.success(mapOf(
                "requestId" to id,
                "status" to data.getString("status"),
                "latencyMs" to if (data.containsKey("latencyMs")) data.getLong("latencyMs") else null,
                "detail" to data.getString("detail"),
            ))
        }
        true
    })

    fun probe(id: String, url: String, config: Bundle, result: MethodChannel.Result) {
        if (pending.containsKey(id)) { result.error("duplicate_probe", "Duplicate probe ID", null); return }
        val data = Bundle().apply {
            putString("requestId", id)
            putString("url", url)
            putBundle("config", config)
        }
        val deadline = Runnable {
            if (pending.containsKey(id)) {
                runCatching { remote?.send(Message.obtain(null, UrlProbeService.CANCEL)) }
                failPending("Probe service timed out")
            }
        }
        pending[id] = Pending(data, result, deadline)
        if (remote != null) send(data)
        else if (!bound) {
            bound = context.bindService(Intent(context, UrlProbeService::class.java), this, Context.BIND_AUTO_CREATE)
            if (!bound) failPending("Probe service unavailable")
        }
        if (pending.containsKey(id)) handler.postDelayed(deadline, 45_000)
    }

    private fun send(data: Bundle) {
        try {
            remote?.send(Message.obtain(null, UrlProbeService.START).apply {
                this.data = data
                replyTo = replies
            })
        } catch (_: Exception) { failPending("Probe service disconnected") }
    }

    override fun onServiceConnected(name: ComponentName, service: IBinder) {
        remote = Messenger(service)
        pending.values.toList().forEach { send(it.data) }
    }
    override fun onServiceDisconnected(name: ComponentName) {
        remote = null
        failPending("Probe service disconnected")
    }
    override fun onBindingDied(name: ComponentName) { close() }
    override fun onNullBinding(name: ComponentName) { close() }

    fun cancelAll() {
        runCatching { remote?.send(Message.obtain(null, UrlProbeService.CANCEL)) }
        val requests = pending.toMap()
        pending.clear()
        requests.forEach { (id, value) ->
            handler.removeCallbacks(value.deadline)
            value.result.success(mapOf("requestId" to id, "status" to "cancelled"))
        }
    }
    private fun failPending(detail: String) {
        val requests = pending.toMap()
        pending.clear()
        requests.forEach { (id, value) ->
            handler.removeCallbacks(value.deadline)
            value.result.success(mapOf("requestId" to id, "status" to "error", "detail" to detail))
        }
    }
    fun close() {
        cancelAll()
        handler.removeCallbacksAndMessages(null)
        if (bound) runCatching { context.unbindService(this) }
        bound = false
        remote = null
    }
}
