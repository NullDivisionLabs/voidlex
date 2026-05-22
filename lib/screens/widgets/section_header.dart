import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Collapsible section header — chevron disc + uppercase mono label + count.
/// Mirrors the design's `CollapsibleHeader`.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.count,
    this.expanded = true,
    this.onToggle,
    this.trailing,
    this.toggleOnlyIcon = false,
  });

  final String label;
  final String? count;
  final bool expanded;
  final VoidCallback? onToggle;
  final Widget? trailing;
  final bool toggleOnlyIcon;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        children: [
          _HeaderChevron(expanded: expanded),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: t.fg2,
            ),
          ),
          if (count case final value?) ...[
            const SizedBox(width: 8),
            Text(
              value,
              style: VoidType.mono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: t.fg3,
              ),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
    if (toggleOnlyIcon) {
      return _HeaderToggleRegion(onToggle: onToggle, child: row);
    }
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: row,
    );
  }
}

/// Subscription header with name + meta line + iconic actions on the right.
class VoidSubscriptionHeader extends StatelessWidget {
  const VoidSubscriptionHeader({
    super.key,
    required this.name,
    required this.meta,
    required this.expanded,
    required this.onToggle,
    this.traffic,
    this.actions = const [],
    this.textBuilder,
  });

  final String name;
  final String meta;
  final String? traffic;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> actions;
  final Widget Function(Widget textBlock)? textBuilder;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VoidType.sans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: t.fg1,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          meta.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VoidType.mono(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
            color: t.fg3,
          ),
        ),
        if (traffic case final value?) ...[
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VoidType.mono(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: t.fg3,
            ),
          ),
        ],
      ],
    );
    return _HeaderToggleRegion(
      onToggle: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          children: [
            _HeaderChevron(expanded: expanded),
            const SizedBox(width: 8),
            Expanded(child: textBuilder?.call(textBlock) ?? textBlock),
            for (final a in actions) ...[const SizedBox(width: 6), a],
          ],
        ),
      ),
    );
  }
}

class _HeaderToggleRegion extends StatefulWidget {
  const _HeaderToggleRegion({required this.onToggle, required this.child});

  final VoidCallback? onToggle;
  final Widget child;

  @override
  State<_HeaderToggleRegion> createState() => _HeaderToggleRegionState();
}

class _HeaderToggleRegionState extends State<_HeaderToggleRegion> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTapUp(TapUpDetails _) {
    _setPressed(false);
  }

  void _handleTapDown(TapDownDetails _) {
    _setPressed(widget.onToggle != null);
  }

  void _handleTapCancel() {
    _setPressed(false);
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: AnimatedOpacity(
                  opacity: _pressed ? 1 : 0,
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.fg2.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 34,
          child: Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onToggle,
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderChevron extends StatelessWidget {
  const _HeaderChevron({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.border),
      ),
      child: AnimatedRotation(
        turns: expanded ? 0 : -0.25,
        duration: const Duration(milliseconds: 200),
        child: Icon(Icons.keyboard_arrow_down_rounded, size: 13, color: t.fg2),
      ),
    );
  }
}

/// Round mono button used inside [VoidSubscriptionHeader] actions and similar.
class VoidIconActionButton extends StatefulWidget {
  const VoidIconActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.busy = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;
  final String? tooltip;

  @override
  State<VoidIconActionButton> createState() => _VoidIconActionButtonState();
}

class _VoidIconActionButtonState extends State<VoidIconActionButton> {
  static const Duration _busyIndicatorDuration = Duration(milliseconds: 1500);

  Timer? _busyIndicatorTimer;
  bool _showBusyIndicator = false;

  @override
  void initState() {
    super.initState();
    if (widget.busy) {
      _startBusyIndicator();
    }
  }

  @override
  void didUpdateWidget(covariant VoidIconActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.busy && widget.busy) {
      _startBusyIndicator();
    } else if (oldWidget.busy && !widget.busy) {
      _stopBusyIndicator();
    }
  }

  @override
  void dispose() {
    _busyIndicatorTimer?.cancel();
    super.dispose();
  }

  void _startBusyIndicator() {
    _busyIndicatorTimer?.cancel();
    _showBusyIndicator = true;
    _busyIndicatorTimer = Timer(_busyIndicatorDuration, () {
      if (!mounted) return;
      setState(() {
        _busyIndicatorTimer = null;
        _showBusyIndicator = false;
      });
    });
  }

  void _stopBusyIndicator() {
    _busyIndicatorTimer?.cancel();
    _busyIndicatorTimer = null;
    _showBusyIndicator = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final disabled = widget.onTap == null;
    final showBusy = widget.busy && _showBusyIndicator;
    final btn = Material(
      color: t.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onTap,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.border),
          ),
          child: showBusy
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: t.fg2,
                  ),
                )
              : Icon(widget.icon, size: 12, color: disabled ? t.fg3 : t.fg2),
        ),
      ),
    );
    if (widget.tooltip == null) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}
