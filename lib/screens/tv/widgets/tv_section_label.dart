import 'package:flutter/material.dart';

import '../../../theme.dart';

/// `// CONNECT` / `// NODES` style heading + trailing divider line used at
/// the top of each TV panel column.
class TvSectionLabel extends StatelessWidget {
  const TvSectionLabel({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '// $label',
          style: VoidType.mono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.8,
            color: t.fg3,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: t.border)),
        if (trailing != null) ...[const SizedBox(width: 14), trailing!],
      ],
    );
  }
}
