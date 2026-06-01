package com.voidlex.voidlex

import android.net.DnsResolver
import android.net.Network
import android.os.Build
import android.os.CancellationSignal
import android.system.ErrnoException
import io.nekohasekai.libbox.ExchangeContext
import io.nekohasekai.libbox.LocalDNSTransport
import java.net.InetAddress
import java.net.UnknownHostException
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

internal class LibboxLocalDnsTransport(
    private val networkProvider: () -> Network?,
) : LocalDNSTransport {
    private companion object {
        const val TAG = "LibboxLocalDnsTransport"
        const val DNS_TIMEOUT_MS = 5_000L
    }

    // DnsResolver wants an Executor to deliver its async callbacks on; we
    // use a dedicated pool instead of borrowing Dispatchers.IO so libbox's
    // DNS path stays isolated from the rest of the app's coroutines.
    private val callbackExecutor = Executors.newCachedThreadPool { runnable ->
        Thread(runnable, "LibboxLocalDns").apply { isDaemon = true }
    }

    // Single-threaded scheduler that fires the timeout fallbacks. A
    // dedicated thread is fine: timeouts only run when DNS got stuck, so
    // we never queue more than a handful of tasks at once.
    private val timeoutScheduler: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "LibboxLocalDns-Timeout").apply { isDaemon = true }
        }

    override fun raw(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    override fun exchange(ctx: ExchangeContext?, message: ByteArray?) {
        if (ctx == null || message == null) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            ctx.errorCode(2)
            return
        }

        val network = networkProvider()
        if (network == null) {
            ctx.errorCode(2)
            return
        }

        // Previously this method wrapped `DnsResolver.rawQuery` inside
        // `runBlocking { withTimeoutOrNull { suspendCoroutine { … } } }`,
        // which served only to wait for the timeout — it was the libbox
        // worker thread that ended up parked. With many concurrent DNS
        // requests (a page with dozens of subresources) the thread pool
        // backed up. The handler is now fire-and-forget: DnsResolver
        // delivers onAnswer/onError to our executor, and a scheduled
        // timeout task fills in errorCode(2) if neither arrives in time.
        val signal = CancellationSignal()
        ctx.onCancel(signal::cancel)
        val resolved = AtomicBoolean(false)
        val timeoutFuture = timeoutScheduler.schedule({
            if (resolved.compareAndSet(false, true)) {
                runCatching { signal.cancel() }
                ctx.errorCode(2)
                AppLogger.w(TAG, "DNS raw query timed out after ${DNS_TIMEOUT_MS}ms")
            }
        }, DNS_TIMEOUT_MS, TimeUnit.MILLISECONDS)

        runCatching {
            DnsResolver.getInstance().rawQuery(
                network,
                message,
                DnsResolver.FLAG_NO_RETRY,
                callbackExecutor,
                signal,
                object : DnsResolver.Callback<ByteArray> {
                    override fun onAnswer(answer: ByteArray, rcode: Int) {
                        if (!resolved.compareAndSet(false, true)) return
                        timeoutFuture.cancel(false)
                        if (rcode == 0) {
                            ctx.rawSuccess(answer)
                        } else {
                            ctx.errorCode(rcode)
                        }
                    }

                    override fun onError(error: DnsResolver.DnsException) {
                        if (!resolved.compareAndSet(false, true)) return
                        timeoutFuture.cancel(false)
                        val cause = error.cause
                        if (cause is ErrnoException) {
                            ctx.errnoCode(cause.errno)
                        } else {
                            ctx.errorCode(2)
                        }
                    }
                },
            )
        }.onFailure {
            // rawQuery can throw synchronously on misuse (null network,
            // closed handle). Make sure we still resolve the ctx so libbox
            // doesn't dangle on this request.
            if (resolved.compareAndSet(false, true)) {
                timeoutFuture.cancel(false)
                ctx.errorCode(2)
                AppLogger.w(TAG, "DnsResolver.rawQuery threw synchronously", it)
            }
        }
    }

    override fun lookup(ctx: ExchangeContext?, network: String?, domain: String?) {
        if (ctx == null || domain.isNullOrBlank()) return
        val activeNetwork = networkProvider()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && activeNetwork != null) {
            lookupWithDnsResolver(ctx, activeNetwork, network, domain)
        } else {
            // InetAddress.getAllByName blocks the calling thread on the
            // system resolver. We offload to our background pool so the
            // libbox worker can keep dispatching.
            callbackExecutor.execute { lookupWithInetAddress(ctx, domain) }
        }
    }

    private fun lookupWithDnsResolver(
        ctx: ExchangeContext,
        activeNetwork: Network,
        network: String?,
        domain: String,
    ) {
        val signal = CancellationSignal()
        ctx.onCancel(signal::cancel)
        val resolved = AtomicBoolean(false)
        val timeoutFuture = timeoutScheduler.schedule({
            if (resolved.compareAndSet(false, true)) {
                runCatching { signal.cancel() }
                ctx.errorCode(2)
                AppLogger.w(TAG, "DNS lookup for $domain timed out after ${DNS_TIMEOUT_MS}ms")
            }
        }, DNS_TIMEOUT_MS, TimeUnit.MILLISECONDS)

        val callback = object : DnsResolver.Callback<List<InetAddress>> {
            override fun onAnswer(answer: List<InetAddress>, rcode: Int) {
                if (!resolved.compareAndSet(false, true)) return
                timeoutFuture.cancel(false)
                if (rcode == 0) {
                    ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
                } else {
                    ctx.errorCode(rcode)
                }
            }

            override fun onError(error: DnsResolver.DnsException) {
                if (!resolved.compareAndSet(false, true)) return
                timeoutFuture.cancel(false)
                val cause = error.cause
                if (cause is ErrnoException) {
                    ctx.errnoCode(cause.errno)
                } else {
                    ctx.errorCode(2)
                }
            }
        }

        val type = when {
            network?.endsWith("4") == true -> DnsResolver.TYPE_A
            network?.endsWith("6") == true -> DnsResolver.TYPE_AAAA
            else -> null
        }

        runCatching {
            if (type != null) {
                DnsResolver.getInstance().query(
                    activeNetwork,
                    domain,
                    type,
                    DnsResolver.FLAG_NO_RETRY,
                    callbackExecutor,
                    signal,
                    callback,
                )
            } else {
                DnsResolver.getInstance().query(
                    activeNetwork,
                    domain,
                    DnsResolver.FLAG_NO_RETRY,
                    callbackExecutor,
                    signal,
                    callback,
                )
            }
        }.onFailure {
            if (resolved.compareAndSet(false, true)) {
                timeoutFuture.cancel(false)
                ctx.errorCode(2)
                AppLogger.w(TAG, "DnsResolver.query threw synchronously", it)
            }
        }
    }

    private fun lookupWithInetAddress(ctx: ExchangeContext, domain: String) {
        val answer = try {
            InetAddress.getAllByName(domain)
        } catch (_: UnknownHostException) {
            ctx.errorCode(3)
            return
        }
        ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
    }
}
