part of '../settings_screen.dart';

class _SubscriptionProviderSettingsScreen extends StatefulWidget {
  const _SubscriptionProviderSettingsScreen({
    required this.controller,
    this.useTvChrome = false,
    this.allowTvChromeInAutoRotate = false,
  });

  final VpnController controller;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<_SubscriptionProviderSettingsScreen> createState() =>
      _SubscriptionProviderSettingsScreenState();
}

class _SubscriptionProviderSettingsScreenState
    extends State<_SubscriptionProviderSettingsScreen> {
  late SubscriptionProviderSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.controller.subscriptionProviderSettings;
  }

  Future<void> _setSettings(SubscriptionProviderSettings settings) async {
    final normalized = settings.normalized();
    if (_settings.hasSameConfiguration(normalized)) return;
    setState(() => _settings = normalized);
    await widget.controller.setSubscriptionProviderSettings(normalized);
  }

  Future<void> _setUpdateInterval(SubscriptionUpdateInterval interval) {
    return _setSettings(_settings.copyWith(updateInterval: interval));
  }

  Future<void> _setPingOnUpdate(bool value) {
    return _setSettings(_settings.copyWith(pingOnUpdate: value));
  }

  Future<void> _setUpdateOnLaunch(bool value) {
    return _setSettings(_settings.copyWith(updateOnLaunch: value));
  }

  Future<void> _setSendHwid(bool value) {
    return _setSettings(_settings.copyWith(sendHwid: value));
  }

  Future<void> _setAllowInsecureTls(bool value) {
    return _setSettings(_settings.copyWith(allowInsecureTls: value));
  }

  Future<void> _setProtectSubscriptions(bool value) {
    return _setSettings(_settings.copyWith(protectSubscriptions: value));
  }

  Future<void> _showUpdateIntervalPicker(BuildContext anchorContext) async {
    final l = AppLocalizations.of(context);
    final box = anchorContext.findRenderObject() as RenderBox?;
    final selected = await showMenu<SubscriptionUpdateInterval>(
      context: context,
      position: box == null
          ? null
          : RelativeRect.fromRect(
              box.localToGlobal(Offset.zero) & box.size,
              Offset.zero & MediaQuery.sizeOf(context),
            ),
      items: [
        for (final interval in SubscriptionUpdateInterval.values)
          CheckedPopupMenuItem<SubscriptionUpdateInterval>(
            value: interval,
            checked: interval == _settings.updateInterval,
            child: Text(_subscriptionUpdateIntervalLabel(l, interval)),
          ),
      ],
    );
    if (selected != null) await _setUpdateInterval(selected);
  }

  Widget _row({
    required bool useTvChrome,
    required bool compactWhenNarrow,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool autofocus = false,
  }) {
    if (useTvChrome) {
      return TvSettingsCard(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        autofocus: autofocus,
      );
    }
    return _ApplicationSettingTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      compactWhenNarrow: compactWhenNarrow,
      onTap: onTap,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OrientationBuilder(
      builder: (context, orientation) {
        final theme = Theme.of(context);
        final useTvChrome = _useTvSettingsChrome(
          controller: widget.controller,
          requested: widget.useTvChrome,
          allowInAutoRotate: widget.allowTvChromeInAutoRotate,
          orientation: orientation,
        );
        return Scaffold(
          appBar: useTvChrome
              ? null
              : AppBar(title: Text(l.providerSettingsTitle)),
          body: _TvSettingsBody(
            enabled: useTvChrome,
            title: l.providerSettingsTitle,
            subtitle: l.settingsSubscriptionsSubtitle,
            child: ValueListenableBuilder<TvLayoutPreference>(
              valueListenable:
                  widget.controller.repository.tvLayoutPreferenceListenable,
              builder: (context, tvLayoutPreference, _) {
                final compactWhenNarrow =
                    tvLayoutPreference != TvLayoutPreference.vertical;
                final gap = useTvChrome ? 14.0 : 10.0;
                final scrollChild = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (useTvChrome)
                        TvSettingsSectionLabel(l.providerSubscriptionsHeading)
                      else ...[
                        Text(
                          l.providerSubscriptionsHeading,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _row(
                        useTvChrome: useTvChrome,
                        compactWhenNarrow: compactWhenNarrow,
                        icon: Icons.update_rounded,
                        title: l.providerAutoUpdateIntervalTitle,
                        subtitle: l.providerAutoUpdateIntervalSubtitle,
                        onTap: useTvChrome
                            ? () => unawaited(_showUpdateIntervalPicker(context))
                            : null,
                        autofocus: useTvChrome,
                        trailing: PopupMenuButton<SubscriptionUpdateInterval>(
                          initialValue: _settings.updateInterval,
                          tooltip: l.providerAutoUpdateIntervalTooltip,
                          onSelected: (interval) {
                            unawaited(_setUpdateInterval(interval));
                          },
                          itemBuilder: (context) => [
                            for (final interval
                                in SubscriptionUpdateInterval.values)
                              CheckedPopupMenuItem<SubscriptionUpdateInterval>(
                                value: interval,
                                checked:
                                    interval == _settings.updateInterval,
                                child: Text(
                                  _subscriptionUpdateIntervalLabel(
                                    AppLocalizations.of(context),
                                    interval,
                                  ),
                                ),
                              ),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _subscriptionUpdateIntervalLabel(
                                  l,
                                  _settings.updateInterval,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.expand_more_rounded),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: gap),
                      _row(
                        useTvChrome: useTvChrome,
                        compactWhenNarrow: compactWhenNarrow,
                        icon: Icons.network_ping_rounded,
                        title: l.providerPingAfterUpdateTitle,
                        subtitle: l.providerPingAfterUpdateSubtitle,
                        onTap: () => _setPingOnUpdate(!_settings.pingOnUpdate),
                        trailing: Switch(
                          value: _settings.pingOnUpdate,
                          onChanged: _setPingOnUpdate,
                        ),
                      ),
                      SizedBox(height: gap),
                      _row(
                        useTvChrome: useTvChrome,
                        compactWhenNarrow: compactWhenNarrow,
                        icon: Icons.rocket_launch_rounded,
                        title: l.providerUpdateOnLaunchTitle,
                        subtitle: l.providerUpdateOnLaunchSubtitle,
                        onTap: () =>
                            _setUpdateOnLaunch(!_settings.updateOnLaunch),
                        trailing: Switch(
                          value: _settings.updateOnLaunch,
                          onChanged: _setUpdateOnLaunch,
                        ),
                      ),
                      SizedBox(height: gap),
                      _row(
                        useTvChrome: useTvChrome,
                        compactWhenNarrow: compactWhenNarrow,
                        icon: Icons.fingerprint_rounded,
                        title: l.providerSendHwidTitle,
                        subtitle: l.providerSendHwidSubtitle,
                        onTap: () => _setSendHwid(!_settings.sendHwid),
                        trailing: Switch(
                          value: _settings.sendHwid,
                          onChanged: _setSendHwid,
                        ),
                      ),
                      SizedBox(height: gap),
                      _row(
                        useTvChrome: useTvChrome,
                        compactWhenNarrow: compactWhenNarrow,
                        icon: Icons.gpp_maybe_rounded,
                        title: l.providerAllowInsecureTitle,
                        subtitle: l.providerAllowInsecureSubtitle,
                        onTap: () =>
                            _setAllowInsecureTls(!_settings.allowInsecureTls),
                        trailing: Switch(
                          value: _settings.allowInsecureTls,
                          onChanged: _setAllowInsecureTls,
                        ),
                      ),
                      SizedBox(height: gap),
                      _row(
                        useTvChrome: useTvChrome,
                        compactWhenNarrow: compactWhenNarrow,
                        icon: Icons.lock_rounded,
                        title: l.providerProtectSubscriptionsTitle,
                        subtitle: l.providerProtectSubscriptionsSubtitle,
                        onTap: () => _setProtectSubscriptions(
                          !_settings.protectSubscriptions,
                        ),
                        trailing: Switch(
                          value: _settings.protectSubscriptions,
                          onChanged: _setProtectSubscriptions,
                        ),
                      ),
                    ],
                  );
                return useTvChrome
                    ? TvSettingsScrollView(child: scrollChild)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: scrollChild,
                      );
              },
            ),
          ),
        );
      },
    );
  }
}

String _subscriptionUpdateIntervalLabel(
  AppLocalizations l,
  SubscriptionUpdateInterval interval,
) {
  switch (interval) {
    case SubscriptionUpdateInterval.oneHour:
      return l.subscriptionIntervalOneHour;
    case SubscriptionUpdateInterval.threeHours:
      return l.subscriptionIntervalThreeHours;
    case SubscriptionUpdateInterval.sixHours:
      return l.subscriptionIntervalSixHours;
    case SubscriptionUpdateInterval.twelveHours:
      return l.subscriptionIntervalTwelveHours;
  }
}
