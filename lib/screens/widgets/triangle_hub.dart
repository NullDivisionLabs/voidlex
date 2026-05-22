import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// The main connect button — a rounded triangle that morphs across three
/// states (off / connecting / on). Geometry and animations follow
/// `triangle-hub.jsx` from the design canvas.
class TriangleHub extends StatefulWidget {
  const TriangleHub({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 184,
    this.label,
    this.subLabel,
    this.enabled = true,
  });

  final HubVisualState state;
  final VoidCallback onTap;
  final double size;
  final String? label;
  final String? subLabel;
  final bool enabled;

  @override
  State<TriangleHub> createState() => _TriangleHubState();
}

enum HubVisualState { off, connecting, on, error }

class _TriangleHubState extends State<TriangleHub>
    with TickerProviderStateMixin {
  late final AnimationController _scan;
  late final AnimationController _rot;
  late final AnimationController _corner;
  late final AnimationController _haloPulse;
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _rot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _corner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _haloPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(TriangleHub old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _syncAnimations();
  }

  void _syncAnimations() {
    final connecting = widget.state == HubVisualState.connecting;
    final on = widget.state == HubVisualState.on;
    if (connecting) {
      _scan.repeat();
      _rot.repeat();
      _corner.repeat(reverse: true);
      _blink.repeat();
    } else {
      _scan.stop();
      _rot.stop();
      _corner.stop();
      _blink.stop();
    }
    if (on) {
      _haloPulse.repeat(reverse: true);
    } else {
      _haloPulse.stop();
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    _rot.dispose();
    _corner.dispose();
    _haloPulse.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final w = widget.size;
    final h = widget.size * 0.92;

    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: w,
        height: h + 16,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (widget.state == HubVisualState.on)
                AnimatedBuilder(
                  animation: _haloPulse,
                  builder: (context, _) {
                    final v = 0.85 + 0.15 * _haloPulse.value;
                    return Container(
                      width: w * 1.2 * v,
                      height: h * 1.2 * v,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [t.haloOn, Colors.transparent],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    );
                  },
                ),
              SizedBox(
                width: w,
                height: h,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_scan, _rot, _corner]),
                  builder: (context, _) => CustomPaint(
                    painter: _TrianglePainter(
                      tokens: t,
                      state: widget.state,
                      scan: _scan.value,
                      rotation: _rot.value,
                      cornerPulse: _corner.value,
                    ),
                  ),
                ),
              ),
              // Centre the label column on the triangle's geometric centroid
              // (~y = 0.65·h for an upright triangle). `top: 0.30·h` makes
              // the available space symmetric around that line so the column
              // ends up at the centroid regardless of state — keeps OFF /
              // CONNECTING / ON visually aligned.
              Positioned.fill(
                top: h * 0.30,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The forward-slash glyph leans right, so its ink mass
                    // sits a few pixels right of its bounding box centre. A
                    // small leftward shift makes it look optically centred.
                    Transform.translate(
                      offset: Offset(-w * 0.013, 0),
                      child: Text(
                        '//',
                        style: VoidType.mono(
                          fontSize: w * 0.20,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: -1,
                          color: _glyphColor(t),
                        ),
                      ),
                    ),
                    SizedBox(height: w * 0.05),
                    Text(
                      widget.label ?? _label,
                      textAlign: TextAlign.center,
                      style: VoidType.mono(
                        fontSize: w * 0.044,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: _glyphColor(t),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedBuilder(
                      animation: _blink,
                      builder: (context, _) {
                        final dots = widget.state == HubVisualState.connecting
                            ? '.' * (1 + (_blink.value * 4).floor() % 3)
                            : '';
                        return Text(
                          (widget.subLabel ?? _subLabel) + dots,
                          textAlign: TextAlign.center,
                          style: VoidType.mono(
                            fontSize: w * 0.036,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.6,
                            color: _glyphColor(t).withValues(alpha: 0.6),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _glyphColor(VoidTokens t) {
    if (widget.state == HubVisualState.on) {
      return t.isDark ? const Color(0xFF0A0B0C) : const Color(0xFFF4F5F6);
    }
    return t.fg1;
  }

  String get _label {
    switch (widget.state) {
      case HubVisualState.off:
        return 'TAP · TO · VOID';
      case HubVisualState.connecting:
        return 'ESTABLISHING';
      case HubVisualState.on:
        return 'TUNNEL · ACTIVE';
      case HubVisualState.error:
        return 'TAP · TO · RETRY';
    }
  }

  String get _subLabel {
    switch (widget.state) {
      case HubVisualState.off:
        return 'IDLE';
      case HubVisualState.connecting:
        return 'NEGOTIATING';
      case HubVisualState.on:
        return 'SECURE';
      case HubVisualState.error:
        return 'ERROR';
    }
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({
    required this.tokens,
    required this.state,
    required this.scan,
    required this.rotation,
    required this.cornerPulse,
  });

  final VoidTokens tokens;
  final HubVisualState state;
  final double scan;
  final double rotation;
  final double cornerPulse;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final corners = [
      Offset(cx, h * 0.06),
      Offset(w * 0.94, h * 0.94),
      Offset(w * 0.06, h * 0.94),
    ];
    final r = math.min(w, h) * 0.045;
    final path = _roundedPolygon(corners, r);

    // OFF: faint horizontal grid hint inside the triangle
    if (state == HubVisualState.off) {
      canvas.save();
      canvas.clipPath(path);
      final gridPaint = Paint()
        ..color = tokens.fg1.withValues(alpha: tokens.isDark ? 0.06 : 0.08)
        ..strokeWidth = 1;
      for (var i = 1; i <= 7; i++) {
        final y = h * (i / 8);
        canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      }
      canvas.restore();
    }

    // Fill — visible only on connecting (faint) / on (full).
    if (state == HubVisualState.connecting || state == HubVisualState.on) {
      final fillColor = state == HubVisualState.on
          ? tokens.accent
          : tokens.accentMid;
      final opacity = state == HubVisualState.on ? 1.0 : 0.10;
      canvas.drawPath(
        path,
        Paint()..color = fillColor.withValues(alpha: opacity),
      );
    }

    // Connecting: scanning sweep lines
    if (state == HubVisualState.connecting) {
      canvas.save();
      canvas.clipPath(path);
      final scanPaint = Paint()
        ..color = tokens.accentMid.withValues(alpha: 0.85)
        ..strokeWidth = 1.5;
      final y1 = h * scan;
      canvas.drawLine(Offset(0, y1), Offset(w, y1), scanPaint);
      final scanSlowPaint = Paint()
        ..color = tokens.accentMid.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      final y2 = h * ((scan + 0.4) % 1.0);
      canvas.drawLine(Offset(0, y2), Offset(w, y2), scanSlowPaint);
      canvas.restore();
    }

    // Stroke
    final strokeColor = switch (state) {
      HubVisualState.off => tokens.fg1.withValues(alpha: 0.55),
      HubVisualState.connecting => tokens.accentMid,
      HubVisualState.on => tokens.accent,
      HubVisualState.error => tokens.error,
    };
    final strokeWidth = state == HubVisualState.off ? 1.25 : 1.75;
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );

    // Connecting: rotating dashed arc
    if (state == HubVisualState.connecting) {
      final centerY = h * 0.6;
      final radius = math.min(w, h) * 0.32;
      canvas.save();
      canvas.translate(cx, centerY);
      canvas.rotate(rotation * 2 * math.pi);
      canvas.translate(-cx, -centerY);
      final dashPaint = Paint()
        ..color = tokens.accentMid.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final rect = Rect.fromCircle(
        center: Offset(cx, centerY),
        radius: radius,
      );
      _drawDashedCircle(canvas, rect, dashPaint, dashLength: 2, gapLength: 6);
      canvas.restore();
    }

    // Connecting: corner crosshairs blinking
    if (state == HubVisualState.connecting) {
      final cornerOpacity = 0.6 + 0.4 * cornerPulse;
      final cornerPaint = Paint()
        ..color = tokens.accentMid.withValues(alpha: cornerOpacity);
      for (final corner in corners) {
        canvas.drawRect(
          Rect.fromCenter(center: corner, width: 8, height: 8),
          cornerPaint,
        );
      }
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final radius = rect.width / 2;
    final circumference = 2 * math.pi * radius;
    final segment = dashLength + gapLength;
    final steps = (circumference / segment).floor();
    final sweep = (dashLength / circumference) * 2 * math.pi;
    final gap = (gapLength / circumference) * 2 * math.pi;
    var start = 0.0;
    for (var i = 0; i < steps; i++) {
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep + gap;
    }
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

  @override
  bool shouldRepaint(covariant _TrianglePainter old) {
    return old.tokens != tokens ||
        old.state != state ||
        old.scan != scan ||
        old.rotation != rotation ||
        old.cornerPulse != cornerPulse;
  }
}
