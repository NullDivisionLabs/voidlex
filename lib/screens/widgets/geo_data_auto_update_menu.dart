import 'package:flutter/material.dart';

import '../../core/geo_data.dart';
import '../../l10n/app_localizations.dart';
import 'selected_popup_menu_item.dart';

class GeoDataAutoUpdateMenuButton extends StatelessWidget {
  const GeoDataAutoUpdateMenuButton({
    super.key,
    required this.interval,
    required this.onSelected,
    this.textStyle,
    this.showLeadingIcon = false,
  });

  final GeoDataAutoUpdateInterval interval;
  final ValueChanged<GeoDataAutoUpdateInterval> onSelected;
  final TextStyle? textStyle;
  final bool showLeadingIcon;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<GeoDataAutoUpdateInterval>(
      initialValue: interval,
      tooltip: l.geoAutoUpdateTitle,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final candidate in GeoDataAutoUpdateInterval.values)
          SelectedPopupMenuItem<GeoDataAutoUpdateInterval>(
            value: candidate,
            selected: candidate == interval,
            label: geoDataAutoUpdateIntervalLabel(
              AppLocalizations.of(context),
              candidate,
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLeadingIcon) ...[
            const Icon(Icons.autorenew_rounded, size: 18),
            const SizedBox(width: 6),
          ],
          Text(geoDataAutoUpdateIntervalLabel(l, interval), style: textStyle),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    );
  }
}

String geoDataAutoUpdateIntervalLabel(
  AppLocalizations l,
  GeoDataAutoUpdateInterval interval,
) {
  return switch (interval) {
    GeoDataAutoUpdateInterval.disabled => l.geoAutoUpdateDisabled,
    GeoDataAutoUpdateInterval.oneDay => l.geoAutoUpdateOneDay,
    GeoDataAutoUpdateInterval.threeDays => l.geoAutoUpdateThreeDays,
    GeoDataAutoUpdateInterval.sevenDays => l.geoAutoUpdateSevenDays,
  };
}
