import 'package:flutter/material.dart';

import '../../../core/vpn_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme.dart';
import '../../widgets/triangle_hub.dart';
import 'tv_kv_pair.dart';
import 'tv_section_label.dart';
import 'tv_side_rail.dart';
import 'tv_throughput_sparkline.dart';
import 'tv_triangle_focus_ring.dart';

/// Left half of the TV screen: section label + triangle hub + status
/// column with KV pairs and throughput sparklines + side rail.
class TvLeftPanel extends StatelessWidget {
  const TvLeftPanel({
    super.key,
    required this.connectionState,
    required this.hubFocused,
    required this.sideRailFocusedIndex,
    required this.sideRailItems,
    required this.exitNodeName,
    required this.exitIpLabel,
    required this.regionLabel,
    required this.downValueLabel,
    required this.upValueLabel,
    this.onHubTap,
  });

  final VpnConnectionState connectionState;
  final bool hubFocused;
  final int sideRailFocusedIndex;
  final List<TvSideRailItem> sideRailItems;
  final String exitNodeName;
  final String exitIpLabel;
  final String regionLabel;
  final String downValueLabel;
  final String upValueLabel;
  final VoidCallback? onHubTap;

  static const Alignment _hubInfoAlignment = Alignment(0, 0.08);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    final live = connectionState == VpnConnectionState.connected;
    final statusLabel = switch (connectionState) {
      VpnConnectionState.connected => l.tvStatusSecure,
      VpnConnectionState.connecting ||
      VpnConnectionState.preparing ||
      VpnConnectionState.disconnecting => l.tvStatusNegotiating,
      VpnConnectionState.error => l.tvStatusError,
      VpnConnectionState.disconnected => l.tvStatusIdle,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        TvSectionLabel(label: l.tvSectionConnect),
        const SizedBox(height: 28),
        Expanded(
          child: Align(
            alignment: _hubInfoAlignment,
            child: SizedBox(
              width: double.infinity,
              height: _HubColumn.outerSize,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HubColumn(
                    focused: hubFocused,
                    connectionState: connectionState,
                    onHubTap: onHubTap,
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: SizedBox(
                      height: _HubColumn.outerSize,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'STATUS',
                            style: VoidType.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.6,
                              color: t.fg3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusLabel.toUpperCase(),
                            style: VoidType.sans(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              height: 1,
                              color: t.fg1,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TvKvPair(
                            keyLabel: l.tvKvExitNode,
                            valueLabel: exitNodeName,
                          ),
                          const SizedBox(height: 14),
                          TvKvPair(
                            keyLabel: l.tvKvExitIp,
                            valueLabel: exitIpLabel,
                          ),
                          const SizedBox(height: 14),
                          TvKvPair(
                            keyLabel: l.tvKvRegion,
                            valueLabel: regionLabel,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TvThroughputSparkline(
                                  label: l.tvKvDown,
                                  valueLabel: downValueLabel,
                                  live: live,
                                  seed: 3,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: TvThroughputSparkline(
                                  label: l.tvKvUp,
                                  valueLabel: upValueLabel,
                                  live: live,
                                  seed: 7,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        TvSideRail(items: sideRailItems, focusedIndex: sideRailFocusedIndex),
      ],
    );
  }
}

class _HubColumn extends StatelessWidget {
  const _HubColumn({
    required this.focused,
    required this.connectionState,
    required this.onHubTap,
  });

  /// Size of the triangle hub plus a margin large enough for the focus
  /// echo to draw without clipping. Kept fixed (not flex) so the
  /// surrounding Row gives the hub a stable intrinsic width.
  static const double _size = 340;
  static const double _ringPadding = 30;
  static const double outerSize = _size + _ringPadding * 2;

  final bool focused;
  final VpnConnectionState connectionState;
  final VoidCallback? onHubTap;

  @override
  Widget build(BuildContext context) {
    final hubState = switch (connectionState) {
      VpnConnectionState.connected => HubVisualState.on,
      VpnConnectionState.connecting ||
      VpnConnectionState.preparing => HubVisualState.connecting,
      VpnConnectionState.disconnecting => HubVisualState.connecting,
      VpnConnectionState.error => HubVisualState.error,
      VpnConnectionState.disconnected => HubVisualState.off,
    };
    final l = AppLocalizations.of(context);
    final labelOverride = switch (hubState) {
      HubVisualState.off => l.tvHubLabelOff,
      HubVisualState.connecting => l.tvHubLabelConnecting,
      HubVisualState.on => l.tvHubLabelOn,
      HubVisualState.error => l.tvHubLabelError,
    };
    final subLabelOverride = switch (hubState) {
      HubVisualState.off => l.tvHubSubOff,
      HubVisualState.connecting => l.tvHubSubConnecting,
      HubVisualState.on => l.tvHubSubOn,
      HubVisualState.error => l.tvHubSubError,
    };
    // Wrap in an explicit SizedBox so the surrounding Row always gives
    // this column a stable size — without it, the inner Stack collapsed
    // to zero on certain phone form factors and the hub became invisible.
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          TriangleHub(
            state: hubState,
            size: _size,
            label: labelOverride,
            subLabel: subLabelOverride,
            onTap: onHubTap ?? () {},
          ),
          IgnorePointer(
            child: TvTriangleFocusRing(
              size: _size,
              focused: focused,
              padding: _ringPadding,
            ),
          ),
        ],
      ),
    );
  }
}
