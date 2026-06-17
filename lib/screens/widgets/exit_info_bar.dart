import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_memory.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import 'slow_marquee_text.dart';

typedef MemoryPssLoader = Future<int?> Function();

/// Compact expandable bar that mirrors the design's "EXIT ... NODE ..." strip.
class ExitInfoBar extends StatefulWidget {
  const ExitInfoBar({
    super.key,
    required this.exitIp,
    required this.node,
    required this.downloadSpeed,
    required this.uploadSpeed,
    this.loadMemoryPssKb,
    this.memoryPollInterval = const Duration(seconds: 1),
  });

  final String exitIp;
  final String node;
  final String downloadSpeed;
  final String uploadSpeed;
  final MemoryPssLoader? loadMemoryPssKb;
  final Duration memoryPollInterval;

  @override
  State<ExitInfoBar> createState() => _ExitInfoBarState();
}

class _ExitInfoBarState extends State<ExitInfoBar> {
  static const _memoryBridge = AppMemoryBridge();

  Timer? _memoryTimer;
  int? _memoryPssKb;
  bool _expanded = false;
  bool _memoryRequestInFlight = false;

  @override
  void dispose() {
    _memoryTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshMemory() async {
    if (!_expanded || _memoryRequestInFlight) return;
    _memoryRequestInFlight = true;
    final loader = widget.loadMemoryPssKb ?? _memoryBridge.getPssKb;
    int? value;
    try {
      value = await loader();
    } catch (_) {
      value = null;
    } finally {
      _memoryRequestInFlight = false;
    }
    if (!mounted || !_expanded) return;
    setState(() => _memoryPssKb = value);
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (!_expanded) _memoryPssKb = null;
    });
    _memoryTimer?.cancel();
    _memoryTimer = null;
    if (!_expanded) return;
    unawaited(_refreshMemory());
    _memoryTimer = Timer.periodic(
      widget.memoryPollInterval,
      (_) => unawaited(_refreshMemory()),
    );
  }

  String _memoryLabel() {
    final value = _memoryPssKb;
    if (value == null || value < 0) return 'N/A';
    return '${(value / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    final labelStyle = VoidType.mono(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.8,
      color: t.fg3,
    );
    final valueStyle = VoidType.mono(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: t.fg1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: const ValueKey('exit-info-bar-toggle'),
          borderRadius: BorderRadius.circular(10),
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ExitInfoCell(
                        label: 'EXIT',
                        value: widget.exitIp,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ExitInfoCell(
                        label: 'NODE',
                        value: widget.node,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: t.fg3,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: !_expanded
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          key: const ValueKey('exit-info-bar-details'),
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: [
                              Divider(height: 1, color: t.border),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _SpeedInfoCell(
                                      downLabel: l.exitInfoDownLabel,
                                      downValue: widget.downloadSpeed,
                                      upLabel: l.exitInfoUpLabel,
                                      upValue: widget.uploadSpeed,
                                      labelStyle: labelStyle,
                                      valueStyle: valueStyle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: _ExitInfoCell(
                                      label: l.exitInfoMemoryLabel,
                                      value: _memoryLabel(),
                                      labelStyle: labelStyle,
                                      valueStyle: valueStyle,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

class _SpeedInfoCell extends StatelessWidget {
  const _SpeedInfoCell({
    required this.downLabel,
    required this.downValue,
    required this.upLabel,
    required this.upValue,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String downLabel;
  final String downValue;
  final String upLabel;
  final String upValue;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _ExitInfoCell._rowHeight,
      child: Row(
        children: [
          Expanded(
            child: _SpeedValue(
              labelKey: const ValueKey('exit-info-speed-down-label'),
              valueKey: const ValueKey('exit-info-speed-down-value'),
              label: downLabel,
              value: downValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SpeedValue(
              labelKey: const ValueKey('exit-info-speed-up-label'),
              valueKey: const ValueKey('exit-info-speed-up-value'),
              label: upLabel,
              value: upValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedValue extends StatelessWidget {
  const _SpeedValue({
    required this.labelKey,
    required this.valueKey,
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final Key labelKey;
  final Key valueKey;
  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          key: labelKey,
          maxLines: 1,
          softWrap: false,
          style: labelStyle,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            key: valueKey,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class _ExitInfoCell extends StatelessWidget {
  const _ExitInfoCell({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  static const double _rowHeight = 18;
  static const double _labelGap = 8;

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          Text(label, maxLines: 1, softWrap: false, style: labelStyle),
          const SizedBox(width: _labelGap),
          Expanded(
            child: SlowMarqueeText(
              key: ValueKey('$label:$value'),
              text: value,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
