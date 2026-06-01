import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_locale.dart';
import '../../core/models/server_config.dart';
import '../../core/models/server_subscription.dart';
import '../../core/tv_layout_preference.dart';
import '../../core/tv_mode_detector.dart';
import '../../core/server_repository.dart';
import '../../core/tv_region_label.dart';
import '../../core/vpn_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../settings_screen.dart';
import 'tv_focus_controller.dart';
import 'tv_shortcuts.dart';
import 'widgets/tv_action_bar.dart';
import 'widgets/tv_left_panel.dart';
import 'widgets/tv_preset_overlay.dart';
import 'widgets/tv_right_panel.dart';
import 'widgets/tv_side_rail.dart';
import 'widgets/tv_subscriptions_overlay.dart';
import 'widgets/tv_top_strip.dart';

/// Google TV / Android TV home screen. Built on top of the same
/// [VpnController] the mobile [HomeScreen] uses, so connection state,
/// subscriptions, presets, and deep-link import all stay in sync.
class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({
    super.key,
    required this.controller,
    required this.repository,
    required this.tvMode,
    required this.isDarkTheme,
    required this.onThemeModeChanged,
    required this.localePreference,
    required this.onLocalePreferenceChanged,
  });

  final VpnController controller;
  final ServerRepository repository;
  final TvModeDetector tvMode;
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeModeChanged;
  final AppLocalePreference localePreference;
  final ValueChanged<AppLocalePreference> onLocalePreferenceChanged;

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  /// Logical canvas the TV layout is composed for — matches the design
  /// canvas exactly. Everything inside `build` is sized at these
  /// coordinates and then [FittedBox]-scaled to the physical screen.
  static const double _designWidth = 1920;
  static const double _designHeight = 1080;
  static const int _sideRailLength = 4;

  late final TvFocusController _focus = TvFocusController(
    listLength: 0,
    sideRailLength: _sideRailLength,
  );
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  late bool _showRemoteFocus;

  @override
  void initState() {
    super.initState();
    // Show D-pad focus chrome immediately on the TV home canvas. Touch
    // still hides it via [_handlePointerAction] until the user presses a
    // remote key again — relying on [isNativeTv] alone left the CONNECT
    // hub without a ring on phones/tablets in forced horizontal layout.
    _showRemoteFocus = true;
    widget.controller.addListener(_handleControllerChanged);
    _focus.updateListLength(_flattenServers(_buildGroups(null)).length);
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    // Real Google TV boxes have no status / navigation bars to begin
    // with, but on a phone in dev override the system chrome eats into
    // the 1920×1080 canvas and offsets the FittedBox. Sticky immersive
    // hides it; the bar comes back on a swipe and re-hides.
    //
    // Orientation lock is NOT touched here — that's app-level, driven
    // by the persisted `TvLayoutPreference` in `main.dart`.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    widget.controller.removeListener(_handleControllerChanged);
    _focus.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  VpnController get _controller => widget.controller;

  void _setRemoteFocusVisible(bool visible) {
    if (_showRemoteFocus == visible) return;
    setState(() => _showRemoteFocus = visible);
  }

  void _handlePointerAction(VoidCallback action) {
    _setRemoteFocusVisible(false);
    action();
  }

  void _showFocusForRemoteInput() {
    _setRemoteFocusVisible(true);
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final groups = _buildGroups(null);
    _focus.updateListLength(_flattenServers(groups).length);
    setState(() {});
  }

  /// Composes the right-rail groups in the order they should be drawn:
  /// MANUAL nodes (if any), then each subscription as its own section.
  /// Favorites are NOT a separate bucket on TV — adding to / managing
  /// favorites is intentionally absent from the 10-foot UI.
  List<TvNodeGroup> _buildGroups(AppLocalizations? l) {
    final groups = <TvNodeGroup>[];
    final seen = <String>{};

    List<ServerConfig> dedup(Iterable<ServerConfig> source) {
      final out = <ServerConfig>[];
      for (final server in source) {
        if (seen.add(server.name)) out.add(server);
      }
      return out;
    }

    final manual = dedup(_controller.manualServers);
    if (manual.isNotEmpty) {
      groups.add(
        TvNodeGroup(
          title: l?.tvGroupManual ?? 'MANUAL',
          meta: l?.tvNodesCount(manual.length),
          servers: manual,
        ),
      );
    }
    for (var i = 0; i < _controller.subscriptions.length; i++) {
      final sub = _controller.subscriptions[i];
      final servers = dedup(_controller.visibleSubscriptionServers(sub));
      if (servers.isEmpty) continue;
      TvSubscriptionSummary? summary;
      if (i == 0 && l != null) {
        summary = TvSubscriptionSummary(
          name: sub.name,
          expiryLabel: _expiryLabel(l, sub),
          nodeCount: servers.length,
          refreshedLabel: _refreshedLabel(l, sub),
        );
      }
      groups.add(
        TvNodeGroup(
          title: sub.name,
          meta: l?.tvNodesCount(servers.length),
          servers: servers,
          showHeaderCard: summary != null,
          headerCardSummary: summary,
        ),
      );
    }
    return groups;
  }

  /// Flatten group servers in render order — used to map a focus row
  /// index back to a [ServerConfig].
  List<ServerConfig> _flattenServers(List<TvNodeGroup> groups) {
    return [for (final group in groups) ...group.servers];
  }

  String _expiryLabel(AppLocalizations l, ServerSubscription sub) {
    final expiresAt = sub.expiresAt;
    if (expiresAt == null) return l.subscriptionExpiryUnknown;
    final local = expiresAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${two(local.day)}.${two(local.month)}.${local.year}';
    return expiresAt.isBefore(DateTime.now().toUtc())
        ? l.subscriptionExpired(date)
        : l.subscriptionExpires(date);
  }

  String _refreshedLabel(AppLocalizations l, ServerSubscription sub) {
    final updatedAt = sub.updatedAt;
    if (updatedAt == null) return l.tvRefreshedUnknown;
    final delta = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (delta.inMinutes < 1) return l.tvRefreshedJustNow;
    if (delta.inHours < 1) return l.tvRefreshedMinutesAgo(delta.inMinutes);
    if (delta.inDays < 1) return l.tvRefreshedHoursAgo(delta.inHours);
    return l.tvRefreshedDaysAgo(delta.inDays);
  }

  void _activate() {
    if (_focus.isOverlayOpen) {
      _executeOverlaySelection();
      return;
    }
    switch (_focus.column) {
      case TvFocusColumn.hub:
        unawaited(_controller.toggleConnection());
        break;
      case TvFocusColumn.side:
        _activateSideRail(_focus.row);
        break;
      case TvFocusColumn.list:
        final flat = _flattenServers(_buildGroups(null));
        if (_focus.row >= flat.length) return;
        _activateServer(flat[_focus.row], null);
        break;
    }
  }

  /// Selects [server] and (when idle) immediately starts the tunnel —
  /// same behaviour as pressing OK while the row is focused. Optionally
  /// updates the focus controller so the row stays highlighted after a
  /// pointer-driven activation.
  void _activateServer(ServerConfig server, List<TvNodeGroup>? groups) {
    final flat = _flattenServers(groups ?? _buildGroups(null));
    final index = flat.indexWhere((s) => s.name == server.name);
    if (index >= 0) {
      _focus.setFocus(TvFocusColumn.list, row: index);
    }
    unawaited(_controller.selectServer(server.name));
    if (_controller.connectionState == VpnConnectionState.disconnected) {
      unawaited(_controller.connect());
    }
  }

  void _activateSideRail(int row) {
    switch (row) {
      case 0:
        if (_controller.isGlobalProxy) {
          unawaited(_controller.setGlobalProxy(false));
        }
        break;
      case 1:
        unawaited(_controller.setGlobalProxy(!_controller.isGlobalProxy));
        break;
      case 2:
        _openPresetOverlay();
        break;
      case 3:
        _openSettings();
        break;
    }
  }

  void _openSettings() {
    // Opening Settings from the TV home — the screen always has a TV
    // variant, so `requested: true`. The helper inside SettingsScreen
    // then picks chrome based on current orientation (horizontal /
    // landscape → TV; portrait under autoRotate → mobile). Bottom dock
    // is hidden because it belongs strictly to the mobile experience.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          controller: _controller,
          isDarkTheme: widget.isDarkTheme,
          onThemeModeChanged: widget.onThemeModeChanged,
          localePreference: widget.localePreference,
          onLocalePreferenceChanged: widget.onLocalePreferenceChanged,
          showBottomDock: false,
          useTvChrome: true,
          allowTvChromeInAutoRotate: widget.tvMode.isNativeTv,
        ),
      ),
    );
  }

  void _executeOverlaySelection() {
    switch (_focus.overlay) {
      case TvOverlay.subscriptions:
        _focus.closeOverlay();
        break;
      case TvOverlay.preset:
        final presets = _controller.routingPresets;
        if (presets.isEmpty || _focus.overlayRow >= presets.length) {
          _focus.closeOverlay();
          return;
        }
        final selectedName = _controller.selectedName;
        final preset = presets[_focus.overlayRow];
        if (selectedName != null) {
          unawaited(
            _controller.setServerRoutingPreset(selectedName, preset.id),
          );
        } else {
          unawaited(_controller.selectRoutingPreset(preset.id));
        }
        _focus.closeOverlay();
        break;
      case TvOverlay.none:
        break;
    }
  }

  void _onMenu() {
    if (_focus.isOverlayOpen) {
      _focus.closeOverlay();
      return;
    }
    if (_focus.column == TvFocusColumn.list) {
      _openPresetOverlay();
    } else {
      _openSubscriptionsOverlay();
    }
  }

  void _openSubscriptionsOverlay() {
    final subs = _controller.subscriptions;
    _focus.openOverlay(TvOverlay.subscriptions, length: subs.length);
  }

  void _openPresetOverlay() {
    final presets = _controller.routingPresets;
    final selectedName = _controller.selectedName;
    final currentId = selectedName == null
        ? _controller.selectedRoutingPresetId
        : (_controller.explicitRoutingPresetForServer(selectedName)?.id ??
              _controller.selectedRoutingPresetId);
    final initialIndex = presets.indexWhere((p) => p.id == currentId);
    _focus.openOverlay(
      TvOverlay.preset,
      length: presets.length,
      initialRow: initialIndex < 0 ? 0 : initialIndex,
    );
  }

  void _onBack() {
    if (_focus.isOverlayOpen) {
      _focus.closeOverlay();
    }
  }

  void _onScan() {
    if (_controller.isScanningLatency) return;
    unawaited(_controller.scanLatencies(force: true));
  }

  /// True when the user explicitly forced the horizontal TV layout on
  /// a non-TV device (the "preview" dev path). On a real Android TV or
  /// in the tablet-friendly auto-rotate mode the chip and back-button
  /// intercept stay inactive — the user picked those intentionally.
  bool get _isDevPreview {
    if (widget.tvMode.isNativeTv) return false;
    return widget.repository.loadTvLayoutPreference() ==
        TvLayoutPreference.horizontal;
  }

  Future<void> _exitDevPreview() async {
    await widget.repository.saveTvLayoutPreference(TvLayoutPreference.vertical);
    // No further action needed — `main.dart`'s ValueListenableBuilder
    // swaps `HomeScreen` back in as soon as the repository notifies.
  }

  String _okHint(AppLocalizations l) {
    if (_focus.isOverlayOpen) return l.tvActionSelect;
    switch (_focus.column) {
      case TvFocusColumn.hub:
        return switch (_controller.connectionState) {
          VpnConnectionState.disconnected => l.tvActionConnect,
          VpnConnectionState.connecting ||
          VpnConnectionState.preparing => l.tvActionCancel,
          VpnConnectionState.connected => l.tvActionDisconnect,
          VpnConnectionState.disconnecting => l.tvActionCancel,
          VpnConnectionState.error => l.tvActionRetry,
        };
      case TvFocusColumn.list:
        return l.tvActionSelectNode;
      case TvFocusColumn.side:
        if (_focus.row == 3) return l.tvActionSelect;
        return l.tvActionToggle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    final groups = _buildGroups(l);
    final flat = _flattenServers(groups);
    _focus.updateListLength(flat.length);
    // Pre-listen so the controller's `notifyListeners` rebuilds us.
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _focus]),
      builder: (context, _) {
        final sideRailItems = <TvSideRailItem>[
          TvSideRailItem(
            label: l.tvSideSplit,
            subtitle: l.tvSideSplitSub,
            active: !_controller.isGlobalProxy,
            onTap: () => _handlePointerAction(() {
              _focus.setFocus(TvFocusColumn.side, row: 0);
              _activateSideRail(0);
            }),
          ),
          TvSideRailItem(
            label: l.tvSideGlobal,
            subtitle: l.tvSideGlobalSub,
            active: _controller.isGlobalProxy,
            onTap: () => _handlePointerAction(() {
              _focus.setFocus(TvFocusColumn.side, row: 1);
              _activateSideRail(1);
            }),
          ),
          TvSideRailItem(
            label: l.tvSidePreset,
            subtitle: l.tvSidePresetSub,
            active: false,
            onTap: () => _handlePointerAction(() {
              _focus.setFocus(TvFocusColumn.side, row: 2);
              _activateSideRail(2);
            }),
          ),
          TvSideRailItem(
            label: 'SETTINGS',
            subtitle: 'CONFIG',
            active: false,
            onTap: () => _handlePointerAction(() {
              _focus.setFocus(TvFocusColumn.side, row: 3);
              _activateSideRail(3);
            }),
          ),
        ];
        final selectedServer = _controller.selectedServer;
        final exitServer = _controller.exitServer ?? selectedServer;
        final externalIp = _controller.externalIpIfResolved;
        final hints = <TvActionHint>[
          TvActionHint(
            button: 'OK',
            label: _okHint(l),
            onTap: () => _handlePointerAction(_activate),
          ),
          TvActionHint(
            button: l.tvActionBackKey,
            label: _focus.isOverlayOpen ? l.tvActionClose : l.tvActionExit,
            onTap: () => _handlePointerAction(_onBack),
          ),
          TvActionHint(
            button: l.tvActionMenuKey,
            label: _focus.column == TvFocusColumn.list
                ? l.tvActionNodeOptions
                : l.tvActionSubscriptions,
            onTap: () => _handlePointerAction(_onMenu),
          ),
          TvActionHint(
            button: l.tvActionPlayPauseKey,
            label: l.tvActionPingScan,
            onTap: () => _handlePointerAction(_onScan),
          ),
        ];

        return Shortcuts(
          shortcuts: tvShortcuts(),
          child: Actions(
            actions: <Type, Action<Intent>>{
              TvMoveIntent: CallbackAction<TvMoveIntent>(
                onInvoke: (intent) {
                  _showFocusForRemoteInput();
                  switch (intent.direction) {
                    case TraversalDirection.left:
                      _focus.moveLeft();
                      break;
                    case TraversalDirection.right:
                      _focus.moveRight();
                      break;
                    case TraversalDirection.up:
                      _focus.moveUp();
                      break;
                    case TraversalDirection.down:
                      _focus.moveDown();
                      break;
                  }
                  return null;
                },
              ),
              TvActivateIntent: CallbackAction<TvActivateIntent>(
                onInvoke: (_) {
                  _showFocusForRemoteInput();
                  _activate();
                  return null;
                },
              ),
              TvBackIntent: CallbackAction<TvBackIntent>(
                onInvoke: (_) {
                  _showFocusForRemoteInput();
                  _onBack();
                  return null;
                },
              ),
              TvMenuIntent: CallbackAction<TvMenuIntent>(
                onInvoke: (_) {
                  _showFocusForRemoteInput();
                  _onMenu();
                  return null;
                },
              ),
              TvScanIntent: CallbackAction<TvScanIntent>(
                onInvoke: (_) {
                  _showFocusForRemoteInput();
                  _onScan();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: PopScope(
                // On the dev-override path the user expects the system
                // back button to escape the preview. On a real Android
                // TV the flag stays false and we let Android handle the
                // back action (close app / go to launcher).
                canPop: !_isDevPreview && !_focus.isOverlayOpen,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  if (_focus.isOverlayOpen) {
                    _focus.closeOverlay();
                    return;
                  }
                  if (_isDevPreview) {
                    unawaited(_exitDevPreview());
                  }
                },
                child: Scaffold(
                  backgroundColor: t.bg,
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      // The TV layout is composed for a fixed 1920×1080
                      // logical canvas. Wrapping it in a [FittedBox] keeps
                      // the design pixel-perfect on a real TV while
                      // letterboxing it onto any smaller surface (phone in
                      // landscape, desktop window, etc.). Without this the
                      // hardcoded 1920×1080 dimensions cause every nested
                      // Row to overflow on a phone.
                      final fitsNatively =
                          constraints.maxWidth >= _designWidth &&
                          constraints.maxHeight >= _designHeight;
                      final body = SizedBox(
                        width: _designWidth,
                        height: _designHeight,
                        child: _buildCanvas(
                          context: context,
                          t: t,
                          l: l,
                          groups: groups,
                          groupTotal: flat.length,
                          sideRailItems: sideRailItems,
                          selectedServer: selectedServer,
                          exitServer: exitServer,
                          externalIp: externalIp,
                          hints: hints,
                        ),
                      );
                      if (fitsNatively) return body;
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          child: body,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCanvas({
    required BuildContext context,
    required VoidTokens t,
    required AppLocalizations l,
    required List<TvNodeGroup> groups,
    required int groupTotal,
    required List<TvSideRailItem> sideRailItems,
    required ServerConfig? selectedServer,
    required ServerConfig? exitServer,
    required String? externalIp,
    required List<TvActionHint> hints,
  }) {
    final showFocus = _showRemoteFocus;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _controller.latencyScanTickListenable,
              builder: (context, tick, child) {
                return TvTopStrip(
                  connectionState: _controller.connectionState,
                  latencyMs: _latencyMs(),
                  now: _now,
                );
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(60, 32, 60, 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 100,
                      child: TvLeftPanel(
                        connectionState: _controller.connectionState,
                        hubFocused:
                            _focus.column == TvFocusColumn.hub &&
                            !_focus.isOverlayOpen,
                        sideRailFocusedIndex:
                            showFocus &&
                                _focus.column == TvFocusColumn.side &&
                                !_focus.isOverlayOpen
                            ? _focus.row
                            : -1,
                        sideRailItems: sideRailItems,
                        exitNodeName:
                            exitServer?.name ?? selectedServer?.name ?? '—',
                        exitIpLabel:
                            externalIp ??
                            (_controller.connectionState ==
                                    VpnConnectionState.connected
                                ? '…'
                                : '———.———.———.———'),
                        regionLabel: TvRegionLabel.regionFor(
                          exitServer?.name ?? selectedServer?.name,
                        ),
                        downHistory: _controller.downloadBpsHistory,
                        upHistory: _controller.uploadBpsHistory,
                        onHubTap: () => _handlePointerAction(
                          () => unawaited(_controller.toggleConnection()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 56),
                    Expanded(
                      flex: 105,
                      child: TvRightPanel(
                        controller: _controller,
                        focusedRow:
                            showFocus &&
                                _focus.column == TvFocusColumn.list &&
                                !_focus.isOverlayOpen
                            ? _focus.row
                            : -1,
                        totalCount: groupTotal,
                        groups: groups,
                        onServerActivated: (server) => _handlePointerAction(
                          () => _activateServer(server, groups),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TvActionBar(hints: hints),
          ],
        ),
        if (_focus.overlay == TvOverlay.subscriptions)
          TvSubscriptionsOverlay(
            subscriptions: _controller.subscriptions,
            focusedRow: showFocus ? _focus.overlayRow : -1,
            expiryLabelFor: (sub) => _expiryLabel(l, sub),
          ),
        if (_focus.overlay == TvOverlay.preset)
          TvPresetOverlay(
            presets: _controller.routingPresets,
            focusedRow: showFocus ? _focus.overlayRow : -1,
            currentPresetId: _resolveCurrentPresetId(),
            targetServerName: selectedServer?.name,
            onBack: () => _handlePointerAction(_onBack),
          ),
      ],
    );
  }

  String? _resolveCurrentPresetId() {
    final selectedName = _controller.selectedName;
    if (selectedName != null) {
      final explicit = _controller.explicitRoutingPresetForServer(selectedName);
      if (explicit != null) return explicit.id;
    }
    return _controller.selectedRoutingPresetId;
  }

  int? _latencyMs() {
    if (_controller.connectionState != VpnConnectionState.connected) {
      return null;
    }
    final raw = _controller.selectedServer?.ping;
    if (raw == null) return null;
    final digits = RegExp(r'\d+').firstMatch(raw)?.group(0);
    return int.tryParse(digits ?? '');
  }
}
