import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/models/server_config.dart';
import '../../core/vpn_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import 'node_ping_badge.dart';
import 'node_row.dart';

/// Actions surfaced from the per-row swipe and overflow menu. Public so
/// HomeScreen can drive the dialogs/snackbars without leaking widget state
/// back into the controller.
enum ServerMenuAction {
  toggleFavorite,
  edit,
  toggleExitNode,
  assignRoutingPreset,
  share,
  remove,
}

/// One row in the server list. Wraps [NodeRow] in a horizontal swipe frame
/// (Share / Delete actions) and an overflow menu. Ping updates flow through
/// [NodePingBadge]'s per-server listenable, so a batched flush touching four
/// servers only rebuilds four badges — not every row on the screen.
///
/// The tile takes selected/exit/preset state as **parameters** rather than
/// subscribing internally: those flags change at most once per user gesture,
/// and routing them through the parent's list rebuild keeps the tile widget
/// itself stateless apart from the swipe controller.
class ServerNodeTile extends StatelessWidget {
  const ServerNodeTile({
    super.key,
    required this.controller,
    required this.server,
    required this.isSelected,
    required this.isExitNode,
    required this.hasPreset,
    required this.presetName,
    required this.onTap,
    required this.onMenuAction,
    this.protectSubscriptionActions = false,
  });

  final VpnController controller;
  final ServerConfig server;
  final bool isSelected;
  final bool isExitNode;
  final bool hasPreset;
  final String? presetName;
  final VoidCallback onTap;
  final ValueChanged<ServerMenuAction> onMenuAction;

  /// When true, share and edit are hidden (subscription nodes with provider
  /// protection enabled).
  final bool protectSubscriptionActions;

  static const double _radius = 10;
  static const double _extentRatio = 0.24;
  static const double _openThreshold = 0.19;
  static const double _closeThreshold = 0.07;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return _NodeSwipeFrame(
      radius: _radius,
      extentRatio: _extentRatio,
      openThreshold: _openThreshold,
      closeThreshold: _closeThreshold,
      startColor: t.fg1,
      endColor: t.error,
      startActionEnabled: !protectSubscriptionActions,
      startAction: _SwipeActionButton(
        backgroundColor: t.fg1,
        foregroundColor: t.bg,
        borderColor: t.fg1,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(_radius),
        ),
        icon: Icons.share_rounded,
        onPressed: () => onMenuAction(ServerMenuAction.share),
      ),
      endAction: _SwipeActionButton(
        backgroundColor: t.error,
        foregroundColor: Colors.white,
        borderColor: t.error,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(_radius),
        ),
        icon: Icons.delete_rounded,
        onPressed: () => onMenuAction(ServerMenuAction.remove),
      ),
      child: NodeRow(
        name: server.name,
        protocol: server.protocol,
        transport: server.transport.wireName,
        pingSlot: NodePingBadge(
          controller: controller,
          serverName: server.name,
        ),
        selected: isSelected,
        pinned: server.isPinned,
        exit: isExitNode,
        insecure: server.tlsInsecure,
        preset: hasPreset ? presetName : null,
        onTap: onTap,
        trailing: _NodeMenuButton(
          isPinned: server.isPinned,
          isExit: isExitNode,
          hasPreset: hasPreset,
          hideEdit: protectSubscriptionActions,
          onSelected: onMenuAction,
        ),
      ),
    );
  }
}

class _NodeSwipeFrame extends StatefulWidget {
  const _NodeSwipeFrame({
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
  final ValueChanged<ServerMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    final itemStyle = VoidType.sans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: t.fg1,
    );
    return PopupMenuButton<ServerMenuAction>(
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
      itemBuilder: (_) => <PopupMenuEntry<ServerMenuAction>>[
        if (!hideEdit) ...[
          PopupMenuItem<ServerMenuAction>(
            value: ServerMenuAction.edit,
            child: Text(l.serverMenuEdit, style: itemStyle),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<ServerMenuAction>(
          value: ServerMenuAction.toggleFavorite,
          child: Text(
            isPinned ? l.serverMenuRemoveFavorite : l.serverMenuAddFavorite,
            style: itemStyle,
          ),
        ),
        PopupMenuItem<ServerMenuAction>(
          value: ServerMenuAction.toggleExitNode,
          child: Text(
            isExit ? l.serverMenuResetExitNode : l.serverMenuSetExitNode,
            style: itemStyle,
          ),
        ),
        PopupMenuItem<ServerMenuAction>(
          value: ServerMenuAction.assignRoutingPreset,
          child: Text(l.serverMenuRulePreset, style: itemStyle),
        ),
      ],
    );
  }
}
