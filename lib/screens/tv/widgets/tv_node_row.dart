import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../widgets/node_row.dart' show NodePingTone;

/// Single row in the TV node list. Mirrors the JSX `TVNodeRow` —
/// triangle indicator + name/region + protocol/transport pills + EXIT /
/// preset chips + signal bars + large ping number.
class TvNodeRow extends StatelessWidget {
  const TvNodeRow({
    super.key,
    required this.name,
    required this.region,
    required this.protocol,
    required this.transport,
    required this.pingRaw,
    this.selected = false,
    this.exit = false,
    this.preset,
    this.insecure = false,
    this.onTap,
  });

  final String name;
  final String region;
  final String protocol;
  final String transport;
  final String pingRaw;
  final bool selected;
  final bool exit;
  final String? preset;
  final bool insecure;

  /// Pointer fallback for the same activation the D-pad's OK triggers.
  /// On a phone in dev preview this is the primary interaction; on a
  /// real Google TV with a touch remote it acts as a discoverable cue.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final tone = NodePingTone.fromRaw(pingRaw);
    final toneColor = tone.colorIn(t);
    final ping = NodePingTone.shortLabel(pingRaw);
    final showMs = RegExp(r'\d').hasMatch(ping);

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: selected ? t.surfaceAlt : t.surface,
        border: Border.all(color: selected ? t.fg1 : t.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 24,
            child: CustomPaint(
              size: const Size(24, 22),
              painter: _NodeRowGlyph(color: t.fg1, filled: selected),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: VoidType.mono(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: t.fg1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  region,
                  overflow: TextOverflow.ellipsis,
                  style: VoidType.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.8,
                    color: t.fg3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (protocol.isNotEmpty) _Pill(text: protocol),
                if (transport.isNotEmpty) _Pill(text: transport),
                if (insecure) _Chip(text: 'INSECURE', tone: _ChipTone.warn),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 220,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (exit) const _Chip(text: 'EXIT'),
                if (preset != null && preset!.isNotEmpty)
                  _Chip(text: preset!.toUpperCase()),
                if (!exit && (preset == null || preset!.isEmpty))
                  Text(
                    '—',
                    style: VoidType.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      color: t.fg3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomPaint(
                  size: const Size(16, 14),
                  painter: _SignalBars(color: toneColor),
                ),
                const SizedBox(width: 10),
                Text(
                  ping,
                  style: VoidType.mono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: toneColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (showMs) ...[
                  const SizedBox(width: 4),
                  Text(
                    'MS',
                    style: VoidType.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      color: t.fg3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: body,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: VoidType.mono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
          color: t.fg2,
        ),
      ),
    );
  }
}

enum _ChipTone { strong, warn }

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.tone = _ChipTone.strong});
  final String text;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final fill = tone == _ChipTone.warn ? t.error : t.fg1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: VoidType.mono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
          color: t.bg,
        ),
      ),
    );
  }
}

class _NodeRowGlyph extends CustomPainter {
  _NodeRowGlyph({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, h * 0.12)
      ..lineTo(w * 0.92, h * 0.88)
      ..lineTo(w * 0.08, h * 0.88)
      ..close();
    if (filled) {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: filled ? 1.0 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NodeRowGlyph oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

class _SignalBars extends CustomPainter {
  _SignalBars({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = color;
    final dim = Paint()..color = color.withValues(alpha: 0.55);
    final faint = Paint()..color = color.withValues(alpha: 0.25);
    canvas.drawRect(const Rect.fromLTWH(0, 10, 3, 4), base);
    canvas.drawRect(const Rect.fromLTWH(4, 6, 3, 8), base);
    canvas.drawRect(const Rect.fromLTWH(8, 3, 3, 11), dim);
    canvas.drawRect(const Rect.fromLTWH(12, 0, 3, 14), faint);
  }

  @override
  bool shouldRepaint(covariant _SignalBars oldDelegate) =>
      oldDelegate.color != color;
}
