import 'package:flutter/material.dart';

import '../../../core/routing_preset.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme.dart';
import '../tv_focus_ring.dart';
import 'tv_overlay_shell.dart';

/// Single-column preset picker. Triggered when MENU is pressed while a node
/// row holds focus.
class TvPresetOverlay extends StatelessWidget {
  const TvPresetOverlay({
    super.key,
    required this.presets,
    required this.focusedRow,
    required this.currentPresetId,
    required this.targetServerName,
    required this.onBack,
  });

  final List<RoutingPreset> presets;
  final int focusedRow;
  final String? currentPresetId;
  final String? targetServerName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    return TvOverlayShell(
      title: l.tvOverlayPresetTitle,
      subtitle: targetServerName == null
          ? l.tvOverlayPresetSubtitleGlobal
          : l.tvOverlayPresetSubtitleForNode(targetServerName!),
      onBack: onBack,
      child: Center(
        child: SizedBox(
          width: 1240,
          child: ListView.separated(
            itemCount: presets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isCurrent = currentPresetId == preset.id;
              return TvFocusRing(
                focused: focusedRow == index,
                radius: 14,
                child: _PresetCard(
                  name: preset.name,
                  description: _describe(l, preset),
                  isCurrent: isCurrent,
                  tokens: t,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _describe(AppLocalizations l, RoutingPreset preset) {
    if (preset.isMain) return l.tvPresetMainDescription;
    final rules = preset.routingRules.length;
    final apps =
        preset.appRoutingPolicy.packages.length +
        preset.appRoutingPolicy.proxyPackages.length +
        preset.appRoutingPolicy.bypassPackages.length;
    return l.tvPresetSummary(rules, apps);
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.name,
    required this.description,
    required this.isCurrent,
    required this.tokens,
  });

  final String name;
  final String description;
  final bool isCurrent;
  final VoidTokens tokens;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 162,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: VoidType.mono(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                      color: tokens.fg1,
                    ),
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.fg1,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      l.tvPresetCurrentChip,
                      style: VoidType.mono(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                        color: tokens.bg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VoidType.sans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: tokens.fg2,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
