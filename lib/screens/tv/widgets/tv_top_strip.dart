import 'package:flutter/material.dart';

import '../../../core/vpn_controller.dart';
import '../../../theme.dart';

/// Top status bar of the TV layout — branding on the left, live network /
/// latency / time stats on the right. Mirrors the JSX `TVTopStrip`.
class TvTopStrip extends StatelessWidget {
  const TvTopStrip({
    super.key,
    required this.connectionState,
    required this.latencyMs,
    required this.now,
    this.versionLabel = 'TV · v1.0.1-beta',
  });

  final VpnConnectionState connectionState;
  final int? latencyMs;
  final DateTime now;
  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(60, 20, 60, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 20,
            child: CustomPaint(painter: _TopStripGlyph(color: t.fg1)),
          ),
          const SizedBox(width: 18),
          Text(
            'VOIDTUNNEL',
            style: VoidType.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.9,
              color: t.fg1,
            ),
          ),
          const SizedBox(width: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              versionLabel,
              style: VoidType.mono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.2,
                color: t.fg3,
              ),
            ),
          ),
          const Spacer(),
          _StatBlock(
            label: 'LATENCY',
            value:
                connectionState == VpnConnectionState.connected &&
                    latencyMs != null
                ? '$latencyMs MS'
                : '— MS',
          ),
          const SizedBox(width: 36),
          _StatBlock(label: 'TIME', value: _formatTime(now)),
        ],
      ),
    );
  }

  static String _formatTime(DateTime moment) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(moment.hour)}:${two(moment.minute)}';
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: VoidType.mono(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
            color: t.fg3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: VoidType.mono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
            color: t.fg1,
          ),
        ),
      ],
    );
  }
}

class _TopStripGlyph extends CustomPainter {
  _TopStripGlyph({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height * 0.10)
      ..lineTo(size.width * 0.92, size.height * 0.90)
      ..lineTo(size.width * 0.08, size.height * 0.90)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TopStripGlyph oldDelegate) =>
      oldDelegate.color != color;
}
