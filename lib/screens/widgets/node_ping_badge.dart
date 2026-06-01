import 'package:flutter/material.dart';

import '../../core/vpn_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import 'node_row.dart';

/// How the ping signal + number are laid out for different surfaces.
enum NodePingBadgeStyle {
  /// Right side of [NodeRow] — compact signal bars + digits + optional MS.
  row,

  /// Bottom-right of [FavCard] — number only.
  fav,

  /// TV node list — large digits with MS suffix.
  tv,
}

/// Subscribes to [VpnController.pingListenableFor] for a specific server, so
/// a batched flush touching four servers only rebuilds four badges — not the
/// whole list.
class NodePingBadge extends StatelessWidget {
  const NodePingBadge({
    super.key,
    required this.controller,
    required this.serverName,
    this.style = NodePingBadgeStyle.row,
  });

  final VpnController controller;
  final String serverName;
  final NodePingBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: controller.pingListenableFor(serverName),
      builder: (context, raw, _) {
        final tone = NodePingTone.fromRaw(raw);
        final label = NodePingTone.shortLabel(raw);
        final t = VoidTokens.of(context);
        final color = tone.colorIn(t);
        return switch (style) {
          NodePingBadgeStyle.row => _RowPing(
            label: label,
            color: color,
            showMs: RegExp(r'\d').hasMatch(label),
          ),
          NodePingBadgeStyle.fav => Text(
            label,
            style: VoidType.mono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          NodePingBadgeStyle.tv => _TvPing(label: label, color: color),
        };
      },
    );
  }
}

class _RowPing extends StatelessWidget {
  const _RowPing({
    required this.label,
    required this.color,
    required this.showMs,
  });

  final String label;
  final Color color;
  final bool showMs;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: const Size(11, 11),
          painter: NodeSignalPainter(color: color),
        ),
        const SizedBox(width: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              style: VoidType.mono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (showMs) ...[
              const SizedBox(width: 2),
              Text(
                AppLocalizations.of(context).pingMsSuffix.trimLeft(),
                style: VoidType.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: t.fg3,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TvPing extends StatelessWidget {
  const _TvPing({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final showMs = RegExp(r'\d').hasMatch(label);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CustomPaint(
          size: const Size(16, 14),
          painter: NodeSignalPainter(color: color, tv: true),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: VoidType.mono(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: color,
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
    );
  }
}

/// Shared signal bars for mobile and TV ping badges.
class NodeSignalPainter extends CustomPainter {
  NodeSignalPainter({required this.color, this.tv = false});

  final Color color;
  final bool tv;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = color;
    final dim = Paint()..color = color.withValues(alpha: 0.55);
    final faint = Paint()..color = color.withValues(alpha: 0.25);
    if (tv) {
      canvas.drawRect(const Rect.fromLTWH(0, 10, 3, 4), base);
      canvas.drawRect(const Rect.fromLTWH(4, 6, 3, 8), base);
      canvas.drawRect(const Rect.fromLTWH(8, 3, 3, 11), dim);
      canvas.drawRect(const Rect.fromLTWH(12, 0, 3, 14), faint);
      return;
    }
    canvas.drawRect(Rect.fromLTWH(0, 7, 2, 4), base);
    canvas.drawRect(Rect.fromLTWH(3, 4, 2, 7), base);
    canvas.drawRect(Rect.fromLTWH(6, 2, 2, 9), dim);
    canvas.drawRect(Rect.fromLTWH(9, 0, 2, 11), faint);
  }

  @override
  bool shouldRepaint(covariant NodeSignalPainter old) =>
      old.color != color || old.tv != tv;
}
