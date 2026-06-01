package com.voidlex.voidlex

import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.quicksettings.TileService

internal object QuickSettingsTileUpdater {
    fun requestUpdate(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        runCatching {
            TileService.requestListeningState(
                context,
                ComponentName(context.packageName, "${context.packageName}.VoidLexTileService"),
            )
        }
    }
}
