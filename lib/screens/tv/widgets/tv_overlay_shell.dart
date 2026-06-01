import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme.dart';
import '../tv_focus_ring.dart';

const tvOverlayChromePadding = EdgeInsets.fromLTRB(80, 60, 80, 60);
const double tvOverlayHeaderGap = 36;
const double tvOverlayFooterGap = 30;

/// Full-bleed scrim used by both the subscriptions and preset overlays.
/// Pulses in with a soft fade + backdrop blur and shows the standard
/// `BACK · CLOSE  OK · SELECT` footer hint.
class TvOverlayShell extends StatelessWidget {
  const TvOverlayShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Opacity(
          opacity: value,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              color: t.bg.withValues(alpha: 0.94),
              padding: tvOverlayChromePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '// ${title.toUpperCase()}',
                        style: VoidType.mono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.6,
                          color: t.fg1,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Flexible(
                        child: Text(
                          subtitle.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: VoidType.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2.0,
                            color: t.fg3,
                          ),
                        ),
                      ),
                      if (onBack != null) ...[
                        const SizedBox(width: 24),
                        TvOverlayBackButton(onTap: onBack!),
                      ],
                    ],
                  ),
                  const SizedBox(height: tvOverlayHeaderGap),
                  Expanded(child: child),
                  const SizedBox(height: tvOverlayFooterGap),
                  Text(
                    l.tvOverlayFooter,
                    style: VoidType.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.2,
                      color: t.fg3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TvOverlayBackButton extends StatefulWidget {
  const TvOverlayBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<TvOverlayBackButton> createState() => _TvOverlayBackButtonState();
}

class _TvOverlayBackButtonState extends State<TvOverlayBackButton> {
  bool _focused = false;

  void _handleFocusChange(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    return TvFocusRing(
      focused: _focused,
      radius: 6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: _handleFocusChange,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: t.borderStrong),
              borderRadius: BorderRadius.circular(6),
              color: t.surface,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 18, color: t.fg1),
                const SizedBox(width: 8),
                Text(
                  l.tvActionBackKey,
                  style: VoidType.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: t.fg1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
