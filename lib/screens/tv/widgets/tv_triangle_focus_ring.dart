import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Triangle-shaped dashed echo painted around [TriangleHub] when the hub
/// holds D-pad focus. Slow rotation animation matches the JSX
/// `tvDashSlide`. When the hub loses focus the ring fades out instead of
/// jumping — keeps the transition calm on TV displays.
class TvTriangleFocusRing extends StatefulWidget {
  const TvTriangleFocusRing({
    super.key,
    required this.size,
    required this.focused,
    this.padding = 30,
  });

  /// Width of the wrapped triangle hub (same value passed to
  /// `TriangleHub.size`). The painted echo will extend [padding] pixels
  /// outward on each side.
  final double size;
  final bool focused;
  final double padding;

  @override
  State<TvTriangleFocusRing> createState() => _TvTriangleFocusRingState();
}

class _TvTriangleFocusRingState extends State<TvTriangleFocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );

  @override
  void initState() {
    super.initState();
    if (widget.focused) _slide.repeat();
  }

  @override
  void didUpdateWidget(covariant TvTriangleFocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focused && !_slide.isAnimating) {
      _slide.repeat();
    } else if (!widget.focused && _slide.isAnimating) {
      _slide.stop();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final width = widget.size + widget.padding * 2;
    final height = widget.size * 0.92 + widget.padding * 2;
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: widget.focused ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          scale: widget.focused ? 1.04 : 1,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) => CustomPaint(
                    painter: _TriangleEchoPainter(
                      color: t.fg1,
                      phase: _slide.value,
                      padding: widget.padding,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TriangleEchoPainter extends CustomPainter {
  _TriangleEchoPainter({
    required this.color,
    required this.phase,
    required this.padding,
  });

  final Color color;
  final double phase;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _trianglePath(size);
    final glowFill = Paint()
      ..color = color.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawPath(path, glowFill);

    final glowRing = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(path, glowRing);

    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _drawDashed(canvas, path, paint, dashLength: 6, gapLength: 8, phase: phase);
  }

  Path _trianglePath(Size size) {
    final innerW = size.width - padding * 2;
    final innerH = size.height - padding * 2;
    final cx = size.width / 2;
    final corners = <Offset>[
      Offset(cx, padding + innerH * 0.06),
      Offset(padding + innerW * 0.94, padding + innerH * 0.94),
      Offset(padding + innerW * 0.06, padding + innerH * 0.94),
    ];
    final r = math.min(innerW, innerH) * 0.045;
    return _roundedPolygon(corners, r);
  }

  Path _roundedPolygon(List<Offset> points, double r) {
    final path = Path();
    final n = points.length;
    for (var i = 0; i < n; i++) {
      final prev = points[(i - 1 + n) % n];
      final curr = points[i];
      final next = points[(i + 1) % n];
      final v1 = (prev - curr);
      final v2 = (next - curr);
      final v1n = v1 / v1.distance;
      final v2n = v2 / v2.distance;
      final p1 = curr + v1n * r;
      final p2 = curr + v2n * r;
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
    required double phase,
  }) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final segment = dashLength + gapLength;
    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var offset = -phase * segment;
    while (offset < 0) {
      offset += totalLength;
    }
    var consumed = 0.0;
    for (final metric in metrics) {
      var local = offset - consumed;
      while (local < metric.length) {
        final start = math.max(0.0, local);
        final end = math.min(metric.length, local + dashLength);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        local += segment;
      }
      consumed += metric.length;
      offset = (offset % totalLength);
      // After processing each subpath, fall through; rounded triangle
      // produces a single subpath so this loop typically runs once.
      break;
    }
  }

  @override
  bool shouldRepaint(covariant _TriangleEchoPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.phase != phase ||
      oldDelegate.padding != padding;
}
