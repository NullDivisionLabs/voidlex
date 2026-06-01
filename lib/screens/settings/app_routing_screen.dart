part of '../settings_screen.dart';

class _AppRoutingScreen extends StatefulWidget {
  const _AppRoutingScreen({
    required this.controller,
    this.useTvChrome = false,
    this.allowTvChromeInAutoRotate = false,
  });

  final VpnController controller;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<_AppRoutingScreen> createState() => _AppRoutingScreenState();
}

class _AppRoutingScreenState extends State<_AppRoutingScreen> {
  static const _bridge = InstalledAppsBridge();

  late AppRoutingMode _mode;
  late Set<String> _proxySelected;
  late Set<String> _bypassSelected;
  late Set<String> _proxySelectedOnOpen;
  late Set<String> _bypassSelectedOnOpen;
  final TextEditingController _searchController = TextEditingController();
  bool _hideSystemApps = true;
  bool _loading = true;
  bool _closing = false;
  bool _showRoutingRestartNoticeOnExit = false;
  String? _loadError;
  List<InstalledApp> _apps = const [];

  @override
  void initState() {
    super.initState();
    final policy = widget.controller.appRoutingPolicy;
    _mode = policy.mode == AppRoutingMode.off
        ? AppRoutingMode.proxy
        : policy.mode;
    _proxySelected = Set<String>.of(policy.proxyPackages);
    _bypassSelected = Set<String>.of(policy.bypassPackages);
    _proxySelectedOnOpen = Set<String>.of(_proxySelected);
    _bypassSelectedOnOpen = Set<String>.of(_bypassSelected);
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final apps = await _bridge.list();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() {
        _loadError = l.appRoutingLoadFailed(e.toString());
        _loading = false;
      });
    }
  }

  List<InstalledApp> get _visibleApps {
    final source = _hideSystemApps
        ? _apps.where((app) => !app.isSystem)
        : _apps;
    return prioritizeSelectedInstalledApps(source, _selectedOnOpenForMode);
  }

  Set<String> get _selectedForMode => switch (_mode) {
    AppRoutingMode.proxy => _proxySelected,
    AppRoutingMode.bypass => _bypassSelected,
    AppRoutingMode.off => _proxySelected,
  };

  Set<String> get _selectedOnOpenForMode => switch (_mode) {
    AppRoutingMode.proxy => _proxySelectedOnOpen,
    AppRoutingMode.bypass => _bypassSelectedOnOpen,
    AppRoutingMode.off => _proxySelectedOnOpen,
  };

  List<InstalledApp> get _filteredVisibleApps {
    final q = _searchController.text.trim().toLowerCase();
    final base = _visibleApps;
    if (q.isEmpty) return base;
    return base
        .where(
          (app) =>
              app.name.toLowerCase().contains(q) ||
              app.packageName.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _onModeChanged(AppRoutingMode mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    await _persistPolicy();
  }

  Future<void> _onPackageToggled(String packageName, bool selected) async {
    setState(() {
      final active = _selectedForMode;
      if (selected) {
        active.add(packageName);
      } else {
        active.remove(packageName);
      }
    });
    await _persistPolicy();
  }

  Future<void> _persistPolicy() async {
    final nextPolicy = AppRoutingPolicy(
      mode: _mode,
      proxyPackages: Set<String>.of(_proxySelected),
      bypassPackages: Set<String>.of(_bypassSelected),
    );
    if (widget.controller.appRoutingPolicy.hasSameConfiguration(nextPolicy)) {
      return;
    }
    final wasConnected = widget.controller.isConnected;
    if (wasConnected) _showRoutingRestartNoticeOnExit = true;
    await widget.controller.setAppRoutingPolicy(nextPolicy);
  }

  void _close() {
    if (_closing) return;
    final result = _showRoutingRestartNoticeOnExit;
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) => _buildBody(context, orientation),
    );
  }

  Widget _buildBody(BuildContext context, Orientation orientation) {
    final theme = Theme.of(context);
    final visibleApps = _filteredVisibleApps;
    final l = AppLocalizations.of(context);
    final useTvChrome = _useTvSettingsChrome(
      controller: widget.controller,
      requested: widget.useTvChrome,
      allowInAutoRotate: widget.allowTvChromeInAutoRotate,
      orientation: orientation,
    );
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        appBar: useTvChrome
            ? null
            : AppBar(
                leading: IconButton(
                  onPressed: _close,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: Text(l.appRoutingTitle),
              ),
        body: _TvSettingsBody(
          enabled: useTvChrome,
          title: l.appRoutingTitle,
          subtitle: l.routingTileAppRouting,
          onBack: _close,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    SegmentedButton<AppRoutingMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment<AppRoutingMode>(
                          value: AppRoutingMode.proxy,
                          label: Text(l.appRoutingViaProxy),
                        ),
                        ButtonSegment<AppRoutingMode>(
                          value: AppRoutingMode.bypass,
                          label: Text(l.appRoutingBypass),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (selection) {
                        _onModeChanged(selection.first);
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.appRoutingHideSystemApps,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TvSettingsNonFocusTrailing(
                            child: Switch(
                              value: _hideSystemApps,
                              onChanged: (value) {
                                setState(() => _hideSystemApps = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSearchField(theme: theme, l: l, useTvChrome: useTvChrome),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildList(
                  theme,
                  visibleApps,
                  useTvChrome: useTvChrome,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField({
    required ThemeData theme,
    required AppLocalizations l,
    required bool useTvChrome,
  }) {
    final field = TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      autocorrect: false,
      decoration: InputDecoration(
        isDense: true,
        hintText: l.appRoutingSearchHint,
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: l.appRoutingClearTooltip,
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
      ),
    );
    return useTvChrome ? tvDpadEscapeTextField(field) : field;
  }

  Widget _buildList(
    ThemeData theme,
    List<InstalledApp> visibleApps, {
    required bool useTvChrome,
  }) {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _loadError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadInstalledApps, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }

    if (_visibleApps.isEmpty) {
      return Center(
        child: Text(
          _hideSystemApps ? l.appRoutingNoUserApps : l.appRoutingNoAppList,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    if (visibleApps.isEmpty) {
      return Center(
        child: Text(
          l.appRoutingNoMatchingApps,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      padding: useTvChrome
          ? const EdgeInsets.fromLTRB(8, 16, 8, 20)
          // Keep a small gap under the search field.
          // Without it, oversized tiles / shadows from the first row can
          // visually overlap the header area while scrolling.
          : const EdgeInsets.fromLTRB(20, 16, 20, 20),
      // TV tiles may render focus rings / glows outside their own bounds.
      // Keep them clipped to the list viewport so they can't overlap the
      // header area (search field) while scrolling.
      clipBehavior: Clip.hardEdge,
      itemCount: visibleApps.length,
      separatorBuilder: (_, _) => SizedBox(height: useTvChrome ? 10 : 8),
      itemBuilder: (context, index) {
        final app = visibleApps[index];
        final selected = _selectedForMode.contains(app.packageName);
        return _AppRoutingTile(
          app: app,
          selected: selected,
          tvFocusable: useTvChrome,
          autofocus: useTvChrome && index == 0,
          onChanged: (value) => _onPackageToggled(app.packageName, value),
        );
      },
    );
  }
}

class _AppRoutingTile extends StatefulWidget {
  const _AppRoutingTile({
    required this.app,
    required this.selected,
    required this.onChanged,
    this.tvFocusable = false,
    this.autofocus = false,
  });

  final InstalledApp app;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final bool tvFocusable;
  final bool autofocus;

  @override
  State<_AppRoutingTile> createState() => _AppRoutingTileState();
}

class _AppRoutingTileState extends State<_AppRoutingTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          _AppIcon(app: widget.app, theme: theme),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.app.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.app.packageName,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TvSettingsNonFocusTrailing(
            child: Switch(
              value: widget.selected,
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );

    if (!widget.tvFocusable) return tile;
    return TvFocusRing(
      focused: _focused,
      radius: 12,
      // Keep row geometry stable in per-app list: only draw ring/glow.
      // Scaling here makes the focused tile look taller than the card slot.
      scaleWhenFocused: 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onChanged(!widget.selected),
          onFocusChange: (value) {
            if (_focused == value) return;
            setState(() => _focused = value);
          },
          child: tile,
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app, required this.theme});

  static const _bridge = InstalledAppsBridge();

  final InstalledApp app;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bridge.iconPng(app.packageName),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _AppIconFallback(name: app.name, theme: theme);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.memory(
            bytes,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                _AppIconFallback(name: app.name, theme: theme),
          ),
        );
      },
    );
  }
}

class _AppIconFallback extends StatelessWidget {
  const _AppIconFallback({required this.name, required this.theme});

  final String name;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
