package com.voidtunnel.voidtunnel

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context

internal object VoidTunnelWidgetUpdater {
    private data class ProviderSpec(
        val providerClass: Class<out AppWidgetProvider>,
        val size: VoidTunnelWidgetSize,
    )

    private val providers = listOf(
        ProviderSpec(
            VoidTunnelCompactAppWidgetProvider::class.java,
            VoidTunnelWidgetSize.COMPACT,
        ),
        ProviderSpec(
            VoidTunnelGlobalProxyAppWidgetProvider::class.java,
            VoidTunnelWidgetSize.GLOBAL_PROXY,
        ),
        ProviderSpec(
            VoidTunnelWideAppWidgetProvider::class.java,
            VoidTunnelWidgetSize.WIDE,
        ),
    )

    fun requestUpdate(context: Context) {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)
        for (provider in providers) {
            val ids = manager.getAppWidgetIds(
                ComponentName(appContext, provider.providerClass),
            )
            if (ids.isEmpty()) continue
            VoidTunnelAppWidgetProvider.updateWidgets(
                context = appContext,
                appWidgetManager = manager,
                appWidgetIds = ids,
                fixedSize = provider.size,
                providerClass = provider.providerClass,
            )
        }
    }
}
