import 'package:flutter/material.dart';

import '../../theme.dart';

class StatusStrip extends StatefulWidget {
  const StatusStrip({
    super.key,
    required this.label,
    required this.tone,
    this.right,
    this.statusHeading,
  });

  final String label;
  final StatusTone tone;
  final String? right;
  final String? statusHeading;

  @override
  State<StatusStrip> createState() => _StatusStripState();
}

enum StatusTone { idle, busy, ok, error }

class _StatusStripState extends State<StatusStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _maybeStart();
  }

  @override
  void didUpdateWidget(StatusStrip old) {
    super.didUpdateWidget(old);
    _maybeStart();
  }

  void _maybeStart() {
    if (widget.tone == StatusTone.busy) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final dot = switch (widget.tone) {
      StatusTone.idle => t.fg3,
      StatusTone.busy => t.accent,
      StatusTone.ok => t.accent,
      StatusTone.error => t.error,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final opacity = widget.tone == StatusTone.busy
                  ? 0.5 + 0.5 * (1 - _pulse.value)
                  : 1.0;
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dot.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            widget.statusHeading ?? 'STATUS',
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.4,
              color: t.fg2,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VoidType.mono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: t.fg1,
              ),
            ),
          ),
          const Spacer(),
          if (widget.right != null)
            Text(
              widget.right!,
              style: VoidType.mono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.4,
                color: t.fg3,
              ),
            ),
        ],
      ),
    );
  }
}
