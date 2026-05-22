import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Compact key/value row used in the TV left panel — a narrow mono label
/// followed by a slightly larger mono value. Mirrors the JSX `KVPair`.
class TvKvPair extends StatelessWidget {
  const TvKvPair({
    super.key,
    required this.keyLabel,
    required this.valueLabel,
  });

  final String keyLabel;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            keyLabel,
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
              color: t.fg3,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            valueLabel,
            overflow: TextOverflow.ellipsis,
            style: VoidType.mono(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: t.fg1,
            ),
          ),
        ),
      ],
    );
  }
}
