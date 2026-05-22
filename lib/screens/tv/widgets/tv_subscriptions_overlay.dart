import 'package:flutter/material.dart';

import '../../../core/models/server_subscription.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme.dart';
import '../tv_focus_ring.dart';
import 'tv_overlay_shell.dart';

/// Overlay that lists every imported subscription, focusable by the
/// D-pad. Triggered from MENU on the home screen.
class TvSubscriptionsOverlay extends StatelessWidget {
  const TvSubscriptionsOverlay({
    super.key,
    required this.subscriptions,
    required this.focusedRow,
    required this.expiryLabelFor,
  });

  final List<ServerSubscription> subscriptions;
  final int focusedRow;
  final String Function(ServerSubscription sub) expiryLabelFor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TvOverlayShell(
      title: l.tvOverlaySubscriptionsTitle,
      subtitle: l.tvOverlaySubscriptionsSubtitle,
      child: subscriptions.isEmpty
          ? Center(
              child: Text(
                l.tvOverlaySubscriptionsEmpty,
                style: VoidType.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.8,
                  color: VoidTokens.of(context).fg3,
                ),
              ),
            )
          : ListView.separated(
              itemCount: subscriptions.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final sub = subscriptions[index];
                return TvFocusRing(
                  focused: focusedRow == index,
                  radius: 14,
                  child: _SubscriptionRow(
                    name: sub.name,
                    expiryLabel: expiryLabelFor(sub),
                    nodeCount: sub.servers.length,
                  ),
                );
              },
            ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.name,
    required this.expiryLabel,
    required this.nodeCount,
  });

  final String name;
  final String expiryLabel;
  final int nodeCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 22,
            child: CustomPaint(painter: _OverlayGlyph(color: t.fg1)),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              name.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: VoidType.mono(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: t.fg1,
              ),
            ),
          ),
          const SizedBox(width: 24),
          _Inline(label: l.tvKvExpires.toUpperCase(), value: expiryLabel),
          const SizedBox(width: 24),
          _Inline(
            label: l.tvKvNodes.toUpperCase(),
            value: nodeCount.toString(),
          ),
        ],
      ),
    );
  }
}

class _Inline extends StatelessWidget {
  const _Inline({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: VoidType.mono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
            color: t.fg3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toUpperCase(),
          style: VoidType.mono(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: t.fg1,
          ),
        ),
      ],
    );
  }
}

class _OverlayGlyph extends CustomPainter {
  _OverlayGlyph({required this.color});
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
  bool shouldRepaint(covariant _OverlayGlyph oldDelegate) =>
      oldDelegate.color != color;
}
