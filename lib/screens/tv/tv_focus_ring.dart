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
    this.scaleAlignment = Alignment.center,
    this.showGlow = true,
  });

  final bool focused;
  final Widget child;
  final double radius;
  final double scaleWhenFocused;
  final Alignment scaleAlignment;

  /// When false, only the focus border is drawn — no outer glow. Use on
  /// dense lists so adjacent rows do not visually bleed into each other.
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final ringColor = focused ? t.fg1 : Colors.transparent;
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: scaleAlignment,
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
                  boxShadow: focused && showGlow
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
