package com.voidlex.voidlex

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

enum class VoidLexWidgetSize {
    COMPACT,
    GLOBAL_PROXY,
    WIDE,
}

open class VoidLexAppWidgetProvider : AppWidgetProvider() {
    protected open val fixedWidgetSize: VoidLexWidgetSize? =
        VoidLexWidgetSize.WIDE

    // Widget click handling is delegated to [WidgetActionActivity] via
    // PendingIntent.getActivity. Starting the VPN service from a
    // BroadcastReceiver leaves Android treating it as background-
    // initiated, and on some OEM stacks (Samsung One UI) the system
    // network agent for the new tun0 is not promoted to the default
    // route for other apps — Chrome/etc keep seeing CELLULAR+NOT_VPN
    // even though the tunnel established. Routing through a
    // transparent foreground Activity sidesteps that. Mirrors v2rayNG
    // / v2raytun's ScSwitchActivity pattern.
    //
    // Note: AppWidgetProvider still receives APPWIDGET_UPDATE etc. —
    // those are handled by [onUpdate] below. Only our custom click
    // actions were moved to the Activity.

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        updateWidgets(
            context.applicationContext,
            appWidgetManager,
            appWidgetIds,
            fixedWidgetSize,
            this::class.java,
        )
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        updateWidgets(
            context.applicationContext,
            appWidgetManager,
            intArrayOf(appWidgetId),
            fixedWidgetSize,
            this::class.java,
        )
    }

    companion object {
        // Legacy broadcast actions. Kept ONLY for backward-compat in case a
        // stale PendingIntent from a previous install still fires
        // post-update — [onReceive] inherits from AppWidgetProvider and
        // simply ignores them. New PendingIntents target WidgetActionActivity.
        private const val ACTION_OPEN_APP =
            "com.voidlex.voidlex.action.WIDGET_OPEN_APP"

        // State strings the [VpnRuntimeState] snapshot emits. Used by
        // [RuntimeUi.from] below to pick the right RemoteViews glyphs.
        private const val STATE_CONNECTED = "connected"
        private const val STATE_CONNECTING = "connecting"
        private const val STATE_ERROR = "error"

        private const val COLOR_BG = 0xFF0E1013.toInt()
        private const val COLOR_FG = 0xFFE9EAEB.toInt()
        private const val COLOR_FG_MUTED = 0xFFC5C7CB.toInt()
        private const val COLOR_FG_DIM = 0xFF9A9DA3.toInt()
        private const val COLOR_OK = 0xFF34D399.toInt()
        private const val COLOR_OK_SOFT = 0xFFA6E2C2.toInt()
        private const val COLOR_WARN = 0xFFC8A14A.toInt()
        private const val COLOR_ERROR = 0xFFF87171.toInt()

        fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            fixedSize: VoidLexWidgetSize? = null,
            providerClass: Class<out AppWidgetProvider> = VoidLexWideAppWidgetProvider::class.java,
        ) {
            for (appWidgetId in appWidgetIds) {
                val views = buildViews(
                    context,
                    appWidgetManager,
                    appWidgetId,
                    fixedSize,
                    providerClass,
                )
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }

        private fun buildViews(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            fixedSize: VoidLexWidgetSize?,
            providerClass: Class<out AppWidgetProvider>,
        ): RemoteViews {
            val size = fixedSize ?: resolveSize(appWidgetManager, appWidgetId)
            val runtime = RuntimeUi.from(runtimeState())
            return when (size) {
                VoidLexWidgetSize.COMPACT -> {
                    RemoteViews(context.packageName, R.layout.widget_void_compact).apply {
                        setCompactHubState(runtime)
                        setOnClickPendingIntent(
                            R.id.widget_root,
                            activityPendingIntent(
                                context,
                                appWidgetId,
                                WidgetActionActivity.ACTION_TOGGLE,
                            ),
                        )
                    }
                }
                VoidLexWidgetSize.GLOBAL_PROXY -> {
                    val snapshot = QuickSettingsVpnConfigStore.widgetSnapshot(context)
                    RemoteViews(
                        context.packageName,
                        R.layout.widget_void_global_proxy_compact,
                    ).apply {
                        setGlobalProxyCompactHubState(snapshot.isGlobalProxy)
                        setOnClickPendingIntent(
                            R.id.widget_root,
                            activityPendingIntent(
                                context,
                                appWidgetId,
                                WidgetActionActivity.ACTION_TOGGLE_GLOBAL_PROXY,
                            ),
                        )
                    }
                }
                VoidLexWidgetSize.WIDE -> {
                    buildPanelViews(context, appWidgetId, runtime, providerClass)
                }
            }
        }

        private fun buildPanelViews(
            context: Context,
            appWidgetId: Int,
            runtime: RuntimeUi,
            providerClass: Class<out AppWidgetProvider>,
        ): RemoteViews {
            val snapshot = QuickSettingsVpnConfigStore.widgetSnapshot(context)
            val hasNode = snapshot.selectedNodeName != null
            val statusLabel = if (hasNode) runtime.statusLabel else "NO NODE"
            val exitLabel = snapshot.selectedNodeName ?: "NO NODE"
            val ipLabel = if (runtime.connectedLike && snapshot.selectedAddress != null) {
                snapshot.selectedAddress
            } else {
                "---.---.---.---"
            }

            return RemoteViews(
                context.packageName,
                R.layout.widget_void_panel,
            ).apply {
                setHubState(runtime)
                setTextViewText(R.id.widget_status_value, statusLabel)
                setTextColor(R.id.widget_status_value, if (hasNode) COLOR_FG else COLOR_WARN)
                setTextViewText(R.id.widget_exit_value, exitLabel)
                setTextViewText(R.id.widget_ip_value, ipLabel)

                setModeSegmentState(snapshot.isGlobalProxy)

                val toggleIntent = activityPendingIntent(
                    context,
                    appWidgetId,
                    WidgetActionActivity.ACTION_TOGGLE,
                )
                setOnClickPendingIntent(R.id.widget_root, toggleIntent)
                setOnClickPendingIntent(R.id.widget_hub_area, toggleIntent)
                setOnClickPendingIntent(
                    R.id.widget_title,
                    openAppPendingIntent(context, appWidgetId),
                )
                setOnClickPendingIntent(
                    R.id.widget_split_mode,
                    modePendingIntent(context, appWidgetId, globalProxy = false),
                )
                setOnClickPendingIntent(
                    R.id.widget_global_mode,
                    modePendingIntent(context, appWidgetId, globalProxy = true),
                )
            }
        }

        private fun RemoteViews.setCompactHubState(runtime: RuntimeUi) {
            setImageViewResource(R.id.widget_hub, runtime.compactTriangleRes)
            setImageViewResource(R.id.widget_hub_slash, runtime.slashRes)
        }

        private fun RemoteViews.setGlobalProxyCompactHubState(globalProxy: Boolean) {
            val triangleRes = if (globalProxy) {
                R.drawable.widget_triangle_global_proxy_on
            } else {
                R.drawable.widget_triangle_global_proxy_off
            }
            val slashRes = if (globalProxy) {
                R.drawable.widget_hub_slash_dark
            } else {
                R.drawable.widget_hub_slash_light
            }
            setImageViewResource(R.id.widget_hub, triangleRes)
            setImageViewResource(R.id.widget_hub_slash, slashRes)
        }

        private fun RemoteViews.setHubState(runtime: RuntimeUi) {
            setImageViewResource(R.id.widget_hub, runtime.triangleRes)
            setImageViewResource(R.id.widget_hub_slash, runtime.slashRes)
            setTextViewText(R.id.widget_hub_label, runtime.hubLabel)
            setTextColor(R.id.widget_hub_label, runtime.hubTextColor)
            setTextViewText(R.id.widget_hub_subtitle, runtime.hubSubtitle)
            setTextColor(R.id.widget_hub_subtitle, runtime.hubSubtitleColor)
        }

        private fun RemoteViews.setModeSegmentState(globalProxy: Boolean) {
            val splitBackground = if (globalProxy) {
                R.drawable.widget_mode_segment_inactive
            } else {
                R.drawable.widget_mode_segment_active
            }
            val globalBackground = if (globalProxy) {
                R.drawable.widget_mode_segment_active
            } else {
                R.drawable.widget_mode_segment_inactive
            }
            setInt(R.id.widget_split_mode, "setBackgroundResource", splitBackground)
            setInt(R.id.widget_global_mode, "setBackgroundResource", globalBackground)
            setTextColor(R.id.widget_split_mode, if (globalProxy) COLOR_FG_MUTED else COLOR_BG)
            setTextColor(R.id.widget_global_mode, if (globalProxy) COLOR_BG else COLOR_FG_MUTED)
        }

        private fun resolveSize(
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ): VoidLexWidgetSize {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            if (minWidth in 1 until 220) return VoidLexWidgetSize.COMPACT
            return VoidLexWidgetSize.WIDE
        }

        private fun runtimeState(): String =
            VpnRuntimeState.snapshot()["state"] as? String ?: "disconnected"

        /**
         * Builds a PendingIntent that launches [WidgetActionActivity].
         * Unlike `PendingIntent.getBroadcast`, this makes the VPN service
         * start happen from an Activity (foreground) context, which is
         * required on some OEM stacks for the new tun0 to be properly
         * promoted as the default route for other apps.
         *
         * `Uri.data` is unique per (appWidgetId, action) so the system
         * doesn't collapse different widget clicks into the same
         * PendingIntent.
         */
        private fun activityPendingIntent(
            context: Context,
            appWidgetId: Int,
            action: String,
        ): PendingIntent {
            val intent = Intent(context, WidgetActionActivity::class.java).apply {
                this.action = action
                data = Uri.parse("voidlex://widget/$appWidgetId/$action")
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
                addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            }
            return PendingIntent.getActivity(
                context,
                appWidgetId * 10 + actionCode(action),
                intent,
                pendingIntentFlags(),
            )
        }

        private fun modePendingIntent(
            context: Context,
            appWidgetId: Int,
            globalProxy: Boolean,
        ): PendingIntent {
            val intent = Intent(context, WidgetActionActivity::class.java).apply {
                action = WidgetActionActivity.ACTION_SET_MODE
                data = Uri.parse("voidlex://widget/$appWidgetId/mode/$globalProxy")
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra(WidgetActionActivity.EXTRA_GLOBAL_PROXY, globalProxy)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
                addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            }
            return PendingIntent.getActivity(
                context,
                appWidgetId * 10 + if (globalProxy) 3 else 2,
                intent,
                pendingIntentFlags(),
            )
        }

        private fun openAppPendingIntent(context: Context, appWidgetId: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_OPEN_APP
                data = Uri.parse("voidlex://widget/$appWidgetId/open")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            return PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 4,
                intent,
                pendingIntentFlags(),
            )
        }

        private fun pendingIntentFlags(): Int =
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        private fun actionCode(action: String): Int {
            return when (action) {
                WidgetActionActivity.ACTION_TOGGLE -> 1
                WidgetActionActivity.ACTION_SET_MODE -> 2
                WidgetActionActivity.ACTION_TOGGLE_GLOBAL_PROXY -> 5
                else -> 9
            }
        }

        private data class RuntimeUi(
            val statusLabel: String,
            val triangleRes: Int,
            val compactTriangleRes: Int,
            val connectedLike: Boolean,
            val slashRes: Int,
            val hubLabel: String,
            val hubSubtitle: String,
            val hubTextColor: Int,
            val hubSubtitleColor: Int,
        ) {
            companion object {
                fun from(state: String): RuntimeUi {
                    return when (state) {
                        STATE_CONNECTED -> RuntimeUi(
                            statusLabel = "SECURE",
                            triangleRes = R.drawable.widget_triangle_on,
                            compactTriangleRes = R.drawable.widget_triangle_on,
                            connectedLike = true,
                            slashRes = R.drawable.widget_hub_slash_dark,
                            hubLabel = "ACTIVE",
                            hubSubtitle = "OK TO DISCONNECT",
                            hubTextColor = COLOR_BG,
                            hubSubtitleColor = 0x990E1013.toInt(),
                        )
                        STATE_CONNECTING -> RuntimeUi(
                            statusLabel = "NEGOTIATING",
                            triangleRes = R.drawable.widget_triangle_connecting,
                            compactTriangleRes = R.drawable.widget_triangle_compact_connecting,
                            connectedLike = true,
                            slashRes = R.drawable.widget_hub_slash_light,
                            hubLabel = "CONNECTING",
                            hubSubtitle = "NEGOTIATING",
                            hubTextColor = COLOR_FG,
                            hubSubtitleColor = COLOR_FG_DIM,
                        )
                        STATE_ERROR -> RuntimeUi(
                            statusLabel = "ERROR",
                            triangleRes = R.drawable.widget_triangle_error,
                            compactTriangleRes = R.drawable.widget_triangle_error,
                            connectedLike = false,
                            slashRes = R.drawable.widget_hub_slash_light,
                            hubLabel = "RETRY",
                            hubSubtitle = "OPEN APP",
                            hubTextColor = COLOR_FG,
                            hubSubtitleColor = COLOR_FG_DIM,
                        )
                        else -> RuntimeUi(
                            statusLabel = "IDLE",
                            triangleRes = R.drawable.widget_triangle_off,
                            compactTriangleRes = R.drawable.widget_triangle_compact_off,
                            connectedLike = false,
                            slashRes = R.drawable.widget_hub_slash_light,
                            hubLabel = "CONNECT",
                            hubSubtitle = "OK / SELECT",
                            hubTextColor = COLOR_FG,
                            hubSubtitleColor = COLOR_FG_DIM,
                        )
                    }
                }
            }
        }
    }
}

class VoidLexCompactAppWidgetProvider : VoidLexAppWidgetProvider() {
    override val fixedWidgetSize = VoidLexWidgetSize.COMPACT
}

class VoidLexGlobalProxyAppWidgetProvider : VoidLexAppWidgetProvider() {
    override val fixedWidgetSize = VoidLexWidgetSize.GLOBAL_PROXY
}

class VoidLexWideAppWidgetProvider : VoidLexAppWidgetProvider() {
    override val fixedWidgetSize = VoidLexWidgetSize.WIDE
}
