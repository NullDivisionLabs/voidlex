import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../theme.dart';

/// Tiny 24-bar throughput chart. v1 has no real RX/TX stream from the
/// native VPN service (see TODO(tv-traffic)), so the bar heights come from
/// a deterministic `sin/cos` curve seeded per-direction. When `live` is
/// false the bars freeze at 20% height in the muted foreground colour;
/// when true they slide by an internal `Ticker` at 8 Hz.
class TvThroughputSparkline extends StatefulWidget {
  const TvThroughputSparkline({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.live,
    this.seed = 0,
    this.barCount = 24,
  });

  final String label;
  final String valueLabel;
  final bool live;
  final int seed;
  final int barCount;

  @override
  State<TvThroughputSparkline> createState() => _TvThroughputSparklineState();
}

class _TvThroughputSparklineState extends State<TvThroughputSparkline>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  double _phase = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.live) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant TvThroughputSparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.live && _ticker.isActive) {
      _ticker.stop();
      _phase = 0;
      setState(() {});
    }
  }

  void _onTick(Duration elapsed) {
    // 8 Hz refresh: only rebuild when ~125 ms has accumulated to avoid
    // doing a setState on every vsync frame.
    if (elapsed - _last < const Duration(milliseconds: 125)) return;
    _last = elapsed;
    setState(() => _phase += 0.4);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final bars = List<double>.generate(widget.barCount, (i) {
      final x =
          (math.sin(i * 0.9 + widget.seed + _phase) + 1) / 2;
      final y =
          (math.cos(i * 0.5 + widget.seed * 1.3 + _phase * 0.6) + 1) / 2;
      final mixed = math.max(0.12, x * 0.6 + y * 0.4);
      return widget.live ? mixed : mixed * 0.2;
    });
    final barColor = widget.live ? t.fg1 : t.fg3;
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
                widget.label,
                style: VoidType.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: t.fg3,
                ),
              ),
              const Spacer(),
              Text(
                widget.valueLabel,
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
                    child: FractionallySizedBox(
                      heightFactor: bars[i],
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor.withValues(
                            alpha: widget.live ? 0.85 : 0.4,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
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
