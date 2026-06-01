package com.voidlex.voidlex

import android.Manifest
import android.app.Activity
import android.app.UiModeManager
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.provider.OpenableColumns
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

class MainActivity: FlutterActivity() {
    private companion object {
        const val TAG = "MainActivity"
    }

    private val CHANNEL = "org.voidlex.vpn/service"
    private val STATE_CHANNEL = "org.voidlex.vpn/state"
    private val SPEED_CHANNEL = "org.voidlex.vpn/speed"
    private val GEODATA_PROGRESS_CHANNEL = "org.voidlex.vpn/geodata_progress"
    private val DEEPLINK_CHANNEL = "void.deeplink"
    private val DEEPLINK_EVENT_CHANNEL = "void.deeplink/events"
    private val TV_INFO_CHANNEL = "org.voidlex.tv/info"
    private val VPN_REQUEST_CODE = 0
    private val OPEN_DOCUMENT_REQUEST_CODE = 42
    private val OPEN_GEODATA_DOCUMENT_REQUEST_CODE = 43
    private val CREATE_LOG_DOCUMENT_REQUEST_CODE = 44
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 45
    private val CREATE_PROFILE_DOCUMENT_REQUEST_CODE = 46
    private var vpnPrepareResult: MethodChannel.Result? = null
    private var openDocumentResult: MethodChannel.Result? = null
    private var pendingOpenDocumentJsonOnly = false
    private var openGeoDataDocumentResult: MethodChannel.Result? = null
    private var exportLogsResult: MethodChannel.Result? = null
    private var pendingExportLogsContent: String? = null
    private var exportProfileResult: MethodChannel.Result? = null
    private var pendingExportProfileContent: String? = null
    private var pendingGeoDataKind: String? = null
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppLogBridge.install(applicationContext)

        // State EventChannel — service pushes connecting/connected/error/disconnected.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STATE_CHANNEL)
            .setStreamHandler(VpnEventBridge)
        // Throughput EventChannel — service pushes instantaneous tunnel
        // bytes/sec down + up while connected (TV throughput widget, etc.).
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SPEED_CHANNEL)
            .setStreamHandler(VpnSpeedBridge)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, GEODATA_PROGRESS_CHANNEL)
            .setStreamHandler(GeoDataProgressBridge)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_EVENT_CHANNEL)
            .setStreamHandler(DeepLinkBridge)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitial" -> result.success(DeepLinkBridge.consumeInitial())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTelevision" -> result.success(isRunningOnTelevision())
                    else -> result.notImplemented()
                }
            }

        // If the activity was started by a voidlex:// VIEW intent, push
        // it to the bridge now so the Flutter side can pick it up on its
        // first listen. Done here (not in onCreate) because the bridge
        // depends on the engine being attached.
        intent?.let { handleVoidLexIntent(it, isInitial = true) }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "prepareVpn" -> handlePrepareVpn(result)
                "startVpn" -> handleStartVpn(call.arguments as? Map<*, *>, result)
                "stopVpn" -> handleStopVpn(result)
                "startProxy" -> handleStartProxy(call.arguments as? Map<*, *>, result)
                "stopProxy" -> handleStopProxy(result)
                "openSystemVpnSettings" -> handleOpenSystemVpnSettings(result)
                "updateKillSwitch" -> handleUpdateKillSwitch(call.arguments as? Boolean, result)
                "getVpnStatus" -> result.success(VpnRuntimeState.snapshot())
                "listInstalledApps" -> handleListInstalledApps(result)
                "getInstalledAppIcon" -> handleGetInstalledAppIcon(call.arguments as? String, result)
                "pickTextFile" -> handlePickTextFile(result)
                "pickJsonFile" -> handlePickJsonFile(result)
                "getGeoDataStatus" -> handleGetGeoDataStatus(result)
                "downloadGeoDataFile" -> handleDownloadGeoDataFile(call.arguments as? Map<*, *>, result)
                "pickGeoDataFile" -> handlePickGeoDataFile(call.arguments as? Map<*, *>, result)
                "getAppLogs" -> handleGetAppLogs(call.arguments as? Map<*, *>, result)
                "getAppLogsSince" ->
                    handleGetAppLogsSince(call.arguments as? Map<*, *>, result)
                "setAppLogRetention" -> handleSetAppLogRetention(call.arguments as? String, result)
                "clearAppLogs" -> handleClearAppLogs(result)
                "exportAppLogs" -> handleExportAppLogs(call.arguments as? Map<*, *>, result)
                "exportProfileFile" -> handleExportProfileFile(call.arguments as? Map<*, *>, result)
                "getDeviceHwid" -> handleGetDeviceHwid(result)
                "requestNotificationPermission" -> handleRequestNotificationPermission(result)
                "updateShowSpeedInNotification" ->
                    handleUpdateShowSpeedInNotification(call.arguments as? Boolean, result)
                "updateKeepAwake" ->
                    handleUpdateKeepAwake(call.arguments as? Boolean, result)
                "refreshAndroidWidgets" -> {
                    VoidLexWidgetUpdater.requestUpdate(applicationContext)
                    result.success(null)
                }
                "secureGetString" -> handleSecureGetString(call.arguments as? String, result)
                "secureSetString" ->
                    handleSecureSetString(call.arguments as? Map<*, *>, result)
                "secureRemove" -> handleSecureRemove(call.arguments as? String, result)
                "setActiveLogLevels" ->
                    handleSetActiveLogLevels(call.arguments as? List<*>, result)
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Returns true when the host is a Google TV / Android TV style device.
     * `UI_MODE_TYPE_TELEVISION` is the canonical signal; we OR it with the
     * Leanback feature flags so set-top boxes that misreport ui-mode (some
     * cheap Chinese TV sticks do) still trigger the 10-foot layout.
     */
    private fun isRunningOnTelevision(): Boolean {
        val uiMode = (getSystemService(UI_MODE_SERVICE) as? UiModeManager)
            ?.currentModeType ?: Configuration.UI_MODE_TYPE_UNDEFINED
        if (uiMode == Configuration.UI_MODE_TYPE_TELEVISION) return true
        val pm = packageManager
        return pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK_ONLY)
    }

    private fun handleGetDeviceHwid(result: MethodChannel.Result) {
        val hwid = android.provider.Settings.Secure.getString(
            contentResolver,
            android.provider.Settings.Secure.ANDROID_ID,
        ) ?: ""
        result.success(hwid)
    }

    private fun handleSecureGetString(key: String?, result: MethodChannel.Result) {
        if (key.isNullOrBlank()) {
            result.success(null)
            return
        }
        result.success(SecurePrefsBridge.get(applicationContext, key))
    }

    private fun handleSecureSetString(args: Map<*, *>?, result: MethodChannel.Result) {
        val key = args?.get("key") as? String
        val value = args?.get("value") as? String
        if (key.isNullOrBlank() || value == null) {
            result.error("SECURE_INVALID_ARGS", "key/value required", null)
            return
        }
        if (!SecurePrefsBridge.set(applicationContext, key, value)) {
            result.error(
                "SECURE_WRITE_FAILED",
                "Failed to store value in secure storage",
                null,
            )
            return
        }
        result.success(null)
    }

    private fun handleSecureRemove(key: String?, result: MethodChannel.Result) {
        if (key.isNullOrBlank()) {
            result.success(null)
            return
        }
        if (!SecurePrefsBridge.remove(applicationContext, key)) {
            result.error(
                "SECURE_WRITE_FAILED",
                "Failed to remove value from secure storage",
                null,
            )
            return
        }
        result.success(null)
    }

    private fun handleSetActiveLogLevels(levels: List<*>?, result: MethodChannel.Result) {
        val normalized = levels
            ?.mapNotNull { it as? String }
            ?.toSet()
            ?: emptySet()
        AppLogBridge.setActiveLevels(normalized)
        result.success(null)
    }

    private fun handleRequestNotificationPermission(result: MethodChannel.Result) {
        // Pre-Android 13 the notification post permission is granted at install
        // time, so the foreground notification is always visible.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        notificationPermissionResult?.let { prior ->
            try {
                prior.error("CANCELLED", "Superseded by new requestNotificationPermission call", null)
            } catch (_: Exception) {}
        }
        notificationPermissionResult = result

        try {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(permission),
                NOTIFICATION_PERMISSION_REQUEST_CODE,
            )
        } catch (e: Exception) {
            notificationPermissionResult = null
            AppLogger.e(TAG, "requestNotificationPermission launch failed", e)
            result.error("REQUEST_FAILED", e.message, null)
        }
    }

    private fun handleUpdateShowSpeedInNotification(
        enabled: Boolean?,
        result: MethodChannel.Result,
    ) {
        try {
            val startIntent = Intent(this, VoidVpnService::class.java).apply {
                action = VoidVpnService.ACTION_UPDATE_SPEED_PREF
                putExtra(
                    VoidVpnService.EXTRA_SHOW_SPEED_IN_NOTIFICATION,
                    enabled ?: false,
                )
            }
            startService(startIntent)
            result.success(true)
        } catch (e: Exception) {
            AppLogger.e(TAG, "updateShowSpeedInNotification failed", e)
            result.error("UPDATE_FAILED", e.message, null)
        }
    }

    private fun handleUpdateKeepAwake(
        enabled: Boolean?,
        result: MethodChannel.Result,
    ) {
        try {
            val startIntent = Intent(this, VoidVpnService::class.java).apply {
                action = VoidVpnService.ACTION_UPDATE_KEEP_AWAKE_PREF
                putExtra(
                    VoidVpnService.EXTRA_KEEP_AWAKE,
                    enabled ?: false,
                )
            }
            startService(startIntent)
            result.success(true)
        } catch (e: Exception) {
            AppLogger.e(TAG, "updateKeepAwake failed", e)
            result.error("UPDATE_FAILED", e.message, null)
        }
    }

    private fun handleGetAppLogs(args: Map<*, *>?, result: MethodChannel.Result) {
        val levels = (args?.get("levels") as? List<*>)
            ?.mapNotNull { it as? String }
            ?.toSet()
            ?: setOf("debug", "info", "warning", "error")
        val retention = args?.get("retention") as? String
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching { AppLogBridge.read(applicationContext, levels, retention) }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        AppLogger.e(TAG, "getAppLogs failed", it)
                        result.error("LOG_READ_FAILED", it.message, null)
                    },
                )
            }
        }
    }

    private fun handleGetAppLogsSince(args: Map<*, *>?, result: MethodChannel.Result) {
        val levels = (args?.get("levels") as? List<*>)
            ?.mapNotNull { it as? String }
            ?.toSet()
            ?: setOf("debug", "info", "warning", "error")
        val retention = args?.get("retention") as? String
        val since = (args?.get("sinceEpochMs") as? Number)?.toLong() ?: 0L
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching {
                AppLogBridge.readSince(applicationContext, levels, since, retention)
            }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        AppLogger.e(TAG, "getAppLogsSince failed", it)
                        result.error("LOG_READ_FAILED", it.message, null)
                    },
                )
            }
        }
    }

    private fun handleSetAppLogRetention(retention: String?, result: MethodChannel.Result) {
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching {
                AppLogBridge.setRetention(applicationContext, retention)
            }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = { result.success(null) },
                    onFailure = {
                        AppLogger.e(TAG, "setAppLogRetention failed", it)
                        result.error("LOG_RETENTION_FAILED", it.message, null)
                    },
                )
            }
        }
    }

    private fun handleClearAppLogs(result: MethodChannel.Result) {
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching { AppLogBridge.clear(applicationContext) }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = { result.success(null) },
                    onFailure = {
                        AppLogger.e(TAG, "clearAppLogs failed", it)
                        result.error("LOG_CLEAR_FAILED", it.message, null)
                    },
                )
            }
        }
    }

    private fun handleExportAppLogs(args: Map<*, *>?, result: MethodChannel.Result) {
        val content = args?.get("content") as? String ?: ""
        val fileName = (args?.get("fileName") as? String)
            ?.takeIf { it.isNotBlank() }
            ?: "voidlex-logs.txt"

        exportLogsResult?.let { prior ->
            try { prior.error("CANCELLED", "Superseded by new exportAppLogs call", null) } catch (_: Exception) {}
        }
        exportLogsResult = result
        pendingExportLogsContent = content

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/plain"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, CREATE_LOG_DOCUMENT_REQUEST_CODE)
        } catch (e: Exception) {
            exportLogsResult = null
            pendingExportLogsContent = null
            AppLogger.e(TAG, "exportAppLogs launch failed", e)
            result.error("EXPORT_FAILED", e.message, null)
        }
    }

    private fun handleExportProfileFile(args: Map<*, *>?, result: MethodChannel.Result) {
        val content = args?.get("content") as? String ?: ""
        val fileName = (args?.get("fileName") as? String)
            ?.takeIf { it.isNotBlank() }
            ?: "voidlex-profile.json"

        exportProfileResult?.let { prior ->
            try { prior.error("CANCELLED", "Superseded by new exportProfileFile call", null) } catch (_: Exception) {}
        }
        exportProfileResult = result
        pendingExportProfileContent = content

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, CREATE_PROFILE_DOCUMENT_REQUEST_CODE)
        } catch (e: Exception) {
            exportProfileResult = null
            pendingExportProfileContent = null
            AppLogger.e(TAG, "exportProfileFile launch failed", e)
            result.error("EXPORT_FAILED", e.message, null)
        }
    }

    private fun handleGetGeoDataStatus(result: MethodChannel.Result) {
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching { GeoDataManager.getStatus(applicationContext) }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        AppLogger.e(TAG, "getGeoDataStatus failed", it)
                        result.error("GEODATA_STATUS_FAILED", it.message, null)
                    },
                )
            }
        }
    }

    private fun handleDownloadGeoDataFile(args: Map<*, *>?, result: MethodChannel.Result) {
        val kind = args?.get("kind") as? String
        val url = args?.get("url") as? String
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching {
                GeoDataManager.download(applicationContext, kind, url) { progressKind, percent ->
                    GeoDataProgressBridge.emit(progressKind.wireName, percent)
                }
            }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        AppLogger.e(TAG, "downloadGeoDataFile failed", it)
                        result.error("GEODATA_DOWNLOAD_FAILED", it.message, null)
                    },
                )
            }
        }
    }

    private fun handlePickGeoDataFile(args: Map<*, *>?, result: MethodChannel.Result) {
        val kind = args?.get("kind") as? String
        runCatching { GeoDataManager.Kind.fromWire(kind) }
            .onFailure {
                result.error("GEODATA_KIND_INVALID", it.message, null)
                return
            }

        openGeoDataDocumentResult?.let { prior ->
            try { prior.error("CANCELLED", "Superseded by new pickGeoDataFile call", null) } catch (_: Exception) {}
        }
        openGeoDataDocumentResult = result
        pendingGeoDataKind = kind
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        try {
            startActivityForResult(intent, OPEN_GEODATA_DOCUMENT_REQUEST_CODE)
        } catch (e: Exception) {
            openGeoDataDocumentResult = null
            pendingGeoDataKind = null
            AppLogger.e(TAG, "pickGeoDataFile launch failed", e)
            result.error("PICK_FAILED", e.message, null)
        }
    }

    private fun handlePickTextFile(result: MethodChannel.Result) {
        openDocumentResult?.let { prior ->
            try { prior.error("CANCELLED", "Superseded by new pickTextFile call", null) } catch (_: Exception) {}
        }
        openDocumentResult = result
        pendingOpenDocumentJsonOnly = false
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Documents UIs treat "*/*" as the safest cross-vendor wildcard,
            // and the picker is the only filter we want — text/json/octet-stream
            // would all be too narrow on some OEM file pickers.
            type = "*/*"
        }
        try {
            startActivityForResult(intent, OPEN_DOCUMENT_REQUEST_CODE)
        } catch (e: Exception) {
            openDocumentResult = null
            AppLogger.e(TAG, "pickTextFile launch failed", e)
            result.error("PICK_FAILED", e.message, null)
        }
    }

    private fun handlePickJsonFile(result: MethodChannel.Result) {
        openDocumentResult?.let { prior ->
            try { prior.error("CANCELLED", "Superseded by new pickJsonFile call", null) } catch (_: Exception) {}
        }
        openDocumentResult = result
        pendingOpenDocumentJsonOnly = true
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/json",
                    "text/json",
                    "text/plain",
                    "application/octet-stream",
                ),
            )
        }
        try {
            startActivityForResult(intent, OPEN_DOCUMENT_REQUEST_CODE)
        } catch (e: Exception) {
            openDocumentResult = null
            pendingOpenDocumentJsonOnly = false
            AppLogger.e(TAG, "pickJsonFile launch failed", e)
            result.error("PICK_FAILED", e.message, null)
        }
    }

    private fun handleListInstalledApps(result: MethodChannel.Result) {
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching { InstalledAppsBridge.list(applicationContext) }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        AppLogger.e(TAG, "listInstalledApps failed", it)
                        result.error("LIST_APPS_FAILED", it.message, null)
                    },
                )
            }
        }
    }

    private fun handleGetInstalledAppIcon(packageName: String?, result: MethodChannel.Result) {
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching { InstalledAppsBridge.icon(applicationContext, packageName) }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        AppLogger.e(TAG, "getInstalledAppIcon failed", it)
                        result.error("APP_ICON_FAILED", it.message, null)
                    },
                )
            }
        }
    }

    private fun handlePrepareVpn(result: MethodChannel.Result) {
        try {
            val intent = VpnService.prepare(this)
            if (intent != null) {
                // Only one prepare can be pending. If a previous call never received
                // its activity result, fail it explicitly so we don't leak callbacks.
                vpnPrepareResult?.let { prior ->
                    try { prior.error("CANCELLED", "Superseded by new prepare call", null) } catch (_: Exception) {}
                }
                vpnPrepareResult = result
                startActivityForResult(intent, VPN_REQUEST_CODE)
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "prepareVpn failed", e)
            result.error("PREPARE_FAILED", e.message, null)
        }
    }

    private fun handleStartVpn(args: Map<*, *>?, result: MethodChannel.Result) {
        try {
            val startIntent = Intent(this, VoidVpnService::class.java).apply {
                putExtra(VoidVpnService.EXTRA_IS_GLOBAL_PROXY,
                    (args?.get("isGlobalProxy") as? Boolean) ?: false)
                putExtra(
                    VoidVpnService.EXTRA_TUN_ENGINE,
                    (args?.get("tunEngine") as? String) ?: TunEngineMode.LIBBOX.wireName,
                )
                putExtra(
                    VoidVpnService.EXTRA_APP_ROUTING_MODE,
                    (args?.get("appRoutingMode") as? String) ?: AppRoutingMode.OFF.wireName,
                )
                val routingPackages = (args?.get("appRoutingPackages") as? List<*>)
                    ?.mapNotNull { it as? String }
                    ?.toTypedArray()
                    ?: emptyArray()
                putExtra(VoidVpnService.EXTRA_APP_ROUTING_PACKAGES, routingPackages)
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_RULES_JSON,
                    (args?.get("routingRulesJson") as? String) ?: "[]",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_ID,
                    (args?.get("routingPresetId") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_NAME,
                    (args?.get("routingPresetName") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_EDITOR_ID,
                    (args?.get("routingPresetEditorId") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_EDITOR_NAME,
                    (args?.get("routingPresetEditorName") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_NODE_ID,
                    (args?.get("routingPresetNodeId") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_NODE_NAME,
                    (args?.get("routingPresetNodeName") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_NODE,
                    (args?.get("routingPresetNode") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_MODE,
                    (args?.get("routingPresetMode") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_PACKAGE_COUNT,
                    readIntArg(args, "routingPresetPackageCount", 0),
                )
                putExtra(
                    VoidVpnService.EXTRA_ROUTING_PRESET_RULE_COUNT,
                    readIntArg(args, "routingPresetRuleCount", 0),
                )
                putExtra(
                    VoidVpnService.EXTRA_SHOW_SPEED_IN_NOTIFICATION,
                    (args?.get("showSpeedInNotification") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_KEEP_AWAKE,
                    (args?.get("keepAwake") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_PROXY_USER,
                    (args?.get("proxyUser") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_PROXY_PASSWORD,
                    (args?.get("proxyPassword") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_ENABLED,
                    (args?.get("fragmentEnabled") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_PACKETS,
                    (args?.get("fragmentPackets") as? String) ?: XrayFragmentSettings.DEFAULT_PACKETS,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_LENGTH,
                    (args?.get("fragmentLength") as? String) ?: XrayFragmentSettings.DEFAULT_LENGTH,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_INTERVAL,
                    (args?.get("fragmentInterval") as? String) ?: XrayFragmentSettings.DEFAULT_INTERVAL,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_MAX_SPLIT,
                    (args?.get("fragmentMaxSplit") as? String) ?: XrayFragmentSettings.DEFAULT_MAX_SPLIT,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_ENABLED,
                    (args?.get("fragmentNoiseEnabled") as? Boolean) ?: true,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_TYPE,
                    (args?.get("fragmentNoiseType") as? String) ?: XrayFragmentSettings.DEFAULT_NOISE_TYPE,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_PACKET,
                    (args?.get("fragmentNoisePacket") as? String) ?: XrayFragmentSettings.DEFAULT_NOISE_PACKET,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_DELAY,
                    (args?.get("fragmentNoiseDelay") as? String) ?: XrayFragmentSettings.DEFAULT_NOISE_DELAY,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_APPLY_TO,
                    (args?.get("fragmentNoiseApplyTo") as? String) ?: XrayFragmentSettings.DEFAULT_NOISE_APPLY_TO,
                )
                putExtra(
                    VoidVpnService.EXTRA_MUX_ENABLED,
                    (args?.get("muxEnabled") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_MUX_TCP_CONCURRENCY,
                    readIntArg(args, "muxTcpConcurrency", XrayMultiplexSettings.DEFAULT_TCP_CONCURRENCY),
                )
                putExtra(
                    VoidVpnService.EXTRA_MUX_XUDP_CONCURRENCY,
                    readIntArg(args, "muxXudpConcurrency", XrayMultiplexSettings.DEFAULT_XUDP_CONCURRENCY),
                )
                putExtra(
                    VoidVpnService.EXTRA_MUX_QUIC_BEHAVIOR,
                    (args?.get("muxQuicBehavior") as? String) ?: XrayMultiplexSettings.DEFAULT_QUIC_BEHAVIOR,
                )
                putExtra(
                    VoidVpnService.EXTRA_USE_LOCAL_DNS,
                    (args?.get("useLocalDns") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_SERVER_RESOLVING_ENABLED,
                    (args?.get("serverResolvingEnabled") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_PACKET_ANALYSIS_ENABLED,
                    (args?.get("packetAnalysisEnabled") as? Boolean) ?: true,
                )
                putExtra(
                    VoidVpnService.EXTRA_BLOCK_UDP,
                    (args?.get("blockUdp") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_NETWORK_STACK,
                    (args?.get("networkStack") as? String) ?: TunnelNetworkStack.SYSTEM.wireName,
                )
                putExtra(
                    VoidVpnService.EXTRA_TUN_MTU,
                    readIntArg(args, "tunMtu", TunnelNetworkSettings.DEFAULT_MTU),
                )
                putExtra(
                    VoidVpnService.EXTRA_IP_MODE,
                    (args?.get("ipMode") as? String) ?: TunnelIpMode.IPV4.wireName,
                )
                putExtra(
                    VoidVpnService.EXTRA_XRAY_TUN_DNS_ENABLED,
                    (args?.get("xrayTunDnsEnabled") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_XRAY_TUN_DNS_SERVER,
                    (args?.get("xrayTunDnsServer") as? String)
                        ?.takeIf { it.isNotBlank() }
                        ?: TunnelNetworkSettings.DEFAULT_XRAY_TUN_DNS_SERVER,
                )
                applyConnectionModeExtras(this, args)
                putServerExtras(this, args)
                putServerExtras(this, args, prefix = "entry")
            }
            startService(startIntent)
            result.success(true)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Failed to start service", e)
            // Propagate the failure. Also push an error event so any Flutter listener
            // that missed the method reply still leaves the connecting state.
            VpnRuntimeState.markError(e.message ?: "Failed to start VPN service")
            VpnEventBridge.emit("error", e.message ?: "Failed to start VPN service")
            result.error("START_FAILED", e.message, null)
        }
    }

    /// Threads the connection-mode/policy/kill-switch settings on the
    /// outgoing Intent. Shared between `startVpn` and `startProxy` so the
    /// proxy-only path also gets policy + auth wiring.
    private fun applyConnectionModeExtras(intent: Intent, args: Map<*, *>?) {
        intent.putExtra(
            VoidVpnService.EXTRA_KILL_SWITCH_ENABLED,
            (args?.get("killSwitchEnabled") as? Boolean) ?: false,
        )
        intent.putExtra(
            VoidVpnService.EXTRA_RUN_MODE,
            (args?.get("runMode") as? String) ?: RunMode.TUN.wireName,
        )
        intent.putExtra(
            VoidVpnService.EXTRA_HOTSPOT_BIND_ENABLED,
            (args?.get("hotspotBindEnabled") as? Boolean) ?: false,
        )
        intent.putExtra(
            VoidVpnService.EXTRA_HTTP_PROXY_AUTH_ENABLED,
            (args?.get("httpProxyAuthEnabled") as? Boolean) ?: false,
        )
        intent.putExtra(
            VoidVpnService.EXTRA_SNIFFING_ROUTE_ONLY,
            (args?.get("sniffingRouteOnly") as? Boolean) ?: true,
        )
        intent.putExtra(
            VoidVpnService.EXTRA_POLICY_HANDSHAKE_SEC,
            readIntArg(args, "policyHandshakeSec", ConnectionPolicy.DEFAULT.handshakeSeconds),
        )
        intent.putExtra(
            VoidVpnService.EXTRA_POLICY_CONN_IDLE_SEC,
            readIntArg(args, "policyConnIdleSec", ConnectionPolicy.DEFAULT.connIdleSeconds),
        )
        intent.putExtra(
            VoidVpnService.EXTRA_POLICY_UPLINK_ONLY_SEC,
            readIntArg(args, "policyUplinkOnlySec", ConnectionPolicy.DEFAULT.uplinkOnlySeconds),
        )
        intent.putExtra(
            VoidVpnService.EXTRA_POLICY_DOWNLINK_ONLY_SEC,
            readIntArg(args, "policyDownlinkOnlySec", ConnectionPolicy.DEFAULT.downlinkOnlySeconds),
        )
        intent.putExtra(
            VoidVpnService.EXTRA_POLICY_MAX_TCP_CONNS,
            readIntArg(args, "policyMaxTcpConns", ConnectionPolicy.DEFAULT.maxTcpConnections),
        )
        intent.putExtra(
            VoidVpnService.EXTRA_POLICY_MAX_UDP_CONNS,
            readIntArg(args, "policyMaxUdpConns", ConnectionPolicy.DEFAULT.maxUdpConnections),
        )
    }

    private fun handleStartProxy(args: Map<*, *>?, result: MethodChannel.Result) {
        try {
            val startIntent = Intent(this, VoidProxyService::class.java).apply {
                applyConnectionModeExtras(this, args)
                // Proxy-only mode reuses the same VPN config args (server,
                // outbound credentials, fragment, mux). We thread them all
                // so the Xray inbound config is identical to the TUN path.
                putExtra(
                    VoidVpnService.EXTRA_PROXY_USER,
                    (args?.get("proxyUser") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_PROXY_PASSWORD,
                    (args?.get("proxyPassword") as? String) ?: "",
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_ENABLED,
                    (args?.get("fragmentEnabled") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_PACKETS,
                    (args?.get("fragmentPackets") as? String) ?: XrayFragmentSettings.DEFAULT_PACKETS,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_LENGTH,
                    (args?.get("fragmentLength") as? String) ?: XrayFragmentSettings.DEFAULT_LENGTH,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_INTERVAL,
                    (args?.get("fragmentInterval") as? String) ?: XrayFragmentSettings.DEFAULT_INTERVAL,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_MAX_SPLIT,
                    (args?.get("fragmentMaxSplit") as? String) ?: XrayFragmentSettings.DEFAULT_MAX_SPLIT,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_ENABLED,
                    (args?.get("fragmentNoiseEnabled") as? Boolean) ?: true,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_TYPE,
                    (args?.get("fragmentNoiseType") as? String) ?: XrayFragmentSettings.DEFAULT_NOISE_TYPE,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_PACKET,
                    (args?.get("fragmentNoisePacket") as? String) ?: XrayFragmentSettings.DEFAULT_NOISE_PACKET,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_DELAY,
                    (args?.get("fragmentNoiseDelay") as? String) ?: XrayFragmentSettings.DEFAULT_NOISE_DELAY,
                )
                putExtra(
                    VoidVpnService.EXTRA_FRAGMENT_NOISE_APPLY_TO,
                    (args?.get("fragmentNoiseApplyTo") as? String) ?: XrayFragmentSettings.DEFAULT_NOISE_APPLY_TO,
                )
                putExtra(
                    VoidVpnService.EXTRA_MUX_ENABLED,
                    (args?.get("muxEnabled") as? Boolean) ?: false,
                )
                putExtra(
                    VoidVpnService.EXTRA_MUX_TCP_CONCURRENCY,
                    readIntArg(args, "muxTcpConcurrency", XrayMultiplexSettings.DEFAULT_TCP_CONCURRENCY),
                )
                putExtra(
                    VoidVpnService.EXTRA_MUX_XUDP_CONCURRENCY,
                    readIntArg(args, "muxXudpConcurrency", XrayMultiplexSettings.DEFAULT_XUDP_CONCURRENCY),
                )
                putExtra(
                    VoidVpnService.EXTRA_MUX_QUIC_BEHAVIOR,
                    (args?.get("muxQuicBehavior") as? String) ?: XrayMultiplexSettings.DEFAULT_QUIC_BEHAVIOR,
                )
                putExtra(
                    VoidVpnService.EXTRA_PACKET_ANALYSIS_ENABLED,
                    (args?.get("packetAnalysisEnabled") as? Boolean) ?: true,
                )
                putServerExtras(this, args)
                putServerExtras(this, args, prefix = "entry")
            }
            startService(startIntent)
            result.success(true)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Failed to start proxy service", e)
            VpnRuntimeState.markError(e.message ?: "Failed to start proxy service")
            VpnEventBridge.emit("error", e.message ?: "Failed to start proxy service")
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun handleStopProxy(result: MethodChannel.Result) {
        try {
            val stopIntent = Intent(this, VoidProxyService::class.java).apply {
                action = VoidProxyService.ACTION_DISCONNECT
            }
            startService(stopIntent)
            result.success(true)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Failed to stop proxy service", e)
            result.error("STOP_FAILED", e.message, null)
        }
    }

    private fun handleOpenSystemVpnSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(android.provider.Settings.ACTION_VPN_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            AppLogger.w(TAG, "Failed to open system VPN settings", e)
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    private fun handleUpdateKillSwitch(enabled: Boolean?, result: MethodChannel.Result) {
        try {
            val value = enabled ?: false
            val updateIntent = Intent(this, VoidVpnService::class.java).apply {
                action = VoidVpnService.ACTION_UPDATE_KILL_SWITCH_PREF
                putExtra(VoidVpnService.EXTRA_KILL_SWITCH_ENABLED, value)
            }
            startService(updateIntent)
            result.success(null)
        } catch (e: Exception) {
            AppLogger.w(TAG, "updateKillSwitch failed", e)
            result.error("UPDATE_FAILED", e.message, null)
        }
    }

    private fun handleStopVpn(result: MethodChannel.Result) {
        try {
            // Stop both runtimes — the user might be in either run mode and
            // the Dart side issues a single `stopVpn` regardless. Stopping a
            // service that isn't running is a no-op on Android.
            val stopVpnIntent = Intent(this, VoidVpnService::class.java).apply {
                action = "ACTION_DISCONNECT"
            }
            val stopProxyIntent = Intent(this, VoidProxyService::class.java).apply {
                action = VoidProxyService.ACTION_DISCONNECT
            }
            runCatching { startService(stopVpnIntent) }
            runCatching { startService(stopProxyIntent) }
            result.success(true)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Failed to stop service", e)
            result.error("STOP_FAILED", e.message, null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Replace the activity's currentIntent so getIntent() returns the
        // new VIEW intent (avoid replaying the original MAIN intent on
        // subsequent lifecycle ticks).
        setIntent(intent)
        handleVoidLexIntent(intent, isInitial = false)
    }

    /**
     * Inspects [intent] for a voidlex:// VIEW action and forwards the URL
     * to [DeepLinkBridge] if present. No-op otherwise.
     */
    private fun handleVoidLexIntent(intent: Intent, isInitial: Boolean) {
        if (intent.action != Intent.ACTION_VIEW) return
        val data: Uri = intent.data ?: return
        if (!"voidlex".equals(data.scheme, ignoreCase = true)) return
        // Widget PendingIntents only use voidlex://widget/... for uniqueness;
        // they are handled by AppWidgetProvider broadcasts, not Flutter.
        if ("widget".equals(data.host, ignoreCase = true)) return
        val url = data.toString()
        DeepLinkBridge.emit(url, isInitial = isInitial)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            VPN_REQUEST_CODE -> {
                val pending = vpnPrepareResult
                vpnPrepareResult = null
                try {
                    pending?.success(resultCode == Activity.RESULT_OK)
                } catch (e: Exception) {
                    AppLogger.e(TAG, "prepare result delivery failed", e)
                }
            }
            OPEN_DOCUMENT_REQUEST_CODE -> handleOpenDocumentResult(resultCode, data)
            OPEN_GEODATA_DOCUMENT_REQUEST_CODE -> handleGeoDataDocumentResult(resultCode, data)
            CREATE_LOG_DOCUMENT_REQUEST_CODE -> handleCreateLogDocumentResult(resultCode, data)
            CREATE_PROFILE_DOCUMENT_REQUEST_CODE -> handleCreateProfileDocumentResult(resultCode, data)
            else -> super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            val pending = notificationPermissionResult
            notificationPermissionResult = null
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            try {
                pending?.success(granted)
            } catch (e: Exception) {
                AppLogger.e(TAG, "notification permission result delivery failed", e)
            }
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun handleCreateLogDocumentResult(resultCode: Int, data: Intent?) {
        val pending = exportLogsResult
        val content = pendingExportLogsContent
        exportLogsResult = null
        pendingExportLogsContent = null
        if (pending == null) {
            return
        }
        if (resultCode != Activity.RESULT_OK) {
            try { pending.success(false) } catch (_: Exception) {}
            return
        }
        val uri = data?.data
        if (uri == null) {
            try { pending.success(false) } catch (_: Exception) {}
            return
        }
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching {
                contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write((content ?: "").toByteArray(Charsets.UTF_8))
                } ?: error("Unable to open output stream")
            }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = {
                        try { pending.success(true) } catch (_: Exception) {}
                    },
                    onFailure = {
                        AppLogger.e(TAG, "exportAppLogs write failed", it)
                        try {
                            pending.error("WRITE_FAILED", it.message, null)
                        } catch (_: Exception) {
                        }
                    },
                )
            }
        }
    }

    private fun handleCreateProfileDocumentResult(resultCode: Int, data: Intent?) {
        val pending = exportProfileResult
        val content = pendingExportProfileContent
        exportProfileResult = null
        pendingExportProfileContent = null
        if (pending == null) {
            return
        }
        if (resultCode != Activity.RESULT_OK) {
            try { pending.success(false) } catch (_: Exception) {}
            return
        }
        val uri = data?.data
        if (uri == null) {
            try { pending.success(false) } catch (_: Exception) {}
            return
        }
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching {
                contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write((content ?: "").toByteArray(Charsets.UTF_8))
                } ?: error("Unable to open output stream")
            }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = {
                        try { pending.success(true) } catch (_: Exception) {}
                    },
                    onFailure = {
                        AppLogger.e(TAG, "exportProfileFile write failed", it)
                        try {
                            pending.error("WRITE_FAILED", it.message, null)
                        } catch (_: Exception) {
                        }
                    },
                )
            }
        }
    }

    private fun handleOpenDocumentResult(resultCode: Int, data: Intent?) {
        val pending = openDocumentResult
        openDocumentResult = null
        val jsonOnly = pendingOpenDocumentJsonOnly
        pendingOpenDocumentJsonOnly = false
        if (pending == null) {
            return
        }
        if (resultCode != Activity.RESULT_OK) {
            try { pending.success(null) } catch (_: Exception) {}
            return
        }
        val uri = data?.data
        if (uri == null) {
            try { pending.success(null) } catch (_: Exception) {}
            return
        }
        if (jsonOnly && !isJsonDocument(uri)) {
            try { pending.error("INVALID_FILE_TYPE", "Please choose a .json file", null) } catch (_: Exception) {}
            return
        }
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching {
                contentResolver.openInputStream(uri)?.use { stream ->
                    stream.bufferedReader().readText()
                }
            }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = {
                        try { pending.success(it) } catch (_: Exception) {}
                    },
                    onFailure = {
                        AppLogger.e(TAG, "pickTextFile read failed", it)
                        try {
                            pending.error("READ_FAILED", it.message, null)
                        } catch (_: Exception) {
                        }
                    },
                )
            }
        }
    }

    private fun isJsonDocument(uri: Uri): Boolean {
        val displayName = displayNameForUri(uri)?.lowercase(Locale.ROOT)
        if (displayName?.endsWith(".json") == true) return true

        val mimeType = contentResolver.getType(uri)?.lowercase(Locale.ROOT)
        return mimeType == "application/json" || mimeType == "text/json"
    }

    private fun displayNameForUri(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index < 0) return null
                return cursor.getString(index)
            }
        return uri.lastPathSegment
    }

    private fun handleGeoDataDocumentResult(resultCode: Int, data: Intent?) {
        val pending = openGeoDataDocumentResult
        val kind = pendingGeoDataKind
        openGeoDataDocumentResult = null
        pendingGeoDataKind = null
        if (pending == null) {
            return
        }
        if (resultCode != Activity.RESULT_OK) {
            try { pending.success(null) } catch (_: Exception) {}
            return
        }
        val uri = data?.data
        if (uri == null || kind == null) {
            try { pending.success(null) } catch (_: Exception) {}
            return
        }
        lifecycleScope.launch(Dispatchers.IO) {
            val outcome = runCatching {
                GeoDataManager.installFromUri(applicationContext, kind, uri)
            }
            withContext(Dispatchers.Main) {
                outcome.fold(
                    onSuccess = {
                        try { pending.success(it) } catch (_: Exception) {}
                    },
                    onFailure = {
                        AppLogger.e(TAG, "pickGeoDataFile read failed", it)
                        try {
                            pending.error("READ_FAILED", it.message, null)
                        } catch (_: Exception) {
                        }
                    },
                )
            }
        }
    }

    private fun putServerExtras(
        intent: Intent,
        args: Map<*, *>?,
        prefix: String = "",
    ) {
        fun readString(baseKey: String, fallback: String = ""): String {
            val key = prefixedKey(prefix, baseKey)
            return (args?.get(key) as? String) ?: fallback
        }

        fun readInt(baseKey: String, fallback: Int): Int {
            val key = prefixedKey(prefix, baseKey)
            return readIntArg(args, key, fallback)
        }

        fun readBoolean(baseKey: String, fallback: Boolean): Boolean {
            val key = prefixedKey(prefix, baseKey)
            return (args?.get(key) as? Boolean) ?: fallback
        }

        val extraPrefix = if (prefix.isBlank()) {
            ""
        } else {
            "${prefix.uppercase()}_"
        }

        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_SERVER, readString("server"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_SERVER_PORT, readInt("serverPort", 443))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_PROTOCOL, readString("protocol", "vless"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_UUID, readString("uuid"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_TRANSPORT, readString("transport", "tcp"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_TRANSPORT_PATH, readString("transportPath", "/"))
        intent.putExtra(
            extraPrefix + VoidVpnService.EXTRA_TRANSPORT_SERVICE_NAME,
            readString("transportServiceName"),
        )
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_TRANSPORT_HOST, readString("transportHost"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_TRANSPORT_MODE, readString("transportMode"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_TLS_ENABLED, readBoolean("tlsEnabled", true))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_TLS_SNI, readString("tlsSni"))
        intent.putExtra(
            extraPrefix + VoidVpnService.EXTRA_TLS_INSECURE,
            readBoolean("tlsInsecure", false),
        )
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_FLOW, readString("flow"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_SECURITY, readString("security"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_REALITY_PBK, readString("pbk"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_REALITY_SID, readString("sid"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_REALITY_SPIDER_X, readString("spx"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_FINGERPRINT, readString("fp"))
        intent.putExtra(extraPrefix + VoidVpnService.EXTRA_ALPN, readString("alpn"))
        intent.putExtra(
            extraPrefix + VoidVpnService.EXTRA_HYSTERIA2_OBFS_PASSWORD,
            readString("hysteria2ObfsPassword"),
        )
        intent.putExtra(
            extraPrefix + VoidVpnService.EXTRA_HYSTERIA2_HOP_PORTS,
            readString("hysteria2HopPorts"),
        )
    }

    private fun prefixedKey(prefix: String, baseKey: String): String {
        if (prefix.isBlank()) return baseKey
        return prefix + baseKey.replaceFirstChar { char -> char.uppercase() }
    }

    private fun readIntArg(args: Map<*, *>?, key: String, fallback: Int): Int {
        return when (val value = args?.get(key)) {
            is Int -> value
            is Number -> value.toInt()
            else -> fallback
        }
    }
}
