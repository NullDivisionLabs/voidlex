package com.voidlex.voidlex

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context

internal object VoidLexWidgetUpdater {
    private data class ProviderSpec(
        val providerClass: Class<out AppWidgetProvider>,
        val size: VoidLexWidgetSize,
    )

    private val providers = listOf(
        ProviderSpec(
            VoidLexCompactAppWidgetProvider::class.java,
            VoidLexWidgetSize.COMPACT,
        ),
        ProviderSpec(
            VoidLexGlobalProxyAppWidgetProvider::class.java,
            VoidLexWidgetSize.GLOBAL_PROXY,
        ),
        ProviderSpec(
            VoidLexWideAppWidgetProvider::class.java,
            VoidLexWidgetSize.WIDE,
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
            VoidLexAppWidgetProvider.updateWidgets(
                context = appContext,
                appWidgetManager = manager,
                appWidgetIds = ids,
                fixedSize = provider.size,
                providerClass = provider.providerClass,
            )
        }
    }
}
