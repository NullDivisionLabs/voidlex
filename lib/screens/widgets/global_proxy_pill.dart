import 'package:flutter/material.dart';

import '../../theme.dart';

/// Segmented pill that switches between split-routing and global-proxy mode —
/// the design's `pill` variant of `GlobalProxyControl`.
class GlobalProxyPill extends StatelessWidget {
  const GlobalProxyPill({
    super.key,
    required this.globalActive,
    required this.onChanged,
    this.enabled = true,
  });

  final bool globalActive;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: _Seg(
                label: 'SPLIT',
                hint: 'ROUTING RULES',
                active: !globalActive,
                onTap: enabled && globalActive ? () => onChanged(false) : null,
              ),
            ),
            Expanded(
              child: _Seg(
                label: 'GLOBAL',
                hint: 'ALL TRAFFIC',
                active: globalActive,
                onTap: enabled && !globalActive ? () => onChanged(true) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.hint,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String hint;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? t.fg1 : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: VoidType.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: active ? t.bg : t.fg2,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: Text(
                  hint,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: VoidType.mono(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.8,
                    color: (active ? t.bg : t.fg2).withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
