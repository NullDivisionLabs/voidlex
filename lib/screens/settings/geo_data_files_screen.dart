part of '../settings_screen.dart';

class _GeoDataFilesScreen extends StatefulWidget {
  const _GeoDataFilesScreen({
    required this.controller,
    this.useTvChrome = false,
    this.allowTvChromeInAutoRotate = false,
  });

  final VpnController controller;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<_GeoDataFilesScreen> createState() => _GeoDataFilesScreenState();
}

class _GeoDataFilesScreenState extends State<_GeoDataFilesScreen> {
  List<GeoDataFileStatus> _statuses = const [];
  Set<GeoDataKind> _lastBusyKinds = const <GeoDataKind>{};
  bool _loading = true;
  String? _error;

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lastBusyKinds = widget.controller.busyGeoDataKinds;
    widget.controller.addListener(_onControllerChanged);
    _loadStatuses();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final busyKinds = widget.controller.busyGeoDataKinds;
    final completed = _lastBusyKinds.any((kind) => !busyKinds.contains(kind));
    setState(() {
      _lastBusyKinds = busyKinds;
    });
    if (completed) {
      unawaited(_loadStatuses(showLoading: false));
    }
  }

  Future<void> _loadStatuses({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final statuses = await widget.controller.loadGeoDataStatuses();
      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        _loading = false;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = l.geoLoadFailed(e.toString());
      });
    }
  }

  void _showMessage(String message, {ScaffoldMessengerState? messenger}) {
    if (!mounted && messenger == null) return;
    final target = messenger ?? ScaffoldMessenger.maybeOf(context);
    if (target == null) return;
    target
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  GeoDataFileStatus _statusFor(GeoDataKind kind) {
    for (final status in _statuses) {
      if (status.kind == kind) return status;
    }
    return GeoDataFileStatus(
      kind: kind,
      installed: false,
      fileSize: 0,
      updatedAt: null,
      source: GeoDataSource.unknown,
      savedUrl: null,
    );
  }

  Future<void> _updateByUrl(GeoDataKind kind) async {
    final l = AppLocalizations.of(context);
    final status = _statusFor(kind);
    final url = await _showUrlDialog(
      status,
      initialUrl: status.savedUrl?.trim(),
    );
    if (url == null || !mounted) return;
    await _runGeoDataAction(
      kind,
      action: () =>
          widget.controller.updateGeoDataFromUrl(kind: kind, url: url),
      successMessage: l.geoFileUpdated(kind.fileName),
    );
  }

  Future<void> _refreshFromSavedUrl(GeoDataKind kind) async {
    final url = _statusFor(kind).savedUrl?.trim();
    if (url == null || url.isEmpty) {
      _showMessage(AppLocalizations.of(context).geoNoSavedUrl);
      return;
    }
    await _runGeoDataAction(
      kind,
      action: () =>
          widget.controller.updateGeoDataFromUrl(kind: kind, url: url),
      successMessage: AppLocalizations.of(
        context,
      ).geoFileUpdated(kind.fileName),
    );
  }

  Future<void> _loadFromDevice(GeoDataKind kind) async {
    await _runGeoDataAction(
      kind,
      action: () => widget.controller.importGeoDataFromDevice(kind),
      successMessage: AppLocalizations.of(
        context,
      ).geoFileImported(kind.fileName),
    );
  }

  Future<void> _runGeoDataAction(
    GeoDataKind kind, {
    required Future<GeoDataFileStatus?> Function() action,
    required String successMessage,
  }) async {
    if (widget.controller.isGeoDataBusy(kind)) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _error = null);
    try {
      final result = await action();
      if (!mounted) return;
      if (result != null) {
        _showMessage(successMessage, messenger: messenger);
      }
    } on PlatformException catch (e) {
      _showMessage(e.message ?? e.code, messenger: messenger);
    } on FormatException catch (e) {
      _showMessage(e.message, messenger: messenger);
    } catch (e) {
      _showMessage(
        l.geoUpdateFileFailed(kind.fileName, e.toString()),
        messenger: messenger,
      );
    }
  }

  Future<String?> _showUrlDialog(
    GeoDataFileStatus status, {
    String? initialUrl,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _GeoDataUrlDialog(status: status, initialUrl: initialUrl),
    );
  }

  bool _canRefreshFromSavedUrl(GeoDataFileStatus status) {
    final url = status.savedUrl?.trim();
    return status.source == GeoDataSource.url && url != null && url.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) => _buildBody(context, orientation),
    );
  }

  Widget _buildBody(BuildContext context, Orientation orientation) {
    final l = AppLocalizations.of(context);
    final useTvChrome = _useTvSettingsChrome(
      controller: widget.controller,
      requested: widget.useTvChrome,
      allowInAutoRotate: widget.allowTvChromeInAutoRotate,
      orientation: orientation,
    );
    return Scaffold(
      appBar: useTvChrome ? null : AppBar(title: Text(l.geoFilesAppBarTitle)),
      body: _TvSettingsBody(
        enabled: useTvChrome,
        title: l.geoFilesAppBarTitle,
        subtitle: l.routingTooltipGeoFiles,
        child: _GeoDataFilesBody(
          loading: _loading,
          error: _error,
          busyKinds: widget.controller.busyGeoDataKinds,
          progressByKind: widget.controller.geoDataProgressByKind,
          statusFor: _statusFor,
          onRefresh: () => _loadStatuses(showLoading: false),
          onUpdateByUrl: _updateByUrl,
          onRefreshFromSavedUrl: _refreshFromSavedUrl,
          canRefreshFromSavedUrl: _canRefreshFromSavedUrl,
          onLoadFromDevice: _loadFromDevice,
        ),
      ),
    );
  }
}

class _GeoDataUrlDialog extends StatefulWidget {
  const _GeoDataUrlDialog({required this.status, this.initialUrl});

  final GeoDataFileStatus status;
  final String? initialUrl;

  @override
  State<_GeoDataUrlDialog> createState() => _GeoDataUrlDialogState();
}

class _GeoDataUrlDialogState extends State<_GeoDataUrlDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialUrl ?? widget.status.savedUrl ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  String? _validateUrl(String? value) {
    final l = AppLocalizations.of(context);
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return l.geoUrlInvalid;
    }
    return null;
  }

  void _applyPreset(String url) {
    _controller.value = TextEditingValue(
      text: url,
      selection: TextSelection.collapsed(offset: url.length),
    );
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.status.fileName;
    final l = AppLocalizations.of(context);
    final presetButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return AlertDialog(
      title: Text(l.geoUpdateFileTitle(fileName)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l.geoFileUrlLabel,
                hintText: l.geoFileUrlHint(fileName),
              ),
              validator: _validateUrl,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final preset in _GeoDataUrlPresets.forKind(
                  widget.status.kind,
                ))
                  OutlinedButton(
                    style: presetButtonStyle,
                    onPressed: () => _applyPreset(preset.url),
                    child: Text(preset.label),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.geoUpdateByUrl)),
      ],
    );
  }
}

class _GeoDataUrlPreset {
  const _GeoDataUrlPreset({required this.label, required this.url});

  final String label;
  final String url;
}

class _GeoDataUrlPresets {
  static List<_GeoDataUrlPreset> forKind(GeoDataKind kind) {
    switch (kind) {
      case GeoDataKind.geoip:
        return const [
          _GeoDataUrlPreset(
            label: 'Loyalsoldier',
            url:
                'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat',
          ),
          _GeoDataUrlPreset(
            label: 'Runetfreedom',
            url:
                'https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat',
          ),
        ];
      case GeoDataKind.geosite:
        return const [
          _GeoDataUrlPreset(
            label: 'Loyalsoldier',
            url:
                'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat',
          ),
          _GeoDataUrlPreset(
            label: 'Runetfreedom',
            url:
                'https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat',
          ),
        ];
    }
  }
}

class _GeoDataFilesBody extends StatelessWidget {
  const _GeoDataFilesBody({
    required this.loading,
    required this.error,
    required this.busyKinds,
    required this.progressByKind,
    required this.statusFor,
    required this.onRefresh,
    required this.onUpdateByUrl,
    required this.onRefreshFromSavedUrl,
    required this.canRefreshFromSavedUrl,
    required this.onLoadFromDevice,
  });

  final bool loading;
  final String? error;
  final Set<GeoDataKind> busyKinds;
  final Map<GeoDataKind, int?> progressByKind;
  final GeoDataFileStatus Function(GeoDataKind kind) statusFor;
  final Future<void> Function() onRefresh;
  final ValueChanged<GeoDataKind> onUpdateByUrl;
  final ValueChanged<GeoDataKind> onRefreshFromSavedUrl;
  final bool Function(GeoDataFileStatus status) canRefreshFromSavedUrl;
  final ValueChanged<GeoDataKind> onLoadFromDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          for (final kind in GeoDataKind.values) ...[
            _GeoDataFileTile(
              status: statusFor(kind),
              busy: busyKinds.contains(kind),
              progressPercent: progressByKind[kind],
              onUpdateByUrl: () => onUpdateByUrl(kind),
              onRefreshFromSavedUrl: canRefreshFromSavedUrl(statusFor(kind))
                  ? () => onRefreshFromSavedUrl(kind)
                  : null,
              onLoadFromDevice: () => onLoadFromDevice(kind),
            ),
            const SizedBox(height: 12),
          ],
          if (error != null)
            Text(
              error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _GeoDataFileTile extends StatelessWidget {
  const _GeoDataFileTile({
    required this.status,
    required this.busy,
    required this.progressPercent,
    required this.onUpdateByUrl,
    this.onRefreshFromSavedUrl,
    required this.onLoadFromDevice,
  });

  final GeoDataFileStatus status;
  final bool busy;
  final int? progressPercent;
  final VoidCallback onUpdateByUrl;
  final VoidCallback? onRefreshFromSavedUrl;
  final VoidCallback onLoadFromDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status.fileName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onRefreshFromSavedUrl != null)
                  IconButton(
                    onPressed: busy ? null : onRefreshFromSavedUrl,
                    tooltip: l.geoRefreshTooltip,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                SizedBox(
                  width: 88,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: busy
                        ? (progressPercent == null
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '$progressPercent%',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ))
                        : _GeoDataStatusChip(installed: status.installed),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GeoDataMeta(
                        label: l.geoMetaSource,
                        value: _formatGeoDataSource(status, l),
                        minWidth: 180,
                      ),
                      const SizedBox(height: 8),
                      _GeoDataMeta(
                        label: l.geoMetaUpdated,
                        value: _formatGeoDataDate(status.updatedAt, l),
                        minWidth: 158,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 124,
                  child: _GeoDataMeta(
                    label: l.geoMetaSize,
                    value: _formatGeoDataBytes(status.fileSize),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onUpdateByUrl,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(l.geoUpdateByUrl),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onLoadFromDevice,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(l.geoLoadFromDevice),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GeoDataStatusChip extends StatelessWidget {
  const _GeoDataStatusChip({required this.installed});

  final bool installed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final color = installed ? Colors.green.shade600 : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        installed ? l.geoStatusInstalled : l.geoStatusMissing,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          height: 1.1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _GeoDataMeta extends StatelessWidget {
  const _GeoDataMeta({
    required this.label,
    required this.value,
    this.minWidth = 92,
  });

  final String label;
  final String value;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

String _formatGeoDataBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes B';
  return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unit]}';
}

String _formatGeoDataSource(GeoDataFileStatus status, AppLocalizations l) {
  final url = status.savedUrl?.trim();
  if (status.source == GeoDataSource.url && url != null && url.isNotEmpty) {
    return url;
  }
  return switch (status.source) {
    GeoDataSource.unknown => l.geoSourceUnknown,
    GeoDataSource.bundled => l.geoSourceBundled,
    GeoDataSource.url => l.geoSourceUrl,
    GeoDataSource.device => l.geoSourceDevice,
  };
}

String _formatGeoDataDate(DateTime? updatedAt, AppLocalizations l) {
  if (updatedAt == null) return l.geoNeverUpdated;
  final local = updatedAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}, '
      '${two(local.hour)}:${two(local.minute)}';
}
