import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Tiny 24-bar throughput chart that visualises a per-second history of
/// tunnel throughput pushed up from the native VPN service.
///
/// The widget itself is stateless — it just renders whatever sample
/// list the parent passes. Animation comes "for free": when
/// [VpnController] notifies a new sample every second the parent
/// rebuilds with a one-position shifted [history], so the bars appear
/// to slide left. The most recent sample drives the labelled rate
/// readout above the bars.
///
/// History units are bytes/sec. The chart auto-scales to its own peak
/// so a quiet link still shows visible motion while a saturated link
/// caps at the bar height.
class TvThroughputSparkline extends StatelessWidget {
  const TvThroughputSparkline({
    super.key,
    required this.label,
    required this.history,
    required this.live,
    this.barCount = 24,
  });

  /// Section label drawn top-left ("DOWN" / "UP" via l10n).
  final String label;

  /// Per-second samples in bytes/sec, oldest → newest. The widget
  /// renders the last [barCount] entries; if the list is shorter, the
  /// leading slots render flat.
  final List<double> history;

  /// True while the tunnel is connected. Drives colour (live = full
  /// foreground, idle = muted) and the formatted label.
  final bool live;

  final int barCount;

  /// Same compact format used in the foreground-notification line.
  /// Inlined here so the widget stays decoupled from the controller's
  /// helper for tests.
  static String _formatBps(double bps) {
    if (!bps.isFinite || bps <= 0) return '0 B/s';
    if (bps < 1000) return '${bps.toInt()} B/s';
    final kb = bps / 1000;
    if (kb < 1000) return '${kb.toStringAsFixed(1)} KB/s';
    final mb = kb / 1000;
    return '${mb.toStringAsFixed(2)} MB/s';
  }

  /// Returns the trailing [barCount] samples, left-padded with zeros
  /// if the history is shorter (e.g. session just started).
  List<double> _windowed() {
    if (history.length >= barCount) {
      return history.sublist(history.length - barCount);
    }
    final pad = barCount - history.length;
    return <double>[for (var i = 0; i < pad; i++) 0.0, ...history];
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final window = _windowed();
    final current = window.isEmpty ? 0.0 : window.last;
    // Auto-scale to the visible peak so a slow link still moves.
    // Floor at 1 KB/s so a near-idle window doesn't amplify
    // single-byte ticks into full-height bars.
    final peak = math.max(1024.0, window.fold<double>(0, math.max));
    final bars = <double>[
      for (final v in window)
        (v / peak).clamp(0.0, 1.0).toDouble(),
    ];
    final barColor = live ? t.fg1 : t.fg3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
              const Spacer(),
              Text(
                live ? _formatBps(current) : '— MB/s',
                style: VoidType.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.fg1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < bars.length; i++) ...[
                  if (i != 0) const SizedBox(width: 2),
                  Expanded(
                    child: _AnimatedBar(
                      heightFactor: live ? math.max(bars[i], 0.04) : 0.12,
                      color: barColor.withValues(alpha: live ? 0.85 : 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Each bar is wrapped in an AnimatedFractionallySizedBox so the slide
/// from one second's sample to the next looks like a smooth motion
/// rather than a hard step.
class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.heightFactor, required this.color});

  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: heightFactor, end: heightFactor),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return FractionallySizedBox(
          heightFactor: value,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }
}
