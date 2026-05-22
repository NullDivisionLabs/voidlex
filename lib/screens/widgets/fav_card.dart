import 'package:flutter/material.dart';

import '../../theme.dart';
import 'node_row.dart';

class FavCard extends StatelessWidget {
  const FavCard({
    super.key,
    required this.name,
    required this.protocol,
    required this.ping,
    required this.pingTone,
    this.selected = false,
    this.onTap,
    this.onLongPressStart,
    this.trailing,
  });

  final String name;
  final String protocol;
  final String ping;
  final NodePingTone pingTone;
  final bool selected;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final pingColor = pingTone.colorIn(t);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: onLongPressStart,
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 120,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? t.fg1 : t.border,
                width: selected ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VoidType.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.fg1,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      trailing!,
                    ],
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      protocol.toUpperCase(),
                      style: VoidType.mono(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: t.fg3,
                      ),
                    ),
                    Text(
                      ping,
                      style: VoidType.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pingColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FavPlaceholder extends StatelessWidget {
  const FavPlaceholder({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: DottedBorderBox(
        color: t.borderStrong,
        radius: 10,
        child: Container(
          width: 96,
          height: 64,
          alignment: Alignment.center,
          child: Icon(Icons.add_rounded, color: t.fg3, size: 18),
        ),
      ),
    );
  }
}

/// Lightweight dashed-border container — used for the favorites placeholder
/// without a full custom painter.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashWidth = 4.0;
    final dashSpace = 4.0;
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      var distance = 0.0;
      while (distance < m.length) {
        final next = distance + dashWidth;
        canvas.drawPath(m.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
