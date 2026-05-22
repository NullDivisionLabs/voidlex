import 'package:flutter/material.dart';

import '../../theme.dart';

class VoidTopBar extends StatelessWidget {
  const VoidTopBar({
    super.key,
    required this.version,
    this.rightBadge,
    this.onRightBadgeDisable,
  });

  final String version;
  final String? rightBadge;
  final VoidCallback? onRightBadgeDisable;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Text(
            'VOID//TUNNEL',
            style: VoidType.mono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: t.fg1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              version,
              style: VoidType.mono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: t.fg3,
              ),
            ),
          ),
          if (rightBadge != null) ...[
            const Spacer(),
            _BridgeModeBadge(
              label: rightBadge!,
              onDisable: onRightBadgeDisable,
            ),
          ],
        ],
      ),
    );
  }
}

enum _BridgeModeBadgeAction { disable }

class _BridgeModeBadge extends StatelessWidget {
  const _BridgeModeBadge({required this.label, required this.onDisable});

  final String label;
  final VoidCallback? onDisable;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: VoidType.mono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: t.fg1,
        ),
      ),
    );

    final disable = onDisable;
    if (disable == null) return badge;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) async {
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final action = await showMenu<_BridgeModeBadgeAction>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            overlay.size.width - details.globalPosition.dx,
            overlay.size.height - details.globalPosition.dy,
          ),
          color: t.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: t.border),
          ),
          items: [
            PopupMenuItem<_BridgeModeBadgeAction>(
              value: _BridgeModeBadgeAction.disable,
              child: Text(
                'Disable',
                style: VoidType.sans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: t.fg1,
                ),
              ),
            ),
          ],
        );
        if (action == _BridgeModeBadgeAction.disable) {
          disable();
        }
      },
      child: badge,
    );
  }
}
