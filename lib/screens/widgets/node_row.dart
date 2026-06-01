import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import 'slow_marquee_text.dart';

/// Tone for the ping number shown on the right of [NodeRow] / [FavCard].
enum NodePingTone {
  ok,
  warn,
  err,
  none;

  /// Maps a raw ping string (as stored on `ServerConfig.ping`) onto the
  /// design's four-bucket tone scale. Lifted from `home_screen.dart` so
  /// the TV node row can stay in sync without re-implementing the rules.
  ///
  /// Buckets follow the design canvas: < 180 ms is OK, < 300 ms is WARN,
  /// timeouts (`> …`) and explicit `ERR` markers go to the ERR bucket.
  /// Empty / `--` / non-numeric values render as the neutral NONE tone.
  static NodePingTone fromRaw(String? raw) {
    final upper = (raw ?? '').trim().toUpperCase();
    if (upper.isEmpty || upper == '--') return NodePingTone.none;
    if (upper == 'ERR' || upper.startsWith('>')) return NodePingTone.err;
    final digits = RegExp(r'\d+').firstMatch(upper)?.group(0);
    final value = int.tryParse(digits ?? '');
    if (value == null) return NodePingTone.none;
    if (value < 180) return NodePingTone.ok;
    if (value < 300) return NodePingTone.warn;
    return NodePingTone.err;
  }

  /// Compact label for the ping number. Empty / `--` collapse to an em
  /// dash; timeouts (`> …`) and `ERR` collapse to `N/A` so a marker like
  /// `>5` cannot be misread as `5 ms` when paired with the MS suffix.
  /// Otherwise the leading digit run is returned.
  static String shortLabel(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty || trimmed == '--') return '—';
    if (trimmed.toUpperCase() == 'ERR' || trimmed.startsWith('>')) return 'N/A';
    final digits = RegExp(r'\d+').firstMatch(trimmed)?.group(0);
    if (digits == null) return trimmed;
    return digits;
  }

  /// Token-aware colour for this tone — call once when painting either
  /// the mobile or the TV row.
  Color colorIn(VoidTokens t) => switch (this) {
    NodePingTone.ok => t.ok,
    NodePingTone.warn => t.warn,
    NodePingTone.err => t.error,
    NodePingTone.none => t.fg2,
  };
}

/// Row in the design's subscription / manual list. Visuals follow
/// `home-screen.jsx` — small triangle marker (filled when selected, hollow
/// otherwise), name with optional EXIT/preset chips, protocol/transport tags
/// underneath, and a signal icon + ping number on the right.
class NodeRow extends StatelessWidget {
  const NodeRow({
    super.key,
    required this.name,
    required this.protocol,
    required this.transport,
    required this.pingSlot,
    this.selected = false,
    this.pinned = false,
    this.exit = false,
    this.insecure = false,
    this.preset,
    this.onTap,
    this.onMenuTap,
    this.trailing,
  });

  final String name;
  final String protocol;
  final String transport;
  final Widget pingSlot;
  final bool selected;
  final bool pinned;
  final bool exit;

  /// True when the underlying server config sets `tlsInsecure`. Surfaced
  /// as a red "INSECURE" chip so the user knows the chosen node accepts
  /// any TLS certificate. Important after a subscription import, where
  /// the flag rides along quietly from the URL.
  final bool insecure;
  final String? preset;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final borderColor = selected ? t.fg1 : (pinned ? t.borderStrong : t.border);

    return RepaintBoundary(
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 18,
                child: CustomPaint(
                  painter: _MiniTrianglePainter(color: t.fg1, fill: selected),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SlowMarqueeText(
                      text: name,
                      style: VoidType.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.fg1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (protocol.isNotEmpty) _Tag(text: protocol),
                        if (transport.isNotEmpty) _Tag(text: transport),
                        if (exit)
                          _Chip(
                            text: AppLocalizations.of(
                              context,
                            ).serverExitNodeLabel,
                          ),
                        if (preset != null && preset!.isNotEmpty)
                          _Chip(text: preset!.toUpperCase()),
                        if (insecure)
                          _Chip(text: 'INSECURE', tone: _ChipTone.warn),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              pingSlot,
              if (onMenuTap != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onMenuTap,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.more_horiz, size: 14, color: t.fg2),
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
          ),
        ),
      ),
    );
  }

}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text.toUpperCase(),
        style: VoidType.mono(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.4,
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
    final fill = switch (tone) {
      _ChipTone.strong => t.fg1,
      _ChipTone.warn => t.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: fill),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: VoidType.mono(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: t.bg,
        ),
      ),
    );
  }
}

class _MiniTrianglePainter extends CustomPainter {
  _MiniTrianglePainter({required this.color, required this.fill});

  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, h * 0.10)
      ..lineTo(w * 0.95, h * 0.92)
      ..lineTo(w * 0.05, h * 0.92)
      ..close();
    if (fill) {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: fill ? 1.0 : 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniTrianglePainter old) =>
      old.color != color || old.fill != fill;
}

