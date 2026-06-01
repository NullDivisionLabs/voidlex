part of '../settings_screen.dart';

String _logLevelL10n(AppLocalizations l, AppLogLevel level) {
  return switch (level) {
    AppLogLevel.debug => l.logLevelDebug,
    AppLogLevel.info => l.logLevelInfo,
    AppLogLevel.warning => l.logLevelWarning,
    AppLogLevel.error => l.logLevelError,
  };
}

String _xrayLogLevelLabel() => 'XRAY';

String _logRetentionL10n(AppLocalizations l, AppLogRetention retention) {
  return switch (retention) {
    AppLogRetention.oneHour => l.logRetentionOneHour,
    AppLogRetention.oneDay => l.logRetentionOneDay,
    AppLogRetention.oneWeek => l.logRetentionOneWeek,
    AppLogRetention.forever => l.logRetentionForever,
  };
}

String _appLocaleLabel(AppLocalizations l, AppLocalePreference p) {
  return switch (p) {
    AppLocalePreference.system => l.appLanguageAuto,
    AppLocalePreference.english => l.appLanguageEnglish,
    AppLocalePreference.russian => l.appLanguageRussian,
  };
}

String _tvLayoutPreferenceLabel(AppLocalizations l, TvLayoutPreference p) {
  return switch (p) {
    TvLayoutPreference.vertical => l.tvLayoutVertical,
    TvLayoutPreference.horizontal => l.tvLayoutHorizontal,
    TvLayoutPreference.autoRotate => l.tvLayoutAutoRotate,
  };
}

class _ApplicationSettingsScreen extends StatefulWidget {
  const _ApplicationSettingsScreen({
    required this.controller,
    required this.repository,
    required this.isDarkTheme,
    required this.localePreference,
    required this.onLocalePreferenceChanged,
    required this.onThemeModeChanged,
    this.useTvChrome = false,
    this.allowTvChromeInAutoRotate = false,
  });

  final VpnController controller;
  final ServerRepository repository;
  final bool isDarkTheme;
  final AppLocalePreference localePreference;
  final ValueChanged<AppLocalePreference> onLocalePreferenceChanged;
  final ValueChanged<bool> onThemeModeChanged;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<_ApplicationSettingsScreen> createState() =>
      _ApplicationSettingsScreenState();
}

class _ApplicationSettingsScreenState
    extends State<_ApplicationSettingsScreen> {
  static const _filePicker = TextFilePicker();
  static const _profileFileExporter = ProfileFileExporter();

  late bool _isDarkTheme;
  late AppLocalePreference _language;
  TvLayoutPreference _tvLayoutPreference = TvLayoutPreference.vertical;
  bool _autoConnectOnLaunch = false;
  bool _killSwitchEnabled = false;
  bool _restartOnSettingsChange = false;
  bool _showSpeedInNotification = false;
  bool _keepAwake = false;
  bool _verboseXrayLogs = false;
  bool _showGlobalProxyButton = false;
  bool _autoSortServersByPing = false;
  LatencyProbeTarget _latencyProbeTarget = LatencyProbeTarget.serverEndpoint;
  bool _profileImportBusy = false;
  bool _profileExportBusy = false;
  bool _closing = false;
  Set<AppLogLevel> _logLevels = Set<AppLogLevel>.of(AppLogLevel.defaultLevels);
  AppLogRetention _logRetention = AppLogRetention.defaultRetention;

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;
    _language = widget.localePreference;
    _tvLayoutPreference = widget.repository.loadTvLayoutPreference();
    _autoConnectOnLaunch = widget.controller.autoConnectOnLaunch;
    _killSwitchEnabled = widget.controller.killSwitchEnabled;
    _restartOnSettingsChange =
        widget.controller.restartConnectionOnSettingsChanges;
    _showGlobalProxyButton = widget.controller.showGlobalProxyButton;
    _autoSortServersByPing = widget.controller.autoSortServersByPing;
    _latencyProbeTarget = widget.controller.latencyProbeTarget;
    _showSpeedInNotification = widget.controller.showSpeedInNotification;
    _keepAwake = widget.controller.keepAwake;
    _verboseXrayLogs = widget.controller.verboseXrayLogs;
    _logLevels = widget.controller.logLevels;
    _logRetention = widget.controller.logRetention;
  }

  @override
  void didUpdateWidget(covariant _ApplicationSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkTheme != widget.isDarkTheme) {
      _isDarkTheme = widget.isDarkTheme;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppLocaleScope.maybeOf(context);
    final language = scope?.preference ?? widget.localePreference;
    if (_language != language) {
      _language = language;
    }
  }

  Future<void> _setRestartOnSettingsChange(bool value) async {
    if (_restartOnSettingsChange == value) return;
    setState(() => _restartOnSettingsChange = value);
    await widget.controller.setRestartConnectionOnSettingsChanges(value);
    if (!mounted) return;
    setState(() {
      _restartOnSettingsChange =
          widget.controller.restartConnectionOnSettingsChanges;
    });
  }

  Future<void> _setAutoConnectOnLaunch(bool value) async {
    if (_autoConnectOnLaunch == value) return;
    setState(() => _autoConnectOnLaunch = value);
    await widget.controller.setAutoConnectOnLaunch(value);
    if (!mounted) return;
    setState(() {
      _autoConnectOnLaunch = widget.controller.autoConnectOnLaunch;
    });
  }

  Future<void> _setKillSwitchEnabled(bool value) async {
    if (_killSwitchEnabled == value) return;
    setState(() => _killSwitchEnabled = value);
    await widget.controller.setKillSwitchEnabled(value);
    if (!mounted) return;
    setState(() {
      _killSwitchEnabled = widget.controller.killSwitchEnabled;
    });
  }

  Future<void> _openSystemVpnSettings() async {
    await widget.controller.openSystemVpnSettings();
  }

  Future<void> _showUrlSchemesSheet() async {
    final l = AppLocalizations.of(context);
    final useTvChrome = _useTvSettingsChrome(
      controller: widget.controller,
      requested: widget.useTvChrome,
      allowInAutoRotate: widget.allowTvChromeInAutoRotate,
      orientation: MediaQuery.of(context).orientation,
    );
    if (useTvChrome) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _UrlSchemesScreen(useTvChrome: true, l: l),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _UrlSchemesSheet(l: l),
      );
    }
  }

  Future<void> _setTvLayoutPreference(TvLayoutPreference value) async {
    if (_tvLayoutPreference == value) return;
    setState(() => _tvLayoutPreference = value);
    await widget.repository.saveTvLayoutPreference(value);
    if (!mounted) return;
    setState(() {
      _tvLayoutPreference = widget.repository.loadTvLayoutPreference();
    });
  }

  Future<void> _showTvLayoutPicker(BuildContext anchorContext) async {
    final l = AppLocalizations.of(context);
    final box = anchorContext.findRenderObject() as RenderBox?;
    final selected = await showMenu<TvLayoutPreference>(
      context: context,
      position: box == null
          ? null
          : RelativeRect.fromRect(
              box.localToGlobal(Offset.zero) & box.size,
              Offset.zero & MediaQuery.sizeOf(context),
            ),
      items: [
        for (final preference in TvLayoutPreference.values)
          CheckedPopupMenuItem<TvLayoutPreference>(
            value: preference,
            checked: preference == _tvLayoutPreference,
            child: Text(_tvLayoutPreferenceLabel(l, preference)),
          ),
      ],
    );
    if (selected != null) await _setTvLayoutPreference(selected);
  }

  Future<void> _setShowGlobalProxyButton(bool value) async {
    if (_showGlobalProxyButton == value) return;
    setState(() => _showGlobalProxyButton = value);
    await widget.controller.setShowGlobalProxyButton(value);
    if (!mounted) return;
    setState(() {
      _showGlobalProxyButton = widget.controller.showGlobalProxyButton;
    });
  }

  Future<void> _setAutoSortServersByPing(bool value) async {
    if (_autoSortServersByPing == value) return;
    setState(() => _autoSortServersByPing = value);
    await widget.controller.setAutoSortServersByPing(value);
    if (!mounted) return;
    setState(() {
      _autoSortServersByPing = widget.controller.autoSortServersByPing;
    });
  }

  Future<void> _setLatencyProbeTarget(LatencyProbeTarget target) async {
    if (_latencyProbeTarget.hasSameConfiguration(target)) return;
    setState(() => _latencyProbeTarget = target);
    await widget.controller.setLatencyProbeTarget(target);
    if (!mounted) return;
    setState(() {
      _latencyProbeTarget = widget.controller.latencyProbeTarget;
    });
  }

  Future<void> _setShowSpeedInNotification(bool value) async {
    if (_showSpeedInNotification == value) return;
    setState(() => _showSpeedInNotification = value);
    await widget.controller.setShowSpeedInNotification(value);
    if (!mounted) return;
    setState(() {
      _showSpeedInNotification = widget.controller.showSpeedInNotification;
    });
  }

  Future<void> _setKeepAwake(bool value) async {
    if (_keepAwake == value) return;
    setState(() => _keepAwake = value);
    await widget.controller.setKeepAwake(value);
    if (!mounted) return;
    setState(() {
      _keepAwake = widget.controller.keepAwake;
    });
  }

  Future<void> _setLogSettings(
    Set<AppLogLevel> levels,
    AppLogRetention retention,
    bool verboseXrayLogs,
  ) async {
    final nextLevels = Set<AppLogLevel>.of(levels);
    setState(() {
      _logLevels = nextLevels;
      _logRetention = retention;
      _verboseXrayLogs = verboseXrayLogs;
    });
    await widget.controller.setLogLevels(nextLevels);
    await widget.controller.setLogRetention(retention);
    await widget.controller.setVerboseXrayLogs(verboseXrayLogs);
    if (!mounted) return;
    setState(() {
      _logLevels = widget.controller.logLevels;
      _logRetention = widget.controller.logRetention;
      _verboseXrayLogs = widget.controller.verboseXrayLogs;
    });
  }

  String _logSettingsLabel(AppLocalizations l) {
    final retentionLabel = l.keepPrefix(_logRetentionL10n(l, _logRetention));
    final labels = <String>[
      if (_logLevels.contains(AppLogLevel.debug))
        _logLevelL10n(l, AppLogLevel.debug),
      if (_verboseXrayLogs) _xrayLogLevelLabel(),
      if (_logLevels.contains(AppLogLevel.info))
        _logLevelL10n(l, AppLogLevel.info),
      if (_logLevels.contains(AppLogLevel.warning))
        _logLevelL10n(l, AppLogLevel.warning),
      if (_logLevels.contains(AppLogLevel.error))
        _logLevelL10n(l, AppLogLevel.error),
    ];
    if (labels.isEmpty) {
      return l.levelsSelectedNone(retentionLabel);
    }
    return l.levelsSelectedSome(labels.join(', '), retentionLabel);
  }

  String _latencyProbeTargetLabel(AppLocalizations l) {
    return _latencyProbeTarget.usesServerEndpoint
        ? l.applicationSettingsPingTargetDefault
        : _latencyProbeTarget.encode();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportProfile() async {
    if (_profileExportBusy) return;
    final l = AppLocalizations.of(context);
    final hasProtectedSubscriptions =
        widget.controller.subscriptionProviderSettings.protectSubscriptions &&
        widget.controller.subscriptions.isNotEmpty;
    setState(() => _profileExportBusy = true);
    try {
      final content = await widget.controller.exportProfileAsJsonString();
      final exported = await _profileFileExporter.export(
        content: content,
        fileName: _defaultProfileExportName(),
      );
      if (!mounted) return;
      if (exported) {
        _showMessage(
          hasProtectedSubscriptions
              ? l.profileExportProtectedSubscriptionsEncrypted
              : l.profileExportedText,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(l.profileExportFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _profileExportBusy = false);
    }
  }

  Future<void> _importProfile() async {
    if (_profileImportBusy) return;
    final l = AppLocalizations.of(context);
    setState(() => _profileImportBusy = true);
    try {
      final String? text;
      try {
        text = await _filePicker.pickJson();
      } on PlatformException catch (e) {
        if (!mounted) return;
        _showMessage(e.message ?? l.profileImportReadFailed);
        return;
      } catch (e) {
        if (!mounted) return;
        _showMessage(l.profileImportReadFailedDetail(e.toString()));
        return;
      }
      if (!mounted || text == null) return;
      if (text.trim().isEmpty) {
        _showMessage(l.profileImportFileEmpty);
        return;
      }

      final replaceExisting = _hasExistingProfileData()
          ? await _confirmProfileImportMode()
          : true;
      if (!mounted || replaceExisting == null) return;

      final result = await widget.controller.importProfileFromJsonString(
        text,
        replaceExisting: replaceExisting,
      );
      if (!mounted) return;
      _showMessage(_profileImportResultMessage(l, result));
    } on ProfileImportException catch (e) {
      if (!mounted) return;
      _showMessage(l.profileImportFailed(_profileImportErrorMessage(l, e)));
    } catch (e) {
      if (!mounted) return;
      _showMessage(l.profileImportFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _profileImportBusy = false);
    }
  }

  bool _hasExistingProfileData() {
    return widget.controller.hasAnyServers ||
        widget.controller.routingPresets.any(
          (preset) =>
              !preset.isMain ||
              preset.routingRules.isNotEmpty ||
              preset.appRoutingPolicy.isActive,
        );
  }

  Future<bool?> _confirmProfileImportMode() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.profileImportModeTitle),
          content: Text(l.profileImportModeBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.append),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.replace),
            ),
          ],
        );
      },
    );
  }

  String _profileImportResultMessage(
    AppLocalizations l,
    ProfileImportResult result,
  ) {
    final base = result.protectedSubscriptionFailureCount > 0
        ? l.profileImportedWithProtectedFailures(
            result.manualNodeCount,
            result.subscriptionCount,
            result.routingPresetCount,
            result.protectedSubscriptionFailureCount,
          )
        : l.profileImportedText(
            result.manualNodeCount,
            result.subscriptionCount,
            result.routingPresetCount,
          );
    if (result.droppedAppRoutingPackageCount > 0) {
      return base +
          l.profileImportedAppRoutingMissingSuffix(
            result.droppedAppRoutingPackageCount,
          );
    }
    return base;
  }

  String _profileImportErrorMessage(
    AppLocalizations l,
    ProfileImportException error,
  ) {
    return switch (error.code) {
      ProfileImportError.empty => l.profileImportFileEmpty,
      ProfileImportError.invalidJson => l.profileImportInvalidJson,
      ProfileImportError.unsupportedFormat => l.profileImportUnsupportedFormat,
      ProfileImportError.unsupportedVersion =>
        l.profileImportUnsupportedVersion,
      ProfileImportError.emptyProfile => l.profileImportEmptyProfile,
      ProfileImportError.payloadTooLarge => l.profileImportTooLarge,
    };
  }

  String _defaultProfileExportName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${now.year}${two(now.month)}${two(now.day)}';
    final time = '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'voidlex-profile-$date-$time.json';
  }

  Future<void> _showLanguageDialog() async {
    const options = AppLocalePreference.values;
    final selected = await showDialog<AppLocalePreference>(
      context: context,
      builder: (context) {
        final dl = AppLocalizations.of(context);
        return SimpleDialog(
          title: Text(dl.appLanguageTitle),
          children: [
            for (final language in options)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(language),
                child: Row(
                  children: [
                    Expanded(child: Text(_appLocaleLabel(dl, language))),
                    if (language == _language)
                      Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
    if (!mounted) return;
    final scope = AppLocaleScope.maybeOf(context);
    final current = scope?.preference ?? _language;
    if (selected == null || selected == current) return;
    setState(() => _language = selected);
    (scope?.onPreferenceChanged ?? widget.onLocalePreferenceChanged)(selected);
  }

  Future<void> _showLatencyProbeTargetDialog() async {
    final selected = await showDialog<LatencyProbeTarget>(
      context: context,
      builder: (context) =>
          _LatencyProbeTargetDialog(initialTarget: _latencyProbeTarget),
    );
    if (!mounted || selected == null) return;
    await _setLatencyProbeTarget(selected);
  }

  Future<void> _showLogSettingsDialog() async {
    var draftLevels = Set<AppLogLevel>.of(_logLevels);
    var draftRetention = _logRetention;
    var draftVerboseXrayLogs = _verboseXrayLogs;
    final selected = await showDialog<_LogSettingsSelection>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void toggleLevel(AppLogLevel level, bool enabled) {
              setDialogState(() {
                if (enabled) {
                  draftLevels.add(level);
                } else {
                  draftLevels.remove(level);
                }
              });
            }

            void toggleVerboseXrayLogs(bool enabled) {
              setDialogState(() {
                draftVerboseXrayLogs = enabled;
              });
            }

            Widget logLevelTile(AppLogLevel level) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_logLevelL10n(AppLocalizations.of(context), level)),
                value: draftLevels.contains(level),
                onChanged: (value) => toggleLevel(level, value ?? false),
              );
            }

            return AlertDialog(
              title: Text(AppLocalizations.of(context).logSettingsDialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    logLevelTile(AppLogLevel.debug),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_xrayLogLevelLabel()),
                      value: draftVerboseXrayLogs,
                      onChanged: (value) =>
                          toggleVerboseXrayLogs(value ?? false),
                    ),
                    logLevelTile(AppLogLevel.info),
                    logLevelTile(AppLogLevel.warning),
                    logLevelTile(AppLogLevel.error),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        AppLocalizations.of(context).logStorageTimeLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      trailing: PopupMenuButton<AppLogRetention>(
                        initialValue: draftRetention,
                        tooltip: AppLocalizations.of(
                          context,
                        ).logStorageTimeTooltip,
                        onSelected: (retention) {
                          setDialogState(() => draftRetention = retention);
                        },
                        itemBuilder: (context) => [
                          for (final retention in AppLogRetention.values)
                            CheckedPopupMenuItem<AppLogRetention>(
                              value: retention,
                              checked: retention == draftRetention,
                              child: Text(
                                _logRetentionL10n(
                                  AppLocalizations.of(context),
                                  retention,
                                ),
                              ),
                            ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _logRetentionL10n(
                                AppLocalizations.of(context),
                                draftRetention,
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _LogSettingsSelection(
                      levels: draftLevels,
                      retention: draftRetention,
                      verboseXrayLogs: draftVerboseXrayLogs,
                    ),
                  ),
                  child: Text(AppLocalizations.of(context).done),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null) return;
    await _setLogSettings(
      selected.levels,
      selected.retention,
      selected.verboseXrayLogs,
    );
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    final controller = widget.controller;
    if (!mounted) return;
    Navigator.of(context).pop();
    unawaited(controller.applyPendingNetworkSettingsRestart());
  }

  bool get _usePhoneSettingTileLayout =>
      _tvLayoutPreference == TvLayoutPreference.vertical;

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
        return _buildScaffold(
          context: context,
          theme: theme,
          l: l,
          useTvChrome: useTvChrome,
        );
      },
    );
  }

  /// Emits the right settings row widget based on whether the parent
  /// screen is showing the TV chrome or the mobile chrome.
  Widget _row({
    required bool useTvChrome,
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
      compactWhenNarrow: !_usePhoneSettingTileLayout,
      onTap: onTap,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    );
  }

  Widget _buildScaffold({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l,
    required bool useTvChrome,
  }) {
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_close());
      },
      child: Scaffold(
        appBar: useTvChrome
            ? null
            : AppBar(title: Text(l.applicationSettingsTitle)),
        body: _TvSettingsBody(
          enabled: useTvChrome,
          title: l.applicationSettingsTitle,
          subtitle: l.settingsApplicationSubtitle,
          onBack: _close,
          child: useTvChrome
              ? TvSettingsScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _applicationSettingsColumn(
                      context: context,
                      theme: theme,
                      l: l,
                      useTvChrome: useTvChrome,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _applicationSettingsColumn(
                      context: context,
                      theme: theme,
                      l: l,
                      useTvChrome: useTvChrome,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _applicationSettingsColumn({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l,
    required bool useTvChrome,
  }) {
    return [
                Text(
                  l.themeSection,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      icon: const Icon(Icons.light_mode_rounded, size: 16),
                      label: Text(l.themeLight),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: const Icon(Icons.dark_mode_rounded, size: 16),
                      label: Text(l.themeDark),
                    ),
                  ],
                  selected: {_isDarkTheme},
                  onSelectionChanged: (selection) {
                    final value = selection.first;
                    setState(() => _isDarkTheme = value);
                    widget.onThemeModeChanged(value);
                  },
                ),
                const SizedBox(height: 18),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.language_rounded,
                  title: l.appLanguageTitle,
                  subtitle: l.appLanguageSubtitle,
                  onTap: _showLanguageDialog,
                  autofocus: useTvChrome,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _appLocaleLabel(l, _language),
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
                if (!useTvChrome) ...[
                  SizedBox(height: useTvChrome ? 14 : 10),
                  _row(
                    useTvChrome: useTvChrome,
                    icon: Icons.public_rounded,
                    title: l.applicationSettingsShowGlobalProxyTitle,
                    subtitle: l.applicationSettingsGlobalProxySubtitle,
                    onTap: () =>
                        _setShowGlobalProxyButton(!_showGlobalProxyButton),
                    trailing: Switch(
                      value: _showGlobalProxyButton,
                      onChanged: _setShowGlobalProxyButton,
                    ),
                  ),
                ],
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.view_quilt_outlined,
                  title: l.tvLayoutSectionTitle,
                  subtitle: l.tvLayoutSectionSubtitle,
                  onTap: useTvChrome
                      ? () => unawaited(_showTvLayoutPicker(context))
                      : null,
                  trailing: PopupMenuButton<TvLayoutPreference>(
                    initialValue: _tvLayoutPreference,
                    tooltip: l.tvLayoutSectionTitle,
                    onSelected: (preference) {
                      unawaited(_setTvLayoutPreference(preference));
                    },
                    itemBuilder: (context) => [
                      for (final preference in TvLayoutPreference.values)
                        CheckedPopupMenuItem<TvLayoutPreference>(
                          value: preference,
                          checked: preference == _tvLayoutPreference,
                          child: Text(
                            _tvLayoutPreferenceLabel(
                              AppLocalizations.of(context),
                              preference,
                            ),
                          ),
                        ),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _tvLayoutPreferenceLabel(l, _tvLayoutPreference),
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
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.sort_rounded,
                  title: l.applicationSettingsAutoSortServersByPingTitle,
                  subtitle: l.applicationSettingsAutoSortServersByPingSubtitle,
                  onTap: () =>
                      _setAutoSortServersByPing(!_autoSortServersByPing),
                  trailing: Switch(
                    value: _autoSortServersByPing,
                    onChanged: _setAutoSortServersByPing,
                  ),
                ),
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.power_settings_new_outlined,
                  title: l.autoConnectOnLaunchTitle,
                  subtitle: l.autoConnectOnLaunchSubtitle,
                  onTap: () => _setAutoConnectOnLaunch(!_autoConnectOnLaunch),
                  trailing: Switch(
                    value: _autoConnectOnLaunch,
                    onChanged: _setAutoConnectOnLaunch,
                  ),
                ),
                if (Platform.isAndroid) ...[
                  SizedBox(height: useTvChrome ? 14 : 10),
                  _row(
                    useTvChrome: useTvChrome,
                    icon: Icons.power_outlined,
                    title: l.autoConnectOnBootTitle,
                    subtitle: l.autoConnectOnBootSubtitle,
                    onTap: _openSystemVpnSettings,
                    trailing: const Icon(Icons.open_in_new_rounded),
                  ),
                ],
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.shield_outlined,
                  title: l.killSwitchTitle,
                  subtitle: l.killSwitchSubtitle,
                  onTap: () => _setKillSwitchEnabled(!_killSwitchEnabled),
                  trailing: Switch(
                    value: _killSwitchEnabled,
                    onChanged: _setKillSwitchEnabled,
                  ),
                ),
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.link_rounded,
                  title: l.urlSchemesTitle,
                  subtitle: l.urlSchemesSubtitle,
                  onTap: _showUrlSchemesSheet,
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.restart_alt_rounded,
                  title: l.restartOnSettingsChangeTitle,
                  onTap: () =>
                      _setRestartOnSettingsChange(!_restartOnSettingsChange),
                  trailing: Switch(
                    value: _restartOnSettingsChange,
                    onChanged: _setRestartOnSettingsChange,
                  ),
                ),
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.speed_rounded,
                  title: l.showSpeedInNotificationTitle,
                  onTap: () =>
                      _setShowSpeedInNotification(!_showSpeedInNotification),
                  trailing: Switch(
                    value: _showSpeedInNotification,
                    onChanged: _setShowSpeedInNotification,
                  ),
                ),
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.battery_saver_outlined,
                  title: l.keepAwakeTitle,
                  subtitle: l.keepAwakeSubtitle,
                  onTap: () => _setKeepAwake(!_keepAwake),
                  trailing: Switch(value: _keepAwake, onChanged: _setKeepAwake),
                ),
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.network_ping_rounded,
                  title: l.applicationSettingsPingTargetTitle,
                  subtitle: _latencyProbeTargetLabel(l),
                  onTap: _showLatencyProbeTargetDialog,
                  trailing: const Icon(Icons.expand_more_rounded),
                ),
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.article_outlined,
                  title: l.logSettingsTitle,
                  subtitle: _logSettingsLabel(l),
                  onTap: _showLogSettingsDialog,
                  trailing: const Icon(Icons.expand_more_rounded),
                ),
                SizedBox(height: useTvChrome ? 22 : 18),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.file_upload_rounded,
                  title: l.profileImportTitle,
                  subtitle: l.profileImportSubtitle,
                  onTap: _profileImportBusy ? null : _importProfile,
                  trailing: _profileImportBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                ),
                SizedBox(height: useTvChrome ? 14 : 10),
                _row(
                  useTvChrome: useTvChrome,
                  icon: Icons.file_download_rounded,
                  title: l.profileExportTitle,
                  subtitle: l.profileExportSubtitle,
                  onTap: _profileExportBusy ? null : _exportProfile,
                  trailing: _profileExportBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                ),
    ];
  }
}

class _LogSettingsSelection {
  const _LogSettingsSelection({
    required this.levels,
    required this.retention,
    required this.verboseXrayLogs,
  });

  final Set<AppLogLevel> levels;
  final AppLogRetention retention;
  final bool verboseXrayLogs;
}

class _LatencyProbeTargetDialog extends StatefulWidget {
  const _LatencyProbeTargetDialog({required this.initialTarget});

  final LatencyProbeTarget initialTarget;

  @override
  State<_LatencyProbeTargetDialog> createState() =>
      _LatencyProbeTargetDialogState();
}

class _LatencyProbeTargetDialogState extends State<_LatencyProbeTargetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialTarget.usesServerEndpoint
          ? ''
          : widget.initialTarget.encode(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final target = LatencyProbeTarget.tryParse(_controller.text);
    if (target == null) return;
    Navigator.of(context).pop(target);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.applicationSettingsPingTargetDialogTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l.applicationSettingsPingTargetFieldLabel,
            hintText: l.applicationSettingsPingTargetHint,
          ),
          validator: (value) {
            final target = LatencyProbeTarget.tryParse(value ?? '');
            return target == null
                ? l.applicationSettingsPingTargetInvalid
                : null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(LatencyProbeTarget.serverEndpoint),
          child: Text(l.applicationSettingsPingTargetReset),
        ),
        FilledButton(onPressed: _submit, child: Text(l.save)),
      ],
    );
  }
}

class _ApplicationSettingTile extends StatelessWidget {
  const _ApplicationSettingTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
    this.compactWhenNarrow = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  /// Stacked title + trailing on one row for narrow widths (TV layouts).
  /// Disabled in [TvLayoutPreference.vertical] phone layout.
  final bool compactWhenNarrow;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = compactWhenNarrow && constraints.maxWidth < 520;
        return Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: compact
                  ? _ApplicationSettingTileCompact(
                      icon: icon,
                      title: title,
                      subtitle: subtitle,
                      trailing: trailing,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                                  s,
                                  style: VoidType.sans(
                                    fontSize: 12,
                                    color: t.fg2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        trailing,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ApplicationSettingTileCompact extends StatelessWidget {
  const _ApplicationSettingTileCompact({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: t.fg2, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VoidType.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.fg1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
        if (subtitle case final s?) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              s,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: VoidType.sans(
                fontSize: 12,
                color: t.fg2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _UrlSchemeEntry {
  const _UrlSchemeEntry({required this.uri});
  final String uri;
}

class _UrlSchemeGroup {
  const _UrlSchemeGroup({required this.title, required this.entries});
  final String title;
  final List<_UrlSchemeEntry> entries;
}

List<_UrlSchemeGroup> _buildUrlSchemeGroups(AppLocalizations l) {
  return [
    _UrlSchemeGroup(
      title: l.urlSchemesStartSection,
      entries: const [
        _UrlSchemeEntry(uri: 'voidlex://connect'),
        _UrlSchemeEntry(uri: 'voidlex://open'),
      ],
    ),
    _UrlSchemeGroup(
      title: l.urlSchemesStopSection,
      entries: const [
        _UrlSchemeEntry(uri: 'voidlex://disconnect'),
        _UrlSchemeEntry(uri: 'voidlex://close'),
      ],
    ),
    _UrlSchemeGroup(
      title: l.urlSchemesToggleSection,
      entries: const [
        _UrlSchemeEntry(uri: 'voidlex://toggle'),
      ],
    ),
    _UrlSchemeGroup(
      title: l.urlSchemesRestartSection,
      entries: const [
        _UrlSchemeEntry(uri: 'voidlex://restart'),
      ],
    ),
    _UrlSchemeGroup(
      title: l.urlSchemesImportSection,
      entries: const [
        _UrlSchemeEntry(uri: 'voidlex://import/{base64}'),
      ],
    ),
    _UrlSchemeGroup(
      title: l.urlSchemesImportRulesetSection,
      entries: const [
        _UrlSchemeEntry(uri: 'voidlex://import-ruleset/{URL}'),
      ],
    ),
  ];
}

Future<void> _copyUrlScheme(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(l.urlSchemeCopied)),
  );
}

class _UrlSchemesSheet extends StatelessWidget {
  const _UrlSchemesSheet({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _buildUrlSchemeGroups(l);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              l.urlSchemesTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.urlSchemesNoteHeader,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.urlSchemesNote,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
                child: Text(
                  group.title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < group.entries.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(
                          group.entries[i].uri,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () => _copyUrlScheme(
                            context,
                            group.entries[i].uri,
                          ),
                        ),
                        onTap: () => _copyUrlScheme(
                          context,
                          group.entries[i].uri,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _UrlSchemesScreen extends StatelessWidget {
  const _UrlSchemesScreen({required this.l, required this.useTvChrome});
  final AppLocalizations l;
  final bool useTvChrome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _buildUrlSchemeGroups(l);
    final body = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.urlSchemesNote,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 6),
              child: Text(
                group.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final entry in group.entries)
              Card(
                child: ListTile(
                  title: Text(
                    entry.uri,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copyUrlScheme(context, entry.uri),
                  ),
                  onTap: () => _copyUrlScheme(context, entry.uri),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
    if (useTvChrome) {
      return Scaffold(
        body: _TvSettingsBody(
          enabled: true,
          title: l.urlSchemesTitle,
          subtitle: l.urlSchemesSubtitle,
          onBack: () => Navigator.of(context).maybePop(),
          child: body,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.urlSchemesTitle)),
      body: body,
    );
  }
}
