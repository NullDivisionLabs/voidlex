import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';
import 'app_message_code.dart';
import 'app_routing.dart';
import 'deep_link_channel.dart';
import 'dev_servers.dart';
import 'device_identity.dart';
import 'geo_data.dart';
import 'installed_apps.dart';
import 'models/server_config.dart';
import 'models/server_subscription.dart';
import 'multiplex_settings.dart';
import 'profile_exporter.dart';
import 'profile_importer.dart';
import 'routing_preset.dart';
import 'routing_rule.dart';
import 'server_importer.dart';
import 'server_latency_probe.dart';
import 'server_repository.dart';
import 'server_subscription_importer.dart';
import 'subscription_link_codec.dart';
import 'subscription_provider_settings.dart';
import 'tunnel_fragment_settings.dart';
import 'tunnel_network_settings.dart';
import 'tun_engine_mode.dart';
import 'vless_parser.dart';

enum VpnConnectionState {
  disconnected,
  preparing,
  connecting,
  connected,
  disconnecting,
  error,
}

class _ProtectedProfileSubscriptions {
  const _ProtectedProfileSubscriptions({
    required this.subscriptions,
    required this.failureCount,
  });

  const _ProtectedProfileSubscriptions.empty()
    : subscriptions = const <ServerSubscription>[],
      failureCount = 0;

  final List<ServerSubscription> subscriptions;
  final int failureCount;
}

class _AppRoutingFilterResult {
  const _AppRoutingFilterResult({
    required this.presets,
    required this.droppedCount,
  });

  final List<RoutingPreset> presets;
  final int droppedCount;
}

class VpnController extends ChangeNotifier {
  VpnController(
    this._repository, {
    VlessParser? parser,
    GeoDataBridge? geoDataBridge,
    SubscriptionLinkCodec? subscriptionLinkCodec,
    DeepLinkChannel? deepLinkChannel,
    InstalledAppsBridge? installedAppsBridge,
  }) : _parser = parser ?? const VlessParser(),
       _geoDataBridge = geoDataBridge ?? const GeoDataBridge(),
       _linkCodec = subscriptionLinkCodec ?? const SubscriptionLinkCodec(),
       _deepLinkChannel = deepLinkChannel ?? DeepLinkChannel(),
       _installedAppsBridge =
           installedAppsBridge ?? const InstalledAppsBridge() {
    _bindEventChannel();
    _bindDeepLinkChannel();
    _bindGeoDataProgressChannel();
  }

  static const Duration _connectTimeout = Duration(seconds: 15);
  // Short per-request timeout because we race the lookup URLs in parallel —
  // a slow endpoint no longer blocks the pipeline behind it.
  static const Duration _ipRequestTimeout = Duration(seconds: 3);
  // Small delay before the first attempt so the tunnel has a chance to
  // finish wiring routes after "connected" fires.
  static const Duration _ipLookupInitialDelay = Duration(milliseconds: 500);
  // If all endpoints fail on the first pass (common right after connect
  // on flaky networks), we retry once after this backoff.
  static const Duration _ipLookupRetryBackoff = Duration(seconds: 2);
  static const int _ipLookupAttempts = 2;
  static const int _latencyScanConcurrency = 4;
  static const Duration _pingBatchInterval = Duration(milliseconds: 300);
  // Auto-triggered full scans (launch, resume from tray) are throttled to
  // this interval. Manual UI taps bypass the cooldown via `force: true`.
  static const Duration _fullScanCooldown = Duration(minutes: 15);
  // Window during which a `disconnected` event is expected to arrive as a
  // consequence of our own `stopVpn` call (timeout or explicit disconnect).
  // Bounding the ignore window ensures a legitimate later disconnect — e.g.
  // after a silent reconnect — still reaches the UI.
  static const Duration _disconnectSuppressionWindow = Duration(seconds: 3);
  static const Duration _disconnectFallbackTimeout = Duration(seconds: 5);
  static const Duration _androidVpnRestartStopTimeout = Duration(seconds: 5);
  static const Duration _androidVpnPostStopSettleDelay = Duration(
    milliseconds: 500,
  );
  // IPv4-only endpoints so the displayed IP stays consistent across nodes
  // with IPv6 connectivity. A dual-stack endpoint can resolve to AAAA at the
  // final VLESS node and surface an IPv6 that races ahead of the IPv4 reply.
  static const List<String> _ipLookupUrls = [
    'https://api.ipify.org?format=text',
    'https://ipv4.icanhazip.com',
    'https://checkip.amazonaws.com/',
  ];
  // Must match RuntimePorts.XRAY_HTTP_PROXY_PORT on Android.
  static const String _externalIpProxyHost = '127.0.0.1';
  static const int _externalIpProxyPort = 10809;

  static const MethodChannel _methodChannel = MethodChannel(
    'org.voidtunnel.vpn/service',
  );
  static const EventChannel _eventChannel = EventChannel(
    'org.voidtunnel.vpn/state',
  );

  final ServerRepository _repository;

  /// Repository the controller was bootstrapped with. Exposed so UI
  /// pieces that already hold the controller (settings screens, the TV
  /// home) can read or persist preferences without re-plumbing the
  /// repository through every constructor.
  ServerRepository get repository => _repository;
  final VlessParser _parser;
  final GeoDataBridge _geoDataBridge;
  final SubscriptionLinkCodec _linkCodec;
  final DeepLinkChannel _deepLinkChannel;
  final InstalledAppsBridge _installedAppsBridge;
  final ServerLatencyProbe _latencyProbe = const ServerLatencyProbe();
  StreamSubscription<dynamic>? _eventSub;
  StreamSubscription<String>? _deepLinkSub;
  StreamSubscription<GeoDataDownloadProgress>? _geoDataProgressSub;
  Timer? _connectTimeoutTimer;
  Timer? _disconnectTimeoutTimer;
  Timer? _connectionTicker;
  Timer? _subscriptionAutoRefreshTimer;
  Timer? _pingBatchTimer;
  final Map<String, DateTime> _subscriptionAutoRefreshAttemptedAt = {};
  Future<String?>? _pendingHwidFetch;
  final ValueNotifier<String> _connectionDurationLabelNotifier = ValueNotifier(
    _formatDuration(Duration.zero),
  );
  // Focused notifiers so frequently-changing signals (state transitions,
  // latency scan progress) can drive small slices of the UI directly via
  // ValueListenableBuilder instead of rebuilding the whole HomeScreen tree
  // through the main ChangeNotifier.
  final ValueNotifier<VpnConnectionState> _connectionStateNotifier =
      ValueNotifier(VpnConnectionState.disconnected);
  final ValueNotifier<int> _latencyScanTick = ValueNotifier<int>(0);

  final List<ServerConfig> _servers = [];
  final List<ServerSubscription> _subscriptions = [];
  String? _selectedName;
  String? _exitNodeName;
  bool _isGlobalProxy = false;
  TunEngineMode _tunEngineMode = TunEngineMode.libbox;
  bool _autoConnectOnLaunch = false;
  bool _restartConnectionOnSettingsChanges = false;
  bool _showGlobalProxyButton = false;
  bool _autoSortServersByPing = false;
  LatencyProbeTarget _latencyProbeTarget = LatencyProbeTarget.serverEndpoint;
  bool _favoritesSectionCollapsed = false;
  final List<String> _favoriteServerNames = [];
  final Set<String> _collapsedSubscriptionIds = <String>{};
  bool _showSpeedInNotification = false;
  bool _keepAwake = false;
  bool _verboseXrayLogs = false;
  Set<AppLogLevel> _logLevels = Set<AppLogLevel>.of(AppLogLevel.defaultLevels);
  AppLogRetention _logRetention = AppLogRetention.defaultRetention;
  final List<RoutingPreset> _routingPresets = [];
  String _selectedRoutingPresetId = RoutingPreset.mainId;
  String? _routingPresetWarning;
  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  String? _lastError;
  bool _acceptConnectedEvent = false;
  DateTime? _suppressDisconnectedUntil;
  bool _isScanningLatency = false;
  DateTime? _lastFullScanTime;
  final Set<String> _scanningSubscriptionIds = <String>{};
  final Set<String> _refreshingSubscriptionIds = <String>{};
  final Set<GeoDataKind> _busyGeoDataKinds = <GeoDataKind>{};
  final Map<GeoDataKind, int?> _geoDataProgressByKind = <GeoDataKind, int?>{};
  final Map<String, String> _pingBuffer = <String, String>{};
  DateTime? _connectedAt;
  String? _externalIp;
  bool _hasExternalIpAttempt = false;
  int _runtimeGeneration = 0;
  int _restartRequestId = 0;
  Future<void>? _restartFuture;
  bool _networkSettingsRestartPending = false;
  bool _useCustomProxyAuth = false;
  String _customProxyUser = '';
  String _customProxyPassword = '';
  TunnelFragmentSettings _tunnelFragmentSettings =
      TunnelFragmentSettings.defaults;
  MultiplexSettings _multiplexSettings = MultiplexSettings.defaults;
  TunnelNetworkSettings _tunnelNetworkSettings = TunnelNetworkSettings.defaults;
  SubscriptionProviderSettings _subscriptionProviderSettings =
      SubscriptionProviderSettings.defaults;
  String? _activeProxyUser;
  String? _activeProxyPassword;
  String? _cachedSubscriptionHwid;
  bool _refreshingAllSubscriptions = false;
  // Set to a fresh completer while a stop/restart sequence is waiting for
  // the native side to confirm teardown. Resolved from `_bindEventChannel`
  // the moment libbox/Xray reports `disconnected` or `error`, so the
  // restart path can react without polling getVpnStatus.
  Completer<void>? _nativeStopWaiter;

  // ─── Public getters ───────────────────────────────────────────────
  // Bumped on every notifyListeners() (see override below). The view-layer
  // getters cache their result against this version; within one build pass
  // — when AnimatedBuilder reads `servers`, `favoriteServers` and
  // `manualServers` in succession — they all hit the cache instead of
  // rebuilding the merged list three times.
  int _viewVersion = 0;
  int _cachedAllServersVersion = -1;
  List<ServerConfig>? _cachedAllServers;
  int _cachedFavoriteServersVersion = -1;
  List<ServerConfig>? _cachedFavoriteServers;
  int _cachedManualServersVersion = -1;
  List<ServerConfig>? _cachedManualServers;
  int _cachedSubscriptionsVersion = -1;
  List<ServerSubscription>? _cachedSubscriptions;

  List<ServerConfig> get servers {
    if (_cachedAllServersVersion == _viewVersion && _cachedAllServers != null) {
      return _cachedAllServers!;
    }
    final result = List<ServerConfig>.unmodifiable(_allServerList());
    _cachedAllServers = result;
    _cachedAllServersVersion = _viewVersion;
    return result;
  }

  List<ServerConfig> get manualServers {
    if (_cachedManualServersVersion == _viewVersion &&
        _cachedManualServers != null) {
      return _cachedManualServers!;
    }
    final result = List<ServerConfig>.unmodifiable(_servers);
    _cachedManualServers = result;
    _cachedManualServersVersion = _viewVersion;
    return result;
  }

  List<ServerSubscription> get subscriptions {
    if (_cachedSubscriptionsVersion == _viewVersion &&
        _cachedSubscriptions != null) {
      return _cachedSubscriptions!;
    }
    final result = List<ServerSubscription>.unmodifiable(_subscriptions);
    _cachedSubscriptions = result;
    _cachedSubscriptionsVersion = _viewVersion;
    return result;
  }

  List<ServerConfig> get favoriteServers {
    if (_cachedFavoriteServersVersion == _viewVersion &&
        _cachedFavoriteServers != null) {
      return _cachedFavoriteServers!;
    }
    final result = List<ServerConfig>.unmodifiable(_orderedFavoriteServers());
    _cachedFavoriteServers = result;
    _cachedFavoriteServersVersion = _viewVersion;
    return result;
  }

  bool get hasAnyServers =>
      _servers.isNotEmpty ||
      _subscriptions.any((subscription) => subscription.servers.isNotEmpty);

  @override
  void notifyListeners() {
    _viewVersion++;
    super.notifyListeners();
  }

  String? get selectedName => _selectedName;
  String? get exitNodeId => _exitNodeName;
  ServerConfig? get selectedServer {
    if (_selectedName == null) return null;
    for (final s in _allServerList()) {
      if (_serverNameEquals(s.name, _selectedName)) return s;
    }
    return null;
  }

  bool get isGlobalProxy => _isGlobalProxy;
  TunEngineMode get tunEngineMode => _tunEngineMode;
  bool get autoConnectOnLaunch => _autoConnectOnLaunch;
  bool get restartConnectionOnSettingsChanges =>
      _restartConnectionOnSettingsChanges;
  bool get showGlobalProxyButton => _showGlobalProxyButton;
  bool get autoSortServersByPing => _autoSortServersByPing;
  LatencyProbeTarget get latencyProbeTarget => _latencyProbeTarget;
  bool get favoritesSectionCollapsed => _favoritesSectionCollapsed;
  bool isSubscriptionCollapsed(String id) =>
      _collapsedSubscriptionIds.contains(id);
  bool get showSpeedInNotification => _showSpeedInNotification;
  bool get keepAwake => _keepAwake;
  bool get verboseXrayLogs => _verboseXrayLogs;
  bool get useCustomProxyAuth => _useCustomProxyAuth;
  String get customProxyUser => _customProxyUser;
  String get customProxyPassword => _customProxyPassword;
  TunnelFragmentSettings get tunnelFragmentSettings => _tunnelFragmentSettings;
  MultiplexSettings get multiplexSettings => _multiplexSettings;
  TunnelNetworkSettings get tunnelNetworkSettings => _tunnelNetworkSettings;
  SubscriptionProviderSettings get subscriptionProviderSettings =>
      _subscriptionProviderSettings;

  Future<String> exportProfileAsJsonString({DateTime? exportedAt}) async {
    final protect = _subscriptionProviderSettings.protectSubscriptions;
    final protectedLinks = protect
        ? await Future.wait(
            _subscriptions.map(
              (sub) => _linkCodec.encode(url: sub.url, name: sub.name),
            ),
          )
        : const <String>[];
    return ProfileExporter.exportJson(
      manualNodes: _servers,
      subscriptions: _subscriptions,
      routingPresets: _routingPresets,
      selectedRoutingPresetId: _selectedRoutingPresetId,
      protectSubscriptions: protect,
      protectedSubscriptionLinks: protectedLinks,
      exportedAt: exportedAt,
    );
  }

  /// Encodes [subscription] as a `voidtunnel://1/...` shareable code.
  Future<String> encodeSubscriptionAsLink(ServerSubscription subscription) {
    return _linkCodec.encode(url: subscription.url, name: subscription.name);
  }

  Set<AppLogLevel> get logLevels => Set<AppLogLevel>.unmodifiable(_logLevels);
  AppLogRetention get logRetention => _logRetention;
  List<RoutingPreset> get routingPresets =>
      List<RoutingPreset>.unmodifiable(_routingPresets);
  RoutingPreset get selectedRoutingPreset => _activeRoutingPreset;
  String get selectedRoutingPresetId => _selectedRoutingPresetId;
  AppRoutingPolicy get appRoutingPolicy =>
      _activeRoutingPreset.appRoutingPolicy;
  List<RoutingRule> get routingRules =>
      List.unmodifiable(_activeRoutingPreset.routingRules);
  bool get selectedRoutingPresetAffectsSelectedServer =>
      _activeRoutingPresetAffectsSelectedServer();
  VpnConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == VpnConnectionState.connected;
  bool get _hasRestartableNativeSession =>
      _connectionState == VpnConnectionState.connected ||
      _connectionState == VpnConnectionState.connecting;
  bool get isBusy =>
      _connectionState == VpnConnectionState.preparing ||
      _connectionState == VpnConnectionState.connecting ||
      _connectionState == VpnConnectionState.disconnecting;
  String? get lastError => _lastError;
  bool get isScanningLatency => _isScanningLatency;

  /// True while the auto-throttled full scan window from the last completed
  /// scan has not elapsed. Manual scans bypass this.
  bool get isFullScanOnCooldown => _isFullScanOnCooldown();
  bool isScanningSubscription(String id) =>
      _scanningSubscriptionIds.contains(id);
  bool isRefreshingSubscription(String id) =>
      _refreshingSubscriptionIds.contains(id);
  Set<GeoDataKind> get busyGeoDataKinds =>
      Set<GeoDataKind>.unmodifiable(_busyGeoDataKinds);
  Map<GeoDataKind, int?> get geoDataProgressByKind =>
      Map<GeoDataKind, int?>.unmodifiable(_geoDataProgressByKind);
  bool isGeoDataBusy(GeoDataKind kind) => _busyGeoDataKinds.contains(kind);

  /// Resolved public IP when connected; otherwise null.
  String? get externalIpIfResolved => _externalIp;

  /// True while connected and the first external-IP lookup has not started.
  bool get isResolvingExternalIp =>
      isConnected && _externalIp == null && !_hasExternalIpAttempt;

  /// True when connected, lookup ran, but no IP was obtained.
  bool get isExternalIpUnavailable =>
      isConnected && _externalIp == null && _hasExternalIpAttempt;

  ValueListenable<String> get connectionDurationLabelListenable =>
      _connectionDurationLabelNotifier;
  String get connectionDurationLabel => _connectionDurationLabelNotifier.value;
  // Listen on this instead of the whole controller when you only care about
  // connect/disconnect/error transitions (top status strip, hub button).
  ValueListenable<VpnConnectionState> get connectionStateListenable =>
      _connectionStateNotifier;
  // Bumped every time a ping cell changes during a latency scan. The value
  // itself is opaque — it exists so the latency-affected widgets can listen
  // without subscribing to the whole controller.
  ValueListenable<int> get latencyScanTickListenable => _latencyScanTick;
  bool isExitNode(String serverId) =>
      _exitNodeName != null && _serverNameEquals(_exitNodeName, serverId);
  bool hasExplicitRoutingPresetForServer(String serverName) =>
      explicitRoutingPresetForServer(serverName) != null;

  RoutingPreset? explicitRoutingPresetForServer(String serverName) {
    final normalizedServerName = RoutingPreset.normalizeServerName(serverName);
    if (normalizedServerName == null) return null;
    for (final preset in _routingPresets) {
      if (!preset.isMain && preset.serverNames.contains(normalizedServerName)) {
        return preset;
      }
    }
    return null;
  }

  ServerConfig? get exitServer {
    final name = _exitNodeName;
    if (name == null) return null;
    for (final s in _allServerList()) {
      if (_serverNameEquals(s.name, name)) return s;
    }
    return null;
  }

  String? consumeRoutingPresetWarning() {
    final warning = _routingPresetWarning;
    _routingPresetWarning = null;
    return warning;
  }

  RoutingPreset get _activeRoutingPreset {
    final selectedIndex = _routingPresets.indexWhere(
      (preset) => preset.id == _selectedRoutingPresetId,
    );
    if (selectedIndex >= 0) return _routingPresets[selectedIndex];
    final mainIndex = _routingPresets.indexWhere((preset) => preset.isMain);
    if (mainIndex >= 0) return _routingPresets[mainIndex];
    return RoutingPreset.main();
  }

  int get _activeRoutingPresetIndex {
    final selectedIndex = _routingPresets.indexWhere(
      (preset) => preset.id == _selectedRoutingPresetId,
    );
    if (selectedIndex >= 0) return selectedIndex;
    return _routingPresets.indexWhere((preset) => preset.isMain);
  }

  RoutingPreset get _mainRoutingPreset {
    final mainIndex = _routingPresets.indexWhere((preset) => preset.isMain);
    if (mainIndex >= 0) return _routingPresets[mainIndex];
    return RoutingPreset.main();
  }

  RoutingPreset _routingPresetForServer(String? serverName) {
    if (serverName != null) {
      final explicit = explicitRoutingPresetForServer(serverName);
      if (explicit != null) return explicit;
    }
    return _mainRoutingPreset;
  }

  RoutingPreset _routingPresetForConnection(ServerConfig server) {
    final explicit = explicitRoutingPresetForServer(server.name);
    if (explicit != null) return explicit;
    return _mainRoutingPreset;
  }

  bool _activeRoutingPresetAffectsSelectedServer() {
    return _routingPresetForServer(_selectedName).id == _activeRoutingPreset.id;
  }

  String _validRoutingPresetId(String? id) {
    if (id != null && _routingPresets.any((preset) => preset.id == id)) {
      return id;
    }
    return RoutingPreset.mainId;
  }

  // ─── Initialization ───────────────────────────────────────────────
  List<ServerConfig> _allServerList({String? excludingSubscriptionId}) {
    return [
      ..._servers,
      for (final subscription in _subscriptions)
        if (subscription.id != excludingSubscriptionId) ...subscription.servers,
    ];
  }

  List<ServerConfig> _orderedFavoriteServers() {
    final pinnedServers = _allServerList()
        .where((server) => server.isPinned)
        .toList(growable: false);
    if (pinnedServers.isEmpty) return const <ServerConfig>[];

    final pinnedByName = <String, ServerConfig>{};
    for (final server in pinnedServers) {
      final normalizedName = RoutingPreset.normalizeServerName(server.name);
      if (normalizedName == null) continue;
      pinnedByName.putIfAbsent(normalizedName, () => server);
    }

    final ordered = <ServerConfig>[];
    final seen = <String>{};
    for (final name in _favoriteServerNames) {
      final normalizedName = RoutingPreset.normalizeServerName(name);
      if (normalizedName == null) continue;
      final server = pinnedByName[normalizedName];
      if (server == null || !seen.add(normalizedName)) continue;
      ordered.add(server);
    }
    for (final server in pinnedServers) {
      final normalizedName = RoutingPreset.normalizeServerName(server.name);
      if (normalizedName == null || !seen.add(normalizedName)) continue;
      ordered.add(server);
    }
    return ordered;
  }

  bool _syncFavoriteServerNames() {
    final next = _orderedFavoriteServers()
        .map((server) => server.name)
        .toList(growable: false);
    if (listEquals(_favoriteServerNames, next)) return false;
    _favoriteServerNames
      ..clear()
      ..addAll(next);
    return true;
  }

  bool _syncCollapsedSubscriptionIds() {
    final knownIds = _subscriptions
        .map((subscription) => subscription.id)
        .toSet();
    final before = _collapsedSubscriptionIds.length;
    _collapsedSubscriptionIds.removeWhere((id) => !knownIds.contains(id));
    return _collapsedSubscriptionIds.length != before;
  }

  Set<String> _allServerNames({String? excludingSubscriptionId}) {
    return _allServerList(
      excludingSubscriptionId: excludingSubscriptionId,
    ).map((server) => server.name).toSet();
  }

  bool _serverNameEquals(String? left, String? right) {
    final normalizedLeft = RoutingPreset.normalizeServerName(left);
    final normalizedRight = RoutingPreset.normalizeServerName(right);
    return normalizedLeft != null &&
        normalizedRight != null &&
        normalizedLeft == normalizedRight;
  }

  String? _canonicalServerName(String name) {
    final normalizedName = RoutingPreset.normalizeServerName(name);
    if (normalizedName == null) return null;
    for (final server in _allServerList()) {
      if (RoutingPreset.normalizeServerName(server.name) == normalizedName) {
        return server.name;
      }
    }
    return null;
  }

  String? _firstAvailableServerName() {
    if (_servers.isNotEmpty) return _servers.first.name;
    for (final subscription in _subscriptions) {
      if (subscription.servers.isNotEmpty) {
        return subscription.servers.first.name;
      }
    }
    return null;
  }

  Future<void> bootstrap() async {
    final snapshot = _repository.load();
    _servers
      ..clear()
      ..addAll(snapshot.servers);
    _subscriptions
      ..clear()
      ..addAll(snapshot.subscriptions);
    _favoriteServerNames
      ..clear()
      ..addAll(snapshot.favoriteServerNames);
    _collapsedSubscriptionIds
      ..clear()
      ..addAll(snapshot.collapsedSubscriptionIds);

    if (_servers.isEmpty && _subscriptions.isEmpty) {
      _servers.addAll(defaultDevServers());
    }

    final storedSelectedName = snapshot.selectedName;
    _selectedName = storedSelectedName != null
        ? _canonicalServerName(storedSelectedName) ??
              _firstAvailableServerName()
        : _firstAvailableServerName();
    final storedExitName = snapshot.exitNodeName;
    _exitNodeName = storedExitName != null
        ? _canonicalServerName(storedExitName)
        : null;
    if (_exitNodeName != null &&
        _serverNameEquals(_exitNodeName, _selectedName)) {
      _exitNodeName = null;
    }
    if (storedExitName != null && _exitNodeName == null) {
      await _repository.saveExitNodeName(null);
    }
    _isGlobalProxy = snapshot.isGlobalProxy;
    _tunEngineMode = snapshot.tunEngineMode;
    _autoConnectOnLaunch = snapshot.autoConnectOnLaunch;
    _restartConnectionOnSettingsChanges =
        snapshot.restartConnectionOnSettingsChanges;
    _showGlobalProxyButton = snapshot.showGlobalProxyButton;
    _autoSortServersByPing = snapshot.autoSortServersByPing;
    _latencyProbeTarget = snapshot.latencyProbeTarget;
    _favoritesSectionCollapsed = snapshot.favoritesSectionCollapsed;
    final favoriteOrderChanged = _syncFavoriteServerNames();
    final collapsedSubscriptionIdsChanged = _syncCollapsedSubscriptionIds();
    if (favoriteOrderChanged) {
      await _persistFavoriteServerNames();
    }
    if (collapsedSubscriptionIdsChanged) {
      await _persistCollapsedSubscriptionIds();
    }
    _logLevels = Set<AppLogLevel>.of(snapshot.logLevels);
    _logRetention = snapshot.logRetention;
    _keepAwake = snapshot.keepAwake;
    _verboseXrayLogs = snapshot.verboseXrayLogs;
    await const AppLogBridge().setRetention(_logRetention);
    _showSpeedInNotification = _repository.loadShowSpeedInNotification();
    if (!_showGlobalProxyButton && _isGlobalProxy) {
      _isGlobalProxy = false;
      await _repository.saveGlobalProxy(false);
    }
    _routingPresets
      ..clear()
      ..addAll(_sanitizeRoutingPresets(snapshot.routingPresets));
    _cleanRoutingPresetBindings();
    _selectedRoutingPresetId = _validRoutingPresetId(
      snapshot.selectedRoutingPresetId,
    );
    await _repository.saveRoutingPresets(_routingPresets);
    await _repository.saveSelectedRoutingPresetId(_selectedRoutingPresetId);
    _useCustomProxyAuth = snapshot.customProxyAuthEnabled;
    _customProxyUser = snapshot.customProxyUser;
    // Password lives in EncryptedSharedPreferences (with a one-time migration
    // from the legacy plain-text SharedPreferences slot). Load asynchronously
    // so the secret never sits unprotected.
    _customProxyPassword = await _repository.loadCustomProxyPassword();
    _tunnelFragmentSettings = snapshot.tunnelFragmentSettings;
    _multiplexSettings = snapshot.multiplexSettings;
    _tunnelNetworkSettings = snapshot.tunnelNetworkSettings;
    _subscriptionProviderSettings = snapshot.subscriptionProviderSettings;
    await _restoreNativeRuntimeState();
    await _pushActiveLogLevelsToNative();
    _scheduleSubscriptionAutoRefresh();
    notifyListeners();
    if (_subscriptionProviderSettings.updateOnLaunch) {
      unawaited(_refreshSubscriptionsAfterLaunch());
    }
  }

  Future<void> _refreshSubscriptionsAfterLaunch() async {
    await Future<void>.delayed(Duration.zero);
    await _refreshAllSubscriptions();
  }

  Future<void> _restoreNativeRuntimeState() async {
    if (!Platform.isAndroid) return;
    final Map<dynamic, dynamic>? status;
    try {
      status = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getVpnStatus',
      );
    } on PlatformException {
      return;
    }
    if (status == null) return;

    switch (status['state'] as String?) {
      case 'connecting':
        _resetConnectionRuntime();
        _restoreProxySession(status);
        _acceptConnectedEvent = true;
        _suppressDisconnectedUntil = null;
        _setState(VpnConnectionState.connecting);
        break;
      case 'connected':
        _resetConnectionRuntime();
        _restoreProxySession(status);
        _acceptConnectedEvent = false;
        _suppressDisconnectedUntil = null;
        _lastError = null;
        _restoreConnectedRuntime(
          _durationFromNativeMillis(status['connectedDurationMillis']),
        );
        break;
      case 'error':
        final message = status['message'] as String?;
        if (message != null && message.isNotEmpty) {
          _setError(message);
        }
        break;
    }
  }

  void _restoreProxySession(Map<dynamic, dynamic> status) {
    _activeProxyUser = _nonEmptyString(status['proxyUser']);
    _activeProxyPassword = _nonEmptyString(status['proxyPassword']);
  }

  void _restoreConnectedRuntime(Duration connectedDuration) {
    _cancelConnectTimeout();
    _connectionState = VpnConnectionState.connected;
    _connectionStateNotifier.value = VpnConnectionState.connected;
    _connectedAt = DateTime.now().subtract(connectedDuration);
    _setConnectionDuration(connectedDuration);
    _startConnectionTicker();

    final generation = _runtimeGeneration;
    if (_externalIp == null && !_hasExternalIpAttempt) {
      unawaited(_refreshExternalIp(generation));
    }
    unawaited(_refreshActiveServerPing(generation));
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  static Duration _durationFromNativeMillis(Object? value) {
    final millis = value is num ? value.toInt() : 0;
    return Duration(milliseconds: max(0, millis));
  }

  // ─── Server management ────────────────────────────────────────────
  List<RoutingPreset> _sanitizeRoutingPresets(List<RoutingPreset> presets) {
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

  void _cleanRoutingPresetBindings() {
    final validNames = RoutingPreset.cleanServerNames(_allServerNames());
    final assignedServerNames = <String>{};
    for (var i = 0; i < _routingPresets.length; i++) {
      final preset = _routingPresets[i];
      if (preset.isMain && preset.serverNames.isNotEmpty) {
        _routingPresets[i] = preset.copyWith(serverNames: const <String>{});
        continue;
      }
      if (preset.serverNames.isEmpty) continue;
      final nextServers = <String>{};
      for (final serverName in preset.serverNames) {
        final normalizedServerName = RoutingPreset.normalizeServerName(
          serverName,
        );
        if (normalizedServerName == null ||
            !validNames.contains(normalizedServerName)) {
          continue;
        }
        if (!assignedServerNames.add(normalizedServerName)) continue;
        nextServers.add(normalizedServerName);
      }
      if (nextServers.length == preset.serverNames.length &&
          preset.serverNames.containsAll(nextServers)) {
        continue;
      }
      _routingPresets[i] = preset.copyWith(serverNames: nextServers);
    }
  }

  void _replaceRoutingPresetServerName(String oldName, String newName) {
    final normalizedOldName = RoutingPreset.normalizeServerName(oldName);
    final normalizedNewName = RoutingPreset.normalizeServerName(newName);
    if (normalizedOldName == null ||
        normalizedNewName == null ||
        normalizedOldName == normalizedNewName) {
      return;
    }
    for (var i = 0; i < _routingPresets.length; i++) {
      final preset = _routingPresets[i];
      if (!preset.serverNames.contains(normalizedOldName)) continue;
      final nextServers = Set<String>.of(preset.serverNames)
        ..remove(normalizedOldName)
        ..add(normalizedNewName);
      _routingPresets[i] = preset.copyWith(serverNames: nextServers);
    }
  }

  bool _replaceFavoriteServerName(String oldName, String newName) {
    final normalizedOldName = RoutingPreset.normalizeServerName(oldName);
    if (normalizedOldName == null) return false;
    final index = _favoriteServerNames.indexWhere(
      (name) => RoutingPreset.normalizeServerName(name) == normalizedOldName,
    );
    if (index < 0 || _favoriteServerNames[index] == newName) return false;
    _favoriteServerNames[index] = newName;
    return true;
  }

  void _setFavoriteServerPinned(String name, bool pinned) {
    final normalizedName = RoutingPreset.normalizeServerName(name);
    if (normalizedName == null) return;
    _favoriteServerNames.removeWhere(
      (existing) =>
          RoutingPreset.normalizeServerName(existing) == normalizedName,
    );
    if (pinned) {
      _favoriteServerNames.add(name);
    }
  }

  Future<ServerImportResult> importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return importServersFromString(data?.text ?? '');
  }

  Future<ServerImportResult> importServersFromString(String raw) async {
    if (SubscriptionLinkCodec.looksLikeLink(raw)) {
      final DecodedSubscriptionLink decoded;
      try {
        decoded = await _linkCodec.decode(raw);
      } on SubscriptionLinkException catch (e) {
        return ServerImportResult.fail(
          ServerImportError.invalidSubscription,
          'subImportEncryptedFailed:${e.message}',
        );
      }
      return importSubscriptionFromUrl(decoded.url, nameOverride: decoded.name);
    }

    final subscriptionUri = ServerSubscriptionImporter.tryParseSubscriptionUri(
      raw,
    );
    if (subscriptionUri != null) {
      return importSubscriptionFromUrl(subscriptionUri.toString());
    }

    final existingNames = _allServerNames();
    final result = ServerImporter(
      vlessParser: _parser,
    ).parse(raw, existingNames: existingNames);
    if (result.isOk) {
      await _insertImportedServers(result.configs);
    }
    return result;
  }

  Future<ProfileImportResult> importProfileFromJsonString(
    String raw, {
    required bool replaceExisting,
  }) async {
    final payload = ProfileImportPayload.parse(raw);
    final usedServerNames = replaceExisting ? <String>{} : _allServerNames();
    final usedSubscriptionIds = replaceExisting
        ? <String>{}
        : _subscriptions.map((subscription) => subscription.id).toSet();
    final usedSubscriptionNames = replaceExisting
        ? <String>{}
        : _subscriptions.map((subscription) => subscription.name).toSet();
    final serverNameMap = <String, String>{};

    final importedManualNodes = payload.manualNodes
        .map(
          (server) => _prepareProfileServer(
            server,
            usedServerNames: usedServerNames,
            serverNameMap: serverNameMap,
          ),
        )
        .toList(growable: false);
    final importedSubscriptions = <ServerSubscription>[];
    for (final subscription in payload.subscriptions) {
      importedSubscriptions.add(
        _prepareProfileSubscription(
          subscription,
          usedServerNames: usedServerNames,
          usedSubscriptionIds: usedSubscriptionIds,
          usedSubscriptionNames: usedSubscriptionNames,
          serverNameMap: serverNameMap,
        ),
      );
    }

    final protectedResult = await _importProtectedProfileSubscriptions(
      payload.protectedSubscriptionLinks,
      usedServerNames: usedServerNames,
      usedSubscriptionIds: usedSubscriptionIds,
      usedSubscriptionNames: usedSubscriptionNames,
    );
    importedSubscriptions.addAll(protectedResult.subscriptions);

    final importedNodeNames = <String>{
      for (final server in importedManualNodes) server.name,
      for (final subscription in importedSubscriptions)
        for (final server in subscription.servers) server.name,
    };
    final rawImportedPresets = replaceExisting
        ? _replacementProfilePresets(payload, serverNameMap)
        : _appendedProfilePresets(payload, serverNameMap, importedNodeNames);
    final filterResult = await _filterImportedAppRoutingPackages(
      rawImportedPresets,
    );
    final importedPresets = filterResult.presets;
    if (importedManualNodes.isEmpty &&
        importedSubscriptions.isEmpty &&
        payload.routingPresets.isEmpty) {
      return ProfileImportResult(
        manualNodeCount: 0,
        subscriptionCount: 0,
        routingPresetCount: 0,
        protectedSubscriptionFailureCount: protectedResult.failureCount,
        droppedAppRoutingPackageCount: filterResult.droppedCount,
      );
    }

    final hadRestartableSession = _hasRestartableNativeSession;
    if (replaceExisting) {
      _servers
        ..clear()
        ..addAll(importedManualNodes);
      _subscriptions
        ..clear()
        ..addAll(importedSubscriptions);
      _favoriteServerNames.clear();
      _routingPresets
        ..clear()
        ..addAll(importedPresets);
      _cleanRoutingPresetBindings();
      _selectedRoutingPresetId = _validRoutingPresetId(
        payload.selectedRoutingPresetId,
      );
      _selectedName = _firstAvailableServerName();
      await _repository.saveSelected(_selectedName);
      await _persistFavoriteServerNames();
      _exitNodeName = null;
      await _repository.saveExitNodeName(null);
    } else {
      _servers.addAll(importedManualNodes);
      _subscriptions.addAll(importedSubscriptions);
      _routingPresets.addAll(importedPresets);
      _cleanRoutingPresetBindings();
      if (_selectedName == null) {
        _selectedName = _firstAvailableServerName();
        await _repository.saveSelected(_selectedName);
      }
      _selectedRoutingPresetId = _validRoutingPresetId(
        _selectedRoutingPresetId,
      );
    }

    await _persistServers();
    await _persistSubscriptions();
    await _repository.saveRoutingPresets(_routingPresets);
    await _repository.saveSelectedRoutingPresetId(_selectedRoutingPresetId);
    _scheduleSubscriptionAutoRefresh();
    notifyListeners();

    if (hadRestartableSession && _restartConnectionOnSettingsChanges) {
      if (selectedServer == null) {
        await disconnect();
      } else {
        await _restartActiveConnection();
      }
    }

    return ProfileImportResult(
      manualNodeCount: importedManualNodes.length,
      subscriptionCount: importedSubscriptions.length,
      routingPresetCount: importedPresets.length,
      protectedSubscriptionFailureCount: protectedResult.failureCount,
      droppedAppRoutingPackageCount: filterResult.droppedCount,
    );
  }

  /// Drops per-app routing packages that are not installed on this device.
  /// On platforms that don't expose installed apps (anything non-Android) or
  /// when enumeration fails, presets pass through unchanged — better to keep
  /// untouchable rules than to nuke everything on a platform mismatch.
  Future<_AppRoutingFilterResult> _filterImportedAppRoutingPackages(
    List<RoutingPreset> presets,
  ) async {
    final hasAnyPackage = presets.any(
      (preset) =>
          preset.appRoutingPolicy.proxyPackages.isNotEmpty ||
          preset.appRoutingPolicy.bypassPackages.isNotEmpty,
    );
    if (!hasAnyPackage) {
      return _AppRoutingFilterResult(presets: presets, droppedCount: 0);
    }
    final installed = await _installedAppsBridge.listPackageNames();
    if (installed == null) {
      return _AppRoutingFilterResult(presets: presets, droppedCount: 0);
    }
    var dropped = 0;
    final filtered = <RoutingPreset>[];
    for (final preset in presets) {
      final proxy = preset.appRoutingPolicy.proxyPackages;
      final bypass = preset.appRoutingPolicy.bypassPackages;
      final nextProxy = proxy.where(installed.contains).toSet();
      final nextBypass = bypass.where(installed.contains).toSet();
      dropped +=
          (proxy.length - nextProxy.length) +
          (bypass.length - nextBypass.length);
      if (nextProxy.length == proxy.length &&
          nextBypass.length == bypass.length) {
        filtered.add(preset);
        continue;
      }
      filtered.add(
        preset.copyWith(
          appRoutingPolicy: preset.appRoutingPolicy.copyWith(
            proxyPackages: nextProxy,
            bypassPackages: nextBypass,
          ),
        ),
      );
    }
    return _AppRoutingFilterResult(presets: filtered, droppedCount: dropped);
  }

  ServerConfig _prepareProfileServer(
    ServerConfig server, {
    required Set<String> usedServerNames,
    required Map<String, String> serverNameMap,
  }) {
    final originalName = server.name;
    final name = _uniqueProfileServerName(originalName, usedServerNames);
    usedServerNames.add(name);
    final normalizedOriginal = RoutingPreset.normalizeServerName(originalName);
    if (normalizedOriginal != null) {
      serverNameMap[normalizedOriginal] = name;
    }
    return server.copyWith(name: name, isPinned: false, ping: '--');
  }

  ServerSubscription _prepareProfileSubscription(
    ServerSubscription subscription, {
    required Set<String> usedServerNames,
    required Set<String> usedSubscriptionIds,
    required Set<String> usedSubscriptionNames,
    required Map<String, String> serverNameMap,
  }) {
    final servers = subscription.servers
        .map(
          (server) => _prepareProfileServer(
            server,
            usedServerNames: usedServerNames,
            serverNameMap: serverNameMap,
          ),
        )
        .toList(growable: false);
    return subscription.copyWith(
      id: _uniqueProfileSubscriptionId(subscription.id, usedSubscriptionIds),
      name: _uniqueProfileSubscriptionName(
        subscription.name,
        usedSubscriptionNames,
      ),
      servers: List.unmodifiable(servers),
    );
  }

  Future<_ProtectedProfileSubscriptions> _importProtectedProfileSubscriptions(
    List<String> links, {
    required Set<String> usedServerNames,
    required Set<String> usedSubscriptionIds,
    required Set<String> usedSubscriptionNames,
  }) async {
    if (links.isEmpty) return const _ProtectedProfileSubscriptions.empty();
    final importer = ServerSubscriptionImporter(vlessParser: _parser);
    final hwid = await _subscriptionRequestHwid();
    final subscriptions = <ServerSubscription>[];
    var failures = 0;

    for (final link in links) {
      final DecodedSubscriptionLink decoded;
      try {
        decoded = await _linkCodec.decode(link);
      } on SubscriptionLinkException {
        failures++;
        continue;
      }
      final id = _uniqueProfileSubscriptionId(
        _newSubscriptionId(),
        usedSubscriptionIds,
      );
      final result = await importer.importFromUrl(
        decoded.url,
        id: id,
        nameOverride: decoded.name,
        existingNames: usedServerNames,
        hwid: hwid,
        allowInsecureTls: _subscriptionProviderSettings.allowInsecureTls,
      );
      if (result.isError || result.subscription == null) {
        failures++;
        continue;
      }
      final subscription = result.subscription!;
      final uniqueName = _uniqueProfileSubscriptionName(
        subscription.name,
        usedSubscriptionNames,
      );
      for (final server in subscription.servers) {
        usedServerNames.add(server.name);
      }
      subscriptions.add(subscription.copyWith(id: id, name: uniqueName));
    }

    return _ProtectedProfileSubscriptions(
      subscriptions: subscriptions,
      failureCount: failures,
    );
  }

  List<RoutingPreset> _replacementProfilePresets(
    ProfileImportPayload payload,
    Map<String, String> serverNameMap,
  ) {
    final presets = payload.routingPresets
        .map((preset) => _remapProfilePresetServerNames(preset, serverNameMap))
        .toList(growable: false);
    return _sanitizeRoutingPresets(presets);
  }

  List<RoutingPreset> _appendedProfilePresets(
    ProfileImportPayload payload,
    Map<String, String> serverNameMap,
    Set<String> importedNodeNames,
  ) {
    final usedIds = _routingPresets.map((preset) => preset.id).toSet();
    final usedNames = _routingPresets.map((preset) => preset.name).toSet();
    final output = <RoutingPreset>[];

    for (final preset in payload.routingPresets) {
      if (preset.isMain) {
        if (importedNodeNames.isEmpty ||
            (preset.routingRules.isEmpty &&
                !preset.appRoutingPolicy.isActive)) {
          continue;
        }
        output.add(
          RoutingPreset(
            id: _newProfileRoutingPresetId(usedIds),
            name: _uniqueProfileRoutingPresetName('Imported Main', usedNames),
            appRoutingPolicy: preset.appRoutingPolicy,
            routingRules: preset.routingRules,
            serverNames: RoutingPreset.cleanServerNames(importedNodeNames),
          ).normalized(),
        );
        continue;
      }

      final remapped = _remapProfilePresetServerNames(preset, serverNameMap);
      output.add(
        RoutingPreset(
          id: _newProfileRoutingPresetId(usedIds),
          name: _uniqueProfileRoutingPresetName(remapped.name, usedNames),
          appRoutingPolicy: remapped.appRoutingPolicy,
          routingRules: remapped.routingRules,
          serverNames: remapped.serverNames,
        ).normalized(),
      );
    }
    return output;
  }

  RoutingPreset _remapProfilePresetServerNames(
    RoutingPreset preset,
    Map<String, String> serverNameMap,
  ) {
    final serverNames = preset.serverNames
        .map((name) {
          final normalized = RoutingPreset.normalizeServerName(name);
          if (normalized == null) return null;
          return serverNameMap[normalized] ?? normalized;
        })
        .whereType<String>()
        .toSet();
    return preset.copyWith(serverNames: serverNames).normalized();
  }

  String _uniqueProfileServerName(String rawName, Set<String> usedNames) {
    final base =
        RoutingPreset.normalizeServerName(rawName) ?? 'Imported server';
    if (!_containsServerName(usedNames, base)) return base;
    var index = 2;
    while (_containsServerName(usedNames, '$base ($index)')) {
      index++;
    }
    return '$base ($index)';
  }

  bool _containsServerName(Set<String> names, String candidate) {
    return names.any((name) => _serverNameEquals(name, candidate));
  }

  String _uniqueProfileSubscriptionId(String id, Set<String> usedIds) {
    var base = id.trim();
    if (base.isEmpty) base = _newSubscriptionId();
    var candidate = base;
    var index = 2;
    while (usedIds.contains(candidate)) {
      candidate = '$base-$index';
      index++;
    }
    usedIds.add(candidate);
    return candidate;
  }

  String _uniqueProfileSubscriptionName(String name, Set<String> usedNames) {
    final base = name.trim().isEmpty ? 'Subscription' : name.trim();
    if (!usedNames.contains(base)) {
      usedNames.add(base);
      return base;
    }
    var index = 2;
    var candidate = '$base ($index)';
    while (usedNames.contains(candidate)) {
      index++;
      candidate = '$base ($index)';
    }
    usedNames.add(candidate);
    return candidate;
  }

  String _newProfileRoutingPresetId(Set<String> usedIds) {
    while (true) {
      final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      final tail = List<int>.generate(
        4,
        (_) => Random.secure().nextInt(0x100),
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final id = 'preset-import-$stamp-$tail';
      if (usedIds.add(id)) return id;
    }
  }

  String _uniqueProfileRoutingPresetName(String name, Set<String> usedNames) {
    final base = name.trim().isEmpty ? 'Imported preset' : name.trim();
    if (!usedNames.contains(base)) {
      usedNames.add(base);
      return base;
    }
    var index = 2;
    var candidate = '$base ($index)';
    while (usedNames.contains(candidate)) {
      index++;
      candidate = '$base ($index)';
    }
    usedNames.add(candidate);
    return candidate;
  }

  Future<ServerImportResult> importSubscriptionFromUrl(
    String rawUrl, {
    String? nameOverride,
  }) async {
    final importer = ServerSubscriptionImporter(vlessParser: _parser);
    final hwid = await _subscriptionRequestHwid();
    final result = await importer.importFromUrl(
      rawUrl,
      id: _newSubscriptionId(),
      nameOverride: nameOverride,
      existingNames: _allServerNames(),
      hwid: hwid,
      allowInsecureTls: _subscriptionProviderSettings.allowInsecureTls,
    );
    if (result.isError) return _subscriptionImportFailure(result.error!);

    final subscription = result.subscription!;
    final persisted = subscription.copyWith(
      name: _ensureUniqueSubscriptionName(subscription.name),
    );
    _subscriptions.insert(0, persisted);
    if (_selectedName == null && persisted.servers.isNotEmpty) {
      _selectedName = persisted.servers.first.name;
      await _repository.saveSelected(_selectedName);
    }
    await _persistSubscriptions();
    _scheduleSubscriptionAutoRefresh();
    notifyListeners();
    unawaited(_refreshAndroidWidgets());
    unawaited(_scanSubscriptionAfterUpdateIfNeeded(persisted.id));
    return ServerImportResult.subscription(persisted);
  }

  Future<String?> addServer(ServerConfig server) async {
    final normalizedName = server.name.trim();
    final duplicateExists = _allServerList().any(
      (existing) => existing.name == normalizedName,
    );
    if (duplicateExists) {
      return Msg.editServerNameDuplicate;
    }

    await _insertImportedServers([server.copyWith(name: normalizedName)]);
    return null;
  }

  Future<void> _insertImportedServers(List<ServerConfig> configs) async {
    if (configs.isEmpty) return;
    _servers.insertAll(0, configs);
    // Don't steal the current selection, especially while connected: it would
    // visually move the selector while the tunnel still uses the previous node.
    if (_selectedName == null) {
      _selectedName = configs.first.name;
      await _repository.saveSelected(_selectedName);
    }
    await _persistServers();
    notifyListeners();
    unawaited(_refreshAndroidWidgets());
  }

  Future<void> selectServer(String name) async {
    final canonicalName = _canonicalServerName(name);
    if (canonicalName == null) return;
    final alreadySelected = _serverNameEquals(_selectedName, canonicalName);
    if (alreadySelected && _selectedName == canonicalName) return;
    final shouldReconnect = _hasRestartableNativeSession && !alreadySelected;
    _selectedName = canonicalName;
    await _repository.saveSelected(canonicalName);
    if (_serverNameEquals(_exitNodeName, canonicalName)) {
      // The exit hop must always be a different node from the entry; the
      // user just chose this node as the entry, so drop the redundant
      // bridge mark instead of trying to bridge to ourselves.
      _exitNodeName = null;
      await _repository.saveExitNodeName(null);
    }
    notifyListeners();
    unawaited(_refreshAndroidWidgets());

    if (shouldReconnect) {
      await _restartActiveConnection();
    }
  }

  Future<void> togglePinned(String name) async {
    final index = _servers.indexWhere((s) => s.name == name);
    if (index >= 0) {
      final nextPinned = !_servers[index].isPinned;
      _servers[index] = _servers[index].copyWith(isPinned: nextPinned);
      _setFavoriteServerPinned(_servers[index].name, nextPinned);
      _syncFavoriteServerNames();
      await _persistServers();
      await _persistFavoriteServerNames();
      notifyListeners();
      return;
    }

    for (var subIndex = 0; subIndex < _subscriptions.length; subIndex++) {
      final subscription = _subscriptions[subIndex];
      final serverIndex = subscription.servers.indexWhere(
        (server) => server.name == name,
      );
      if (serverIndex < 0) continue;
      final nextServers = List<ServerConfig>.from(subscription.servers);
      final nextPinned = !nextServers[serverIndex].isPinned;
      nextServers[serverIndex] = nextServers[serverIndex].copyWith(
        isPinned: nextPinned,
      );
      _subscriptions[subIndex] = subscription.copyWith(
        servers: List.unmodifiable(nextServers),
      );
      _setFavoriteServerPinned(nextServers[serverIndex].name, nextPinned);
      _syncFavoriteServerNames();
      await _persistSubscriptions();
      await _persistFavoriteServerNames();
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  Future<void> removeFavorite(String name) async {
    final index = _servers.indexWhere((s) => s.name == name && s.isPinned);
    if (index >= 0) {
      _servers[index] = _servers[index].copyWith(isPinned: false);
      _setFavoriteServerPinned(_servers[index].name, false);
      _syncFavoriteServerNames();
      await _persistServers();
      await _persistFavoriteServerNames();
      notifyListeners();
      return;
    }

    for (var subIndex = 0; subIndex < _subscriptions.length; subIndex++) {
      final subscription = _subscriptions[subIndex];
      final serverIndex = subscription.servers.indexWhere(
        (server) => server.name == name && server.isPinned,
      );
      if (serverIndex < 0) continue;
      final nextServers = List<ServerConfig>.from(subscription.servers);
      nextServers[serverIndex] = nextServers[serverIndex].copyWith(
        isPinned: false,
      );
      _subscriptions[subIndex] = subscription.copyWith(
        servers: List.unmodifiable(nextServers),
      );
      _setFavoriteServerPinned(nextServers[serverIndex].name, false);
      _syncFavoriteServerNames();
      await _persistSubscriptions();
      await _persistFavoriteServerNames();
      notifyListeners();
      return;
    }
  }

  /// Reorders servers in the home list. Persists order to storage.
  Future<void> reorderServers(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 ||
        oldIndex >= _servers.length ||
        newIndex < 0 ||
        newIndex >= _servers.length) {
      return;
    }
    final item = _servers.removeAt(oldIndex);
    _servers.insert(newIndex, item);
    notifyListeners();
    await _persistServers();
  }

  /// Reorders subscriptions in the home list. Persists order to storage.
  Future<void> reorderSubscriptions(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 ||
        oldIndex >= _subscriptions.length ||
        newIndex < 0 ||
        newIndex >= _subscriptions.length) {
      return;
    }
    final item = _subscriptions.removeAt(oldIndex);
    _subscriptions.insert(newIndex, item);
    notifyListeners();
    await _persistSubscriptions();
  }

  /// Reorders the favorites strip without changing the underlying server lists.
  Future<void> reorderFavoriteServers(int oldIndex, int newIndex) async {
    final favorites = _orderedFavoriteServers();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 ||
        oldIndex >= favorites.length ||
        newIndex < 0 ||
        newIndex >= favorites.length) {
      return;
    }
    final names = favorites.map((server) => server.name).toList();
    final item = names.removeAt(oldIndex);
    names.insert(newIndex, item);
    _favoriteServerNames
      ..clear()
      ..addAll(names);
    notifyListeners();
    await _persistFavoriteServerNames();
  }

  Future<void> removeServer(String name) async {
    final hadRestartableSession = _hasRestartableNativeSession;
    final removedSelected = _serverNameEquals(_selectedName, name);
    final removedExit = _serverNameEquals(_exitNodeName, name);

    final manualBefore = _servers.length;
    _servers.removeWhere((s) => _serverNameEquals(s.name, name));
    var subscriptionsChanged = false;
    for (var i = _subscriptions.length - 1; i >= 0; i--) {
      final subscription = _subscriptions[i];
      final nextServers = subscription.servers
          .where((server) => !_serverNameEquals(server.name, name))
          .toList(growable: false);
      if (nextServers.length == subscription.servers.length) continue;
      subscriptionsChanged = true;
      if (nextServers.isEmpty) {
        _subscriptions.removeAt(i);
      } else {
        _subscriptions[i] = subscription.copyWith(
          servers: List.unmodifiable(nextServers),
        );
      }
    }
    final manualChanged = manualBefore != _servers.length;
    if (!manualChanged && !subscriptionsChanged) return;

    if (removedSelected) {
      _selectedName = _firstAvailableServerName();
      await _repository.saveSelected(_selectedName);
    }
    if (removedExit) {
      _exitNodeName = null;
      await _repository.saveExitNodeName(null);
    }
    _cleanRoutingPresetBindings();
    final favoriteOrderChanged = _syncFavoriteServerNames();
    if (manualChanged) await _persistServers();
    if (subscriptionsChanged) {
      await _persistSubscriptions();
      _scheduleSubscriptionAutoRefresh();
    }
    await _repository.saveRoutingPresets(_routingPresets);
    if (favoriteOrderChanged) await _persistFavoriteServerNames();
    notifyListeners();
    unawaited(_refreshAndroidWidgets());

    if (hadRestartableSession && (removedSelected || removedExit)) {
      if (selectedServer == null) {
        await disconnect();
      } else {
        await _restartActiveConnection();
      }
    }
  }

  Future<String?> updateServer({
    required String originalName,
    required ServerConfig updatedServer,
  }) async {
    final manualIndex = _servers.indexWhere(
      (server) => _serverNameEquals(server.name, originalName),
    );
    var subscriptionIndex = -1;
    var subscriptionServerIndex = -1;
    if (manualIndex < 0) {
      for (var i = 0; i < _subscriptions.length; i++) {
        final index = _subscriptions[i].servers.indexWhere(
          (server) => _serverNameEquals(server.name, originalName),
        );
        if (index < 0) continue;
        subscriptionIndex = i;
        subscriptionServerIndex = index;
        break;
      }
    }

    if (manualIndex < 0 && subscriptionIndex < 0) {
      return Msg.editServerNotFound;
    }

    final normalizedName = updatedServer.name.trim();
    final duplicateExists = _allServerList().any(
      (server) =>
          _serverNameEquals(server.name, normalizedName) &&
          !_serverNameEquals(server.name, originalName),
    );
    if (duplicateExists) {
      return Msg.editServerNameDuplicate;
    }

    final affectsActiveConnection =
        _hasRestartableNativeSession &&
        _serverNameEquals(_selectedName, originalName);
    final persistedServer = updatedServer.copyWith(name: normalizedName);
    if (manualIndex >= 0) {
      _servers[manualIndex] = persistedServer;
    } else {
      final subscription = _subscriptions[subscriptionIndex];
      final nextServers = List<ServerConfig>.from(subscription.servers);
      nextServers[subscriptionServerIndex] = persistedServer;
      _subscriptions[subscriptionIndex] = subscription.copyWith(
        servers: List.unmodifiable(nextServers),
      );
    }

    if (_serverNameEquals(_selectedName, originalName)) {
      _selectedName = persistedServer.name;
      await _repository.saveSelected(_selectedName);
    }
    if (_serverNameEquals(_exitNodeName, originalName)) {
      _exitNodeName = persistedServer.name;
      await _repository.saveExitNodeName(_exitNodeName);
    }

    _replaceRoutingPresetServerName(originalName, persistedServer.name);
    final favoriteNameChanged = _replaceFavoriteServerName(
      originalName,
      persistedServer.name,
    );
    final favoriteOrderSynced = _syncFavoriteServerNames();
    final favoriteOrderChanged = favoriteNameChanged || favoriteOrderSynced;
    if (manualIndex >= 0) {
      await _persistServers();
    } else {
      await _persistSubscriptions();
    }
    await _repository.saveRoutingPresets(_routingPresets);
    if (favoriteOrderChanged) await _persistFavoriteServerNames();
    notifyListeners();

    if (affectsActiveConnection && _restartConnectionOnSettingsChanges) {
      await _restartActiveConnection();
    }

    return null;
  }

  Future<String?> refreshSubscription(String id) async {
    final index = _subscriptions.indexWhere(
      (subscription) => subscription.id == id,
    );
    if (index < 0) return Msg.subscriptionNotFound;
    if (_refreshingSubscriptionIds.contains(id)) return null;

    final current = _subscriptions[index];
    _refreshingSubscriptionIds.add(id);
    notifyListeners();
    try {
      final hwid = await _subscriptionRequestHwid();
      final result = await ServerSubscriptionImporter(vlessParser: _parser)
          .importFromUrl(
            current.url,
            id: current.id,
            nameOverride: current.name,
            existingNames: _allServerNames(excludingSubscriptionId: id),
            hwid: hwid,
            allowInsecureTls: _subscriptionProviderSettings.allowInsecureTls,
          );
      if (result.isError) return result.error!.toWireMessage();

      await _replaceSubscription(
        index,
        _preserveSubscriptionServerState(
          current: current,
          next: result.subscription!,
        ),
      );
      await _scanSubscriptionAfterUpdateIfNeeded(id);
      return null;
    } finally {
      _refreshingSubscriptionIds.remove(id);
      notifyListeners();
    }
  }

  Future<String?> updateSubscription({
    required String id,
    required String name,
    required String url,
    required SubscriptionUpdateInterval? updateIntervalOverride,
  }) async {
    final index = _subscriptions.indexWhere(
      (subscription) => subscription.id == id,
    );
    if (index < 0) return Msg.subscriptionNotFound;

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return Msg.subscriptionNameRequired;

    final normalizedUrl = url.trim();
    if (ServerSubscriptionImporter.tryParseSubscriptionUri(normalizedUrl) ==
        null) {
      return Msg.subscriptionInvalidUrl;
    }

    final current = _subscriptions[index];
    final currentWithUpdateSettings = current.copyWith(
      updateIntervalOverride: updateIntervalOverride,
      clearUpdateIntervalOverride: updateIntervalOverride == null,
    );
    if (normalizedUrl == current.url) {
      _subscriptions[index] = currentWithUpdateSettings.copyWith(
        name: normalizedName,
      );
      await _persistSubscriptions();
      _scheduleSubscriptionAutoRefresh();
      notifyListeners();
      return null;
    }

    _refreshingSubscriptionIds.add(id);
    notifyListeners();
    try {
      final hwid = await _subscriptionRequestHwid();
      final result = await ServerSubscriptionImporter(vlessParser: _parser)
          .importFromUrl(
            normalizedUrl,
            id: current.id,
            nameOverride: normalizedName,
            existingNames: _allServerNames(excludingSubscriptionId: id),
            hwid: hwid,
            allowInsecureTls: _subscriptionProviderSettings.allowInsecureTls,
          );
      if (result.isError) return result.error!.toWireMessage();

      await _replaceSubscription(
        index,
        _preserveSubscriptionServerState(
          current: currentWithUpdateSettings,
          next: result.subscription!.copyWith(
            name: normalizedName,
            url: normalizedUrl,
          ),
        ),
      );
      _scheduleSubscriptionAutoRefresh();
      await _scanSubscriptionAfterUpdateIfNeeded(id);
      return null;
    } finally {
      _refreshingSubscriptionIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> _refreshAllSubscriptions() async {
    if (_refreshingAllSubscriptions || _subscriptions.isEmpty) return;
    _refreshingAllSubscriptions = true;
    try {
      final ids = _subscriptions
          .map((subscription) => subscription.id)
          .toList(growable: false);
      for (final id in ids) {
        _subscriptionAutoRefreshAttemptedAt[id] = DateTime.now();
        await refreshSubscription(id);
      }
    } finally {
      _refreshingAllSubscriptions = false;
      _pruneSubscriptionAutoRefreshAttempts();
    }
  }

  Future<void> _refreshDueSubscriptions() async {
    if (_refreshingAllSubscriptions || _subscriptions.isEmpty) return;
    final now = DateTime.now();
    final ids = _subscriptions
        .where(
          (subscription) => _isSubscriptionAutoRefreshDue(subscription, now),
        )
        .map((subscription) => subscription.id)
        .toList(growable: false);
    if (ids.isEmpty) return;

    _refreshingAllSubscriptions = true;
    try {
      for (final id in ids) {
        _subscriptionAutoRefreshAttemptedAt[id] = DateTime.now();
        await refreshSubscription(id);
      }
    } finally {
      _refreshingAllSubscriptions = false;
      _pruneSubscriptionAutoRefreshAttempts();
    }
  }

  void _scheduleSubscriptionAutoRefresh() {
    _subscriptionAutoRefreshTimer?.cancel();
    _subscriptionAutoRefreshTimer = null;
    _pruneSubscriptionAutoRefreshAttempts();
    if (_subscriptions.isEmpty) return;

    final delay = _nextSubscriptionAutoRefreshDelay(DateTime.now());
    if (delay == null) return;

    _subscriptionAutoRefreshTimer = Timer(delay, () async {
      try {
        await _refreshDueSubscriptions();
      } finally {
        _scheduleSubscriptionAutoRefresh();
      }
    });
  }

  @visibleForTesting
  SubscriptionUpdateInterval effectiveSubscriptionUpdateIntervalForTesting(
    ServerSubscription subscription,
  ) {
    return _effectiveSubscriptionUpdateInterval(subscription);
  }

  @visibleForTesting
  bool isSubscriptionAutoRefreshDueForTesting(
    ServerSubscription subscription,
    DateTime now,
  ) {
    return _isSubscriptionAutoRefreshDue(subscription, now);
  }

  @visibleForTesting
  Duration? nextSubscriptionAutoRefreshDelayForTesting(DateTime now) {
    return _nextSubscriptionAutoRefreshDelay(now);
  }

  SubscriptionUpdateInterval _effectiveSubscriptionUpdateInterval(
    ServerSubscription subscription,
  ) {
    return subscription.updateIntervalOverride ??
        _subscriptionProviderSettings.updateInterval;
  }

  bool _isSubscriptionAutoRefreshDue(
    ServerSubscription subscription,
    DateTime now,
  ) {
    final reference = _subscriptionAutoRefreshReference(subscription);
    if (reference == null) return false;
    final interval = _effectiveSubscriptionUpdateInterval(
      subscription,
    ).duration;
    return !now.isBefore(reference.add(interval));
  }

  Duration? _nextSubscriptionAutoRefreshDelay(DateTime now) {
    Duration? shortestDelay;
    for (final subscription in _subscriptions) {
      final interval = _effectiveSubscriptionUpdateInterval(
        subscription,
      ).duration;
      final reference = _subscriptionAutoRefreshReference(subscription) ?? now;
      final rawDelay = reference.add(interval).difference(now);
      final delay = rawDelay.isNegative ? Duration.zero : rawDelay;
      if (shortestDelay == null || delay < shortestDelay) {
        shortestDelay = delay;
      }
    }
    return shortestDelay;
  }

  DateTime? _subscriptionAutoRefreshReference(ServerSubscription subscription) {
    final updatedAt = subscription.updatedAt;
    final attemptedAt = _subscriptionAutoRefreshAttemptedAt[subscription.id];
    if (updatedAt == null) return attemptedAt;
    if (attemptedAt == null) return updatedAt;
    return attemptedAt.isAfter(updatedAt) ? attemptedAt : updatedAt;
  }

  void _pruneSubscriptionAutoRefreshAttempts() {
    final activeIds = _subscriptions
        .map((subscription) => subscription.id)
        .toSet();
    _subscriptionAutoRefreshAttemptedAt.removeWhere(
      (id, _) => !activeIds.contains(id),
    );
  }

  Future<void> _scanSubscriptionAfterUpdateIfNeeded(String id) async {
    if (!_subscriptionProviderSettings.pingOnUpdate) return;
    await scanSubscriptionLatencies(id);
  }

  Future<String?> _subscriptionRequestHwid() async {
    if (!_subscriptionProviderSettings.sendHwid) return null;
    final cached = _cachedSubscriptionHwid;
    if (cached != null) return cached.isEmpty ? null : cached;
    return _pendingHwidFetch ??= _fetchSubscriptionHwid();
  }

  Future<String?> _fetchSubscriptionHwid() async {
    try {
      final hwid = (await const DeviceIdentityBridge().getHwid()).trim();
      _cachedSubscriptionHwid = hwid;
      return hwid.isEmpty ? null : hwid;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } finally {
      _pendingHwidFetch = null;
    }
  }

  Future<void> deleteSubscription(String id) async {
    final index = _subscriptions.indexWhere(
      (subscription) => subscription.id == id,
    );
    if (index < 0) return;

    final hadRestartableSession = _hasRestartableNativeSession;
    final removed = _subscriptions.removeAt(index);
    final removedNames = RoutingPreset.cleanServerNames(
      removed.servers.map((server) => server.name),
    );
    final selectedName = RoutingPreset.normalizeServerName(_selectedName);
    final removedSelected =
        selectedName != null && removedNames.contains(selectedName);
    final exitName = RoutingPreset.normalizeServerName(_exitNodeName);
    final removedExit = exitName != null && removedNames.contains(exitName);

    if (removedSelected) {
      _selectedName = _firstAvailableServerName();
      await _repository.saveSelected(_selectedName);
    }
    if (removedExit) {
      _exitNodeName = null;
      await _repository.saveExitNodeName(null);
    }
    _cleanRoutingPresetBindings();
    final favoriteOrderChanged = _syncFavoriteServerNames();
    await _persistSubscriptions();
    _scheduleSubscriptionAutoRefresh();
    await _repository.saveRoutingPresets(_routingPresets);
    if (favoriteOrderChanged) await _persistFavoriteServerNames();
    notifyListeners();
    unawaited(_refreshAndroidWidgets());

    if (hadRestartableSession && (removedSelected || removedExit)) {
      if (selectedServer == null) {
        await disconnect();
      } else {
        await _restartActiveConnection();
      }
    }
  }

  /// Mark [serverId] as the bridge exit hop, or clear it when [serverId] is
  /// already the active exit. Triggers a forced reconnect whenever the
  /// active session would land on a different config — the spec requires
  /// changing the exit to fully tear the tunnel down and rebuild it.
  Future<void> toggleExitNode(String serverId) async {
    final canonical = _canonicalServerName(serverId);
    if (canonical == null) return;
    // Exit must differ from the entry/selected node; if the user picks the
    // currently-selected server as the exit, treat it as a clear.
    final wantsClear =
        _serverNameEquals(_exitNodeName, canonical) ||
        _serverNameEquals(_selectedName, canonical);
    final nextExitNodeName = wantsClear ? null : canonical;
    if (_exitNodeName == nextExitNodeName) return;
    _exitNodeName = nextExitNodeName;
    await _repository.saveExitNodeName(_exitNodeName);
    notifyListeners();
    unawaited(_refreshAndroidWidgets());

    if (_hasRestartableNativeSession) {
      await _restartActiveConnection();
    }
  }

  Future<void> clearExitNode() async {
    if (_exitNodeName == null) return;
    _exitNodeName = null;
    await _repository.saveExitNodeName(null);
    notifyListeners();
    unawaited(_refreshAndroidWidgets());

    if (_hasRestartableNativeSession) {
      await _restartActiveConnection();
    }
  }

  Future<void> setGlobalProxy(bool value) async {
    if (value && !_showGlobalProxyButton) return;
    if (_isGlobalProxy == value) return;
    _isGlobalProxy = value;
    await _repository.saveGlobalProxy(value);
    notifyListeners();
    unawaited(_refreshAndroidWidgets());

    if (_hasRestartableNativeSession) {
      await _restartActiveConnection();
    }
  }

  Future<void> setRestartConnectionOnSettingsChanges(bool value) async {
    if (_restartConnectionOnSettingsChanges == value) return;
    _restartConnectionOnSettingsChanges = value;
    if (!value) {
      _networkSettingsRestartPending = false;
    }
    await _repository.saveRestartConnectionOnSettingsChanges(value);
    notifyListeners();
  }

  Future<void> setAutoConnectOnLaunch(bool value) async {
    if (_autoConnectOnLaunch == value) return;
    _autoConnectOnLaunch = value;
    await _repository.saveAutoConnectOnLaunch(value);
    notifyListeners();
  }

  Future<void> setShowSpeedInNotification(bool value) async {
    if (_showSpeedInNotification == value) return;
    if (value && Platform.isAndroid) {
      // Opting *into* a notification feature should always re-prompt for the
      // OS-level permission if it isn't granted yet — even when the user
      // declined on first connect — so the toggle actually takes effect.
      try {
        await _methodChannel.invokeMethod<bool>(
          'requestNotificationPermission',
        );
      } on PlatformException {
        // The setting still gets persisted; the notification simply won't
        // be visible until the permission is granted via system settings.
      }
      await _repository.saveNotificationPermissionAsked(true);
    }
    _showSpeedInNotification = value;
    await _repository.saveShowSpeedInNotification(value);
    notifyListeners();
    if (isConnected && Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod<void>(
          'updateShowSpeedInNotification',
          value,
        );
      } catch (_) {}
    }
  }

  Future<void> setKeepAwake(bool value) async {
    if (_keepAwake == value) return;
    _keepAwake = value;
    await _repository.saveKeepAwake(value);
    notifyListeners();
    if (isConnected && Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod<void>('updateKeepAwake', value);
      } catch (_) {}
    }
  }

  /// Toggle Xray verbose log capture. The flag is baked into the Xray JSON
  /// config at startup, so changing it during an active session does NOT
  /// apply until the tunnel restarts. When the restart-on-settings toggle is
  /// enabled, the restart is queued and applied after the settings screen
  /// closes, so a batch of edits still produces one reconnect.
  Future<void> setVerboseXrayLogs(bool value) async {
    if (_verboseXrayLogs == value) return;
    _verboseXrayLogs = value;
    await _repository.saveVerboseXrayLogs(value);
    notifyListeners();
    _markNetworkSettingsRestartPending();
  }

  Future<void> setUseCustomProxyAuth(bool value) async {
    if (_useCustomProxyAuth == value) return;
    _useCustomProxyAuth = value;
    await _repository.saveCustomProxyAuthEnabled(value);
    notifyListeners();
    _markNetworkSettingsRestartPending();
  }

  Future<void> setCustomProxyUser(String value) async {
    final trimmed = value.trim();
    if (_customProxyUser == trimmed) return;
    _customProxyUser = trimmed;
    await _repository.saveCustomProxyUser(trimmed);
    notifyListeners();
    if (_useCustomProxyAuth) {
      _markNetworkSettingsRestartPending();
    }
  }

  Future<void> setCustomProxyPassword(String value) async {
    if (_customProxyPassword == value) return;
    _customProxyPassword = value;
    await _repository.saveCustomProxyPassword(value);
    notifyListeners();
    if (_useCustomProxyAuth) {
      _markNetworkSettingsRestartPending();
    }
  }

  Future<void> setTunnelFragmentSettings(
    TunnelFragmentSettings settings,
  ) async {
    final normalized = settings.normalized();
    if (_tunnelFragmentSettings.hasSameConfiguration(normalized)) return;
    _tunnelFragmentSettings = normalized;
    await _repository.saveTunnelFragmentSettings(normalized);
    notifyListeners();
    _markNetworkSettingsRestartPending();
  }

  Future<void> setMultiplexSettings(MultiplexSettings settings) async {
    final normalized = settings.normalized();
    if (_multiplexSettings.hasSameConfiguration(normalized)) return;
    _multiplexSettings = normalized;
    await _repository.saveMultiplexSettings(normalized);
    notifyListeners();
    _markNetworkSettingsRestartPending();
  }

  Future<void> setTunnelNetworkSettings(TunnelNetworkSettings settings) async {
    final normalized = settings.normalized();
    if (_tunnelNetworkSettings.hasSameConfiguration(normalized)) return;
    _tunnelNetworkSettings = normalized;
    await _repository.saveTunnelNetworkSettings(normalized);
    notifyListeners();
    _markNetworkSettingsRestartPending();
  }

  void _markNetworkSettingsRestartPending() {
    if (!_hasRestartableNativeSession) return;
    if (!_restartConnectionOnSettingsChanges) return;
    _networkSettingsRestartPending = true;
  }

  Future<void> applyPendingNetworkSettingsRestart() async {
    if (!_networkSettingsRestartPending) return;
    _networkSettingsRestartPending = false;
    if (!_hasRestartableNativeSession) return;
    await _restartActiveConnection();
  }

  Future<void> setSubscriptionProviderSettings(
    SubscriptionProviderSettings settings,
  ) async {
    final normalized = settings.normalized();
    if (_subscriptionProviderSettings.hasSameConfiguration(normalized)) return;
    final intervalChanged =
        _subscriptionProviderSettings.updateInterval !=
        normalized.updateInterval;
    await _repository.saveSubscriptionProviderSettings(normalized);
    _subscriptionProviderSettings = normalized;
    if (!normalized.sendHwid) {
      _cachedSubscriptionHwid = null;
    }
    if (intervalChanged) {
      _scheduleSubscriptionAutoRefresh();
    }
    notifyListeners();
  }

  Future<void> setLogLevels(Set<AppLogLevel> levels) async {
    final normalized = Set<AppLogLevel>.of(levels);
    if (_logLevels.length == normalized.length &&
        _logLevels.containsAll(normalized)) {
      return;
    }
    _logLevels = normalized;
    await _repository.saveLogLevels(_logLevels);
    notifyListeners();
    await _pushActiveLogLevelsToNative();
  }

  Future<void> _pushActiveLogLevelsToNative() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>(
        'setActiveLogLevels',
        _logLevels.map((level) => level.wireName).toList(),
      );
    } on PlatformException {
      // Native side will fall back to its default (write everything) — the
      // user can still filter on read. Not worth surfacing.
    }
  }

  Future<void> setLogRetention(AppLogRetention retention) async {
    if (_logRetention == retention) return;
    _logRetention = retention;
    await _repository.saveLogRetention(retention);
    await const AppLogBridge().setRetention(retention);
    notifyListeners();
  }

  Future<void> setAutoSortServersByPing(bool value) async {
    if (_autoSortServersByPing == value) return;
    _autoSortServersByPing = value;
    await _repository.saveAutoSortServersByPing(value);
    notifyListeners();
  }

  Future<void> setLatencyProbeTarget(LatencyProbeTarget target) async {
    if (_latencyProbeTarget.hasSameConfiguration(target)) return;
    _latencyProbeTarget = target;
    await _repository.saveLatencyProbeTarget(target);
    notifyListeners();
  }

  Future<void> setFavoritesSectionCollapsed(bool value) async {
    if (_favoritesSectionCollapsed == value) return;
    _favoritesSectionCollapsed = value;
    await _repository.saveFavoritesSectionCollapsed(value);
    notifyListeners();
  }

  Future<void> setSubscriptionCollapsed(String id, bool value) async {
    if (_subscriptions.every((subscription) => subscription.id != id)) return;
    final changed = value
        ? _collapsedSubscriptionIds.add(id)
        : _collapsedSubscriptionIds.remove(id);
    if (!changed) return;
    await _persistCollapsedSubscriptionIds();
    notifyListeners();
  }

  Future<void> setShowGlobalProxyButton(bool value) async {
    if (_showGlobalProxyButton == value) return;
    final shouldDisableGlobalProxy = !value && _isGlobalProxy;
    final shouldReconnect =
        shouldDisableGlobalProxy && _hasRestartableNativeSession;

    _showGlobalProxyButton = value;
    if (shouldDisableGlobalProxy) {
      _isGlobalProxy = false;
    }
    await _repository.saveShowGlobalProxyButton(value);
    if (shouldDisableGlobalProxy) {
      await _repository.saveGlobalProxy(false);
    }
    notifyListeners();

    if (shouldReconnect) {
      await _restartActiveConnection();
    }
  }

  Future<String?> createRoutingPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Msg.presetNameRequired;
    final duplicate = _routingPresets.any(
      (preset) => preset.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) return Msg.presetNameDuplicate;

    final preset = RoutingPreset.fresh(trimmed);
    _routingPresets.add(preset);
    _selectedRoutingPresetId = preset.id;
    await _repository.saveSelectedRoutingPresetId(_selectedRoutingPresetId);
    await _saveRoutingPresetsAndNotify();
    return null;
  }

  Future<String?> renameRoutingPreset(String id, String name) async {
    final index = _routingPresets.indexWhere((preset) => preset.id == id);
    if (index < 0) return Msg.presetNotFound;
    final preset = _routingPresets[index];
    if (preset.isMain) return Msg.presetMainCannotRename;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Msg.presetNameRequired;
    final duplicate = _routingPresets.any(
      (item) =>
          item.id != id && item.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) return Msg.presetNameDuplicate;
    _routingPresets[index] = preset.copyWith(name: trimmed).normalized();
    await _saveRoutingPresetsAndNotify();
    return null;
  }

  Future<String?> deleteRoutingPreset(String id) async {
    final index = _routingPresets.indexWhere((preset) => preset.id == id);
    if (index < 0) return Msg.presetNotFound;
    final preset = _routingPresets[index];
    if (preset.isMain) return Msg.presetMainCannotDelete;
    final removedActive = preset.id == _selectedRoutingPresetId;
    final removedEffective =
        _routingPresetForServer(_selectedName).id == preset.id;
    _routingPresets.removeAt(index);
    if (removedActive) {
      _selectedRoutingPresetId = RoutingPreset.mainId;
      await _repository.saveSelectedRoutingPresetId(_selectedRoutingPresetId);
    }
    await _saveRoutingPresets(reconnectIfNeeded: removedEffective);
    return null;
  }

  Future<void> selectRoutingPreset(String id) async {
    if (_selectedRoutingPresetId == id) return;
    if (_routingPresets.every((preset) => preset.id != id)) return;
    _selectedRoutingPresetId = id;
    await _repository.saveSelectedRoutingPresetId(id);
    notifyListeners();
  }

  Future<void> setServerRoutingPreset(
    String serverName,
    String presetId,
  ) async {
    final canonicalServerName = _canonicalServerName(serverName);
    final normalizedServerName = RoutingPreset.normalizeServerName(
      canonicalServerName,
    );
    if (canonicalServerName == null || normalizedServerName == null) return;
    RoutingPreset? selectedPreset;
    for (final preset in _routingPresets) {
      if (preset.id == presetId) {
        selectedPreset = preset;
        break;
      }
    }
    if (selectedPreset == null) return;

    final selectedServerAffected = _serverNameEquals(
      _selectedName,
      canonicalServerName,
    );
    var changed = false;
    for (var i = 0; i < _routingPresets.length; i++) {
      final preset = _routingPresets[i];
      final nextServers = Set<String>.of(preset.serverNames)
        ..remove(normalizedServerName);
      if (!selectedPreset.isMain && preset.id == selectedPreset.id) {
        nextServers.add(normalizedServerName);
      }
      if (preset.serverNames.length == nextServers.length &&
          preset.serverNames.containsAll(nextServers)) {
        continue;
      }
      changed = true;
      _routingPresets[i] = preset.copyWith(serverNames: nextServers);
    }
    if (!changed) return;
    await _saveRoutingPresets(reconnectIfNeeded: selectedServerAffected);
  }

  Future<void> setRoutingPresetServers(
    String presetId,
    Set<String> serverNames,
  ) async {
    final index = _routingPresets.indexWhere((preset) => preset.id == presetId);
    if (index < 0) return;
    final validNames = RoutingPreset.cleanServerNames(_allServerNames());
    var nextServers = RoutingPreset.cleanServerNames(
      serverNames,
    ).where(validNames.contains).toSet();
    final preset = _routingPresets[index];
    if (!preset.isMain) {
      for (var i = 0; i < _routingPresets.length; i++) {
        if (i == index) continue;
        final other = _routingPresets[i];
        if (other.isMain || other.serverNames.isEmpty) continue;
        final otherServers = Set<String>.of(other.serverNames)
          ..removeAll(nextServers);
        if (otherServers.length == other.serverNames.length) continue;
        _routingPresets[i] = other.copyWith(serverNames: otherServers);
      }
    } else {
      nextServers = const <String>{};
    }
    if (preset.serverNames.length == nextServers.length &&
        preset.serverNames.containsAll(nextServers)) {
      return;
    }
    final previousEffectivePresetId = _routingPresetForServer(_selectedName).id;
    final nextPreset = preset.copyWith(serverNames: nextServers);
    _routingPresets[index] = nextPreset;
    final nextEffectivePresetId = _routingPresetForServer(_selectedName).id;
    await _saveRoutingPresets(
      reconnectIfNeeded: previousEffectivePresetId != nextEffectivePresetId,
    );
  }

  void _updateActiveRoutingPreset(RoutingPreset preset) {
    final index = _activeRoutingPresetIndex;
    if (index < 0) {
      _routingPresets.add(preset);
      _selectedRoutingPresetId = preset.id;
      return;
    }
    _routingPresets[index] = preset.normalized();
  }

  Future<void> setAppRoutingPolicy(AppRoutingPolicy policy) async {
    final current = appRoutingPolicy;
    if (current.hasSameConfiguration(policy)) {
      return;
    }
    _updateActiveRoutingPreset(
      _activeRoutingPreset.copyWith(appRoutingPolicy: policy),
    );
    await _persistRoutingPresetsAndMaybeReconnect();
  }

  Future<void> upsertRoutingRule(RoutingRule rule) async {
    final rules = List<RoutingRule>.of(_activeRoutingPreset.routingRules);
    final index = rules.indexWhere((r) => r.id == rule.id);
    if (index < 0) {
      rules.add(rule);
    } else {
      rules[index] = rule;
    }
    _updateActiveRoutingPreset(
      _activeRoutingPreset.copyWith(routingRules: rules),
    );
    await _persistRoutingPresetsAndMaybeReconnect();
  }

  Future<void> removeRoutingRule(String id) async {
    final rules = List<RoutingRule>.of(_activeRoutingPreset.routingRules);
    final removed = rules.indexWhere((r) => r.id == id);
    if (removed < 0) return;
    rules.removeAt(removed);
    _updateActiveRoutingPreset(
      _activeRoutingPreset.copyWith(routingRules: rules),
    );
    await _persistRoutingPresetsAndMaybeReconnect();
  }

  Future<void> reorderRoutingRule(int oldIndex, int newIndex) async {
    final rules = List<RoutingRule>.of(_activeRoutingPreset.routingRules);
    if (oldIndex < 0 || oldIndex >= rules.length) return;
    var insertAt = newIndex;
    if (insertAt > oldIndex) insertAt -= 1;
    if (insertAt < 0) insertAt = 0;
    if (insertAt > rules.length) insertAt = rules.length;
    final moved = rules.removeAt(oldIndex);
    rules.insert(insertAt, moved);
    _updateActiveRoutingPreset(
      _activeRoutingPreset.copyWith(routingRules: rules),
    );
    await _persistRoutingPresetsAndMaybeReconnect();
  }

  Future<void> clearRoutingRules() async {
    if (_activeRoutingPreset.routingRules.isEmpty) return;
    _updateActiveRoutingPreset(
      _activeRoutingPreset.copyWith(routingRules: const []),
    );
    await _persistRoutingPresetsAndMaybeReconnect();
  }

  /// Replaces the rule list with the imported set. Returns the number of
  /// rules accepted from the source so the UI can surface a confirmation.
  Future<int> importRoutingRulesFromJsonString(
    String raw, {
    bool replaceExisting = true,
  }) async {
    final imported = RoutingRule.importRulesFromJsonString(raw);
    if (imported.isEmpty) return 0;
    final rules = List<RoutingRule>.of(_activeRoutingPreset.routingRules);
    if (replaceExisting) {
      rules
        ..clear()
        ..addAll(imported);
    } else {
      rules.addAll(imported);
    }
    _updateActiveRoutingPreset(
      _activeRoutingPreset.copyWith(routingRules: rules),
    );
    await _persistRoutingPresetsAndMaybeReconnect();
    return imported.length;
  }

  String exportRoutingRulesAsJsonString() =>
      RoutingRule.exportRulesToJsonString(_activeRoutingPreset.routingRules);

  Future<void> _persistRoutingPresetsAndMaybeReconnect() async {
    await _saveRoutingPresets(
      reconnectIfNeeded: _activeRoutingPresetAffectsSelectedServer(),
    );
  }

  Future<void> _saveRoutingPresetsAndNotify() async {
    await _saveRoutingPresets();
  }

  Future<void> _saveRoutingPresets({bool reconnectIfNeeded = false}) async {
    await _repository.saveRoutingPresets(_routingPresets);
    notifyListeners();
    if (reconnectIfNeeded && _hasRestartableNativeSession) {
      await _restartActiveConnection();
    }
  }

  Future<void> setTunEngineMode(TunEngineMode mode) async {
    if (_tunEngineMode == mode) return;
    final shouldReconnect = _hasRestartableNativeSession;
    _tunEngineMode = mode;
    await _repository.saveTunEngineMode(mode);
    notifyListeners();

    if (shouldReconnect) {
      await _restartActiveConnection();
    }
  }

  Future<List<GeoDataFileStatus>> loadGeoDataStatuses() async {
    final nativeStatuses = await _geoDataBridge.getStatus();
    final byKind = {for (final status in nativeStatuses) status.kind: status};

    final output = <GeoDataFileStatus>[];
    for (final kind in GeoDataKind.values) {
      final native = byKind[kind];
      final metadata = _repository.loadGeoDataMetadata(kind);
      final resolved = _resolveGeoDataStatus(kind, native, metadata);
      output.add(resolved);

      if (native != null &&
          native.installed &&
          metadata.source == GeoDataSource.unknown) {
        await _repository.saveGeoDataMetadata(
          kind,
          GeoDataMetadata(
            source: GeoDataSource.bundled,
            url: metadata.url,
            updatedAt: native.modifiedAt,
            fileSize: native.fileSize,
          ),
        );
      }
    }
    return output;
  }

  Stream<GeoDataDownloadProgress> get geoDataDownloadProgressStream =>
      _geoDataBridge.downloadProgressStream();

  void _beginGeoDataAction(GeoDataKind kind, {bool trackProgress = false}) {
    if (!_busyGeoDataKinds.add(kind)) {
      throw StateError('${kind.fileName} is already updating.');
    }
    if (trackProgress) {
      _geoDataProgressByKind[kind] = null;
    } else {
      _geoDataProgressByKind.remove(kind);
    }
    notifyListeners();
  }

  void _endGeoDataAction(GeoDataKind kind) {
    final wasBusy = _busyGeoDataKinds.remove(kind);
    final hadProgress = _geoDataProgressByKind.containsKey(kind);
    _geoDataProgressByKind.remove(kind);
    if (wasBusy || hadProgress) {
      notifyListeners();
    }
  }

  Future<GeoDataFileStatus> updateGeoDataFromUrl({
    required GeoDataKind kind,
    required String url,
  }) async {
    final normalizedUrl = _normalizeGeoDataUrl(url);
    _beginGeoDataAction(kind, trackProgress: true);
    try {
      // Persist the URL before the download starts so it's not lost if the
      // process is killed mid-download (e.g. Android tearing down the Activity
      // after the app is backgrounded).
      final previous = _repository.loadGeoDataMetadata(kind);
      await _repository.saveGeoDataMetadata(
        kind,
        GeoDataMetadata(
          source: GeoDataSource.url,
          url: normalizedUrl,
          updatedAt: previous.updatedAt,
          fileSize: previous.fileSize,
        ),
      );
      final native = await _geoDataBridge.download(
        kind: kind,
        url: normalizedUrl,
      );
      final metadata = GeoDataMetadata(
        source: GeoDataSource.url,
        url: normalizedUrl,
        updatedAt: native.modifiedAt ?? DateTime.now().toUtc(),
        fileSize: native.fileSize,
      );
      await _repository.saveGeoDataMetadata(kind, metadata);
      await _restartAfterGeoDataChange();
      return _resolveGeoDataStatus(kind, native, metadata);
    } finally {
      _endGeoDataAction(kind);
    }
  }

  Future<GeoDataFileStatus?> importGeoDataFromDevice(GeoDataKind kind) async {
    _beginGeoDataAction(kind);
    try {
      final native = await _geoDataBridge.pick(kind);
      if (native == null) return null;
      final current = _repository.loadGeoDataMetadata(kind);
      final metadata = GeoDataMetadata(
        source: GeoDataSource.device,
        url: current.url,
        updatedAt: native.modifiedAt ?? DateTime.now().toUtc(),
        fileSize: native.fileSize,
      );
      await _repository.saveGeoDataMetadata(kind, metadata);
      await _restartAfterGeoDataChange();
      return _resolveGeoDataStatus(kind, native, metadata);
    } finally {
      _endGeoDataAction(kind);
    }
  }

  GeoDataFileStatus _resolveGeoDataStatus(
    GeoDataKind kind,
    GeoDataNativeStatus? native,
    GeoDataMetadata metadata,
  ) {
    final installed = native?.installed ?? false;
    final fileSize = native?.fileSize ?? metadata.fileSize;
    final updatedAt = native?.modifiedAt ?? metadata.updatedAt;
    final source = metadata.source == GeoDataSource.unknown && installed
        ? GeoDataSource.bundled
        : metadata.source;
    return GeoDataFileStatus(
      kind: kind,
      installed: installed,
      fileSize: fileSize,
      updatedAt: updatedAt,
      source: source,
      savedUrl: metadata.url,
    );
  }

  String _normalizeGeoDataUrl(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Enter a valid HTTP or HTTPS URL.');
    }
    return uri.toString();
  }

  Future<void> _restartAfterGeoDataChange() async {
    notifyListeners();
    if (_hasRestartableNativeSession) {
      await _restartActiveConnection();
    }
  }

  Future<void> _replaceSubscription(int index, ServerSubscription next) async {
    if (index < 0 || index >= _subscriptions.length) return;

    final hadRestartableSession = _hasRestartableNativeSession;
    final current = _subscriptions[index];
    final oldNames = RoutingPreset.cleanServerNames(
      current.servers.map((server) => server.name),
    );
    final newNames = RoutingPreset.cleanServerNames(
      next.servers.map((server) => server.name),
    );
    final selectedName = RoutingPreset.normalizeServerName(_selectedName);
    final selectedWasInSubscription =
        selectedName != null && oldNames.contains(selectedName);
    final selectedRemoved =
        selectedName != null &&
        oldNames.contains(selectedName) &&
        !newNames.contains(selectedName);

    final exitName = RoutingPreset.normalizeServerName(_exitNodeName);
    final exitRemoved =
        exitName != null &&
        oldNames.contains(exitName) &&
        !newNames.contains(exitName);

    _subscriptions[index] = next;

    if (selectedRemoved) {
      _selectedName = next.servers.isNotEmpty
          ? next.servers.first.name
          : _firstAvailableServerName();
      await _repository.saveSelected(_selectedName);
    }
    if (exitRemoved) {
      _exitNodeName = null;
      await _repository.saveExitNodeName(null);
    }

    _cleanRoutingPresetBindings();
    final favoriteOrderChanged = _syncFavoriteServerNames();
    await _persistSubscriptions();
    await _repository.saveRoutingPresets(_routingPresets);
    if (favoriteOrderChanged) await _persistFavoriteServerNames();
    notifyListeners();

    if (!hadRestartableSession) return;
    if (selectedServer == null) {
      await disconnect();
      return;
    }
    if (selectedRemoved ||
        exitRemoved ||
        (selectedWasInSubscription && _restartConnectionOnSettingsChanges)) {
      await _restartActiveConnection();
    }
  }

  ServerSubscription _preserveSubscriptionServerState({
    required ServerSubscription current,
    required ServerSubscription next,
  }) {
    final previousByName = {
      for (final server in current.servers) server.name: server,
    };
    final servers = next.servers
        .map((server) {
          final previous = previousByName[server.name];
          if (previous == null) return server;
          return server.copyWith(
            isPinned: previous.isPinned,
            ping: previous.ping,
          );
        })
        .toList(growable: false);
    return next.copyWith(
      servers: List.unmodifiable(servers),
      updateIntervalOverride: current.updateIntervalOverride,
      clearUpdateIntervalOverride: current.updateIntervalOverride == null,
    );
  }

  ServerImportResult _subscriptionImportFailure(
    ServerSubscriptionImportException error,
  ) {
    final code = switch (error.code) {
      ServerSubscriptionImportError.network =>
        ServerImportError.subscriptionNetwork,
      ServerSubscriptionImportError.invalidVless =>
        ServerImportError.invalidVless,
      ServerSubscriptionImportError.invalidHysteria2 =>
        ServerImportError.invalidHysteria2,
      ServerSubscriptionImportError.invalidUrl ||
      ServerSubscriptionImportError.empty ||
      ServerSubscriptionImportError.unsupportedFormat =>
        ServerImportError.invalidSubscription,
    };
    return ServerImportResult.fail(
      code,
      error.message,
      vlessError: error.vlessError,
      hysteria2Error: error.hysteria2Error,
    );
  }

  String _newSubscriptionId() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'sub_$micros';
  }

  String _ensureUniqueSubscriptionName(String baseName) {
    final normalized = baseName.trim().isEmpty
        ? 'Subscription'
        : baseName.trim();
    if (_subscriptions.every(
      (subscription) => subscription.name != normalized,
    )) {
      return normalized;
    }
    var index = 2;
    while (_subscriptions.any(
      (subscription) => subscription.name == '$normalized ($index)',
    )) {
      index++;
    }
    return '$normalized ($index)';
  }

  Future<void> _persistServers() => _repository.saveServers(_servers);

  Future<void> _persistSubscriptions() async {
    await _repository.saveSubscriptions(_subscriptions);
    _syncCollapsedSubscriptionIds();
    await _persistCollapsedSubscriptionIds();
  }

  Future<void> _persistFavoriteServerNames() =>
      _repository.saveFavoriteServerNames(_favoriteServerNames);

  Future<void> _persistCollapsedSubscriptionIds() {
    final ids = _subscriptions
        .where(
          (subscription) => _collapsedSubscriptionIds.contains(subscription.id),
        )
        .map((subscription) => subscription.id)
        .toList(growable: false);
    return _repository.saveCollapsedSubscriptionIds(ids);
  }

  // ─── Connection lifecycle ─────────────────────────────────────────
  Future<void> toggleConnection() async {
    if (isConnected) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    if (isBusy || isConnected) return;
    final server = selectedServer;
    if (server == null) {
      _setError(Msg.vpnNoServerSelected);
      return;
    }
    await _ensureNotificationPermissionAsked();
    _resetConnectionRuntime();
    _acceptConnectedEvent = true;
    _suppressDisconnectedUntil = null;
    _setState(VpnConnectionState.preparing);
    try {
      final prepared =
          await _methodChannel.invokeMethod<bool>('prepareVpn') ?? false;
      if (!prepared) {
        _setError(Msg.vpnPermissionDenied);
        return;
      }
      _setState(VpnConnectionState.connecting);
      await _invokeStart();
      // Native now reports connected only after the Android side confirms
      // live proxy activity, so the UI may remain in "connecting" briefly
      // until the first real outbound traffic is observed.
    } on PlatformException catch (e) {
      _setError(e.message ?? Msg.vpnPlatformError);
    }
  }

  Future<void> disconnect() async {
    if (_connectionState == VpnConnectionState.disconnected) return;
    _restartRequestId++;
    _networkSettingsRestartPending = false;
    _acceptConnectedEvent = false;
    _suppressDisconnectedUntil = null;
    _setState(VpnConnectionState.disconnecting);
    try {
      await _methodChannel.invokeMethod('stopVpn');
    } on PlatformException catch (e) {
      _cancelDisconnectTimeout();
      _setError(e.message ?? Msg.vpnFailedToStop);
      return;
    }
    if (_connectionState == VpnConnectionState.disconnecting) {
      _scheduleDisconnectFallback();
    }
  }

  Future<void> _ensureNotificationPermissionAsked() async {
    if (_repository.loadNotificationPermissionAsked()) return;
    try {
      await _methodChannel.invokeMethod<bool>('requestNotificationPermission');
    } on PlatformException {
      // A failure or denial doesn't block the connect flow — the user just
      // won't see the foreground notification in the shade.
    } finally {
      await _repository.saveNotificationPermissionAsked(true);
    }
  }

  Future<void> _invokeStart() async {
    final entry = selectedServer;
    if (entry == null) return;
    final exit = _resolveBridgeExitFor(entry);
    // Bridge mode: the EXIT server is the final outbound (Xray's main proxy
    // outbound), the ENTRY server is the bridge dialer. Routing rules and
    // per-app policy always come from the ENTRY node's preset — the exit's
    // preset is fully ignored because it's used purely as a transport hop.
    final outer = exit ?? entry;
    final isBridge = exit != null;
    final editorPreset = _activeRoutingPreset;
    final explicitPreset = explicitRoutingPresetForServer(entry.name);
    final preset = _routingPresetForConnection(entry);
    final args = outer.toNativeArgs(
      isGlobalProxy: _isGlobalProxy,
      tunEngineMode: _tunEngineMode,
      appRoutingPolicy: preset.appRoutingPolicy,
      routingRules: preset.routingRules,
      entryServer: isBridge ? entry : null,
    );
    args['routingPresetId'] = preset.id;
    args['routingPresetName'] = preset.name;
    args['routingPresetEditorId'] = editorPreset.id;
    args['routingPresetEditorName'] = editorPreset.name;
    args['routingPresetNodeId'] = explicitPreset?.id ?? '';
    args['routingPresetNodeName'] = explicitPreset?.name ?? '';
    args['routingPresetNode'] = entry.name;
    args['routingPresetMode'] = preset.appRoutingPolicy.mode.wireName;
    args['routingPresetPackageCount'] = preset.appRoutingPolicy.packages.length;
    args['routingPresetRuleCount'] = preset.routingRules.length;
    args['bridgeMode'] = isBridge;
    args['bridgeEntryNode'] = isBridge ? entry.name : '';
    args['bridgeExitNode'] = isBridge ? outer.name : '';
    args['showSpeedInNotification'] = _showSpeedInNotification;
    args['keepAwake'] = _keepAwake;
    args['verboseXrayLogs'] = _verboseXrayLogs;
    final session = _resolveSessionProxyAuth();
    _activeProxyUser = session.$1;
    _activeProxyPassword = session.$2;
    args['proxyUser'] = session.$1;
    args['proxyPassword'] = session.$2;
    args.addAll(_tunnelFragmentSettings.toNativeArgs());
    args.addAll(_multiplexSettings.toNativeArgs());
    args.addAll(_tunnelNetworkSettings.toNativeArgs());
    await _methodChannel.invokeMethod<bool>('startVpn', args);
  }

  /// Returns the exit-marked server to bridge through, or null when the
  /// active selection is single-hop (no exit mark, or the mark points at
  /// the entry itself / a node that no longer exists).
  ServerConfig? _resolveBridgeExitFor(ServerConfig entry) {
    final candidate = exitServer;
    if (candidate == null) return null;
    if (_serverNameEquals(candidate.name, entry.name)) return null;
    return candidate;
  }

  Future<void> _refreshAndroidWidgets() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('refreshAndroidWidgets');
    } catch (_) {}
  }

  /// Returns the (username, password) pair the local Xray inbounds will
  /// require this session. When the user has configured custom credentials,
  /// they take precedence; otherwise we mint fresh random ones so a stale
  /// secret cannot be guessed by another process / browser tab on the same
  /// device. The credentials live only in memory for the lifetime of the
  /// session — see `_resetConnectionRuntime`.
  (String, String) _resolveSessionProxyAuth() {
    if (_useCustomProxyAuth &&
        _customProxyUser.isNotEmpty &&
        _customProxyPassword.isNotEmpty) {
      return (_customProxyUser, _customProxyPassword);
    }
    return (_randomHex(16), _randomHex(24));
  }

  static String _randomHex(int byteLength) {
    final rng = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < byteLength; i++) {
      buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<void> _restartActiveConnection() {
    _networkSettingsRestartPending = false;
    final requestId = ++_restartRequestId;
    final previous = _restartFuture?.catchError((Object _) {});
    final scheduled = (previous ?? Future<void>.value()).then(
      (_) => _runRestartRequest(requestId),
    );
    _restartFuture = scheduled;
    unawaited(
      scheduled
          .whenComplete(() {
            if (identical(_restartFuture, scheduled)) {
              _restartFuture = null;
            }
          })
          .catchError((Object _) {}),
    );
    return scheduled;
  }

  Future<void> _runRestartRequest(int requestId) async {
    if (requestId != _restartRequestId) return;
    final server = selectedServer;
    if (server == null) {
      _setError(Msg.vpnNoServerSelected);
      return;
    }

    _resetConnectionRuntime();
    _acceptConnectedEvent = true;
    _suppressDisconnectedUntil = DateTime.now().add(
      Platform.isAndroid
          ? _androidVpnRestartStopTimeout + _disconnectSuppressionWindow
          : _disconnectSuppressionWindow,
    );
    if (_connectionState == VpnConnectionState.connecting) {
      _scheduleConnectTimeout();
    } else {
      _setState(VpnConnectionState.connecting);
    }

    try {
      if (Platform.isAndroid) {
        await _methodChannel.invokeMethod<void>('stopVpn');
        await _waitForAndroidVpnStop(requestId);
        if (requestId != _restartRequestId) return;
        await Future<void>.delayed(_androidVpnPostStopSettleDelay);
        if (requestId != _restartRequestId) return;
        _acceptConnectedEvent = true;
      }
      await _invokeStart();
    } on PlatformException catch (e) {
      _setError(e.message ?? Msg.vpnFailedToReconnect);
    }
  }

  Future<void> _waitForAndroidVpnStop(int requestId) async {
    // Short-circuit: if native already reports a terminal state, no need
    // to wait for an event that won't fire.
    final initialState = await _nativeVpnState();
    if (initialState == 'disconnected' ||
        initialState == 'error' ||
        initialState == null) {
      return;
    }
    if (requestId != _restartRequestId) return;

    // Replace any in-flight waiter so we don't deliver to a stale one.
    final previous = _nativeStopWaiter;
    if (previous != null && !previous.isCompleted) {
      previous.complete();
    }
    final waiter = Completer<void>();
    _nativeStopWaiter = waiter;
    try {
      await waiter.future.timeout(
        _androidVpnRestartStopTimeout,
        onTimeout: () {},
      );
    } finally {
      if (identical(_nativeStopWaiter, waiter)) {
        _nativeStopWaiter = null;
      }
    }
  }

  void _completeNativeStopWaiter() {
    final waiter = _nativeStopWaiter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
    _nativeStopWaiter = null;
  }

  Future<String?> _nativeVpnState() async {
    try {
      final status = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getVpnStatus',
      );
      return status?['state'] as String?;
    } on PlatformException {
      return null;
    }
  }

  // ─── DeepLink wiring ─────────────────────────────────────────────
  // Drains both the cold-launch URL (if any) and warm events from the
  // platform-side bridge. Each URL is run through [importServersFromString]
  // — that path already routes voidtunnel:// codes through the link codec
  // and falls back to the plain subscription-URL importer if a future
  // version of the scheme ships a raw https payload.
  void _bindDeepLinkChannel() {
    unawaited(() async {
      final initial = await _deepLinkChannel.consumeInitial();
      if (initial != null && initial.isNotEmpty) {
        await importServersFromString(initial);
      }
    }());
    _deepLinkSub = _deepLinkChannel.incomingLinks.listen(
      (url) {
        unawaited(importServersFromString(url));
      },
      onError: (Object error) {
        debugPrint('deeplink event stream error: $error');
      },
    );
  }

  // ─── EventChannel wiring ──────────────────────────────────────────
  void _bindEventChannel() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final state = event['state'] as String?;
        final message = event['message'] as String?;
        switch (state) {
          case 'connecting':
            _acceptConnectedEvent = true;
            _setState(VpnConnectionState.connecting);
            break;
          case 'connected':
            if (!_acceptConnectedEvent &&
                _connectionState != VpnConnectionState.connected) {
              return;
            }
            _acceptConnectedEvent = false;
            _suppressDisconnectedUntil = null;
            _lastError = null;
            _markConnected();
            _setState(VpnConnectionState.connected);
            break;
          case 'disconnected':
            // Anything waiting on native teardown (the restart path) should
            // resolve here regardless of the suppression-window logic that
            // follows — the native side really has stopped, even if we
            // hide the UI-level transition.
            _completeNativeStopWaiter();
            final deadline = _suppressDisconnectedUntil;
            if (deadline != null && DateTime.now().isBefore(deadline)) {
              // Expected tail of our own stopVpn — keep the current state
              // (usually error from the timeout path) instead of clobbering
              // it with a terminal disconnected. Clear the window so any
              // *later* disconnect still propagates.
              _suppressDisconnectedUntil = null;
              return;
            }
            _suppressDisconnectedUntil = null;
            _acceptConnectedEvent = false;
            _lastError = null;
            _setState(VpnConnectionState.disconnected);
            break;
          case 'error':
            _completeNativeStopWaiter();
            _acceptConnectedEvent = false;
            _setError(message ?? Msg.vpnUnknownError);
            break;
        }
      },
      onError: (Object err) {
        _setError(Msg.vpnEventChannelError(err.toString()));
      },
    );
  }

  void _bindGeoDataProgressChannel() {
    _geoDataProgressSub = _geoDataBridge.downloadProgressStream().listen(
      (event) {
        if (!_busyGeoDataKinds.contains(event.kind)) return;
        if (_geoDataProgressByKind.containsKey(event.kind) &&
            _geoDataProgressByKind[event.kind] == event.percent) {
          return;
        }
        _geoDataProgressByKind[event.kind] = event.percent;
        notifyListeners();
      },
      onError: (Object err) {
        debugPrint('geodata progress stream error: $err');
      },
    );
  }

  void _setState(VpnConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    if (state == VpnConnectionState.connecting) {
      _scheduleConnectTimeout();
    } else {
      _cancelConnectTimeout();
    }
    if (state != VpnConnectionState.disconnecting) {
      _cancelDisconnectTimeout();
    }
    if (state == VpnConnectionState.disconnected) {
      _resetConnectionRuntime();
    }
    if (state != VpnConnectionState.error) _lastError = null;
    _connectionStateNotifier.value = state;
    notifyListeners();
  }

  void _setError(String message) {
    _acceptConnectedEvent = false;
    _cancelConnectTimeout();
    _cancelDisconnectTimeout();
    _resetConnectionRuntime();
    _lastError = message;
    _connectionState = VpnConnectionState.error;
    _connectionStateNotifier.value = VpnConnectionState.error;
    notifyListeners();
  }

  /// Scans every known server. Auto-triggered callers (launch, lifecycle
  /// resume) must leave [force] unset so the [_fullScanCooldown] applies;
  /// the manual refresh button in the UI passes `force: true` to bypass it.
  /// When the cooldown blocks the call the previously-measured pings stay
  /// in memory untouched.
  Future<void> scanLatencies({bool force = false}) async {
    if (!force && _isFullScanOnCooldown()) return;
    final snapshot = _allServerList();
    if (_isScanningLatency || snapshot.isEmpty) return;
    _isScanningLatency = true;
    for (final server in snapshot) {
      _updateServerPing(server.name, '...', notify: false);
    }
    _flushPingBuffer(notify: false);
    notifyListeners();

    try {
      await _scanLatencySnapshot(snapshot);
    } finally {
      _flushPingBuffer(notify: false);
      _isScanningLatency = false;
      _lastFullScanTime = DateTime.now();
      if (_autoSortServersByPing) {
        _sortServersByPingInPlace();
      }
      // Persist measured pings so they survive a restart even when
      // auto-sort is off. Without this the on-disk JSON would still
      // contain the pre-scan values.
      await _persistServers();
      await _persistSubscriptions();
      notifyListeners();
    }
  }

  bool _isFullScanOnCooldown() {
    final last = _lastFullScanTime;
    if (last == null) return false;
    return DateTime.now().difference(last) < _fullScanCooldown;
  }

  /// Pings only the currently-selected server. Used on resume from the tray
  /// when a full scan is on cooldown — the user wants to see fresh latency
  /// for their working node without re-probing the other 400.
  Future<void> pingActiveServerOnly() async {
    if (_isScanningLatency) return;
    await _refreshActiveServerPing(_runtimeGeneration);
  }

  Future<void> scanManualLatencies() async {
    final snapshot = List<ServerConfig>.from(_servers);
    if (_isScanningLatency || snapshot.isEmpty) return;
    _isScanningLatency = true;
    for (final server in snapshot) {
      _updateServerPing(server.name, '...', notify: false);
    }
    _flushPingBuffer(notify: false);
    notifyListeners();

    try {
      await _scanLatencySnapshot(snapshot);
    } finally {
      _flushPingBuffer(notify: false);
      _isScanningLatency = false;
      if (_autoSortServersByPing) {
        _sortManualServersByPingInPlace();
      }
      await _persistServers();
      notifyListeners();
    }
  }

  Future<void> scanSubscriptionLatencies(String id) async {
    if (_isScanningLatency || _scanningSubscriptionIds.contains(id)) return;
    final index = _subscriptions.indexWhere(
      (subscription) => subscription.id == id,
    );
    if (index < 0) return;
    final snapshot = List<ServerConfig>.from(_subscriptions[index].servers);
    if (snapshot.isEmpty) return;

    _scanningSubscriptionIds.add(id);
    for (final server in snapshot) {
      _updateServerPing(server.name, '...', notify: false);
    }
    _flushPingBuffer(notify: false);
    notifyListeners();

    try {
      await _scanLatencySnapshot(snapshot);
      _flushPingBuffer(notify: false);
      if (_autoSortServersByPing) {
        _sortSubscriptionByPingInPlace(id);
      }
      await _persistSubscriptions();
    } finally {
      _flushPingBuffer(notify: false);
      _scanningSubscriptionIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> _scanLatencySnapshot(List<ServerConfig> snapshot) async {
    final target = _latencyProbeTarget;
    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        if (index >= snapshot.length) return;
        nextIndex++;
        final server = snapshot[index];
        final ping = await _measureServerLatency(server, target: target);
        _updateServerPing(server.name, ping);
      }
    }

    final workerCount = min(_latencyScanConcurrency, snapshot.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  void _sortServersByPingInPlace() {
    _sortManualServersByPingInPlace();
    for (final subscription in _subscriptions) {
      _sortSubscriptionByPingInPlace(subscription.id);
    }
  }

  void _sortManualServersByPingInPlace() {
    _servers.sort((a, b) {
      final c = ServerConfig.pingOrderKey(
        a.ping,
      ).compareTo(ServerConfig.pingOrderKey(b.ping));
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  void _sortSubscriptionByPingInPlace(String id) {
    final index = _subscriptions.indexWhere(
      (subscription) => subscription.id == id,
    );
    if (index < 0) return;
    final subscription = _subscriptions[index];
    final sorted = List<ServerConfig>.from(subscription.servers)
      ..sort((a, b) {
        final c = ServerConfig.pingOrderKey(
          a.ping,
        ).compareTo(ServerConfig.pingOrderKey(b.ping));
        if (c != 0) return c;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    _subscriptions[index] = subscription.copyWith(
      servers: List.unmodifiable(sorted),
    );
  }

  void _markConnected() {
    if (_connectedAt == null) {
      _connectedAt = DateTime.now();
      _setConnectionDuration(Duration.zero);
      _startConnectionTicker();
    }

    if (_externalIp == null && !_hasExternalIpAttempt) {
      unawaited(_refreshExternalIp(_runtimeGeneration));
    }

    unawaited(_refreshActiveServerPing(_runtimeGeneration));
  }

  Future<void> _refreshActiveServerPing(int generation) async {
    final server = selectedServer;
    if (server == null) return;
    final target = _latencyProbeTarget;
    _updateServerPing(server.name, '...');
    final ping = await _measureServerLatency(
      server,
      target: target,
      preferRuntimeProxy: true,
    );
    if (generation != _runtimeGeneration) return;
    _updateServerPing(server.name, ping);
    _flushPingBuffer(notify: true);
    await _persistServers();
    await _persistSubscriptions();
  }

  Future<String> _measureServerLatency(
    ServerConfig server, {
    required LatencyProbeTarget target,
    bool preferRuntimeProxy = false,
  }) async {
    if (preferRuntimeProxy &&
        Platform.isAndroid &&
        isConnected &&
        target.usesServerEndpoint &&
        _serverNameEquals(server.name, selectedServer?.name ?? '')) {
      final runtimePing = await _latencyProbe.measureViaHttpProxy(
        proxyHost: _externalIpProxyHost,
        proxyPort: _externalIpProxyPort,
        proxyUser: _activeProxyUser,
        proxyPassword: _activeProxyPassword,
      );
      if (runtimePing != null) return runtimePing;
    }
    return _latencyProbe.measure(server, target: target);
  }

  void _startConnectionTicker() {
    _connectionTicker?.cancel();
    _connectionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final connectedAt = _connectedAt;
      if (connectedAt == null) return;
      _setConnectionDuration(DateTime.now().difference(connectedAt));
    });
  }

  void _resetConnectionRuntime() {
    _runtimeGeneration++;
    _connectionTicker?.cancel();
    _connectionTicker = null;
    _connectedAt = null;
    _setConnectionDuration(Duration.zero);
    _externalIp = null;
    _hasExternalIpAttempt = false;
    _activeProxyUser = null;
    _activeProxyPassword = null;
  }

  void _setConnectionDuration(Duration duration) {
    final label = _formatDuration(duration);
    if (_connectionDurationLabelNotifier.value != label) {
      _connectionDurationLabelNotifier.value = label;
    }
  }

  Future<void> _refreshExternalIp(int generation) async {
    // Give the tunnel a moment to finish wiring before we try to resolve
    // our external IP through it.
    await Future<void>.delayed(_ipLookupInitialDelay);
    if (generation != _runtimeGeneration || !isConnected) return;

    try {
      for (var attempt = 0; attempt < _ipLookupAttempts; attempt++) {
        if (generation != _runtimeGeneration || !isConnected) return;
        final ip = await _raceExternalIpLookup(generation);
        if (generation != _runtimeGeneration || !isConnected) return;
        if (ip != null) {
          _externalIp = ip;
          _hasExternalIpAttempt = true;
          notifyListeners();
          return;
        }
        // Backoff between retries gives the network/tunnel a chance to
        // recover if the first pass raced the initial handshake.
        if (attempt < _ipLookupAttempts - 1) {
          await Future<void>.delayed(_ipLookupRetryBackoff);
        }
      }
    } finally {
      if (generation == _runtimeGeneration &&
          isConnected &&
          _externalIp == null) {
        _hasExternalIpAttempt = true;
        notifyListeners();
      }
    }
  }

  /// Fires all IP-lookup endpoints in parallel and returns the first
  /// non-null response.
  ///
  /// The app package is excluded from the Android VPN route, so direct Dart
  /// networking would report the device's own public IP. Xray exposes a local
  /// HTTP proxy specifically for this probe and routes that inbound straight
  /// to the final proxy outbound.
  Future<String?> _raceExternalIpLookup(int generation) {
    final completer = Completer<String?>();
    var pending = _ipLookupUrls.length;

    for (final rawUrl in _ipLookupUrls) {
      _fetchExternalIpViaRuntimeProxy(Uri.parse(rawUrl))
          .then((ip) {
            if (completer.isCompleted) return;
            if (generation != _runtimeGeneration) {
              completer.complete(null);
              return;
            }
            if (ip != null) {
              completer.complete(ip);
              return;
            }
            pending--;
            if (pending == 0) completer.complete(null);
          })
          .catchError((_) {
            if (completer.isCompleted) return;
            pending--;
            if (pending == 0) completer.complete(null);
          });
    }

    return completer.future;
  }

  Future<String?> _fetchExternalIpViaRuntimeProxy(Uri url) async {
    HttpClient? client;
    try {
      if (url.scheme != 'https' && url.scheme != 'http') return null;
      client = HttpClient()
        ..connectionTimeout = _ipRequestTimeout
        ..findProxy = (_) =>
            'PROXY $_externalIpProxyHost:$_externalIpProxyPort';
      final user = _activeProxyUser;
      final password = _activeProxyPassword;
      if (user != null &&
          password != null &&
          user.isNotEmpty &&
          password.isNotEmpty) {
        // Xray's HTTP inbound advertises an empty realm, so we register the
        // credentials under "" — matching that exactly is what makes
        // `HttpClient` actually attach the Proxy-Authorization header on the
        // first hop instead of waiting for a 407 challenge that never comes
        // back when the proxy just closes the connection on auth failure.
        client.addProxyCredentials(
          _externalIpProxyHost,
          _externalIpProxyPort,
          '',
          HttpClientBasicCredentials(user, password),
        );
      }
      final request = await client.getUrl(url).timeout(_ipRequestTimeout);
      request.followRedirects = true;
      request.maxRedirects = 3;
      request.headers.set(HttpHeaders.acceptHeader, 'text/plain');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(_ipRequestTimeout);
      if (response.statusCode != 200) return null;
      final body = await utf8.decoder.bind(response).join();
      final firstLine = body.trim().split(RegExp(r'[\r\n]+')).first.trim();
      return InternetAddress.tryParse(firstLine) == null ? null : firstLine;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  void _updateServerPing(String serverName, String ping, {bool notify = true}) {
    _pingBuffer[serverName] = ping;
    if (notify) _schedulePingFlush();
  }

  void _schedulePingFlush() {
    if (_pingBatchTimer != null) return;
    _pingBatchTimer = Timer(_pingBatchInterval, () {
      _pingBatchTimer = null;
      _flushPingBuffer();
    });
  }

  bool _flushPingBuffer({bool notify = true}) {
    if (_pingBuffer.isEmpty) return false;
    _pingBatchTimer?.cancel();
    _pingBatchTimer = null;

    final updates = Map<String, String>.from(_pingBuffer);
    _pingBuffer.clear();
    var changed = false;

    for (var i = 0; i < _servers.length; i++) {
      final server = _servers[i];
      final ping = updates[server.name];
      if (ping == null || server.ping == ping) continue;
      _servers[i] = server.copyWith(ping: ping);
      changed = true;
    }

    for (var subIndex = 0; subIndex < _subscriptions.length; subIndex++) {
      final subscription = _subscriptions[subIndex];
      List<ServerConfig>? nextServers;
      for (
        var serverIndex = 0;
        serverIndex < subscription.servers.length;
        serverIndex++
      ) {
        final server = subscription.servers[serverIndex];
        final ping = updates[server.name];
        if (ping == null || server.ping == ping) continue;
        nextServers ??= List<ServerConfig>.from(subscription.servers);
        nextServers[serverIndex] = server.copyWith(ping: ping);
        changed = true;
      }
      if (nextServers != null) {
        _subscriptions[subIndex] = subscription.copyWith(
          servers: List.unmodifiable(nextServers),
        );
      }
    }

    if (changed && notify) {
      _latencyScanTick.value++;
      notifyListeners();
    }
    return changed;
  }

  static String _formatDuration(Duration duration) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _scheduleConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = Timer(_connectTimeout, () {
      if (_connectionState != VpnConnectionState.connecting) return;
      _acceptConnectedEvent = false;
      _suppressDisconnectedUntil = DateTime.now().add(
        _disconnectSuppressionWindow,
      );
      unawaited(_stopVpnAfterTimeout());
      _setError(Msg.vpnConnectionTimedOut);
    });
  }

  void _cancelConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
  }

  void _scheduleDisconnectFallback() {
    _disconnectTimeoutTimer?.cancel();
    _disconnectTimeoutTimer = Timer(_disconnectFallbackTimeout, () {
      if (_connectionState != VpnConnectionState.disconnecting) return;
      _setState(VpnConnectionState.disconnected);
    });
  }

  void _cancelDisconnectTimeout() {
    _disconnectTimeoutTimer?.cancel();
    _disconnectTimeoutTimer = null;
  }

  Future<void> _stopVpnAfterTimeout() async {
    try {
      await _methodChannel.invokeMethod('stopVpn');
    } catch (_) {
      // stopVpn never dispatched, so no "disconnected" event is coming in
      // the suppression window — clear it so the next real disconnect lands.
      _suppressDisconnectedUntil = null;
    }
  }

  @override
  void dispose() {
    _cancelConnectTimeout();
    _cancelDisconnectTimeout();
    _connectionTicker?.cancel();
    _subscriptionAutoRefreshTimer?.cancel();
    _pingBatchTimer?.cancel();
    _pingBuffer.clear();
    _connectionDurationLabelNotifier.dispose();
    _connectionStateNotifier.dispose();
    _latencyScanTick.dispose();
    _completeNativeStopWaiter();
    _eventSub?.cancel();
    _deepLinkSub?.cancel();
    _geoDataProgressSub?.cancel();
    super.dispose();
  }
}
