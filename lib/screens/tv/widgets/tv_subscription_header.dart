import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Collapsed subscription bar above the node list. Static in v1 — the
/// MENU button opens the full overlay with the actionable list.
class TvSubscriptionHeader extends StatelessWidget {
  const TvSubscriptionHeader({
    super.key,
    required this.name,
    required this.expiryLabel,
    required this.nodeCount,
    required this.refreshedLabel,
  });

  final String name;
  final String expiryLabel;
  final int nodeCount;
  final String refreshedLabel;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 16,
            child: CustomPaint(painter: _SubscriptionGlyph(color: t.fg2)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: VoidType.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: t.fg1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${expiryLabel.toUpperCase()} · $nodeCount NODES',
                  overflow: TextOverflow.ellipsis,
                  style: VoidType.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.2,
                    color: t.fg3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            refreshedLabel.toUpperCase(),
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.8,
              color: t.fg2,
            ),
          ),
          const SizedBox(width: 18),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: t.fg3,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '<MENU> ON REMOTE',
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.8,
              color: t.fg2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionGlyph extends CustomPainter {
  _SubscriptionGlyph({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height * 0.10)
      ..lineTo(size.width * 0.95, size.height * 0.90)
      ..lineTo(size.width * 0.05, size.height * 0.90)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SubscriptionGlyph oldDelegate) =>
      oldDelegate.color != color;
}
