import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../core/app_locale.dart';
import '../core/models/server_config.dart';
import '../core/models/server_subscription.dart';
import '../core/routing_preset.dart';
import '../core/server_config_exporter.dart';
import '../core/vpn_controller.dart';
import '../l10n/app_localizations.dart';
import '../l10n/user_message_localizer.dart';
import '../theme.dart';
import 'edit_server_screen.dart';
import 'edit_subscription_screen.dart';
import 'widgets/bottom_dock.dart';
import 'widgets/exit_info_bar.dart';
import 'widgets/fav_card.dart';
import 'widgets/global_proxy_pill.dart';
import 'widgets/node_row.dart';
import 'widgets/section_header.dart';
import 'widgets/status_strip.dart';
import 'widgets/triangle_hub.dart';
import 'widgets/void_dock.dart';
import 'widgets/void_top_bar.dart';

enum _ServerMenuAction {
  toggleFavorite,
  edit,
  toggleExitNode,
  assignRoutingPreset,
  share,
  remove,
}

enum _FavoriteMenuAction { move, remove }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.isDarkTheme,
    required this.onThemeModeChanged,
    required this.localePreference,
    required this.onLocalePreferenceChanged,
  });

  final VpnController controller;
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeModeChanged;
  final AppLocalePreference localePreference;
  final ValueChanged<AppLocalePreference> onLocalePreferenceChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _nodeRadius = 10;
  static const double _nodeSlidableExtentRatio = 0.24;
  static const double _nodeSlidableOpenThreshold = 0.19;
  static const double _nodeSlidableCloseThreshold = 0.07;

  String? _lastShownConnectionError;
  bool _manualNodesCollapsed = false;
  bool _favoritesMoveMode = false;

  VpnController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  // didUpdateWidget intentionally removed: HomeScreen.controller is the
  // singleton VpnController constructed in main() and is never swapped out.
  // The defensive listener-replacement logic that used to live here was
  // dead code reachable only through a hypothetical future refactor — if
  // the controller ever becomes per-route, restore the override.
  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final routingWarning = _controller.consumeRoutingPresetWarning();
    if (routingWarning != null && routingWarning.isNotEmpty) {
      _scheduleBubble(
        () => localizeUserMessage(context, routingWarning),
        guard: () => mounted,
      );
    }

    final isErrorState =
        _controller.connectionState == VpnConnectionState.error;
    if (!isErrorState) {
      _lastShownConnectionError = null;
      return;
    }

    final error = _controller.lastError;
    if (error == null || error.isEmpty || error == _lastShownConnectionError) {
      return;
    }
    _lastShownConnectionError = error;
    _scheduleBubble(
      () => localizeUserMessage(context, error),
      guard: () =>
          mounted &&
          _controller.connectionState == VpnConnectionState.error &&
          _controller.lastError == error,
    );
  }

  /// Queues a snackbar for the next frame, dropping it if `guard` no longer
  /// holds when the frame fires. Used for both routing warnings (no
  /// re-entrancy check needed) and connection errors (where state/lastError
  /// may have already moved on by the time the frame lands).
  void _scheduleBubble(
    String Function() messageBuilder, {
    required bool Function() guard,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!guard()) return;
      _showConnectionErrorBubble(messageBuilder());
    });
  }

  void _showConnectionErrorBubble(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, maxLines: 6, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  // ── Connect / proxy ──────────────────────────────────────────────────
  Future<void> _toggleConnection() async {
    await _controller.toggleConnection();
  }

  Future<void> _disableBridgeMode() async {
    await _controller.clearExitNode();
  }

  // ── Server actions ───────────────────────────────────────────────────
  Future<void> _handleServerMenuAction(
    ServerConfig server,
    _ServerMenuAction action,
  ) async {
    final protectedSubscriptionServer =
        _controller.subscriptionProviderSettings.protectSubscriptions &&
        _isSubscriptionServer(server.name);
    switch (action) {
      case _ServerMenuAction.toggleFavorite:
        await _controller.togglePinned(server.name);
        break;
      case _ServerMenuAction.edit:
        if (protectedSubscriptionServer) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                EditServerScreen(controller: _controller, server: server),
          ),
        );
        break;
      case _ServerMenuAction.toggleExitNode:
        await _controller.toggleExitNode(server.name);
        break;
      case _ServerMenuAction.assignRoutingPreset:
        await _assignRoutingPresetToServer(server);
        break;
      case _ServerMenuAction.share:
        if (protectedSubscriptionServer) return;
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(
          ClipboardData(text: ServerConfigExporter.toXrayJson(server)),
        );
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.homeServerCopied)));
        break;
      case _ServerMenuAction.remove:
        await _controller.removeServer(server.name);
        break;
    }
  }

  Future<void> _removeFavoriteFromFavorites(ServerConfig server) async {
    HapticFeedback.mediumImpact();
    if (_favoritesMoveMode) {
      setState(() => _favoritesMoveMode = false);
    }
    await _controller.removeFavorite(server.name);
  }

  Future<void> _showFavoriteMenu(
    ServerConfig server,
    LongPressStartDetails details,
  ) async {
    HapticFeedback.mediumImpact();
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    final itemStyle = VoidType.sans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: t.fg1,
    );
    final action = await showMenu<_FavoriteMenuAction>(
      context: context,
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.border),
      ),
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        overlay.size.width - details.globalPosition.dx,
        overlay.size.height - details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem<_FavoriteMenuAction>(
          value: _FavoriteMenuAction.move,
          child: Row(
            children: [
              Icon(Icons.drag_indicator_rounded, size: 16, color: t.fg2),
              const SizedBox(width: 8),
              Text(l.favoriteMenuMove, style: itemStyle),
            ],
          ),
        ),
        PopupMenuItem<_FavoriteMenuAction>(
          value: _FavoriteMenuAction.remove,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: t.fg2),
              const SizedBox(width: 8),
              Text(l.delete, style: itemStyle),
            ],
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _FavoriteMenuAction.move:
        setState(() => _favoritesMoveMode = true);
        break;
      case _FavoriteMenuAction.remove:
        await _removeFavoriteFromFavorites(server);
        break;
    }
  }

  bool _isSubscriptionServer(String serverName) {
    return _controller.subscriptions.any(
      (subscription) =>
          subscription.servers.any((server) => server.name == serverName),
    );
  }

  Future<void> _assignRoutingPresetToServer(ServerConfig server) async {
    final assigned =
        _controller.explicitRoutingPresetForServer(server.name) ??
        _controller.routingPresets.first;
    final l = AppLocalizations.of(context);
    final preset = await showDialog<RoutingPreset>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l.homeNodePresetTitle),
          children: [
            for (final item in _controller.routingPresets)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(item),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name)),
                    if (assigned.id == item.id)
                      Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
    if (preset == null) return;
    await _controller.setServerRoutingPreset(server.name, preset.id);
    if (!mounted) return;
    final message = preset.isMain
        ? l.homeNodePresetCleared
        : l.homeNodePresetSelected(preset.name);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editSubscription(ServerSubscription subscription) async {
    if (_controller.subscriptionProviderSettings.protectSubscriptions) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditSubscriptionScreen(
          controller: _controller,
          subscription: subscription,
        ),
      ),
    );
  }

  Future<void> _shareSubscriptionAsEncryptedCode(
    ServerSubscription subscription,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final code = await _controller.encodeSubscriptionAsLink(subscription);
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l.subscriptionShareEncryptedCopied)),
        );
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l.subscriptionShareEncryptedFailed)),
        );
    }
  }

  Future<void> _refreshSubscription(ServerSubscription subscription) async {
    final error = await _controller.refreshSubscription(subscription.id);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error != null
                ? localizeUserMessage(context, error)
                : l.homeSubscriptionUpdated(subscription.name),
          ),
        ),
      );
  }

  Future<void> _confirmAndDeleteSubscription(
    ServerSubscription subscription,
  ) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        return AlertDialog(
          title: Text(l.homeDeleteSubscriptionTitle(subscription.name)),
          content: Text(l.homeDeleteSubscriptionBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogTheme.colorScheme.error,
                foregroundColor: dialogTheme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _controller.deleteSubscription(subscription.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l.homeSubscriptionDeleted(subscription.name))),
      );
  }

  // ── Layout ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // The top status strip and the connect-button hub are split out of the
    // big AnimatedBuilder so that latency scans, server-list edits, and
    // other notifyListeners() callers don't redraw them. They rebuild only
    // on real connect/disconnect/error transitions.
    final t = VoidTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SlidableAutoCloseBehavior(
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final exitServer = _controller.exitServer;
                  return VoidTopBar(
                    version: 'v1.0.1-beta',
                    rightBadge: exitServer != null ? 'BRIDGE MODE' : null,
                    onRightBadgeDisable: exitServer != null
                        ? _disableBridgeMode
                        : null,
                  );
                },
              ),
              ValueListenableBuilder<VpnConnectionState>(
                valueListenable: _controller.connectionStateListenable,
                builder: (context, state, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable:
                        _controller.connectionDurationLabelListenable,
                    builder: (context, durationLabel, _) {
                      return StatusStrip(
                        statusHeading: AppLocalizations.of(
                          context,
                        ).statusStripLabel,
                        label: _statusLabelFor(context, state),
                        tone: _statusToneFor(state),
                        right: _statusRight(state, durationLabel),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 4),
              Center(
                child: ValueListenableBuilder<VpnConnectionState>(
                  valueListenable: _controller.connectionStateListenable,
                  builder: (context, state, _) {
                    final busy = _isBusyState(state);
                    return TriangleHub(
                      state: _hubVisualStateFor(state),
                      onTap: busy ? () {} : _toggleConnection,
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _buildBody(context, t),
                ),
              ),
              VoidDock(
                current: DockItem.hub,
                controller: _controller,
                isDarkTheme: widget.isDarkTheme,
                onThemeModeChanged: widget.onThemeModeChanged,
                localePreference: widget.localePreference,
                onLocalePreferenceChanged: widget.onLocalePreferenceChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VoidTokens t) {
    return Column(
      children: [
        if (_controller.showGlobalProxyButton)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GlobalProxyPill(
              globalActive: _controller.isGlobalProxy,
              enabled: !_controller.isBusy,
              onChanged: (v) async {
                await _controller.setGlobalProxy(v);
              },
            ),
          ),
        if (_controller.showGlobalProxyButton) const SizedBox(height: 14),
        ExitInfoBar(
          exitIp: _controller.isConnected
              ? _exitIpLabel(context)
              : AppLocalizations.of(context).ipPlaceholder,
          node: _nodeLabel(),
        ),
        Expanded(child: _buildList(context, t)),
      ],
    );
  }

  // ── Status helpers ───────────────────────────────────────────────────
  String _exitIpLabel(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ip = _controller.externalIpIfResolved;
    if (ip != null && ip.isNotEmpty) return ip;
    if (_controller.isResolvingExternalIp) return l.ipStatusResolving;
    return l.ipStatusUnavailable;
  }

  String _statusLabelFor(BuildContext context, VpnConnectionState state) {
    final l = AppLocalizations.of(context);
    switch (state) {
      case VpnConnectionState.disconnected:
        return l.statusIdle;
      case VpnConnectionState.preparing:
      case VpnConnectionState.connecting:
        return l.statusNegotiating;
      case VpnConnectionState.connected:
        return l.statusSecure;
      case VpnConnectionState.disconnecting:
        return l.statusClosing;
      case VpnConnectionState.error:
        return l.statusError;
    }
  }

  StatusTone _statusToneFor(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.disconnected:
        return StatusTone.idle;
      case VpnConnectionState.preparing:
      case VpnConnectionState.connecting:
      case VpnConnectionState.disconnecting:
        return StatusTone.busy;
      case VpnConnectionState.connected:
        return StatusTone.ok;
      case VpnConnectionState.error:
        return StatusTone.error;
    }
  }

  String? _statusRight(VpnConnectionState state, String durationLabel) {
    if (state == VpnConnectionState.connected) {
      return durationLabel;
    }
    return '— : —';
  }

  HubVisualState _hubVisualStateFor(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.connected:
        return HubVisualState.on;
      case VpnConnectionState.preparing:
      case VpnConnectionState.connecting:
      case VpnConnectionState.disconnecting:
        return HubVisualState.connecting;
      case VpnConnectionState.error:
        return HubVisualState.error;
      case VpnConnectionState.disconnected:
        return HubVisualState.off;
    }
  }

  bool _isBusyState(VpnConnectionState state) =>
      state == VpnConnectionState.preparing ||
      state == VpnConnectionState.connecting ||
      state == VpnConnectionState.disconnecting;

  String _nodeLabel() {
    if (!_controller.isConnected) return '—';
    final selected = _controller.selectedServer;
    if (selected == null) return '—';
    final parts = selected.name.split(RegExp(r'[.\-_]'));
    if (parts.isEmpty) return '—';
    return parts.first.toUpperCase();
  }

  // ── List body ────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context, VoidTokens t) {
    final l = AppLocalizations.of(context);
    final favorites = _controller.favoriteServers;
    final manual = _controller.manualServers;
    final subs = _controller.subscriptions;

    if (!_controller.hasAnyServers) {
      return _emptyState(t, l);
    }

    // CustomScrollView + slivers replaces the previous outer ListView with a
    // shrinkWrapped ReorderableListView nested inside. The old layout forced
    // every node row to lay out eagerly (NeverScrollableScrollPhysics + a
    // sized child); the sliver-based version lets the manual list and each
    // subscription block paginate lazily.
    final slivers = <Widget>[];
    if (favorites.isNotEmpty) {
      slivers.addAll(_favoritesSlivers(context, t, favorites));
    }
    if (manual.isNotEmpty) {
      slivers.addAll(_manualNodesSlivers(context, l, manual));
    }
    if (subs.isNotEmpty) {
      slivers.addAll(_subscriptionSlivers(context, subs));
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 12)));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
  }

  List<Widget> _favoritesSlivers(
    BuildContext context,
    VoidTokens t,
    List<ServerConfig> favorites,
  ) {
    final l = AppLocalizations.of(context);
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          label: l.sectionFavorites,
          count: favorites.length.toString(),
          expanded: !_controller.favoritesSectionCollapsed,
          onToggle: () => _controller.setFavoritesSectionCollapsed(
            !_controller.favoritesSectionCollapsed,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverToBoxAdapter(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _controller.favoritesSectionCollapsed
              ? const SizedBox.shrink()
              : SizedBox(
                  height: 64,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: favorites.length,
                    onReorderEnd: (_) {
                      if (_favoritesMoveMode) {
                        setState(() => _favoritesMoveMode = false);
                      }
                    },
                    onReorder: (oldIndex, newIndex) async {
                      await _controller.reorderFavoriteServers(
                        oldIndex,
                        newIndex,
                      );
                      if (mounted && _favoritesMoveMode) {
                        setState(() => _favoritesMoveMode = false);
                      }
                    },
                    proxyDecorator: _reorderProxyDecorator,
                    itemBuilder: (context, index) {
                      final s = favorites[index];
                      return Padding(
                        key: ValueKey('favorite:${s.name}'),
                        padding: EdgeInsets.only(
                          right: index < favorites.length - 1 ? 8 : 0,
                        ),
                        child: _favoriteCard(server: s, index: index),
                      );
                    },
                  ),
                ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
    ];
  }

  Widget _favoriteCard({required ServerConfig server, required int index}) {
    final card = FavCard(
      name: _shortName(server.name),
      protocol: server.protocol,
      ping: NodePingTone.shortLabel(server.ping),
      pingTone: NodePingTone.fromRaw(server.ping),
      selected: _controller.selectedName == server.name,
      onTap: _favoritesMoveMode
          ? null
          : () => _controller.selectServer(server.name),
      onLongPressStart: _favoritesMoveMode
          ? null
          : (details) => _showFavoriteMenu(server, details),
    );

    if (!_favoritesMoveMode) return card;
    return ReorderableDragStartListener(
      index: index,
      child: Listener(
        onPointerUp: (_) {
          if (_favoritesMoveMode) {
            setState(() => _favoritesMoveMode = false);
          }
        },
        onPointerCancel: (_) {
          if (_favoritesMoveMode) {
            setState(() => _favoritesMoveMode = false);
          }
        },
        child: card,
      ),
    );
  }

  List<Widget> _manualNodesSlivers(
    BuildContext context,
    AppLocalizations l,
    List<ServerConfig> manual,
  ) {
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: SectionHeader(
          label: l.sectionNodes,
          count: l.sectionNodesManualCount(manual.length),
          expanded: !_manualNodesCollapsed,
          onToggle: () =>
              setState(() => _manualNodesCollapsed = !_manualNodesCollapsed),
          toggleOnlyIcon: true,
          trailing: _ScanButton(
            busy: _controller.isScanningLatency,
            onTap: _controller.isScanningLatency
                ? null
                : _controller.scanManualLatencies,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];

    if (!_manualNodesCollapsed) {
      slivers.add(
        SliverReorderableList(
          itemCount: manual.length,
          onReorder: (oldIndex, newIndex) {
            _controller.reorderServers(oldIndex, newIndex);
          },
          proxyDecorator: _reorderProxyDecorator,
          itemBuilder: (context, index) {
            final server = manual[index];
            return Padding(
              key: ValueKey('manual:${server.name}'),
              padding: EdgeInsets.only(
                bottom: index < manual.length - 1 ? 6 : 12,
              ),
              child: ReorderableDelayedDragStartListener(
                index: index,
                child: _buildSwipeableNode(server),
              ),
            );
          },
        ),
      );
    }
    return slivers;
  }

  List<Widget> _subscriptionSlivers(
    BuildContext context,
    List<ServerSubscription> subscriptions,
  ) {
    return [
      SliverReorderableList(
        itemCount: subscriptions.length,
        onReorder: (oldIndex, newIndex) {
          _controller.reorderSubscriptions(oldIndex, newIndex);
        },
        proxyDecorator: _reorderProxyDecorator,
        itemBuilder: (context, index) {
          final sub = subscriptions[index];
          return KeyedSubtree(
            key: ValueKey('subscription:${sub.id}'),
            child: _subscriptionBlock(sub, index),
          );
        },
      ),
    ];
  }

  Widget _subscriptionBlock(ServerSubscription sub, int reorderIndex) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSubscriptionHeader(sub, reorderIndex),
        if (!_controller.isSubscriptionCollapsed(sub.id))
          _subscriptionNodeList(sub),
      ],
    );
  }

  Widget _emptyState(VoidTokens t, AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 36, color: t.fg3),
            const SizedBox(height: 12),
            Text(
              l.homeNoNodesTitle,
              style: VoidType.mono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: t.fg2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.homeNoNodesSubtitle,
              textAlign: TextAlign.center,
              style: VoidType.sans(
                fontSize: 13,
                color: t.fg2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reorderProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final tt = Curves.easeInOut.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.02 * tt,
          child: Material(
            color: Colors.transparent,
            elevation: 8 * tt,
            borderRadius: BorderRadius.circular(10),
            shadowColor: Colors.black38,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionHeader(ServerSubscription sub, int reorderIndex) {
    final l = AppLocalizations.of(context);
    final isScanning = _controller.isScanningSubscription(sub.id);
    final isRefreshing = _controller.isRefreshingSubscription(sub.id);
    final protectSubscriptions =
        _controller.subscriptionProviderSettings.protectSubscriptions;
    final collapsed = _controller.isSubscriptionCollapsed(sub.id);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: VoidSubscriptionHeader(
        name: sub.name,
        meta: l.subscriptionMetaLine(
          _subscriptionExpiryLabel(l, sub),
          sub.servers.length,
        ),
        traffic: _subscriptionTrafficLabel(sub),
        expanded: !collapsed,
        onToggle: () =>
            _controller.setSubscriptionCollapsed(sub.id, !collapsed),
        textBuilder: (textBlock) => ReorderableDelayedDragStartListener(
          index: reorderIndex,
          child: textBlock,
        ),
        actions: [
          VoidIconActionButton(
            icon: Icons.refresh_rounded,
            busy: isRefreshing,
            tooltip: l.tooltipUpdateSubscription,
            onTap: isRefreshing || isScanning
                ? null
                : () => _refreshSubscription(sub),
          ),
          VoidIconActionButton(
            icon: Icons.network_ping_rounded,
            busy: isScanning,
            tooltip: l.tooltipScanPing,
            onTap: isScanning || isRefreshing
                ? null
                : () => _controller.scanSubscriptionLatencies(sub.id),
          ),
          _SubMenuButton(
            protectSubscriptions: protectSubscriptions,
            onShareEncrypted: () => _shareSubscriptionAsEncryptedCode(sub),
            onEdit: () => _editSubscription(sub),
            onDelete: () => _confirmAndDeleteSubscription(sub),
          ),
        ],
      ),
    );
  }

  Widget _subscriptionNodeList(ServerSubscription sub) {
    final protectSubscriptions =
        _controller.subscriptionProviderSettings.protectSubscriptions;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(sub.servers.length, (index) {
          final server = sub.servers[index];
          return Padding(
            key: ValueKey('${sub.id}:${server.id}'),
            padding: EdgeInsets.only(
              bottom: index < sub.servers.length - 1 ? 6 : 0,
            ),
            child: _buildSwipeableNode(
              server,
              protectSubscriptionActions: protectSubscriptions,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSwipeableNode(
    ServerConfig server, {
    bool protectSubscriptionActions = false,
  }) {
    final t = VoidTokens.of(context);
    final isSelected = _controller.selectedName == server.name;
    final isExitNode = _controller.isExitNode(server.name);
    final hasPreset = _controller.hasExplicitRoutingPresetForServer(
      server.name,
    );
    final preset = _controller.explicitRoutingPresetForServer(server.name);

    final frame = _NodeSwipeFrame(
      key: ValueKey('slidable:${server.name}'),
      radius: _nodeRadius,
      extentRatio: _nodeSlidableExtentRatio,
      openThreshold: _nodeSlidableOpenThreshold,
      closeThreshold: _nodeSlidableCloseThreshold,
      startColor: t.fg1,
      endColor: t.error,
      startActionEnabled: !protectSubscriptionActions,
      startAction: _SwipeActionButton(
        backgroundColor: t.fg1,
        foregroundColor: t.bg,
        borderColor: t.fg1,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(_nodeRadius),
        ),
        icon: Icons.share_rounded,
        onPressed: () =>
            _handleServerMenuAction(server, _ServerMenuAction.share),
      ),
      endAction: _SwipeActionButton(
        backgroundColor: t.error,
        foregroundColor: Colors.white,
        borderColor: t.error,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(_nodeRadius),
        ),
        icon: Icons.delete_rounded,
        onPressed: () =>
            _handleServerMenuAction(server, _ServerMenuAction.remove),
      ),
      child: NodeRow(
        name: server.name,
        protocol: server.protocol,
        transport: server.transport.wireName,
        ping: NodePingTone.shortLabel(server.ping),
        pingTone: NodePingTone.fromRaw(server.ping),
        selected: isSelected,
        pinned: server.isPinned,
        exit: isExitNode,
        insecure: server.tlsInsecure,
        preset: hasPreset ? preset?.name : null,
        onTap: () => _controller.selectServer(server.name),
        trailing: _NodeMenuButton(
          isPinned: server.isPinned,
          isExit: isExitNode,
          hasPreset: hasPreset,
          hideEdit: protectSubscriptionActions,
          onSelected: (action) => _handleServerMenuAction(server, action),
        ),
      ),
    );
    // Fade-in on first build of each row. Was `flutter_animate`'s
    // `.fadeIn(duration: 180.ms)` — replaced with a one-shot
    // TweenAnimationBuilder so the flutter_animate dependency can be
    // dropped from pubspec.yaml entirely.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: frame,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  String _subscriptionExpiryLabel(AppLocalizations l, ServerSubscription sub) {
    final expiresAt = sub.expiresAt;
    if (expiresAt == null) return l.subscriptionExpiryUnknown;
    final local = expiresAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final date = '$day.$month.${local.year}';
    return expiresAt.isBefore(DateTime.now().toUtc())
        ? l.subscriptionExpired(date)
        : l.subscriptionExpires(date);
  }

  String _subscriptionTrafficLabel(ServerSubscription sub) {
    final used = _formatTrafficBytes(sub.trafficUsedBytes ?? 0);
    final limit = sub.trafficLimitBytes == null
        ? 'unlimited'
        : _formatTrafficBytes(sub.trafficLimitBytes!);
    return '$used/$limit';
  }

  String _formatTrafficBytes(int bytes) {
    if (bytes <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var unitIndex = 0;
    var value = bytes.toDouble();
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final precision = unitIndex == 0 || value >= 100
        ? 0
        : value >= 10
        ? 1
        : 2;
    return '${_trimTrailingZeroes(value.toStringAsFixed(precision))} '
        '${units[unitIndex]}';
  }

  String _trimTrailingZeroes(String raw) {
    if (!raw.contains('.')) return raw;
    return raw.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _shortName(String name) {
    final segments = name.split(RegExp(r'\.'));
    if (segments.length >= 2) return segments.first;
    return name;
  }
}

class _NodeSwipeFrame extends StatefulWidget {
  const _NodeSwipeFrame({
    super.key,
    required this.radius,
    required this.extentRatio,
    required this.openThreshold,
    required this.closeThreshold,
    required this.startColor,
    required this.endColor,
    this.startActionEnabled = true,
    required this.startAction,
    required this.endAction,
    required this.child,
  });

  final double radius;
  final double extentRatio;
  final double openThreshold;
  final double closeThreshold;
  final Color startColor;
  final Color endColor;
  final bool startActionEnabled;
  final Widget startAction;
  final Widget endAction;
  final Widget child;

  @override
  State<_NodeSwipeFrame> createState() => _NodeSwipeFrameState();
}

class _NodeSwipeFrameState extends State<_NodeSwipeFrame>
    with SingleTickerProviderStateMixin {
  static const double _dragScale = 0.5;

  late final SlidableController _slidableController;
  late final Listenable _visuals;
  double _dragExtent = 0;
  double _dragStartRatio = 0;

  @override
  void initState() {
    super.initState();
    _slidableController = SlidableController(this);
    _visuals = Listenable.merge([
      _slidableController.animation,
      _slidableController.actionPaneType,
    ]);
  }

  @override
  void dispose() {
    _slidableController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NodeSwipeFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startActionEnabled && !widget.startActionEnabled) {
      _slidableController.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    return AnimatedBuilder(
      animation: _visuals,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _actionFillColor(),
            borderRadius: radius,
          ),
          child: ClipRRect(
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.start,
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: Slidable(
                controller: _slidableController,
                enabled: false,
                groupTag: 'servers',
                closeOnScroll: true,
                startActionPane: widget.startActionEnabled
                    ? ActionPane(
                        motion: const BehindMotion(),
                        extentRatio: widget.extentRatio,
                        openThreshold: widget.openThreshold,
                        closeThreshold: widget.closeThreshold,
                        children: [widget.startAction],
                      )
                    : null,
                endActionPane: ActionPane(
                  motion: const BehindMotion(),
                  extentRatio: widget.extentRatio,
                  openThreshold: widget.openThreshold,
                  closeThreshold: widget.closeThreshold,
                  children: [widget.endAction],
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _actionFillColor() {
    if (_slidableController.animation.value <= 0.001) {
      return Colors.transparent;
    }
    if (!widget.startActionEnabled &&
        _slidableController.actionPaneType.value == ActionPaneType.start) {
      return Colors.transparent;
    }
    return switch (_slidableController.actionPaneType.value) {
      ActionPaneType.start => widget.startColor,
      ActionPaneType.end => widget.endColor,
      ActionPaneType.none => Colors.transparent,
    };
  }

  void _handleDragStart(DragStartDetails details) {
    final width = _dragWidth;
    _dragStartRatio = _slidableController.ratio;
    _dragExtent = _dragStartRatio * width;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final width = _dragWidth;
    _dragExtent += (details.primaryDelta ?? 0) * _dragScale;
    final maxRatio = widget.startActionEnabled ? widget.extentRatio : 0.0;
    final nextRatio = (_dragExtent / width)
        .clamp(-widget.extentRatio, maxRatio)
        .toDouble();
    _slidableController.ratio = nextRatio;
  }

  void _handleDragEnd(DragEndDetails details) {
    final ratio = _slidableController.ratio;
    final absRatio = ratio.abs();
    final wasOpen = _dragStartRatio.abs() > widget.closeThreshold;
    final shouldOpen = wasOpen
        ? absRatio > widget.closeThreshold
        : absRatio >= widget.openThreshold;

    if (shouldOpen && ratio != 0) {
      _slidableController.openTo(widget.extentRatio * ratio.sign);
    } else {
      _slidableController.close();
    }
  }

  double get _dragWidth {
    final width = context.size?.width ?? 1;
    return width <= 0 ? 1 : width;
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.borderRadius,
    required this.icon,
    required this.onPressed,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final BorderRadius borderRadius;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: borderRadius,
          ),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () {
              onPressed();
              Slidable.of(context)?.close();
            },
            child: Center(child: Icon(icon, color: foregroundColor, size: 18)),
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return VoidIconActionButton(
      icon: Icons.network_ping_rounded,
      busy: busy,
      tooltip: AppLocalizations.of(context).tooltipScanPing,
      onTap: onTap,
    );
  }
}

class _NodeMenuButton extends StatelessWidget {
  const _NodeMenuButton({
    required this.isPinned,
    required this.isExit,
    required this.hasPreset,
    required this.hideEdit,
    required this.onSelected,
  });

  final bool isPinned;
  final bool isExit;
  final bool hasPreset;
  final bool hideEdit;
  final ValueChanged<_ServerMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    final itemStyle = VoidType.sans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: t.fg1,
    );
    return PopupMenuButton<_ServerMenuAction>(
      tooltip: '',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.border),
      ),
      onSelected: onSelected,
      icon: Icon(Icons.more_horiz_rounded, color: t.fg2, size: 16),
      itemBuilder: (_) => <PopupMenuEntry<_ServerMenuAction>>[
        if (!hideEdit) ...[
          PopupMenuItem<_ServerMenuAction>(
            value: _ServerMenuAction.edit,
            child: Text(l.serverMenuEdit, style: itemStyle),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<_ServerMenuAction>(
          value: _ServerMenuAction.toggleFavorite,
          child: Text(
            isPinned ? l.serverMenuRemoveFavorite : l.serverMenuAddFavorite,
            style: itemStyle,
          ),
        ),
        PopupMenuItem<_ServerMenuAction>(
          value: _ServerMenuAction.toggleExitNode,
          child: Text(
            isExit ? l.serverMenuResetExitNode : l.serverMenuSetExitNode,
            style: itemStyle,
          ),
        ),
        PopupMenuItem<_ServerMenuAction>(
          value: _ServerMenuAction.assignRoutingPreset,
          child: Text(l.serverMenuRulePreset, style: itemStyle),
        ),
      ],
    );
  }
}

enum _SubMenuAction { shareEncrypted, edit, delete }

class _SubMenuButton extends StatelessWidget {
  const _SubMenuButton({
    required this.protectSubscriptions,
    required this.onShareEncrypted,
    required this.onEdit,
    required this.onDelete,
  });

  final bool protectSubscriptions;
  final VoidCallback onShareEncrypted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    final itemStyle = VoidType.sans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: t.fg1,
    );
    return PopupMenuButton<_SubMenuAction>(
      tooltip: '',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.border),
      ),
      onSelected: (action) {
        switch (action) {
          case _SubMenuAction.shareEncrypted:
            onShareEncrypted();
            break;
          case _SubMenuAction.edit:
            onEdit();
            break;
          case _SubMenuAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<_SubMenuAction>>[
        PopupMenuItem<_SubMenuAction>(
          value: _SubMenuAction.shareEncrypted,
          child: Text(l.subscriptionShareEncrypted, style: itemStyle),
        ),
        const PopupMenuDivider(),
        if (!protectSubscriptions) ...[
          PopupMenuItem<_SubMenuAction>(
            value: _SubMenuAction.edit,
            child: Text(l.serverMenuEdit, style: itemStyle),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<_SubMenuAction>(
          value: _SubMenuAction.delete,
          child: Text(l.delete, style: itemStyle),
        ),
      ],
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface,
          shape: BoxShape.circle,
          border: Border.all(color: t.border),
        ),
        child: Icon(Icons.more_horiz_rounded, size: 12, color: t.fg2),
      ),
    );
  }
}
