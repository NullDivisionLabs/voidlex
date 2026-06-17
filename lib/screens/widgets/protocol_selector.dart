import 'package:flutter/material.dart';

import '../../core/models/server_config.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';

String protocolLabel(AppLocalizations l, ServerProtocol protocol) {
  switch (protocol) {
    case ServerProtocol.vless:
      return l.protocolVless;
    case ServerProtocol.hysteria2:
      return l.protocolHysteria2;
    case ServerProtocol.naive:
      return l.protocolNaive;
  }
}

/// Card-style popup button used by Add/Edit Server screens to swap between
/// the supported tunnel protocols. Tap opens a [PopupMenuButton] with a
/// checkmark next to the active option.
class ProtocolSelector extends StatelessWidget {
  const ProtocolSelector({
    super.key,
    required this.protocols,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final List<ServerProtocol> protocols;
  final ServerProtocol selected;
  final bool enabled;
  final ValueChanged<ServerProtocol> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    final foreground = enabled
        ? theme.textTheme.bodyLarge?.color
        : theme.disabledColor;

    return PopupMenuButton<ServerProtocol>(
      enabled: enabled,
      initialValue: selected,
      tooltip: l.editServerProtocolLabel,
      offset: const Offset(0, 56),
      itemBuilder: (context) => [
        for (final protocol in protocols)
          PopupMenuItem<ServerProtocol>(
            value: protocol,
            child: Row(
              children: [
                Icon(
                  protocol == selected
                      ? Icons.check_rounded
                      : Icons.circle_outlined,
                  size: 18,
                  color: protocol == selected
                      ? theme.colorScheme.primary
                      : theme.iconTheme.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Text(protocolLabel(l, protocol)),
              ],
            ),
          ),
      ],
      onSelected: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            Text(
              l.editServerProtocolLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground?.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              protocolLabel(l, selected),
              style: theme.textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: foreground,
            ),
          ],
        ),
      ),
    );
  }
}
