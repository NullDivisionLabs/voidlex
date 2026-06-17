import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tv_focus_ring.dart';

/// Extra padding inside TV settings scroll views so [TvFocusRing]'s scale
/// and glow are not clipped by the viewport.
const EdgeInsets tvSettingsFocusScrollPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 10,
);

/// Scroll container for TV settings routes. Uses [Clip.none] and focus inset
/// padding so the D-pad selection ring can draw outside card bounds.
class TvSettingsScrollView extends StatelessWidget {
  const TvSettingsScrollView({
    super.key,
    required this.child,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      clipBehavior: Clip.none,
      padding: padding + tvSettingsFocusScrollPadding,
      child: child,
    );
  }
}

/// Keeps D-pad traversal on the parent card/row instead of embedded controls
/// (switches, popup triggers, chevrons).
class TvSettingsNonFocusTrailing extends StatelessWidget {
  const TvSettingsNonFocusTrailing({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(child: child);
}

/// On TV, vertical D-pad arrows should leave the field and move focus instead
/// of moving the caret / doing nothing.
Widget tvDpadEscapeTextField(Widget textField) {
  return Focus(
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final direction = switch (event.logicalKey) {
        LogicalKeyboardKey.arrowDown => TraversalDirection.down,
        LogicalKeyboardKey.arrowUp => TraversalDirection.up,
        _ => null,
      };
      if (direction == null) return KeyEventResult.ignored;
      final scope = node.nearestScope;
      if (scope == null) return KeyEventResult.ignored;
      scope.unfocus();
      scope.focusInDirection(direction);
      return KeyEventResult.handled;
    },
    child: textField,
  );
}

/// On TV, prevents [RadioGroup] from trapping vertical D-pad navigation.
/// This must wrap the group's child so it handles arrows before the group.
Widget tvDpadEscapeRadioGroup({required bool enabled, required Widget child}) {
  if (!enabled) return child;
  return Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final direction = switch (event.logicalKey) {
        LogicalKeyboardKey.arrowDown => TraversalDirection.down,
        LogicalKeyboardKey.arrowUp => TraversalDirection.up,
        _ => null,
      };
      if (direction == null) return KeyEventResult.ignored;
      final scope = node.nearestScope;
      if (scope == null) return KeyEventResult.ignored;
      scope.focusInDirection(direction);
      return KeyEventResult.handled;
    },
    child: child,
  );
}

/// Compact list row (tunnel settings blocks) with the same TV focus ring as
/// [TvSettingsCard], for toggles inside grouped containers.
class TvCompactFocusRow extends StatefulWidget {
  const TvCompactFocusRow({
    super.key,
    required this.onActivate,
    required this.child,
    this.autofocus = false,
    this.enabled = true,
    this.scaleWhenFocused = 1.04,
    this.scaleAlignment = Alignment.centerLeft,
    this.showGlow = true,
  });

  final VoidCallback onActivate;
  final Widget child;
  final bool autofocus;
  final bool enabled;
  final double scaleWhenFocused;
  final Alignment scaleAlignment;
  final bool showGlow;

  @override
  State<TvCompactFocusRow> createState() => _TvCompactFocusRowState();
}

class _TvCompactFocusRowState extends State<TvCompactFocusRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return TvFocusRing(
      focused: _focused,
      radius: 10,
      scaleWhenFocused: widget.scaleWhenFocused,
      scaleAlignment: widget.scaleAlignment,
      showGlow: widget.showGlow,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          autofocus: widget.autofocus,
          onTap: widget.onActivate,
          onFocusChange: (value) {
            if (_focused == value) return;
            setState(() => _focused = value);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
