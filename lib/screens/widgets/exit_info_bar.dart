import 'package:flutter/material.dart';

import '../../theme.dart';
import 'slow_marquee_text.dart';

/// Compact one-line bar that mirrors the design's "EXIT … NODE …" strip.
///
/// The bar is split into two equal-width invisible cells. EXIT/NODE labels
/// are anchored to the left edge of their cell, the value sits to the right
/// of the label, and `SlowMarqueeText` auto-scrolls when the value can't fit
/// in the remaining lane.
class ExitInfoBar extends StatelessWidget {
  const ExitInfoBar({super.key, required this.exitIp, required this.node});

  final String exitIp;
  final String node;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final labelStyle = VoidType.mono(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.8,
      color: t.fg3,
    );
    final valueStyle = VoidType.mono(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: t.fg1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ExitInfoCell(
              label: 'EXIT',
              value: exitIp,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ExitInfoCell(
              label: 'NODE',
              value: node,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitInfoCell extends StatelessWidget {
  const _ExitInfoCell({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  static const double _rowHeight = 18;
  static const double _labelGap = 8;

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          Text(label, maxLines: 1, softWrap: false, style: labelStyle),
          const SizedBox(width: _labelGap),
          Expanded(
            child: SlowMarqueeText(
              key: ValueKey('$label:$value'),
              text: value,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
