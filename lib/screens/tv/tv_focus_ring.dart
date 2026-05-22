import 'package:flutter/material.dart';

import '../../theme.dart';

/// Reusable focus indicator for the TV layout.
///
/// Mirrors the design's `TVFocus` JSX wrapper: scale up by 4%, paint a
/// thin border ring, and add a soft glow shadow. Pure presentation — the
/// `focused` flag is driven by [TvFocusController] in the parent tree.
class TvFocusRing extends StatelessWidget {
  const TvFocusRing({
    super.key,
    required this.focused,
    required this.child,
    this.radius = 12,
    this.scaleWhenFocused = 1.04,
  });

  final bool focused;
  final Widget child;
  final double radius;
  final double scaleWhenFocused;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final ringColor = focused ? t.fg1 : Colors.transparent;
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: focused ? scaleWhenFocused : 1.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: ringColor, width: 2),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: t.fg1.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: -6,
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
