import 'package:flutter/material.dart';

import '../../../core/models/server_config.dart';
import '../../../core/tv_region_label.dart';
import '../../../core/vpn_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme.dart';
import '../tv_focus_ring.dart';
import 'tv_node_row.dart';
import 'tv_section_label.dart';
import 'tv_subscription_header.dart';

/// One contiguous group of nodes in the rail (e.g. "MANUAL · 3" or
/// "VOID.NET · PRIMARY · expires 14.06.2026"). Drawn as a thin header
/// stripe above its servers; never focusable itself.
class TvNodeGroup {
  TvNodeGroup({
    required this.title,
    required this.servers,
    this.meta,
    this.showHeaderCard = false,
    this.headerCardSummary,
  });

  /// Section heading (e.g. `MANUAL` / `VOID.NET · PRIMARY`). Rendered in
  /// the same mono / 0.18em style as the section labels above.
  final String title;

  /// Optional small secondary line shown next to the title.
  final String? meta;

  final List<ServerConfig> servers;

  /// When true, the group is rendered with the bigger
  /// [TvSubscriptionHeader] card instead of a thin label — used for the
  /// primary subscription.
  final bool showHeaderCard;
  final TvSubscriptionSummary? headerCardSummary;
}

/// Right half of the TV screen: section header + grouped node list.
class TvRightPanel extends StatefulWidget {
  const TvRightPanel({
    super.key,
    required this.controller,
    required this.focusedRow,
    required this.totalCount,
    required this.groups,
    required this.onServerActivated,
  });

  final VpnController controller;
  final int focusedRow;
  final int totalCount;
  final List<TvNodeGroup> groups;

  /// Pointer-driven activation for a node — same effect as pressing OK
  /// on the D-pad while that row is focused (select + connect).
  final void Function(ServerConfig server) onServerActivated;

  @override
  State<TvRightPanel> createState() => _TvRightPanelState();
}

class _TvRightPanelState extends State<TvRightPanel> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(covariant TvRightPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedRow != widget.focusedRow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureRowVisible(widget.focusedRow);
      });
    }
  }

  GlobalKey _keyFor(int index) {
    return _rowKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _ensureRowVisible(int index) {
    final key = _rowKeys[index];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 220),
      alignment: 0.1,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    final hasNodes = widget.groups.any((g) => g.servers.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvSectionLabel(
          label: l.tvSectionNodes,
          trailing: Text(
            l.tvNodesCount(widget.totalCount),
            style: VoidType.mono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.8,
              color: t.fg3,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: !hasNodes
              ? Center(
                  child: Text(
                    l.tvEmptyNodes,
                    textAlign: TextAlign.center,
                    style: VoidType.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      color: t.fg3,
                    ),
                  ),
                )
              : _buildScroller(t, l),
        ),
      ],
    );
  }

  Widget _buildScroller(VoidTokens t, AppLocalizations l) {
    final children = <Widget>[];
    var rowIndex = 0;

    for (var groupIdx = 0; groupIdx < widget.groups.length; groupIdx++) {
      final group = widget.groups[groupIdx];
      if (group.servers.isEmpty) continue;
      if (groupIdx > 0) {
        children.add(const SizedBox(height: 22));
      }
      if (group.showHeaderCard && group.headerCardSummary != null) {
        final summary = group.headerCardSummary!;
        children.add(
          TvSubscriptionHeader(
            name: summary.name,
            expiryLabel: summary.expiryLabel,
            nodeCount: summary.nodeCount,
            refreshedLabel: summary.refreshedLabel,
          ),
        );
        children.add(const SizedBox(height: 14));
      } else {
        children.add(_GroupHeader(title: group.title, meta: group.meta));
        children.add(const SizedBox(height: 12));
      }
      for (var i = 0; i < group.servers.length; i++) {
        final server = group.servers[i];
        final selected = widget.controller.selectedName == server.name;
        final exit = widget.controller.isExitNode(server.name);
        final preset = widget.controller
            .explicitRoutingPresetForServer(server.name)
            ?.name;
        final index = rowIndex++;
        if (i != 0) children.add(const SizedBox(height: 10));
        children.add(
          KeyedSubtree(
            key: _keyFor(index),
            child: RepaintBoundary(
              child: TvFocusRing(
                focused: widget.focusedRow == index,
                radius: 14,
                child: TvNodeRow(
                  name: server.name,
                  region: TvRegionLabel.regionFor(server.name),
                  protocol: server.protocol,
                  transport: server.transport.wireName
                      .toUpperCase()
                      .replaceAll('_', '-'),
                  pingRaw: server.ping,
                  selected: selected,
                  exit: exit,
                  preset: preset,
                  insecure: server.tlsInsecure,
                  onTap: () => widget.onServerActivated(server),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Horizontal padding gives the focus ring's 1.04 scale + glow
    // shadow somewhere to render without being clipped by the list
    // viewport; `clipBehavior: Clip.none` lets the in-row Stack draw
    // beyond the rounded clip on the focused row.
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      clipBehavior: Clip.none,
      children: children,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, this.meta});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
              color: t.fg2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: t.border)),
          if (meta != null) ...[
            const SizedBox(width: 12),
            Text(
              meta!.toUpperCase(),
              style: VoidType.mono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.8,
                color: t.fg3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Snapshot of the subscription block rendered above its node group.
class TvSubscriptionSummary {
  const TvSubscriptionSummary({
    required this.name,
    required this.expiryLabel,
    required this.nodeCount,
    required this.refreshedLabel,
  });

  final String name;
  final String expiryLabel;
  final int nodeCount;
  final String refreshedLabel;
}
