import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../core/app_locale.dart';
import '../core/models/server_config.dart';
import '../core/models/server_subscription.dart';
import '../core/pending_deep_link.dart';
import '../core/routing_preset.dart';
import '../core/server_config_exporter.dart';
import '../core/subscription_client_identity.dart';
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
import 'widgets/node_ping_badge.dart';
import 'widgets/section_header.dart';
import 'widgets/server_node_tile.dart';
import 'widgets/status_strip.dart';
import 'widgets/triangle_hub.dart';
import 'widgets/void_dock.dart';
import 'widgets/void_top_bar.dart';

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
  String? _lastShownConnectionError;
  bool _deepLinkDialogVisible = false;
  bool _manualNodesCollapsed = false;
  bool _favoritesMoveMode = false;
  bool _subscriptionsMoveMode = false;

  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchActive = false;
      _searchQuery = '';
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _handleControllerChanged() {
    final routingWarning = _controller.consumeRoutingPresetWarning();
    if (routingWarning != null && routingWarning.isNotEmpty) {
      _scheduleBubble(
        () => localizeUserMessage(context, routingWarning),
        guard: () => mounted,
      );
    }

    final deepLinkNotice = _controller.consumeDeepLinkNotice();
    if (deepLinkNotice != null && deepLinkNotice.isNotEmpty) {
      _scheduleBubble(
        () => localizeUserMessage(context, deepLinkNotice),
        guard: () => mounted,
      );
    }

    final pendingDeepLink = _controller.pendingDeepLink;
    if (pendingDeepLink != null && !_deepLinkDialogVisible) {
      _deepLinkDialogVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _deepLinkDialogVisible = false;
          return;
        }
        unawaited(_showDeepLinkConsentDialog(pendingDeepLink));
      });
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

  String _deepLinkConsentDescription(
    AppLocalizations l,
    DeepLinkActionKind kind,
  ) {
    return switch (kind) {
      DeepLinkActionKind.importServers => l.deepLinkConsentImportServers,
      DeepLinkActionKind.importRuleset => l.deepLinkConsentImportRuleset,
      DeepLinkActionKind.importSubscription =>
        l.deepLinkConsentImportSubscription,
    };
  }

  Future<void> _showDeepLinkConsentDialog(PendingDeepLink request) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(l.deepLinkConsentTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_deepLinkConsentDescription(l, request.kind)),
                const SizedBox(height: 12),
                Text(
                  l.deepLinkConsentSourceLabel,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  request.displayUrl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                if (request.isInsecureHttp) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.deepLinkConsentHttpWarning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.deepLinkConsentConfirm),
            ),
          ],
        );
      },
    );
    _deepLinkDialogVisible = false;
    if (!mounted) return;
    if (confirmed == true) {
      await _controller.confirmPendingDeepLink();
    } else {
      _controller.cancelPendingDeepLink();
    }
  }

  // ── Connect / proxy ──────────────────────────────────────────────────
  Future<void> _toggleConnection() async {
    await _controller.toggleConnection();
  }

  Future<void> _disableBridgeMode() async {
    await _controller.clearExitNode();
  }

  Future<void> _selectServer(String name) async {
    final error = await _controller.selectServer(name);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(localizeUserMessage(context, error))),
        );
    }
  }

  // ── Server actions ───────────────────────────────────────────────────
  Future<void> _handleServerMenuAction(
    ServerConfig server,
    ServerMenuAction action,
  ) async {
    final protectedSubscriptionServer =
        _controller.subscriptionProviderSettings.protectSubscriptions &&
        _isSubscriptionServer(server.name);
    switch (action) {
      case ServerMenuAction.toggleFavorite:
        await _controller.togglePinned(server.name);
        break;
      case ServerMenuAction.edit:
        if (protectedSubscriptionServer) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                EditServerScreen(controller: _controller, server: server),
          ),
        );
        break;
      case ServerMenuAction.toggleExitNode:
        final error = await _controller.toggleExitNode(server.name);
        if (error != null && mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(localizeUserMessage(context, error))),
            );
        }
        break;
      case ServerMenuAction.assignRoutingPreset:
        await _assignRoutingPresetToServer(server);
        break;
      case ServerMenuAction.share:
        if (protectedSubscriptionServer) return;
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(
          ClipboardData(text: ServerConfigExporter.toServerUrl(server)),
        );
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.homeServerCopied)));
        break;
      case ServerMenuAction.remove:
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
              ListenableBuilder(
                listenable: _controller.homeListRevisionListenable,
                builder: (context, _) {
                  final exitServer = _controller.exitServer;
                  return VoidTopBar(
                    version: 'v${SubscriptionClientIdentity.appVersion}',
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
                child: ListenableBuilder(
                  listenable: _controller.homeListRevisionListenable,
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
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.showExitNodeInfoBar) {
              return const SizedBox.shrink();
            }
            return ExitInfoBar(
              exitIp: _controller.isConnected
                  ? _exitIpLabel(context)
                  : AppLocalizations.of(context).ipPlaceholder,
              node: _nodeLabel(),
              downloadSpeed: VpnController.formatBpsLabel(
                _controller.downloadBps,
              ),
              uploadSpeed: VpnController.formatBpsLabel(_controller.uploadBps),
            );
          },
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
    final hasSubServers = subs.any((s) => s.servers.isNotEmpty);
    final hasNodes = manual.isNotEmpty || hasSubServers;
    final slivers = <Widget>[];
    if (favorites.isNotEmpty) {
      slivers.addAll(_favoritesSlivers(context, t, favorites));
    }
    if (_searchActive) {
      slivers.addAll(_searchSlivers(context, l, t, manual, subs));
    } else {
      if (hasNodes) {
        slivers.addAll(_manualNodesSlivers(context, l, manual, hasNodes));
      }
      if (subs.isNotEmpty) {
        slivers.addAll(_subscriptionSlivers(context, subs));
      }
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
      pingSlot: NodePingBadge(
        controller: _controller,
        serverName: server.name,
        style: NodePingBadgeStyle.fav,
      ),
      selected: _controller.selectedName == server.name,
      onTap: _favoritesMoveMode
          ? null
          : () => _selectServer(server.name),
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
    bool hasNodes,
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SearchButton(onTap: hasNodes ? _openSearch : null),
              const SizedBox(width: 6),
              ValueListenableBuilder<bool>(
                valueListenable: _controller.isScanningLatencyListenable,
                builder: (context, scanning, _) {
                  return _ScanButton(
                    busy: scanning,
                    onTap: scanning ? null : _controller.scanManualLatencies,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];

    if (!_manualNodesCollapsed && manual.isNotEmpty) {
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
                child: _buildNodeTile(server),
              ),
            );
          },
        ),
      );
    }
    return slivers;
  }

  List<Widget> _searchSlivers(
    BuildContext context,
    AppLocalizations l,
    VoidTokens t,
    List<ServerConfig> manual,
    List<ServerSubscription> subs,
  ) {
    final q = _searchQuery.trim().toLowerCase();
    final protectSubscriptions =
        _controller.subscriptionProviderSettings.protectSubscriptions;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              const SizedBox(width: 6),
              Icon(Icons.search_rounded, size: 14, color: t.fg3),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  cursorColor: t.fg1,
                  style: VoidType.sans(
                    fontSize: 13,
                    color: t.fg1,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: l.searchNodesHint,
                    hintStyle: VoidType.sans(
                      fontSize: 13,
                      color: t.fg3,
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _CloseSearchButton(onTap: _closeSearch),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 10)),
    ];

    // Filter once per build (cheap; runs when query/composition changes).
    // Result rows do their own per-server ping subscription, so the search
    // list does not need a global tick listener.
    final all = <ServerConfig>[
      ...manual,
      for (final sub in subs) ..._controller.visibleSubscriptionServers(sub),
    ];
    final results = q.isEmpty
        ? all
        : all.where((s) => s.name.toLowerCase().contains(q)).toList();

    if (results.isEmpty && q.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l.searchNoResults,
                style: VoidType.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: t.fg3,
                ),
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final server = results[index];
            return Padding(
              key: ValueKey('search:${server.name}'),
              padding: EdgeInsets.only(
                bottom: index < results.length - 1 ? 6 : 12,
              ),
              child: _buildNodeTile(
                server,
                protectSubscriptionActions:
                    protectSubscriptions && _isSubscriptionServer(server.name),
              ),
            );
          },
          childCount: results.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
    return slivers;
  }

  List<Widget> _subscriptionSlivers(
    BuildContext context,
    List<ServerSubscription> subscriptions,
  ) {
    if (_subscriptionsMoveMode) {
      // Move mode: only headers are shown (collapsed), reordered as a single
      // SliverReorderableList. The expansion state from regular mode is left
      // untouched in the controller, so leaving move mode restores everything.
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
              key: ValueKey('subscription-move:${sub.id}'),
              child: ReorderableDelayedDragStartListener(
                index: index,
                child: _buildMoveModeHeader(sub),
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: _moveModeFooter()),
      ];
    }

    // Normal mode: each subscription is rendered as adjacent slivers — the
    // header is a single box and the nodes live in their own SliverList so
    // off-screen rows never lay out. This is what makes scrolling stay
    // smooth even with 1000+ nodes across many subscriptions.
    final protectSubscriptions =
        _controller.subscriptionProviderSettings.protectSubscriptions;
    final slivers = <Widget>[];
    for (final sub in subscriptions) {
      slivers.addAll(_subscriptionSliversFor(sub, protectSubscriptions));
    }
    return slivers;
  }

  List<Widget> _subscriptionSliversFor(
    ServerSubscription sub,
    bool protectSubscriptions,
  ) {
    final collapsed = _controller.isSubscriptionCollapsed(sub.id);
    final out = <Widget>[
      SliverToBoxAdapter(
        key: ValueKey('subscription-header:${sub.id}'),
        child: _buildSubscriptionHeader(sub),
      ),
    ];
    if (collapsed) return out;

    final visible = _controller.visibleSubscriptionServers(sub);
    if (visible.isEmpty) return out;

    out.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    out.add(
      SliverList(
        key: ValueKey('subscription-list:${sub.id}'),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final server = visible[index];
            return Padding(
              key: ValueKey('${sub.id}:${server.id}'),
              padding: EdgeInsets.only(
                bottom: index < visible.length - 1 ? 6 : 0,
              ),
              child: _buildNodeTile(
                server,
                protectSubscriptionActions: protectSubscriptions,
              ),
            );
          },
          childCount: visible.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
    return out;
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

  void _enterSubscriptionsMoveMode() {
    HapticFeedback.mediumImpact();
    setState(() => _subscriptionsMoveMode = true);
  }

  void _exitSubscriptionsMoveMode() {
    if (!_subscriptionsMoveMode) return;
    setState(() => _subscriptionsMoveMode = false);
  }

  Widget _buildMoveModeHeader(ServerSubscription sub) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: VoidSubscriptionHeader(
        name: sub.name,
        meta: l.subscriptionMetaLine(
          _subscriptionExpiryLabel(l, sub),
          _controller.visibleSubscriptionServers(sub).length,
        ),
        traffic: _subscriptionTrafficLabel(sub),
        expanded: false,
        onToggle: _exitSubscriptionsMoveMode,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: VoidTokens.of(context).fg2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moveModeFooter() {
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Center(
        child: Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _exitSubscriptionsMoveMode,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                l.done.toUpperCase(),
                style: VoidType.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: t.fg1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionHeader(ServerSubscription sub) {
    final l = AppLocalizations.of(context);
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
          _controller.visibleSubscriptionServers(sub).length,
        ),
        traffic: _subscriptionTrafficLabel(sub),
        expanded: !collapsed,
        onToggle: () =>
            _controller.setSubscriptionCollapsed(sub.id, !collapsed),
        textBuilder: (textBlock) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: _controller.subscriptions.length > 1
              ? _enterSubscriptionsMoveMode
              : null,
          child: textBlock,
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _controller.subscriptionScanTickListenable,
            builder: (context, tick, _) {
              final isScanning = _controller.isScanningSubscription(sub.id);
              return VoidIconActionButton(
                icon: Icons.refresh_rounded,
                busy: isRefreshing,
                tooltip: l.tooltipUpdateSubscription,
                onTap: isRefreshing || isScanning
                    ? null
                    : () => _refreshSubscription(sub),
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: _controller.subscriptionScanTickListenable,
            builder: (context, tick, _) {
              final isScanning = _controller.isScanningSubscription(sub.id);
              return VoidIconActionButton(
                icon: Icons.network_ping_rounded,
                busy: isScanning,
                tooltip: l.tooltipScanPing,
                onTap: isScanning || isRefreshing
                    ? null
                    : () => _controller.scanSubscriptionLatencies(sub.id),
              );
            },
          ),
          _SubMenuButton(
            protectSubscriptions: protectSubscriptions,
            hideNaServers: sub.hideNaServers,
            onShareEncrypted: () => _shareSubscriptionAsEncryptedCode(sub),
            onEdit: () => _editSubscription(sub),
            onToggleHideNa: () => _controller.setSubscriptionHideNaServers(
              sub.id,
              !sub.hideNaServers,
            ),
            onDelete: () => _confirmAndDeleteSubscription(sub),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTile(
    ServerConfig server, {
    bool protectSubscriptionActions = false,
  }) {
    final isSelected = _controller.selectedName == server.name;
    final isExitNode = _controller.isExitNode(server.name);
    final preset = _controller.explicitRoutingPresetForServer(server.name);
    return ServerNodeTile(
      key: ValueKey('tile:${server.name}'),
      controller: _controller,
      server: server,
      isSelected: isSelected,
      isExitNode: isExitNode,
      hasPreset: preset != null,
      presetName: preset?.name,
      protectSubscriptionActions: protectSubscriptionActions,
      onTap: () => _selectServer(server.name),
      onMenuAction: (action) => _handleServerMenuAction(server, action),
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

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return VoidIconActionButton(
      icon: Icons.search_rounded,
      tooltip: AppLocalizations.of(context).tooltipSearchNodes,
      onTap: onTap,
    );
  }
}

class _CloseSearchButton extends StatelessWidget {
  const _CloseSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VoidIconActionButton(
      icon: Icons.close_rounded,
      tooltip: AppLocalizations.of(context).tooltipCloseSearch,
      onTap: onTap,
    );
  }
}

enum _SubMenuAction { shareEncrypted, edit, toggleHideNa, delete }

class _SubMenuButton extends StatelessWidget {
  const _SubMenuButton({
    required this.protectSubscriptions,
    required this.hideNaServers,
    required this.onShareEncrypted,
    required this.onEdit,
    required this.onToggleHideNa,
    required this.onDelete,
  });

  final bool protectSubscriptions;
  final bool hideNaServers;
  final VoidCallback onShareEncrypted;
  final VoidCallback onEdit;
  final VoidCallback onToggleHideNa;
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
          case _SubMenuAction.toggleHideNa:
            onToggleHideNa();
            break;
          case _SubMenuAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<_SubMenuAction>>[
        // Encrypted-link sharing is hidden from the UI for now; the underlying
        // encode/share plumbing is kept intact for future use.
        if (!protectSubscriptions) ...[
          PopupMenuItem<_SubMenuAction>(
            value: _SubMenuAction.edit,
            child: Text(l.serverMenuEdit, style: itemStyle),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<_SubMenuAction>(
          value: _SubMenuAction.toggleHideNa,
          child: Text(
            hideNaServers ? l.subscriptionShowNa : l.subscriptionHideNa,
            style: itemStyle,
          ),
        ),
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
