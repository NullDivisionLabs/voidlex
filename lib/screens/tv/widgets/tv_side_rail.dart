import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../tv_focus_ring.dart';

/// Single entry in the SPLIT / GLOBAL / PRESET / SETTINGS rail.
class TvSideRailItem {
  const TvSideRailItem({
    required this.label,
    required this.subtitle,
    required this.active,
    this.onTap,
  });

  final String label;
  final String subtitle;

  /// Whether this card represents the currently effective routing mode.
  /// Distinct from focus — the rail can have GLOBAL `active` while focus
  /// sits on SPLIT.
  final bool active;

  /// Pointer fallback for the same activation the D-pad triggers — lets
  /// a developer (or anyone on a touch-capable Google TV) poke the card
  /// directly without the remote.
  final VoidCallback? onTap;
}

/// Side rail used under the triangle hub. Each card is wrapped
/// in [TvFocusRing] so the D-pad focus indicator is consistent.
class TvSideRail extends StatelessWidget {
  const TvSideRail({
    super.key,
    required this.items,
    required this.focusedIndex,
  });

  final List<TvSideRailItem> items;

  /// Index of the focused card, or `-1` when focus lives elsewhere.
  final int focusedIndex;

  @override
  Widget build(BuildContext context) {
    // Each card fills its share of the row both horizontally (via
    // Expanded) and vertically (via the explicit SizedBox height). Tap
    // zone === visible card, which is what the user expects from a 10-
    // foot UI.
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: 12),
            Expanded(
              child: TvFocusRing(
                focused: focusedIndex == i,
                radius: 12,
                child: _TvSideRailCard(item: items[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TvSideRailCard extends StatelessWidget {
  const _TvSideRailCard({required this.item});

  final TvSideRailItem item;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final active = item.active;
    final fg = active ? t.bg : t.fg1;
    final bg = active ? t.fg1 : t.surface;
    final border = active ? t.fg1 : t.border;
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      // Card now fills the entire Expanded cell so its visible bounds
      // match the InkWell tap region.
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: active ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: fg.withValues(alpha: 0.6),
            ),
          ),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VoidType.mono(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: fg,
            ),
          ),
        ],
      ),
    );
    if (item.onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: body,
      ),
    );
  }
}
