import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'tv_settings_focus.dart';
import '../tv_focus_ring.dart';

/// Visual constants shared by every TV settings card so spacing,
/// borders, and typography stay locked to the preset-overlay reference
/// (`_PresetCard` in `tv_preset_overlay.dart`).
const double _tvCardHeight = 162;
const EdgeInsets _tvCardPadding = EdgeInsets.symmetric(
  horizontal: 32,
  vertical: 26,
);
const BorderRadius _tvCardRadius = BorderRadius.all(Radius.circular(14));

/// Big, focusable settings card that matches the preset-overlay card
/// style. Used across every settings screen when the TV chrome is on,
/// so the entire settings tree shares one visual language.
///
/// The card can be:
///   * Pure navigation (provide [onTap] only) → renders a chevron on
///     the right.
///   * Action-bearing (provide [trailing]) → the caller supplies the
///     control (switch / popup menu / segmented button etc.).
///   * Read-only (omit both) → behaves like an info card.
class TvSettingsCard extends StatefulWidget {
  const TvSettingsCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.badge,
    this.trailing,
    this.onTap,
    this.height = _tvCardHeight,
    this.autofocus = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Short pill drawn next to the title (e.g. `CURRENT`, `BETA`,
  /// `EXPERIMENTAL`). Same chip style as the preset overlay's CURRENT
  /// marker.
  final String? badge;

  /// Replaces the default chevron with a custom control (switch,
  /// segmented button etc.). When provided the entire card is still
  /// tappable via [onTap] — the control handles its own gesture.
  final Widget? trailing;

  final VoidCallback? onTap;
  final double height;

  /// When true and [onTap] is set, the card claims keyboard focus on
  /// first build. Callers set this on the first interactive card of a
  /// screen so the movable focus shadow appears as soon as the user
  /// lands on the route via the D-pad.
  final bool autofocus;

  @override
  State<TvSettingsCard> createState() => _TvSettingsCardState();
}

class _TvSettingsCardState extends State<TvSettingsCard> {
  bool _focused = false;

  bool get _isFocusable => widget.onTap != null || widget.trailing != null;

  void _handleFocusChange(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final trailing = widget.trailing == null
        ? null
        : TvSettingsNonFocusTrailing(child: widget.trailing!);
    final body = SizedBox(
      height: widget.height,
      child: Container(
        padding: _tvCardPadding,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: _tvCardRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: t.fg2, size: 28),
              const SizedBox(width: 22),
            ],
            Expanded(
              child: _TextColumn(
                title: widget.title,
                subtitle: widget.subtitle,
                badge: widget.badge,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 18),
              trailing,
            ] else if (widget.onTap != null) ...[
              const SizedBox(width: 18),
              Icon(Icons.chevron_right_rounded, size: 28, color: t.fg3),
            ],
          ],
        ),
      ),
    );

    if (!_isFocusable) return body;
    return TvFocusRing(
      focused: _focused,
      radius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          autofocus: widget.autofocus,
          onTap: widget.onTap,
          onFocusChange: _handleFocusChange,
          borderRadius: _tvCardRadius,
          child: body,
        ),
      ),
    );
  }
}

class _TextColumn extends StatelessWidget {
  const _TextColumn({required this.title, this.subtitle, this.badge});

  final String title;
  final String? subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VoidType.mono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.6,
                  color: t.fg1,
                ),
              ),
            ),
            if (badge case final value?) ...[
              const SizedBox(width: 12),
              _TvSettingsBadge(label: value),
            ],
          ],
        ),
        if (subtitle case final s?) ...[
          const SizedBox(height: 8),
          Text(
            s,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VoidType.sans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: t.fg2,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small filled chip matching `tvPresetCurrentChip` styling. Exported
/// so callers can reuse it in `trailing` slots (e.g. show "X NODES" or
/// "ACTIVE" pills next to a value).
class _TvSettingsBadge extends StatelessWidget {
  const _TvSettingsBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.fg1,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label.toUpperCase(),
        style: VoidType.mono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
          color: t.bg,
        ),
      ),
    );
  }
}

/// Mono section heading inside TV settings panels (`// CONNECT` style,
/// matching the home screen). Use between groups of [TvSettingsCard]s.
class TvSettingsSectionLabel extends StatelessWidget {
  const TvSettingsSectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '// ${label.toUpperCase()}',
            style: VoidType.mono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.8,
              color: t.fg3,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Container(height: 1, color: t.border)),
          if (trailing != null) ...[const SizedBox(width: 14), trailing!],
        ],
      ),
    );
  }
}
