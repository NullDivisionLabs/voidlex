import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<bool> confirmInsecureSubscription(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l = AppLocalizations.of(dialogContext);
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(l.insecureSubscriptionTitle),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(l.insecureSubscriptionBody)),
          ],
        ),
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
            child: Text(l.insecureSubscriptionConfirm),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
