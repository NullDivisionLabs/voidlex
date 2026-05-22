import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme.dart';

/// Bottom hint strip showing the four primary remote actions. Labels are
/// context-aware on `(focusColumn, connectionState)` so the OK button
/// communicates the action it will take if pressed now.
class TvActionBar extends StatelessWidget {
  const TvActionBar({super.key, required this.hints});

  final List<TvActionHint> hints;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < hints.length; i++) ...[
            if (i != 0) const SizedBox(width: 28),
            _HintBlock(hint: hints[i]),
          ],
          const Spacer(),
          Text(
            l.tvHintRemoteFooter,
            style: VoidType.mono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.0,
              color: t.fg3,
            ),
          ),
        ],
      ),
    );
  }
}

class TvActionHint {
  const TvActionHint({
    required this.button,
    required this.label,
    this.onTap,
  });

  final String button;
  final String label;

  /// Optional tap handler — when present, the chip becomes a tap target.
  /// Lets a developer drive the layout from a phone (and gives Google TV
  /// users an obvious "this is what OK does" cue, even though pressing
  /// the OK key on the remote is the canonical path).
  final VoidCallback? onTap;
}

class _HintBlock extends StatelessWidget {
  const _HintBlock({required this.hint});

  final TvActionHint hint;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          constraints: const BoxConstraints(minWidth: 28),
          decoration: BoxDecoration(
            border: Border.all(color: t.borderStrong),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            hint.button,
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: t.fg1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          hint.label,
          style: VoidType.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: t.fg2,
          ),
        ),
      ],
    );
    if (hint.onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hint.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: body,
        ),
      ),
    );
  }
}
