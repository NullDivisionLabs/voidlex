package com.voidlex.voidlex

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.widget.Toast
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Transparent, no-UI bridge between the home-screen widgets and the VPN
 * service. Widget [PendingIntent]s target THIS Activity instead of the
 * widget receiver directly.
 *
 * Why an Activity? When `startForegroundService` is invoked from a
 * [android.content.BroadcastReceiver] (the AppWidgetProvider's natural
 * dispatch site), Android treats the VPN service as
 * "background-initiated". On some OEM stacks (Samsung One UI most
 * notably) this means the system network agent that gets registered for
 * the new `tun0` is not promoted to the default route for other apps —
 * Chrome/etc keep seeing `Transports: CELLULAR ... NOT_VPN` even though
 * `VpnService.Builder.establish()` succeeded.
 *
 * Routing through a foreground Activity (no_history, excluded from
 * recents, no UI) sidesteps that: the service start happens from an
 * Activity context, the system tags it as a regular foreground-initiated
 * VPN, and the routing tables fully take effect for all non-disallowed
 * apps.
 *
 * Mirrors v2rayNG / v2raytun's `ScSwitchActivity` pattern.
 */
class WidgetActionActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // No setContentView — we never want a visible UI. The
        // <activity android:theme="Transparent" /> entry in AndroidManifest
        // keeps the surface unrendered.

        val action = intent?.action
        AppLogger.i(TAG, "onCreate action=$action")

        when (action) {
            ACTION_TOGGLE -> launchAsync { handleToggle(applicationContext) }
            ACTION_SET_MODE -> {
                val globalProxy = intent.getBooleanExtra(EXTRA_GLOBAL_PROXY, false)
                launchAsync { handleSetMode(applicationContext, globalProxy) }
            }
            ACTION_TOGGLE_GLOBAL_PROXY -> launchAsync {
                handleToggleGlobalProxy(applicationContext)
            }
            else -> {
                AppLogger.w(TAG, "onCreate: unknown action=$action, finishing")
                finish()
                return
            }
        }
    }

    /**
     * Kicks off the work coroutine and finishes the Activity immediately
     * — we don't need to keep it alive for the duration of the stop/start
     * dance, the VPN service handles its own lifecycle. The service was
     * started from this Activity's context, which is the bit Android
     * cares about for the foreground-vs-background classification.
     */
    private fun launchAsync(block: suspend () -> Unit) {
        actionScope.launch {
            try {
                block()
            } catch (t: Throwable) {
                AppLogger.e(TAG, "WidgetAction failed", t)
            }
        }
        // Finish synchronously. The coroutine continues on the IO
        // dispatcher and the service it kicked off survives independently.
        // The Theme.NoDisplay theme already suppresses any window
        // transition, so we don't need overridePendingTransition (which
        // has also been deprecated since API 34).
        finish()
    }

    private suspend fun handleToggle(context: Context) {
        val initialState = runtimeState()
        AppLogger.i(TAG, "handleToggle entry state=$initialState")
        when (initialState) {
            STATE_CONNECTED, STATE_CONNECTING -> {
                requestDisconnect(context)
                VoidLexWidgetUpdater.requestUpdate(context)
                AppLogger.i(TAG, "handleToggle: requested disconnect, exiting")
                return
            }
        }

        val startConfig = QuickSettingsVpnConfigStore.buildStartConfig(context)
        if (startConfig == null) {
            AppLogger.w(TAG, "handleToggle: no start config (no node selected)")
            showToast(context, "No node selected")
            openApp(context)
            VoidLexWidgetUpdater.requestUpdate(context)
            return
        }

        if (startConfig.requiresVpnPermission && VpnService.prepare(context) != null) {
            AppLogger.w(TAG, "handleToggle: VPN permission missing, redirecting to app")
            showToast(context, "Open Void//Lex once to grant VPN permission")
            openApp(context)
            VoidLexWidgetUpdater.requestUpdate(context)
            return
        }

        // Defensive stop only when something is actually running or was
        // running very recently — saves a wasted 500 ms on cold starts.
        if (VpnRuntimeState.recentlyHadRuntime(STOP_RECENT_WINDOW_MS)) {
            AppLogger.i(
                TAG,
                "handleToggle: defensive stop before start (recentTeardown=true)",
            )
            for (stopIntent in QuickSettingsVpnConfigStore.buildStopIntents(
                context,
                startConfig.runMode,
            )) {
                runCatching { context.startService(stopIntent) }
            }
            val settled = VpnRuntimeState.awaitTerminal(STOP_AWAIT_TIMEOUT_MS)
            if (!settled) {
                AppLogger.w(
                    TAG,
                    "handleToggle: stop did not settle within ${STOP_AWAIT_TIMEOUT_MS}ms",
                )
            }
            delay(POST_STOP_SETTLE_MS)
        } else {
            AppLogger.d(
                TAG,
                "handleToggle: cold start (no recent runtime), skipping defensive stop",
            )
        }

        AppLogger.i(
            TAG,
            "handleToggle: startForegroundService node=${startConfig.selectedNodeName} " +
                "runMode=${startConfig.runMode.wireName}",
        )
        val startResult = runCatching {
            ContextCompat.startForegroundService(context, startConfig.intent)
        }
        if (startResult.isSuccess) {
            showToast(context, "Connecting: ${startConfig.selectedNodeName}")
        } else {
            val err = startResult.exceptionOrNull()
            AppLogger.e(TAG, "handleToggle: startForegroundService failed", err)
            showToast(context, err?.message ?: "Failed to start VPN")
        }
        VoidLexWidgetUpdater.requestUpdate(context)
    }

    private suspend fun handleSetMode(context: Context, globalProxy: Boolean) {
        val current = QuickSettingsVpnConfigStore.widgetSnapshot(context).isGlobalProxy
        AppLogger.i(
            TAG,
            "handleSetMode entry current=$current target=$globalProxy state=${runtimeState()}",
        )
        if (current == globalProxy) {
            AppLogger.d(TAG, "handleSetMode: no change, exiting")
            VoidLexWidgetUpdater.requestUpdate(context)
            return
        }

        QuickSettingsVpnConfigStore.saveGlobalProxy(context, globalProxy)

        val wasActive = when (runtimeState()) {
            STATE_CONNECTED, STATE_CONNECTING -> true
            else -> false
        }
        AppLogger.i(TAG, "handleSetMode: wasActive=$wasActive")

        if (wasActive) {
            val restartConfig = QuickSettingsVpnConfigStore.buildStartConfig(context)
            if (restartConfig == null) {
                AppLogger.w(TAG, "handleSetMode: no restart config, opening app")
                openApp(context)
            } else {
                AppLogger.i(TAG, "handleSetMode: sending ACTION_DISCONNECT")
                for (stopIntent in QuickSettingsVpnConfigStore.buildStopIntents(
                    context,
                    restartConfig.runMode,
                )) {
                    runCatching { context.startService(stopIntent) }
                }
                val settled = VpnRuntimeState.awaitTerminal(STOP_AWAIT_TIMEOUT_MS)
                AppLogger.i(TAG, "handleSetMode: stop settled=$settled")
                if (!settled) {
                    AppLogger.w(
                        TAG,
                        "handleSetMode: stop did not settle within ${STOP_AWAIT_TIMEOUT_MS}ms",
                    )
                }
                delay(POST_STOP_SETTLE_MS)
                AppLogger.i(
                    TAG,
                    "handleSetMode: startForegroundService node=${restartConfig.selectedNodeName} " +
                        "globalProxy=$globalProxy runMode=${restartConfig.runMode.wireName}",
                )
                val startResult = runCatching {
                    ContextCompat.startForegroundService(context, restartConfig.intent)
                }
                if (startResult.isFailure) {
                    val err = startResult.exceptionOrNull()
                    AppLogger.e(
                        TAG,
                        "handleSetMode: startForegroundService failed",
                        err,
                    )
                    showToast(context, err?.message ?: "Failed to restart VPN")
                }
            }
        }

        VoidLexWidgetUpdater.requestUpdate(context)
    }

    private suspend fun handleToggleGlobalProxy(context: Context) {
        val current = QuickSettingsVpnConfigStore.widgetSnapshot(context).isGlobalProxy
        handleSetMode(context, globalProxy = !current)
    }

    private fun requestDisconnect(context: Context) {
        for (stopIntent in QuickSettingsVpnConfigStore.buildStopIntents(
            context,
            QuickSettingsVpnConfigStore.currentRunMode(context),
        )) {
            runCatching { context.startService(stopIntent) }
        }
    }

    private fun openApp(context: Context) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(launchIntent) }
    }

    private fun runtimeState(): String =
        VpnRuntimeState.snapshot()["state"] as? String ?: "disconnected"

    private suspend fun showToast(context: Context, message: String) {
        withContext(Dispatchers.Main) {
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        private const val TAG = "WidgetAction"

        // Action constants are duplicated here intentionally — the widget
        // provider's companion is private, and these have to be Intent
        // actions visible to the OS when the PendingIntent fires.
        const val ACTION_TOGGLE =
            "com.voidlex.voidlex.action.WIDGET_ACTIVITY_TOGGLE"
        const val ACTION_SET_MODE =
            "com.voidlex.voidlex.action.WIDGET_ACTIVITY_SET_MODE"
        const val ACTION_TOGGLE_GLOBAL_PROXY =
            "com.voidlex.voidlex.action.WIDGET_ACTIVITY_TOGGLE_GLOBAL_PROXY"
        const val EXTRA_GLOBAL_PROXY = "globalProxy"

        private const val STATE_CONNECTED = "connected"
        private const val STATE_CONNECTING = "connecting"

        private const val STOP_AWAIT_TIMEOUT_MS = 5_000L
        private const val POST_STOP_SETTLE_MS = 500L
        private const val STOP_RECENT_WINDOW_MS = 3_000L

        private val actionScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    }
}
