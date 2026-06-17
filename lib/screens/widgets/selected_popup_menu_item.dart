import 'package:flutter/material.dart';

/// Popup menu entry without the trailing checkmark slot that skews padding.
/// The active option is marked with primary color, semibold weight, and a
/// light underline.
class SelectedPopupMenuItem<T> extends PopupMenuItem<T> {
  SelectedPopupMenuItem({
    required super.value,
    required String label,
    required bool selected,
    super.enabled,
  }) : super(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
         child: SelectedPopupMenuLabel(label: label, selected: selected),
       );
}

class SelectedPopupMenuLabel extends StatelessWidget {
  const SelectedPopupMenuLabel({
    super.key,
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: selected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        decoration: selected ? TextDecoration.underline : null,
        decorationColor: selected
            ? colorScheme.primary.withValues(alpha: 0.75)
            : null,
        decorationThickness: 1.2,
      ),
    );
  }
}
