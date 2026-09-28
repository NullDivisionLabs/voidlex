import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<bool> confirmDiscardUnsavedChanges(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l = AppLocalizations.of(dialogContext);
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(l.discardChangesTitle),
        content: Text(l.discardChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.discardChangesAction),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
