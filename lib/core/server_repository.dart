import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import 'app_log.dart';
import 'app_routing.dart';
import 'geo_data.dart';
import 'models/server_config.dart';
import 'models/server_subscription.dart';
import 'multiplex_settings.dart';
import 'routing_preset.dart';
import 'routing_rule.dart';
import 'secure_storage.dart';
import 'server_latency_probe.dart';
import 'subscription_provider_settings.dart';
import 'tun_engine_mode.dart';
import 'tv_layout_preference.dart';
import 'tunnel_fragment_settings.dart';
import 'tunnel_network_settings.dart';

class ServerRepositorySnapshot {
  const ServerRepositorySnapshot({
    required this.servers,
    required this.subscriptions,
    required this.selectedName,
    required this.exitNodeName,
    required this.isGlobalProxy,
    required this.tunEngineMode,
    required this.autoConnectOnLaunch,
    required this.restartConnectionOnSettingsChanges,
    required this.showGlobalProxyButton,
    required this.autoSortServersByPing,
    required this.latencyProbeTarget,
    required this.favoritesSectionCollapsed,
    required this.favoriteServerNames,
    required this.collapsedSubscriptionIds,
    required this.logLevels,
    required this.logRetention,
    required this.keepAwake,
    required this.verboseXrayLogs,
    required this.appRoutingPolicy,
    required this.routingRules,
    required this.routingPresets,
    required this.selectedRoutingPresetId,
    required this.customProxyAuthEnabled,
    required this.customProxyUser,
    required this.tunnelFragmentSettings,
    required this.multiplexSettings,
    required this.tunnelNetworkSettings,
    required this.subscriptionProviderSettings,
  });

  final List<ServerConfig> servers;
  final List<ServerSubscription> subscriptions;
  final String? selectedName;
  final String? exitNodeName;
  final bool isGlobalProxy;
  final TunEngineMode tunEngineMode;
  final bool autoConnectOnLaunch;
  final bool restartConnectionOnSettingsChanges;
  final bool showGlobalProxyButton;
  final bool autoSortServersByPing;
  final LatencyProbeTarget latencyProbeTarget;
  final bool favoritesSectionCollapsed;
  final List<String> favoriteServerNames;
  final List<String> collapsedSubscriptionIds;
  final Set<AppLogLevel> logLevels;
  final AppLogRetention logRetention;
  final bool keepAwake;
  final bool verboseXrayLogs;
  final AppRoutingPolicy appRoutingPolicy;
  final List<RoutingRule> routingRules;
  final List<RoutingPreset> routingPresets;
  final String? selectedRoutingPresetId;
  final bool customProxyAuthEnabled;
  final String customProxyUser;
  final TunnelFragmentSettings tunnelFragmentSettings;
  final MultiplexSettings multiplexSettings;
  final TunnelNetworkSettings tunnelNetworkSettings;
  final SubscriptionProviderSettings subscriptionProviderSettings;
}

class ServerRepository {
  ServerRepository(this._prefs, {SecureStorage? secureStorage})
    : _secure = secureStorage ?? const SecureStorage();

  static const _kServers = 'void.servers';
  static const _kSubscriptions = 'void.subscriptions';
  static const _kSelected = 'void.selectedName';
  static const _kExitNode = 'void.exitNodeName';
  static const _kGlobalProxy = 'void.globalProxy';
  static const _kTunEngineMode = 'void.tunEngineMode';
  static const _kAutoConnectOnLaunch = 'void.autoConnectOnLaunch';
  static const _kRestartConnectionOnSettingsChanges =
      'void.restartConnectionOnSettingsChanges';
  static const _kShowGlobalProxyButton = 'void.showGlobalProxyButton';
  static const _kLegacyHideGlobalProxyButton = 'void.hideGlobalProxyButton';
  static const _kAutoSortServersByPing = 'void.autoSortServersByPing';
  static const _kLatencyProbeTarget = 'void.latencyProbeTarget';
  static const _kFavoritesSectionCollapsed = 'void.favoritesSectionCollapsed';
  static const _kFavoriteServerNames = 'void.favoriteServerNames';
  static const _kCollapsedSubscriptionIds = 'void.subscriptions.collapsedIds';
  static const _kLogLevels = 'void.logLevels';
  static const _kLogRetention = 'void.logRetention';
  static const _kAppRoutingMode = 'void.appRoutingMode';
  static const _kAppRoutingPackages = 'void.appRoutingPackages';
  static const _kAppRoutingProxyPackages = 'void.appRoutingProxyPackages';
  static const _kAppRoutingBypassPackages = 'void.appRoutingBypassPackages';
  static const _kRoutingRules = 'void.routingRules';
  static const _kRoutingPresets = 'void.routingPresets';
  static const _kSelectedRoutingPreset = 'void.selectedRoutingPreset';
  static const _kDarkTheme = 'void.darkTheme';
  static const _kTvLayoutPreference = 'void.tvLayoutPreference';
  // Legacy bool key from the first iteration of the TV preview toggle.
  // Read once on first launch after the upgrade, then deleted.
  static const _kLegacyForceTvLayout = 'void.forceTvLayout';
  static const _kAppLocalePreference = 'void.appLocalePreference';
  static const _kNotificationPermissionAsked =
      'void.notificationPermissionAsked';
  static const _kShowSpeedInNotification = 'void.showSpeedInNotification';
  static const _kKeepAwake = 'void.keepAwake';
  static const _kVerboseXrayLogs = 'void.verboseXrayLogs';
  static const _kCustomProxyAuthEnabled = 'void.customProxyAuth.enabled';
  static const _kCustomProxyUser = 'void.customProxyAuth.user';
  static const _kCustomProxyPassword = 'void.customProxyAuth.password';
  static const _kTunnelFragmentSettings = 'void.tunnel.fragmentSettings';
  static const _kMultiplexSettings = 'void.tunnel.multiplexSettings';
  static const _kTunnelNetworkSettings = 'void.tunnel.networkSettings';
  static const _kSubscriptionProviderSettings =
      'void.subscriptions.providerSettings';
  static const _kGeoDataSourcePrefix = 'void.geoData.source.';
  static const _kGeoDataUrlPrefix = 'void.geoData.url.';
  static const _kGeoDataUpdatedAtPrefix = 'void.geoData.updatedAt.';
  static const _kGeoDataFileSizePrefix = 'void.geoData.fileSize.';

  final SharedPreferences _prefs;
  final SecureStorage _secure;
  late final ValueNotifier<TvLayoutPreference> _tvLayoutPrefNotifier =
      ValueNotifier(_resolveInitialTvLayoutPreference());

  TvLayoutPreference _resolveInitialTvLayoutPreference() {
    final raw = _prefs.getString(_kTvLayoutPreference);
    if (raw != null) return TvLayoutPreference.parse(raw);
    // Migrate the legacy "force TV layout" bool: TRUE → horizontal,
    // FALSE / missing → vertical. The key is deleted on the next write
    // so we don't keep migrating forever.
    final legacy = _prefs.getBool(_kLegacyForceTvLayout);
    if (legacy == true) return TvLayoutPreference.horizontal;
    return TvLayoutPreference.vertical;
  }

  static Future<ServerRepository> open() async {
    final prefs = await SharedPreferences.getInstance();
    return ServerRepository(prefs);
  }

  ServerRepositorySnapshot load() {
    final raw = _prefs.getString(_kServers) ?? '';
    final servers = ServerConfig.decodeList(raw);
    final subscriptions = ServerSubscription.decodeList(
      _prefs.getString(_kSubscriptions),
    );
    final routingMode = AppRoutingMode.parse(
      _prefs.getString(_kAppRoutingMode),
    );
    final routingPackages = AppRoutingPolicy.decodePackages(
      _prefs.getString(_kAppRoutingPackages),
    );
    final rawProxyPackages = _prefs.getString(_kAppRoutingProxyPackages);
    final rawBypassPackages = _prefs.getString(_kAppRoutingBypassPackages);
    final hasSplitPackages =
        rawProxyPackages != null || rawBypassPackages != null;
    final appRoutingPolicy = hasSplitPackages
        ? AppRoutingPolicy(
            mode: routingMode,
            proxyPackages: AppRoutingPolicy.decodePackages(rawProxyPackages),
            bypassPackages: AppRoutingPolicy.decodePackages(rawBypassPackages),
          )
        : AppRoutingPolicy.legacy(mode: routingMode, packages: routingPackages);
    final routingRules = RoutingRule.decodeListFromStorage(
      _prefs.getString(_kRoutingRules),
    );
    final routingPresets = _loadRoutingPresets(
      fallbackPolicy: appRoutingPolicy,
      fallbackRules: routingRules,
    );
    return ServerRepositorySnapshot(
      servers: servers,
      subscriptions: subscriptions,
      selectedName: _prefs.getString(_kSelected),
      exitNodeName: _prefs.getString(_kExitNode),
      isGlobalProxy: _prefs.getBool(_kGlobalProxy) ?? false,
      tunEngineMode: TunEngineMode.parse(_prefs.getString(_kTunEngineMode)),
      autoConnectOnLaunch: _prefs.getBool(_kAutoConnectOnLaunch) ?? false,
      restartConnectionOnSettingsChanges:
          _prefs.getBool(_kRestartConnectionOnSettingsChanges) ?? false,
      showGlobalProxyButton:
          _prefs.getBool(_kShowGlobalProxyButton) ??
          !(_prefs.getBool(_kLegacyHideGlobalProxyButton) ?? true),
      autoSortServersByPing: _prefs.getBool(_kAutoSortServersByPing) ?? false,
      latencyProbeTarget: LatencyProbeTarget.decode(
        _prefs.getString(_kLatencyProbeTarget),
      ),
      favoritesSectionCollapsed:
          _prefs.getBool(_kFavoritesSectionCollapsed) ?? false,
      favoriteServerNames:
          _prefs.getStringList(_kFavoriteServerNames) ?? const <String>[],
      collapsedSubscriptionIds:
          _prefs.getStringList(_kCollapsedSubscriptionIds) ?? const <String>[],
      logLevels: AppLogLevel.decodeSet(_prefs.getString(_kLogLevels)),
      logRetention: AppLogRetention.decode(_prefs.getString(_kLogRetention)),
      keepAwake: _prefs.getBool(_kKeepAwake) ?? false,
      verboseXrayLogs: _prefs.getBool(_kVerboseXrayLogs) ?? false,
      appRoutingPolicy: appRoutingPolicy,
      routingRules: routingRules,
      routingPresets: routingPresets,
      selectedRoutingPresetId: _prefs.getString(_kSelectedRoutingPreset),
      customProxyAuthEnabled: _prefs.getBool(_kCustomProxyAuthEnabled) ?? false,
      customProxyUser: _prefs.getString(_kCustomProxyUser) ?? '',
      tunnelFragmentSettings: TunnelFragmentSettings.decode(
        _prefs.getString(_kTunnelFragmentSettings),
      ),
      multiplexSettings: MultiplexSettings.decode(
        _prefs.getString(_kMultiplexSettings),
      ),
      tunnelNetworkSettings: TunnelNetworkSettings.decode(
        _prefs.getString(_kTunnelNetworkSettings),
      ),
      subscriptionProviderSettings: SubscriptionProviderSettings.decode(
        _prefs.getString(_kSubscriptionProviderSettings),
      ),
    );
  }

  Future<void> saveServers(List<ServerConfig> servers) async {
    final encoded = await Isolate.run(() => ServerConfig.encodeList(servers));
    await _prefs.setString(_kServers, encoded);
  }

  Future<void> saveSubscriptions(List<ServerSubscription> subscriptions) async {
    final encoded = await Isolate.run(
      () => ServerSubscription.encodeList(subscriptions),
    );
    await _prefs.setString(_kSubscriptions, encoded);
  }

  Future<void> saveSelected(String? name) async {
    if (name == null) {
      await _prefs.remove(_kSelected);
    } else {
      await _prefs.setString(_kSelected, name);
    }
  }

  Future<void> saveExitNodeName(String? name) async {
    if (name == null) {
      await _prefs.remove(_kExitNode);
    } else {
      await _prefs.setString(_kExitNode, name);
    }
  }

  Future<void> saveGlobalProxy(bool value) async {
    await _prefs.setBool(_kGlobalProxy, value);
  }

  Future<void> saveTunEngineMode(TunEngineMode mode) async {
    await _prefs.setString(_kTunEngineMode, mode.wireName);
  }

  Future<void> saveAutoConnectOnLaunch(bool value) async {
    await _prefs.setBool(_kAutoConnectOnLaunch, value);
  }

  Future<void> saveRestartConnectionOnSettingsChanges(bool value) async {
    await _prefs.setBool(_kRestartConnectionOnSettingsChanges, value);
  }

  Future<void> saveShowGlobalProxyButton(bool value) async {
    await _prefs.setBool(_kShowGlobalProxyButton, value);
  }

  Future<void> saveAutoSortServersByPing(bool value) async {
    await _prefs.setBool(_kAutoSortServersByPing, value);
  }

  Future<void> saveLatencyProbeTarget(LatencyProbeTarget target) async {
    if (target.usesServerEndpoint) {
      await _prefs.remove(_kLatencyProbeTarget);
    } else {
      await _prefs.setString(_kLatencyProbeTarget, target.encode());
    }
  }

  Future<void> saveFavoritesSectionCollapsed(bool value) async {
    await _prefs.setBool(_kFavoritesSectionCollapsed, value);
  }

  Future<void> saveFavoriteServerNames(List<String> names) async {
    await _prefs.setStringList(_kFavoriteServerNames, names);
  }

  List<String> loadCollapsedSubscriptionIds() {
    return _prefs.getStringList(_kCollapsedSubscriptionIds) ?? const <String>[];
  }

  Future<void> saveCollapsedSubscriptionIds(List<String> ids) async {
    await _prefs.setStringList(_kCollapsedSubscriptionIds, ids);
  }

  Future<void> saveLogLevels(Set<AppLogLevel> levels) async {
    await _prefs.setString(_kLogLevels, AppLogLevel.encodeSet(levels));
  }

  Future<void> saveLogRetention(AppLogRetention retention) async {
    await _prefs.setString(_kLogRetention, retention.wireName);
  }

  Future<void> saveRoutingRules(List<RoutingRule> rules) async {
    await _prefs.setString(
      _kRoutingRules,
      RoutingRule.encodeListForStorage(rules),
    );
  }

  Future<void> saveAppRoutingPolicy(AppRoutingPolicy policy) async {
    await _prefs.setString(_kAppRoutingMode, policy.mode.wireName);
    await _prefs.setString(
      _kAppRoutingPackages,
      AppRoutingPolicy.encodePackages(policy.packages),
    );
    await _prefs.setString(
      _kAppRoutingProxyPackages,
      AppRoutingPolicy.encodePackages(policy.proxyPackages),
    );
    await _prefs.setString(
      _kAppRoutingBypassPackages,
      AppRoutingPolicy.encodePackages(policy.bypassPackages),
    );
  }

  Future<void> saveRoutingPresets(List<RoutingPreset> presets) async {
    await _prefs.setString(_kRoutingPresets, RoutingPreset.encodeList(presets));
  }

  Future<void> saveSelectedRoutingPresetId(String id) async {
    await _prefs.setString(_kSelectedRoutingPreset, id);
  }

  bool loadDarkTheme() {
    return _prefs.getBool(_kDarkTheme) ?? false;
  }

  Future<void> saveDarkTheme(bool value) async {
    await _prefs.setBool(_kDarkTheme, value);
  }

  /// Which UI flavour and orientation lock the app should apply on
  /// non-TV devices. See [TvLayoutPreference]; on a real Android TV
  /// this still gets read but the layout switches to TV regardless.
  TvLayoutPreference loadTvLayoutPreference() => _tvLayoutPrefNotifier.value;

  /// Stable handle the detector and the orientation manager subscribe
  /// to so the UI can swap live when the user changes the preference.
  ValueListenable<TvLayoutPreference> get tvLayoutPreferenceListenable =>
      _tvLayoutPrefNotifier;

  Future<void> saveTvLayoutPreference(TvLayoutPreference value) async {
    if (_tvLayoutPrefNotifier.value == value) return;
    await _prefs.setString(_kTvLayoutPreference, value.wireName);
    // Drop the legacy bool now that the new key is authoritative.
    if (_prefs.containsKey(_kLegacyForceTvLayout)) {
      await _prefs.remove(_kLegacyForceTvLayout);
    }
    _tvLayoutPrefNotifier.value = value;
  }

  bool loadForceTvLayout() => loadTvLayoutPreference().prefersTvLayout;

  Future<void> saveForceTvLayout(bool value) async {
    await saveTvLayoutPreference(
      value ? TvLayoutPreference.horizontal : TvLayoutPreference.vertical,
    );
  }

  AppLocalePreference loadAppLocalePreference() {
    return AppLocalePreference.parse(_prefs.getString(_kAppLocalePreference));
  }

  Future<void> saveAppLocalePreference(AppLocalePreference value) async {
    await _prefs.setString(_kAppLocalePreference, value.wireName);
  }

  bool loadNotificationPermissionAsked() {
    return _prefs.getBool(_kNotificationPermissionAsked) ?? false;
  }

  Future<void> saveNotificationPermissionAsked(bool value) async {
    await _prefs.setBool(_kNotificationPermissionAsked, value);
  }

  bool loadShowSpeedInNotification() {
    return _prefs.getBool(_kShowSpeedInNotification) ?? false;
  }

  Future<void> saveShowSpeedInNotification(bool value) async {
    await _prefs.setBool(_kShowSpeedInNotification, value);
  }

  Future<void> saveKeepAwake(bool value) async {
    await _prefs.setBool(_kKeepAwake, value);
  }

  Future<void> saveVerboseXrayLogs(bool value) async {
    await _prefs.setBool(_kVerboseXrayLogs, value);
  }

  Future<void> saveCustomProxyAuthEnabled(bool value) async {
    await _prefs.setBool(_kCustomProxyAuthEnabled, value);
  }

  Future<void> saveCustomProxyUser(String value) async {
    if (value.isEmpty) {
      await _prefs.remove(_kCustomProxyUser);
    } else {
      await _prefs.setString(_kCustomProxyUser, value);
    }
  }

  Future<void> saveCustomProxyPassword(String value) async {
    if (value.isEmpty) {
      await _secure.remove(_kCustomProxyPassword);
    } else {
      await _secure.writeString(_kCustomProxyPassword, value);
    }
    // Always clear any leftover plain-text copy from older builds. Cheap and
    // makes the migration in [loadCustomProxyPassword] idempotent.
    await _prefs.remove(_kCustomProxyPassword);
  }

  /// Reads the custom proxy password from EncryptedSharedPreferences. If the
  /// value still lives in plain-text SharedPreferences (a pre-#8 install),
  /// migrate it across and wipe the legacy copy on the same call.
  Future<String> loadCustomProxyPassword() async {
    final secure = await _secure.readString(_kCustomProxyPassword);
    if (secure != null && secure.isNotEmpty) {
      // Belt-and-braces: if the legacy plain-text entry is still around (e.g.
      // an aborted earlier migration), drop it now.
      if (_prefs.containsKey(_kCustomProxyPassword)) {
        await _prefs.remove(_kCustomProxyPassword);
      }
      return secure;
    }
    final legacy = _prefs.getString(_kCustomProxyPassword) ?? '';
    if (legacy.isEmpty) return '';
    await _secure.writeString(_kCustomProxyPassword, legacy);
    await _prefs.remove(_kCustomProxyPassword);
    return legacy;
  }

  Future<void> saveTunnelFragmentSettings(
    TunnelFragmentSettings settings,
  ) async {
    await _prefs.setString(
      _kTunnelFragmentSettings,
      settings.normalized().encode(),
    );
  }

  Future<void> saveMultiplexSettings(MultiplexSettings settings) async {
    await _prefs.setString(_kMultiplexSettings, settings.normalized().encode());
  }

  Future<void> saveTunnelNetworkSettings(TunnelNetworkSettings settings) async {
    await _prefs.setString(_kTunnelNetworkSettings, settings.encode());
  }

  Future<void> saveSubscriptionProviderSettings(
    SubscriptionProviderSettings settings,
  ) async {
    await _prefs.setString(_kSubscriptionProviderSettings, settings.encode());
  }

  GeoDataMetadata loadGeoDataMetadata(GeoDataKind kind) {
    final updatedAtMillis = _prefs.getInt(
      _geoDataKey(_kGeoDataUpdatedAtPrefix, kind),
    );
    return GeoDataMetadata(
      source: GeoDataSource.parse(
        _prefs.getString(_geoDataKey(_kGeoDataSourcePrefix, kind)),
      ),
      url: _prefs.getString(_geoDataKey(_kGeoDataUrlPrefix, kind)),
      updatedAt: updatedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAtMillis, isUtc: true),
      fileSize: _prefs.getInt(_geoDataKey(_kGeoDataFileSizePrefix, kind)) ?? 0,
    );
  }

  Future<void> saveGeoDataMetadata(
    GeoDataKind kind,
    GeoDataMetadata metadata,
  ) async {
    await _prefs.setString(
      _geoDataKey(_kGeoDataSourcePrefix, kind),
      metadata.source.wireName,
    );
    final url = metadata.url;
    if (url == null || url.isEmpty) {
      await _prefs.remove(_geoDataKey(_kGeoDataUrlPrefix, kind));
    } else {
      await _prefs.setString(_geoDataKey(_kGeoDataUrlPrefix, kind), url);
    }
    final updatedAt = metadata.updatedAt;
    if (updatedAt == null) {
      await _prefs.remove(_geoDataKey(_kGeoDataUpdatedAtPrefix, kind));
    } else {
      await _prefs.setInt(
        _geoDataKey(_kGeoDataUpdatedAtPrefix, kind),
        updatedAt.toUtc().millisecondsSinceEpoch,
      );
    }
    if (metadata.fileSize <= 0) {
      await _prefs.remove(_geoDataKey(_kGeoDataFileSizePrefix, kind));
    } else {
      await _prefs.setInt(
        _geoDataKey(_kGeoDataFileSizePrefix, kind),
        metadata.fileSize,
      );
    }
  }

  static String _geoDataKey(String prefix, GeoDataKind kind) {
    return '$prefix${kind.wireName}';
  }

  List<RoutingPreset> _loadRoutingPresets({
    required AppRoutingPolicy fallbackPolicy,
    required List<RoutingRule> fallbackRules,
  }) {
    final stored = RoutingPreset.decodeList(_prefs.getString(_kRoutingPresets));
    if (stored.isNotEmpty) return _ensureMainPreset(stored);
    return [
      RoutingPreset.main(
        appRoutingPolicy: fallbackPolicy,
        routingRules: fallbackRules,
      ),
    ];
  }

  static List<RoutingPreset> _ensureMainPreset(List<RoutingPreset> presets) {
    final seen = <String>{};
    final output = <RoutingPreset>[];
    for (final preset in presets) {
      final normalized = preset.normalized();
      if (!seen.add(normalized.id)) continue;
      output.add(normalized);
    }
    if (output.every((preset) => !preset.isMain)) {
      output.insert(0, RoutingPreset.main());
    }
    final mainIndex = output.indexWhere((preset) => preset.isMain);
    if (mainIndex > 0) {
      final main = output.removeAt(mainIndex);
      output.insert(0, main);
    }
    return output;
  }
}
