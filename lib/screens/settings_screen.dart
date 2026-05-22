import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../core/app_locale.dart';
import '../core/app_routing.dart';
import '../core/app_log.dart';
import '../core/device_identity.dart';
import '../core/geo_data.dart';
import '../core/installed_apps.dart';
import '../core/multiplex_settings.dart';
import '../core/profile_file_exporter.dart';
import '../core/profile_importer.dart';
import '../core/routing_preset.dart';
import '../core/routing_rule.dart';
import '../core/server_latency_probe.dart';
import '../core/server_repository.dart';
import '../core/subscription_provider_settings.dart';
import '../core/text_file_picker.dart';
import '../core/tunnel_fragment_settings.dart';
import '../core/tunnel_network_settings.dart';
import '../core/tv_layout_preference.dart';
import '../core/tun_engine_mode.dart';
import '../core/vpn_controller.dart';
import '../theme.dart';
import 'tv/widgets/tv_overlay_shell.dart';
import 'tv/widgets/tv_settings_card.dart';
import 'widgets/bottom_dock.dart';
import 'widgets/void_dock.dart';

part 'settings/log_journal_screen.dart';
part 'settings/tunnel_settings_screen.dart';
part 'settings/routing_settings_screen.dart';
part 'settings/geo_data_files_screen.dart';
part 'settings/routing_rule_widgets.dart';
part 'settings/app_routing_screen.dart';
part 'settings/routing_rule_editor_screen.dart';
part 'settings/subscription_provider_settings_screen.dart';
part 'settings/application_settings_screen.dart';
part 'settings/faq_screen.dart';
part 'settings/settings_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.isDarkTheme,
    required this.onThemeModeChanged,
    required this.localePreference,
    required this.onLocalePreferenceChanged,
    this.showBottomDock = true,
    bool? useTvChrome,
    this.allowTvChromeInAutoRotate = false,
  }) : useTvChrome = useTvChrome ?? !showBottomDock;

  final VpnController controller;
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeModeChanged;
  final AppLocalePreference localePreference;
  final ValueChanged<AppLocalePreference> onLocalePreferenceChanged;
  final bool showBottomDock;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _deviceIdentityBridge = DeviceIdentityBridge();

  late bool _isDarkTheme;
  String _deviceHwid = 'Loading...';

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;
    widget.controller.repository.tvLayoutPreferenceListenable.addListener(
      _handleTvLayoutPreferenceChanged,
    );
    _loadDeviceHwid();
  }

  @override
  void dispose() {
    widget.controller.repository.tvLayoutPreferenceListenable.removeListener(
      _handleTvLayoutPreferenceChanged,
    );
    super.dispose();
  }

  void _handleTvLayoutPreferenceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDeviceHwid() async {
    try {
      final hwid = await _deviceIdentityBridge.getHwid();
      if (!mounted) return;
      setState(() {
        _deviceHwid = hwid.trim().isEmpty ? 'Unavailable' : hwid.trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _deviceHwid = 'Unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final localeScope = AppLocaleScope.maybeOf(context);
    final localePreference = localeScope?.preference ?? widget.localePreference;
    final onLocalePreferenceChanged =
        localeScope?.onPreferenceChanged ?? widget.onLocalePreferenceChanged;
    return OrientationBuilder(
      builder: (context, orientation) {
        return _buildBody(
          context: context,
          l: l,
          localePreference: localePreference,
          onLocalePreferenceChanged: onLocalePreferenceChanged,
          orientation: orientation,
        );
      },
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AppLocalizations l,
    required AppLocalePreference localePreference,
    required ValueChanged<AppLocalePreference> onLocalePreferenceChanged,
    required Orientation orientation,
  }) {
    final t = VoidTokens.of(context);
    final useTvChrome = _useTvSettingsChrome(
      controller: widget.controller,
      requested: widget.useTvChrome,
      allowInAutoRotate: widget.allowTvChromeInAutoRotate,
      orientation: orientation,
    );
    final showBottomDock = !useTvChrome;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: showBottomDock
          ? AppBar(
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(
                l.settingsConfigTitle,
                style: VoidType.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: t.fg1,
                ),
              ),
            )
          : null,
      body: _TvSettingsBody(
        enabled: useTvChrome,
        title: l.settingsConfigTitle,
        subtitle: l.settingsSectionsHeading,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: useTvChrome
                    ? EdgeInsets.zero
                    : const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: useTvChrome
                    ? _buildTvSections(
                        l: l,
                        localePreference: localePreference,
                        onLocalePreferenceChanged: onLocalePreferenceChanged,
                      )
                    : _buildMobileSections(
                        l: l,
                        localePreference: localePreference,
                        onLocalePreferenceChanged: onLocalePreferenceChanged,
                      ),
              ),
            ),
            if (showBottomDock)
              VoidDock(
                current: DockItem.config,
                controller: widget.controller,
                isDarkTheme: _isDarkTheme,
                onThemeModeChanged: (value) {
                  setState(() => _isDarkTheme = value);
                  widget.onThemeModeChanged(value);
                },
                localePreference: localePreference,
                onLocalePreferenceChanged: onLocalePreferenceChanged,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSections({
    required AppLocalizations l,
    required AppLocalePreference localePreference,
    required ValueChanged<AppLocalePreference> onLocalePreferenceChanged,
  }) {
    final routes = _settingsRoutes(
      localePreference: localePreference,
      onLocalePreferenceChanged: onLocalePreferenceChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSectionHeading(l.settingsSectionsHeading),
        const SizedBox(height: 4),
        for (var i = 0; i < routes.length; i++) ...[
          if (i != 0) const SizedBox(height: 8),
          _SettingsSectionTile(
            icon: routes[i].icon,
            title: routes[i].title,
            subtitle: routes[i].subtitle,
            onTap: routes[i].onTap,
          ),
        ],
        const SizedBox(height: 24),
        _SettingsSectionHeading(
          l.settingsAboutHeading,
          trailing: _AboutFaqLink(
            label: l.settingsFaqLabel,
            onTap: _openFaqScreen,
          ),
        ),
        _AboutRow(label: l.settingsVersionLabel, value: '1.0.1-beta'),
        _AboutRow(label: l.settingsXrayCoreLabel, value: '26.5.9'),
        _AboutRow(label: l.settingsLibboxLabel, value: '1.14.0-alpha.24'),
        _AboutRow(label: l.settingsHwidLabel, value: _deviceHwid),
        _AboutRow(
          label: l.settingsProtocolLabel,
          value: l.settingsProtocolValue,
        ),
        const _AboutBrandFooter(),
      ],
    );
  }

  Widget _buildTvSections({
    required AppLocalizations l,
    required AppLocalePreference localePreference,
    required ValueChanged<AppLocalePreference> onLocalePreferenceChanged,
  }) {
    final routes = _settingsRoutes(
      localePreference: localePreference,
      onLocalePreferenceChanged: onLocalePreferenceChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvSettingsSectionLabel(l.settingsSectionsHeading),
        for (var i = 0; i < routes.length; i++) ...[
          if (i != 0) const SizedBox(height: 16),
          TvSettingsCard(
            icon: routes[i].icon,
            title: routes[i].title,
            subtitle: routes[i].subtitle,
            onTap: routes[i].onTap,
          ),
        ],
        const SizedBox(height: 28),
        TvSettingsSectionLabel(
          l.settingsAboutHeading,
          trailing: _AboutFaqLink(
            label: l.settingsFaqLabel,
            onTap: _openFaqScreen,
          ),
        ),
        _AboutRow(label: l.settingsVersionLabel, value: '1.0.1-beta'),
        _AboutRow(label: l.settingsXrayCoreLabel, value: '26.5.9'),
        _AboutRow(label: l.settingsLibboxLabel, value: '1.14.0-alpha.24'),
        _AboutRow(label: l.settingsHwidLabel, value: _deviceHwid),
        _AboutRow(
          label: l.settingsProtocolLabel,
          value: l.settingsProtocolValue,
        ),
        const _AboutBrandFooter(),
      ],
    );
  }

  void _openFaqScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FaqScreen(
          controller: widget.controller,
          useTvChrome: widget.useTvChrome,
          allowTvChromeInAutoRotate: widget.allowTvChromeInAutoRotate,
        ),
      ),
    );
  }

  List<_SettingsRouteSpec> _settingsRoutes({
    required AppLocalePreference localePreference,
    required ValueChanged<AppLocalePreference> onLocalePreferenceChanged,
  }) {
    final l = AppLocalizations.of(context);
    return <_SettingsRouteSpec>[
      _SettingsRouteSpec(
        icon: Icons.alt_route_rounded,
        title: l.settingsRoutingTitle,
        subtitle: l.settingsRoutingSubtitle,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RoutingSettingsScreen(
                controller: widget.controller,
                isDarkTheme: _isDarkTheme,
                onThemeModeChanged: widget.onThemeModeChanged,
                localePreference: localePreference,
                onLocalePreferenceChanged: onLocalePreferenceChanged,
                showBottomDock: widget.showBottomDock,
                useTvChrome: widget.useTvChrome,
                allowTvChromeInAutoRotate: widget.allowTvChromeInAutoRotate,
              ),
            ),
          );
        },
      ),
      _SettingsRouteSpec(
        icon: Icons.hub_rounded,
        title: l.settingsTunnelTitle,
        subtitle: l.settingsTunnelSubtitle,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _TunnelSettingsScreen(
                controller: widget.controller,
                useTvChrome: widget.useTvChrome,
                allowTvChromeInAutoRotate: widget.allowTvChromeInAutoRotate,
              ),
            ),
          );
          if (mounted) setState(() {});
        },
      ),
      _SettingsRouteSpec(
        icon: Icons.sync_rounded,
        title: l.settingsSubscriptionsTitle,
        subtitle: l.settingsSubscriptionsSubtitle,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _SubscriptionProviderSettingsScreen(
                controller: widget.controller,
                useTvChrome: widget.useTvChrome,
                allowTvChromeInAutoRotate: widget.allowTvChromeInAutoRotate,
              ),
            ),
          );
        },
      ),
      _SettingsRouteSpec(
        icon: _isDarkTheme
            ? Icons.dark_mode_rounded
            : Icons.light_mode_rounded,
        title: l.settingsApplicationTitle,
        subtitle: l.settingsApplicationSubtitle,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _ApplicationSettingsScreen(
                controller: widget.controller,
                repository: widget.controller.repository,
                isDarkTheme: _isDarkTheme,
                localePreference: localePreference,
                onLocalePreferenceChanged: onLocalePreferenceChanged,
                onThemeModeChanged: (value) {
                  setState(() => _isDarkTheme = value);
                  widget.onThemeModeChanged(value);
                },
                useTvChrome: widget.useTvChrome,
                allowTvChromeInAutoRotate: widget.allowTvChromeInAutoRotate,
              ),
            ),
          );
        },
      ),
      _SettingsRouteSpec(
        icon: Icons.article_rounded,
        title: l.logJournalTitle,
        subtitle: l.settingsLogJournalSubtitle,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _LogJournalScreen(controller: widget.controller),
            ),
          );
        },
      ),
    ];
  }
}

/// Plain row describing a Settings section row → used by both the TV
/// card list and the mobile tile list so the two layouts share the
/// same icon / title / subtitle / handler triple.
class _SettingsRouteSpec {
  const _SettingsRouteSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
