part of '../settings_screen.dart';

enum _RoutingMenuAction {
  importFromClipboard,
  importFromFile,
  exportRules,
  clearRules,
}

enum _RoutingPresetMenuAction { create, rename, delete }

class RoutingSettingsScreen extends StatefulWidget {
  const RoutingSettingsScreen({
    super.key,
    required this.controller,
    this.isDarkTheme,
    this.onThemeModeChanged,
    required this.localePreference,
    required this.onLocalePreferenceChanged,
    this.showBottomDock = true,
    bool? useTvChrome,
    this.allowTvChromeInAutoRotate = false,
  }) : useTvChrome = useTvChrome ?? !showBottomDock;

  final VpnController controller;

  /// Optional — passed through so the bottom dock can route to Settings with
  /// theme state intact when navigated from the dock.
  final bool? isDarkTheme;
  final ValueChanged<bool>? onThemeModeChanged;
  final AppLocalePreference localePreference;
  final ValueChanged<AppLocalePreference> onLocalePreferenceChanged;
  final bool showBottomDock;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<RoutingSettingsScreen> createState() => _RoutingSettingsScreenState();
}

class _RoutingSettingsScreenState extends State<RoutingSettingsScreen> {
  static const _filePicker = TextFilePicker();
  static const _presetsExpandedPrefKey = 'void.routing.presetsExpanded';

  bool _presetsExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _restorePresetsExpandedState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restorePresetsExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getBool(_presetsExpandedPrefKey);
    if (!mounted || savedValue == null || savedValue == _presetsExpanded) {
      return;
    }
    setState(() => _presetsExpanded = savedValue);
  }

  Future<void> _setPresetsExpanded(bool value) async {
    if (_presetsExpanded == value) return;
    setState(() => _presetsExpanded = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_presetsExpandedPrefKey, value);
  }

  void _showMessage(String message, {ScaffoldMessengerState? messenger}) {
    if (!mounted && messenger == null) return;
    final target = messenger ?? ScaffoldMessenger.maybeOf(context);
    if (target == null) return;
    target
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRoutingRestartNoticeIf(bool wasConnected) {
    if (!wasConnected) return;
    final l = AppLocalizations.of(context);
    _showMessage(l.routingRestartingMessage);
  }

  void _showEditorPresetRestartNoticeIf(bool wasConnected) {
    _showRoutingRestartNoticeIf(
      wasConnected &&
          widget.controller.selectedRoutingPresetAffectsSelectedServer,
    );
  }

  Future<void> _selectRoutingPreset(String id) async {
    if (id == widget.controller.selectedRoutingPresetId) return;
    await widget.controller.selectRoutingPreset(id);
  }

  Future<void> _createRoutingPreset() async {
    final nameController = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l.routingNewPresetDialogTitle),
            content: TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l.routingPresetNameLabel,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(nameController.text),
                child: Text(l.create),
              ),
            ],
          );
        },
      );
      if (name == null) return;
      final error = await widget.controller.createRoutingPreset(name);
      if (error != null) {
        _showMessage(error);
        return;
      }
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _renameRoutingPreset(RoutingPreset preset) async {
    final nameController = TextEditingController(text: preset.name);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l.routingRenamePresetDialogTitle),
            content: TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l.routingPresetNameLabel,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(nameController.text),
                child: Text(l.save),
              ),
            ],
          );
        },
      );
      if (name == null) return;
      final error = await widget.controller.renameRoutingPreset(
        preset.id,
        name,
      );
      if (error != null) _showMessage(error);
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _deleteRoutingPreset(RoutingPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.routingDeletePresetTitle),
          content: Text(preset.name),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final wasConnected = widget.controller.isConnected;
    final selectedName = widget.controller.selectedName;
    final affectedSelected =
        selectedName != null && preset.appliesToServer(selectedName);
    final error = await widget.controller.deleteRoutingPreset(preset.id);
    if (error != null) {
      _showMessage(error);
      return;
    }
    _showRoutingRestartNoticeIf(wasConnected && affectedSelected);
  }

  Future<void> _onPresetMenuAction(
    _RoutingPresetMenuAction action,
    RoutingPreset preset,
  ) async {
    switch (action) {
      case _RoutingPresetMenuAction.create:
        await _createRoutingPreset();
      case _RoutingPresetMenuAction.rename:
        await _renameRoutingPreset(preset);
      case _RoutingPresetMenuAction.delete:
        await _deleteRoutingPreset(preset);
    }
  }

  Future<void> _openEditor({RoutingRule? initial}) async {
    final useTvChrome = _useTvSettingsChrome(
      controller: widget.controller,
      requested: widget.useTvChrome,
      allowInAutoRotate: widget.allowTvChromeInAutoRotate,
    );
    final shouldShowRestartNotice = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _RoutingRuleEditorScreen(
          controller: widget.controller,
          initial: initial,
          useTvChrome: useTvChrome,
          allowTvChromeInAutoRotate: widget.allowTvChromeInAutoRotate,
        ),
      ),
    );
    _showEditorPresetRestartNoticeIf(shouldShowRestartNotice == true);
  }

  Future<void> _openGeoFiles() async {
    final useTvChrome = _useTvSettingsChrome(
      controller: widget.controller,
      requested: widget.useTvChrome,
      allowInAutoRotate: widget.allowTvChromeInAutoRotate,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GeoDataFilesScreen(
          controller: widget.controller,
          useTvChrome: useTvChrome,
          allowTvChromeInAutoRotate: widget.allowTvChromeInAutoRotate,
        ),
      ),
    );
  }

  Future<void> _onMenuAction(_RoutingMenuAction action) async {
    switch (action) {
      case _RoutingMenuAction.importFromClipboard:
        await _importFromClipboard();
      case _RoutingMenuAction.importFromFile:
        await _importFromFile();
      case _RoutingMenuAction.exportRules:
        await _exportToClipboard();
      case _RoutingMenuAction.clearRules:
        await _clearRules();
    }
  }

  Future<void> _importFromClipboard() async {
    final l = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      _showMessage(l.routingClipboardEmpty);
      return;
    }
    await _importPayload(text, source: 'clipboard');
  }

  Future<void> _importFromFile() async {
    final l = AppLocalizations.of(context);
    final String? text;
    try {
      text = await _filePicker.pick();
    } catch (e) {
      _showMessage(l.routingReadFileFailed(e.toString()));
      return;
    }
    if (text == null) return;
    if (text.trim().isEmpty) {
      _showMessage(l.routingFileEmpty);
      return;
    }
    await _importPayload(text, source: 'file');
  }

  Future<void> _importPayload(String raw, {required String source}) async {
    if (widget.controller.routingRules.isNotEmpty) {
      final replace = await _confirmReplace(
        widget.controller.routingRules.length,
      );
      if (replace == null) return;
      await _runImport(raw, replaceExisting: replace, source: source);
    } else {
      await _runImport(raw, replaceExisting: true, source: source);
    }
  }

  Future<void> _runImport(
    String raw, {
    required bool replaceExisting,
    required String source,
  }) async {
    final int count;
    final l = AppLocalizations.of(context);
    final wasConnected = widget.controller.isConnected;
    try {
      count = await widget.controller.importRoutingRulesFromJsonString(
        raw,
        replaceExisting: replaceExisting,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(l.routingParseFailed(e.toString()));
      return;
    }
    if (!mounted) return;
    if (count == 0) {
      _showMessage(l.routingNoRulesInSource);
      return;
    }
    _showEditorPresetRestartNoticeIf(wasConnected);
  }

  Future<bool?> _confirmReplace(int existing) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.routingImportRulesTitle),
          content: Text(l.routingImportRulesBody(existing)),
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

  Future<void> _exportToClipboard() async {
    final l = AppLocalizations.of(context);
    final rules = widget.controller.routingRules;
    if (rules.isEmpty) {
      _showMessage(l.routingNoRulesToExport);
      return;
    }
    final json = widget.controller.exportRoutingRulesAsJsonString();
    await Clipboard.setData(ClipboardData(text: json));
    _showMessage(l.routingCopiedRules(rules.length));
  }

  Future<void> _clearRules() async {
    if (widget.controller.routingRules.isEmpty) {
      _showMessage(AppLocalizations.of(context).routingRulesAlreadyEmpty);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final d = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(d.routingClearRulesTitle),
          content: Text(d.routingClearRulesBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(d.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(d.clear),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final wasConnected = widget.controller.isConnected;
    await widget.controller.clearRoutingRules();
    _showEditorPresetRestartNoticeIf(wasConnected);
  }

  Future<void> _toggleRule(RoutingRule rule, bool enabled) async {
    if (rule.enabled == enabled) return;
    final wasConnected = widget.controller.isConnected;
    await widget.controller.upsertRoutingRule(rule.copyWith(enabled: enabled));
    _showEditorPresetRestartNoticeIf(wasConnected);
  }

  Future<void> _confirmDelete(RoutingRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.routingDeleteRuleTitle),
          content: Text(
            l.routingDeleteRuleBody(rule.name.isEmpty ? l.untitled : rule.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final wasConnected = widget.controller.isConnected;
    await widget.controller.removeRoutingRule(rule.id);
    _showEditorPresetRestartNoticeIf(wasConnected);
  }

  Widget _buildPresetsBlock(ThemeData theme, AppLocalizations l) {
    final preset = widget.controller.selectedRoutingPreset;
    final presets = widget.controller.routingPresets;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.routingPresetsHeading,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(value: _presetsExpanded, onChanged: _setPresetsExpanded),
              ],
            ),
          ),
          if (_presetsExpanded) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: PopupMenuButton<String>(
                          tooltip: l.routingSelectPresetTooltip,
                          onSelected: _selectRoutingPreset,
                          itemBuilder: (context) => [
                            for (final item in presets)
                              PopupMenuItem<String>(
                                value: item.id,
                                child: Row(
                                  children: [
                                    Expanded(child: Text(item.name)),
                                    if (item.id == preset.id)
                                      Icon(
                                        Icons.check_rounded,
                                        color: theme.colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    preset.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.expand_more_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<_RoutingPresetMenuAction>(
                        tooltip: l.routingPresetActionsTooltip,
                        onSelected: (action) =>
                            _onPresetMenuAction(action, preset),
                        itemBuilder: (context) => [
                          PopupMenuItem<_RoutingPresetMenuAction>(
                            value: _RoutingPresetMenuAction.create,
                            child: Text(l.routingCreatePresetMenu),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<_RoutingPresetMenuAction>(
                            value: _RoutingPresetMenuAction.rename,
                            enabled: !preset.isMain,
                            child: Text(l.routingRenamePresetMenu),
                          ),
                          PopupMenuItem<_RoutingPresetMenuAction>(
                            value: _RoutingPresetMenuAction.delete,
                            enabled: !preset.isMain,
                            child: Text(l.routingDeletePresetMenu),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) => _buildBody(context, orientation),
    );
  }

  Widget _buildBody(BuildContext context, Orientation orientation) {
    final theme = Theme.of(context);
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    final rules = widget.controller.routingRules;
    final useTvChrome = _useTvSettingsChrome(
      controller: widget.controller,
      requested: widget.useTvChrome,
      allowInAutoRotate: widget.allowTvChromeInAutoRotate,
      orientation: orientation,
    );
    final showBottomDock = !useTvChrome;
    final routingActions = [
      IconButton(
        tooltip: l.routingTooltipAdd,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
      ),
      IconButton(
        tooltip: l.routingTooltipGeoFiles,
        onPressed: _openGeoFiles,
        icon: const Icon(Icons.insert_drive_file_rounded),
      ),
      PopupMenuButton<_RoutingMenuAction>(
        tooltip: l.more,
        onSelected: _onMenuAction,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _RoutingMenuAction.importFromClipboard,
            child: Text(l.routingMenuImportClipboard),
          ),
          PopupMenuItem(
            value: _RoutingMenuAction.importFromFile,
            child: Text(l.routingMenuImportFile),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _RoutingMenuAction.exportRules,
            child: Text(l.routingMenuExportClipboard),
          ),
          PopupMenuItem(
            value: _RoutingMenuAction.clearRules,
            child: Text(l.routingMenuClearRules),
          ),
        ],
      ),
    ];
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
                l.routingScreenTitle,
                style: VoidType.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: t.fg1,
                ),
              ),
              actions: routingActions,
            ),
      body: _TvSettingsBody(
        enabled: useTvChrome,
        title: l.routingScreenTitle,
        subtitle: l.settingsRoutingSubtitle,
        actions: useTvChrome ? routingActions : const [],
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPresetsBlock(theme, l),
                    SizedBox(height: useTvChrome ? 16 : 12),
                    if (useTvChrome)
                      TvSettingsCard(
                        icon: Icons.apps_rounded,
                        title: l.routingTileAppRouting,
                        onTap: () async {
                          final shouldShowRestartNotice =
                              await Navigator.of(context).push<bool>(
                                MaterialPageRoute<bool>(
                                  builder: (_) => _AppRoutingScreen(
                                    controller: widget.controller,
                                    useTvChrome: useTvChrome,
                                    allowTvChromeInAutoRotate:
                                        widget.allowTvChromeInAutoRotate,
                                  ),
                                ),
                              );
                          _showEditorPresetRestartNoticeIf(
                            shouldShowRestartNotice == true,
                          );
                        },
                      )
                    else
                      _RoutingActionTile(
                        title: l.routingTileAppRouting,
                        onTap: () async {
                          final shouldShowRestartNotice =
                              await Navigator.of(context).push<bool>(
                                MaterialPageRoute<bool>(
                                  builder: (_) => _AppRoutingScreen(
                                    controller: widget.controller,
                                    useTvChrome: useTvChrome,
                                    allowTvChromeInAutoRotate:
                                        widget.allowTvChromeInAutoRotate,
                                  ),
                                ),
                              );
                          _showEditorPresetRestartNoticeIf(
                            shouldShowRestartNotice == true,
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    Text(
                      l.routingCustomRulesHeading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (rules.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Text(
                          l.routingNoCustomRulesYet,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: rules.length,
                        onReorder: (oldIndex, newIndex) async {
                          final wasConnected = widget.controller.isConnected;
                          await widget.controller.reorderRoutingRule(
                            oldIndex,
                            newIndex,
                          );
                          _showEditorPresetRestartNoticeIf(wasConnected);
                        },
                        proxyDecorator: (child, _, _) => Material(
                          color: Colors.transparent,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(14),
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final rule = rules[index];
                          return Padding(
                            key: ValueKey(rule.id),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _RoutingRuleTile(
                              rule: rule,
                              index: index,
                              onTap: () => _openEditor(initial: rule),
                              onToggle: (value) => _toggleRule(rule, value),
                              onDelete: () => _confirmDelete(rule),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (showBottomDock)
              VoidDock(
                current: DockItem.route,
                controller: widget.controller,
                isDarkTheme:
                    widget.isDarkTheme ??
                    Theme.of(context).brightness == Brightness.dark,
                onThemeModeChanged: widget.onThemeModeChanged ?? ((_) {}),
                localePreference: widget.localePreference,
                onLocalePreferenceChanged: widget.onLocalePreferenceChanged,
              ),
          ],
        ),
      ),
    );
  }
}
