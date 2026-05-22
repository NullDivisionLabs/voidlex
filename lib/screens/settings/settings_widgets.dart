part of '../settings_screen.dart';

/// Decides whether the calling settings screen should render itself with
/// the TV chrome (header `// TITLE`, footer hint, big focus-friendly
/// cards). Three signals combine:
///
///   * **[requested]** — what the parent route asked for at push-time.
///     If the parent is a mobile screen we should never switch into TV
///     chrome later (that would break the navigation aesthetics).
///   * **[allowInAutoRotate]** — set when running on a real Android TV
///     so the chrome stays on regardless of orientation.
///   * **[orientation]** — the current device orientation, threaded
///     through an [OrientationBuilder] in each settings screen. In
///     auto-rotate mode we follow it; in fixed-preference mode we
///     ignore it (the preference already implies the orientation).
bool _useTvSettingsChrome({
  required VpnController controller,
  required bool requested,
  required bool allowInAutoRotate,
  Orientation? orientation,
}) {
  if (!requested) return false;
  if (allowInAutoRotate) return true;
  final preference = controller.repository.loadTvLayoutPreference();
  switch (preference) {
    case TvLayoutPreference.horizontal:
      return true;
    case TvLayoutPreference.vertical:
      return false;
    case TvLayoutPreference.autoRotate:
      if (orientation == null) {
        // Caller hasn't wrapped in OrientationBuilder yet — fall back
        // to "true if we *might* be in landscape soon". The chrome
        // decision will tighten on the next rebuild.
        return true;
      }
      return orientation == Orientation.landscape;
  }
}

class _TvSettingsBody extends StatelessWidget {
  const _TvSettingsBody({
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.onBack,
  });

  final bool enabled;
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// Logical canvas the TV settings pages compose for. Mirrors
  /// `TvHomeScreen._designWidth/_designHeight`: a real Google TV renders
  /// at 1:1, anything smaller (phone in landscape, tablet) is letter-
  /// boxed via [FittedBox]. Without this, the preset-style cards looked
  /// proportional on the Preset overlay (which lives inside the home
  /// canvas) but huge on Config / Route routes.
  static const double _designWidth = 1920;
  static const double _designHeight = 1080;

  /// Cap content width so cards on a 1920-wide canvas don't stretch all
  /// the way edge-to-edge. Matches the `SizedBox(width: 1240)` the
  /// Preset overlay uses inside `tv_preset_overlay.dart` — keeping
  /// every TV cardlist visually consistent.
  static const double _contentMaxWidth = 1240;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return SafeArea(child: child);

    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsNatively = constraints.maxWidth >= _designWidth &&
            constraints.maxHeight >= _designHeight;
        final canvas = SizedBox(
          width: _designWidth,
          height: _designHeight,
          child: _buildCanvasContents(l, t),
        );
        if (fitsNatively) return canvas;
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: canvas,
          ),
        );
      },
    );
  }

  Widget _buildCanvasContents(AppLocalizations l, VoidTokens t) {
    return Padding(
      padding: tvOverlayChromePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TvSettingsHeader(
            title: title,
            subtitle: subtitle,
            actions: actions,
            onBack: onBack,
            compact: false,
            tokens: t,
          ),
          const SizedBox(height: tvOverlayHeaderGap),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: child,
              ),
            ),
          ),
          const SizedBox(height: tvOverlayFooterGap),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l.tvOverlayFooter,
              maxLines: 1,
              softWrap: false,
              style: VoidType.mono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.2,
                color: t.fg3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvSettingsHeader extends StatelessWidget {
  const _TvSettingsHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onBack,
    required this.compact,
    required this.tokens,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool compact;
  final VoidTokens tokens;

  @override
  Widget build(BuildContext context) {
    final titleStyle = VoidType.mono(
      fontSize: compact ? 14 : 16,
      fontWeight: FontWeight.w700,
      letterSpacing: compact ? 2.8 : 3.6,
      color: tokens.fg1,
    );
    final subtitleStyle = VoidType.mono(
      fontSize: compact ? 10 : 12,
      fontWeight: FontWeight.w500,
      letterSpacing: compact ? 1.6 : 2.0,
      color: tokens.fg3,
    );
    final actionRow = _TvSettingsActions(
      actions: actions,
      iconSize: compact ? 18 : 20,
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '// ${title.toUpperCase()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              if (actions.isNotEmpty) ...[const SizedBox(width: 10), actionRow],
              const SizedBox(width: 12),
              TvOverlayBackButton(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subtitleStyle,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('// ${title.toUpperCase()}', style: titleStyle),
        const SizedBox(width: 24),
        Flexible(
          child: Text(
            subtitle.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: subtitleStyle,
          ),
        ),
        if (actions.isNotEmpty) ...[const SizedBox(width: 18), actionRow],
        const SizedBox(width: 24),
        TvOverlayBackButton(
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _TvSettingsActions extends StatelessWidget {
  const _TvSettingsActions({required this.actions, required this.iconSize});

  final List<Widget> actions;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final t = VoidTokens.of(context);
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(40),
          minimumSize: const Size.square(40),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: IconTheme(
        data: IconThemeData(color: t.fg1, size: iconSize),
        child: Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}

class _SettingsSectionTile extends StatelessWidget {
  const _SettingsSectionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: t.fg2, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: VoidType.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.fg1,
                      ),
                    ),
                    if (subtitle case final s?) ...[
                      const SizedBox(height: 2),
                      Text(
                        s.toUpperCase(),
                        style: VoidType.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                          color: t.fg3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: t.fg3),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: VoidType.mono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: t.fg3,
              ),
            ),
          ),
          Text(
            value,
            style: VoidType.mono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.fg1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutBrandFooter extends StatelessWidget {
  const _AboutBrandFooter();

  /// Project Telegram channel — opens via `url_launcher` with the platform
  /// default handler (will switch to the Telegram app if it's installed,
  /// otherwise the system browser).
  static final Uri _telegramUri = Uri.parse('https://t.me/voidtun');

  Future<void> _openTelegram(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final launched = await launchUrl(
        _telegramUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l.telegramOpenFailed)),
        );
      }
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l.telegramOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openTelegram(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.telegram_rounded, size: 22, color: t.fg2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Null Division · 2026',
              style: VoidType.mono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: t.fg3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mono section heading reused inside settings sub-screens. An optional
/// [trailing] widget is rendered on the right edge of the same row, useful
/// for in-line affordances such as the About → FAQ link.
class _SettingsSectionHeading extends StatelessWidget {
  const _SettingsSectionHeading(this.label, {this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final labelText = Text(
      label.toUpperCase(),
      style: VoidType.mono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: t.fg2,
      ),
    );
    if (trailing == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: labelText,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: labelText),
          trailing!,
        ],
      ),
    );
  }
}

/// Compact inline FAQ affordance shown in the About heading row. Mono label
/// plus a chevron, sized to sit on the same baseline as the heading.
class _AboutFaqLink extends StatelessWidget {
  const _AboutFaqLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: VoidType.mono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: t.fg1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 14, color: t.fg2),
          ],
        ),
      ),
    );
  }
}

