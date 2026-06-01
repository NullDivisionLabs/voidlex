package com.voidlex.voidlex

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast
import androidx.core.content.ContextCompat

class VoidLexTileService : TileService() {
    companion object {
        private const val STATE_CONNECTED = "connected"
        private const val STATE_CONNECTING = "connecting"

        fun requestUpdate(context: Context) {
            QuickSettingsTileUpdater.requestUpdate(context)
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()

        when (runtimeState()) {
            STATE_CONNECTED, STATE_CONNECTING -> {
                requestDisconnect()
                updateTile(stateOverride = Tile.STATE_INACTIVE, subtitleOverride = "Disconnecting")
                return
            }
        }

        val startConfig = QuickSettingsVpnConfigStore.buildStartConfig(this)
        if (startConfig == null) {
            Toast.makeText(this, "No node selected", Toast.LENGTH_SHORT).show()
            openAppAndCollapse()
            updateTile()
            return
        }

        if (startConfig.requiresVpnPermission && VpnService.prepare(this) != null) {
            Toast.makeText(
                this,
                "Open Void//Lex once to grant VPN permission",
                Toast.LENGTH_SHORT,
            ).show()
            openAppAndCollapse()
            updateTile()
            return
        }

        runCatching {
            ContextCompat.startForegroundService(this, startConfig.intent)
            Toast.makeText(
                this,
                "Connecting: ${startConfig.selectedNodeName}",
                Toast.LENGTH_SHORT,
            ).show()
        }.onFailure {
            Toast.makeText(this, it.message ?: "Failed to start VPN", Toast.LENGTH_SHORT).show()
        }
        updateTile(stateOverride = Tile.STATE_ACTIVE, subtitleOverride = "Connecting")
    }

    private fun requestDisconnect() {
        for (stopIntent in QuickSettingsVpnConfigStore.buildStopIntents(this)) {
            runCatching { startService(stopIntent) }
        }
    }

    private fun runtimeState(): String =
        VpnRuntimeState.snapshot()["state"] as? String ?: "disconnected"

    private fun updateTile(
        stateOverride: Int? = null,
        subtitleOverride: String? = null,
    ) {
        val tile = qsTile ?: return
        val state = runtimeState()
        val selectedNodeName = QuickSettingsVpnConfigStore.selectedNodeName(this)

        tile.label = getString(R.string.quick_settings_tile_label)
        tile.icon = Icon.createWithResource(this, R.drawable.ic_quick_settings_tile)
        tile.state = stateOverride ?: when (state) {
            STATE_CONNECTED, STATE_CONNECTING -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = subtitleOverride ?: when {
                selectedNodeName == null -> "No node"
                state == STATE_CONNECTED -> selectedNodeName
                state == STATE_CONNECTING -> "Connecting"
                else -> selectedNodeName
            }
        }
        tile.updateTile()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openAppAndCollapse() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        @Suppress("DEPRECATION")
        startActivityAndCollapse(intent)
    }
}
