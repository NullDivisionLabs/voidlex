import 'package:flutter/material.dart';

import '../../core/app_locale.dart';
import '../../core/vpn_controller.dart';
import '../../l10n/app_localizations.dart';
import '../settings_screen.dart';
import 'add_node_sheet.dart';
import 'bottom_dock.dart';

/// Bottom dock wired to the app's standard navigation.
///
/// HUB pops back to the home route. ADD opens the add-node sheet over the
/// current screen. ROUTE / CONFIG are pushed from HUB and replace each other
/// directly so HUB does not flash during tab-to-tab navigation.
class VoidDock extends StatelessWidget {
  const VoidDock({
    super.key,
    required this.current,
    required this.controller,
    required this.isDarkTheme,
    required this.onThemeModeChanged,
    required this.localePreference,
    required this.onLocalePreferenceChanged,
  });

  final DockItem current;
  final VpnController controller;
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeModeChanged;
  final AppLocalePreference localePreference;
  final ValueChanged<AppLocalePreference> onLocalePreferenceChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final localeScope = AppLocaleScope.maybeOf(context);
    final effectiveLocalePreference =
        localeScope?.preference ?? localePreference;
    final effectiveOnLocalePreferenceChanged =
        localeScope?.onPreferenceChanged ?? onLocalePreferenceChanged;
    return BottomDock(
      active: current,
      hubLabel: l.dockHub,
      addLabel: l.dockAdd,
      routeLabel: l.dockRoute,
      configLabel: l.dockConfig,
      onSelect: (tapped) {
        if (tapped == current) return;
        switch (tapped) {
          case DockItem.hub:
            Navigator.of(context).popUntil((r) => r.isFirst);
            break;
          case DockItem.add:
            showAddNodeSheet(context, controller);
            break;
          case DockItem.route:
            _openDockPage(
              context,
              _DockPageRoute<void>(
                builder: (_) => RoutingSettingsScreen(
                  controller: controller,
                  isDarkTheme: isDarkTheme,
                  onThemeModeChanged: onThemeModeChanged,
                  localePreference: effectiveLocalePreference,
                  onLocalePreferenceChanged: effectiveOnLocalePreferenceChanged,
                ),
              ),
            );
            break;
          case DockItem.config:
            _openDockPage(
              context,
              _DockPageRoute<void>(
                builder: (_) => SettingsScreen(
                  controller: controller,
                  isDarkTheme: isDarkTheme,
                  onThemeModeChanged: onThemeModeChanged,
                  localePreference: effectiveLocalePreference,
                  onLocalePreferenceChanged: effectiveOnLocalePreferenceChanged,
                ),
              ),
            );
            break;
        }
      },
    );
  }

  void _openDockPage(BuildContext context, Route<void> route) {
    final navigator = Navigator.of(context);
    if (current == DockItem.hub) {
      navigator.push(route);
      return;
    }
    navigator.pushReplacement(route);
  }
}

class _DockPageRoute<T> extends MaterialPageRoute<T> {
  _DockPageRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
