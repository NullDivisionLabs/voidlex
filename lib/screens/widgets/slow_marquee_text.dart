import 'package:flutter/material.dart';

class SlowMarqueeText extends StatefulWidget {
  const SlowMarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.pixelsPerSecond = 26,
  });

  final String text;
  final TextStyle style;
  final double pixelsPerSecond;

  @override
  State<SlowMarqueeText> createState() => _SlowMarqueeTextState();
}

class _SlowMarqueeTextState extends State<SlowMarqueeText>
    with SingleTickerProviderStateMixin {
  // ScrollController is allocated lazily so rows whose text fits never pay
  // for one. The marquee AnimationController is allocated even later — only
  // after layout reports actual overflow inside _tryStartMarquee.
  final ScrollController _scroll = ScrollController();
  AnimationController? _marquee;
  double? _lastViewportWidth;
  bool _marqueeSetupScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMarqueeSetup();
  }

  @override
  void didUpdateWidget(covariant SlowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.pixelsPerSecond != widget.pixelsPerSecond) {
      _stopMarquee();
      _scheduleMarqueeSetup();
    }
  }

  @override
  void dispose() {
    _stopMarquee();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 0.0;
        if (_lastViewportWidth == null ||
            (viewportWidth - _lastViewportWidth!).abs() > 0.5) {
          _lastViewportWidth = viewportWidth;
          _scheduleMarqueeSetup();
        }

        return ClipRect(
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: viewportWidth),
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: widget.style,
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleMarqueeSetup() {
    if (_marqueeSetupScheduled) return;
    _marqueeSetupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _marqueeSetupScheduled = false;
        _tryStartMarquee();
      });
    });
  }

  void _tryStartMarquee() {
    if (!mounted || !_scroll.hasClients) return;

    final maxExtent = _scroll.position.maxScrollExtent;
    if (maxExtent <= 1) {
      // Text fits in the viewport — no ticker needed. This is the path most
      // node rows take, and keeps the per-row cost down on long subscription
      // lists.
      _stopMarquee();
      return;
    }

    final durationMs = (maxExtent / widget.pixelsPerSecond * 1000)
        .round()
        .clamp(3200, 30000);

    final existing = _marquee;
    if (existing != null && existing.duration?.inMilliseconds == durationMs) {
      // Already running with the right tempo — avoid the dispose/recreate
      // churn that fired on every layout pass in the previous revision.
      return;
    }

    existing?.removeListener(_syncScrollToAnimation);
    existing?.dispose();
    _marquee =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: durationMs),
          )
          ..addListener(_syncScrollToAnimation)
          ..repeat(reverse: true);
  }

  void _syncScrollToAnimation() {
    if (!mounted || _marquee == null || !_scroll.hasClients) return;
    final maxExtent = _scroll.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    _scroll.jumpTo(_marquee!.value * maxExtent);
  }

  void _stopMarquee() {
    _marquee?.removeListener(_syncScrollToAnimation);
    _marquee?.dispose();
    _marquee = null;
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }
}
