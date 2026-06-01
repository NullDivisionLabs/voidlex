part of '../settings_screen.dart';

class _RoutingRuleTile extends StatelessWidget {
  const _RoutingRuleTile({
    required this.rule,
    required this.index,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.useTvChrome = false,
  });

  final RoutingRule rule;
  final int index;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final bool useTvChrome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (useTvChrome) {
      // Fixed-height row: nested focus rows + CrossAxisAlignment.stretch
      // collapsed to zero height on some Android TV / armv32 stacks.
      final tile = Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                rule.name.isEmpty ? 'Untitled' : rule.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _OutboundBadge(outbound: rule.outbound),
            const SizedBox(width: 10),
            TvSettingsNonFocusTrailing(
              child: Switch(
                value: rule.enabled,
                onChanged: onToggle,
              ),
            ),
          ],
        ),
      );
      return TvCompactFocusRow(
        scaleWhenFocused: 1.0,
        showGlow: false,
        onActivate: onTap,
        child: tile,
      );
    }
    return Slidable(
      // Reserve only a slim end pane so swipe gestures stay reversible —
      // a long swipe should not commit a delete by accident.
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rule.name.isEmpty ? 'Untitled' : rule.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _OutboundBadge(outbound: rule.outbound),
                  const SizedBox(width: 10),
                  Switch(value: rule.enabled, onChanged: onToggle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutboundBadge extends StatelessWidget {
  const _OutboundBadge({required this.outbound});

  final RoutingOutbound outbound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (outbound) {
      RoutingOutbound.proxy => theme.colorScheme.primary,
      RoutingOutbound.direct => Colors.green.shade600,
      RoutingOutbound.block => theme.colorScheme.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        outbound.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoutingActionTile extends StatelessWidget {
  const _RoutingActionTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
