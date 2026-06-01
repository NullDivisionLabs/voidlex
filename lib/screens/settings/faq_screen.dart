part of '../settings_screen.dart';

/// FAQ screen, reachable from the About block in Settings. Pure presentation:
/// pulls all 20 Q/A pairs from [AppLocalizations] and renders them as
/// independently-toggleable cards styled to match the rest of the settings
/// surfaces (mono section labels, sans body, hairline borders on
/// [VoidTokens.surface]).
class _FaqScreen extends StatefulWidget {
  const _FaqScreen({
    required this.controller,
    this.useTvChrome = false,
    this.allowTvChromeInAutoRotate = false,
  });

  final VpnController controller;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<_FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<_FaqScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OrientationBuilder(
      builder: (context, orientation) {
        final useTvChrome = _useTvSettingsChrome(
          controller: widget.controller,
          requested: widget.useTvChrome,
          allowInAutoRotate: widget.allowTvChromeInAutoRotate,
          orientation: orientation,
        );
        return _buildScaffold(l: l, useTvChrome: useTvChrome);
      },
    );
  }

  Widget _buildScaffold({
    required AppLocalizations l,
    required bool useTvChrome,
  }) {
    final t = VoidTokens.of(context);
    final entries = _faqEntries(l);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: useTvChrome
          ? null
          : AppBar(
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(
                l.faqTitle,
                style: VoidType.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: t.fg1,
                ),
              ),
            ),
      body: _TvSettingsBody(
        enabled: useTvChrome,
        title: l.faqTitle,
        subtitle: l.faqSubtitle,
        child: useTvChrome
            ? TvSettingsScrollView(
                child: _buildFaqList(
                  l: l,
                  t: t,
                  entries: entries,
                  useTvChrome: useTvChrome,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _buildFaqList(
                  l: l,
                  t: t,
                  entries: entries,
                  useTvChrome: useTvChrome,
                ),
              ),
      ),
    );
  }

  Widget _buildFaqList({
    required AppLocalizations l,
    required VoidTokens t,
    required List<(String, String)> entries,
    required bool useTvChrome,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 2),
          child: Text(
            l.faqHint,
            style: VoidType.mono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: t.fg3,
            ),
          ),
        ),
        for (var i = 0; i < entries.length; i++) ...[
          if (i != 0) SizedBox(height: useTvChrome ? 12 : 8),
          _FaqCard(
            index: i + 1,
            question: entries[i].$1,
            answer: entries[i].$2,
            useTvChrome: useTvChrome,
            autofocus: useTvChrome && i == 0,
          ),
        ],
      ],
    );
  }

  List<(String, String)> _faqEntries(AppLocalizations l) {
    return <(String, String)>[
      (l.faqQ1, l.faqA1),
      (l.faqQ2, l.faqA2),
      (l.faqQ3, l.faqA3),
      (l.faqQ4, l.faqA4),
      (l.faqQ5, l.faqA5),
      (l.faqQ6, l.faqA6),
      (l.faqQ7, l.faqA7),
      (l.faqQ8, l.faqA8),
      (l.faqQ9, l.faqA9),
      (l.faqQ10, l.faqA10),
      (l.faqQ11, l.faqA11),
      (l.faqQ12, l.faqA12),
      (l.faqQ13, l.faqA13),
      (l.faqQ14, l.faqA14),
      (l.faqQ15, l.faqA15),
      (l.faqQ16, l.faqA16),
      (l.faqQ17, l.faqA17),
      (l.faqQ18, l.faqA18),
      (l.faqQ19, l.faqA19),
      (l.faqQ20, l.faqA20),
    ];
  }
}

/// One collapsible Q/A. Closed: question + chevron. Open: question + answer
/// below a hairline divider. Tap or D-pad OK toggles. The index ("01", "02"…)
/// echoes the mono numbering used elsewhere in settings.
class _FaqCard extends StatefulWidget {
  const _FaqCard({
    required this.index,
    required this.question,
    required this.answer,
    this.useTvChrome = false,
    this.autofocus = false,
  });

  final int index;
  final String question;
  final String answer;
  final bool useTvChrome;
  final bool autofocus;

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;
  bool _focused = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final number = widget.index.toString().padLeft(2, '0');
    final card = Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        autofocus: widget.autofocus,
        borderRadius: BorderRadius.circular(10),
        onTap: _toggle,
        onFocusChange: widget.useTvChrome
            ? (value) {
                if (_focused == value) return;
                setState(() => _focused = value);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            border: Border.all(
              color: _expanded ? t.borderStrong : t.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 12),
                    child: Text(
                      number,
                      style: VoidType.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: t.fg3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: VoidType.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.fg1,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: _expanded ? t.fg1 : t.fg3,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 1,
                              color: t.border,
                              margin: const EdgeInsets.only(bottom: 12),
                            ),
                            _FaqAnswerText(text: widget.answer),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    if (!widget.useTvChrome) return card;
    return TvFocusRing(focused: _focused, radius: 10, child: card);
  }
}

/// Renders answer text with a tiny markdown dialect: `**bold**` spans inline
/// and literal `\n` newlines (which the ARB JSON decoder already turns into
/// real newline characters). Backticks and other syntax are left as-is.
class _FaqAnswerText extends StatelessWidget {
  const _FaqAnswerText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final base = VoidType.sans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: t.fg2,
      height: 1.5,
    );
    final bold = base.copyWith(
      fontWeight: FontWeight.w700,
      color: t.fg1,
    );
    return RichText(
      text: TextSpan(
        style: base,
        children: _spans(text, base: base, bold: bold),
      ),
    );
  }

  static List<TextSpan> _spans(
    String input, {
    required TextStyle base,
    required TextStyle bold,
  }) {
    final spans = <TextSpan>[];
    final parts = input.split('**');
    // Odd-indexed segments are inside a **...** pair. Trailing unmatched
    // marker (odd count) is treated as literal text — never breaks layout.
    final balanced = parts.length.isOdd;
    for (var i = 0; i < parts.length; i++) {
      final segment = parts[i];
      if (segment.isEmpty) continue;
      final isBold = balanced && i.isOdd;
      spans.add(TextSpan(text: segment, style: isBold ? bold : base));
    }
    return spans;
  }
}
