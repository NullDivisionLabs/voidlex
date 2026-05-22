import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../core/server_config_exporter.dart';
import '../core/models/server_config.dart';
import '../core/vpn_controller.dart';
import '../theme.dart';
import 'widgets/orientation_gate.dart';
import 'widgets/protocol_selector.dart';

enum _ServerCopyAction { url, json }

class EditServerScreen extends StatefulWidget {
  const EditServerScreen({
    super.key,
    required this.controller,
    required this.server,
  });

  final VpnController controller;
  final ServerConfig server;

  @override
  State<EditServerScreen> createState() => _EditServerScreenState();
}

class _EditServerScreenState extends State<EditServerScreen> {
  static const _supportedProtocols = <ServerProtocol>[
    ServerProtocol.vless,
    ServerProtocol.hysteria2,
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _aliasController;
  late final TextEditingController _addressController;
  late final TextEditingController _portController;
  late final TextEditingController _uuidController;
  late final TextEditingController _pathController;
  late final TextEditingController _serviceNameController;
  late final TextEditingController _hostController;
  late final TextEditingController _sniController;
  late final TextEditingController _alpnController;
  late final TextEditingController _shortIdController;
  late final TextEditingController _publicKeyController;
  late final TextEditingController _obfsPasswordController;
  late final TextEditingController _hopPortsController;
  late final TextEditingController _xhttpPaddingController;
  late final TextEditingController _xhttpMaxPostController;
  late final TextEditingController _xhttpMinIntervalController;

  late ServerProtocol _protocol;
  late VlessTransport _transport;
  late VlessSecurity _security;
  // xhttp mode: empty string = "Auto", otherwise one of the
  // _xhttpModeOptions values. Kept as String so the empty-default round-trips
  // unchanged through ServerConfig.transportMode.
  late String _xhttpMode;
  // uTLS fingerprint. Empty = "Auto (none)" — the Android side substitutes
  // "chrome" specifically for xhttp at build time, and leaves it blank for
  // other transports. Imported values outside the known list are preserved
  // as-is via [_extendedFingerprintOptions].
  late String _fingerprint;
  late bool _tlsInsecure;
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isBusy => _isSaving || _isDeleting;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _aliasController = TextEditingController(text: server.name);
    _addressController = TextEditingController(text: server.address);
    _portController = TextEditingController(text: server.port.toString());
    _uuidController = TextEditingController(text: server.uuid);
    _pathController = TextEditingController(text: server.transportPath);
    _serviceNameController = TextEditingController(
      text: server.transportServiceName,
    );
    _hostController = TextEditingController(text: server.transportHost);
    _sniController = TextEditingController(text: server.sni);
    _alpnController = TextEditingController(text: server.alpn);
    _shortIdController = TextEditingController(text: server.realityShortId);
    _publicKeyController = TextEditingController(text: server.realityPublicKey);
    _obfsPasswordController = TextEditingController(
      text: server.hysteria2ObfsPassword,
    );
    _hopPortsController = TextEditingController(text: server.hysteria2HopPorts);
    _xhttpPaddingController = TextEditingController(text: server.xhttpPadding);
    _xhttpMaxPostController = TextEditingController(
      text: server.xhttpMaxPostBytes,
    );
    _xhttpMinIntervalController = TextEditingController(
      text: server.xhttpMinPostInterval,
    );
    _protocol = server.isHysteria2
        ? ServerProtocol.hysteria2
        : ServerProtocol.vless;
    _transport = server.transport;
    _security = server.security;
    _xhttpMode = _normalizeXhttpMode(server.transportMode);
    _fingerprint = server.fingerprint.trim();
    _tlsInsecure = server.tlsInsecure;
  }

  /// Coerces a free-form transportMode string into one of the dropdown
  /// values. Unknown / blank values collapse to "" (Auto), which lets the
  /// Android side substitute its curated default (stream-up).
  static String _normalizeXhttpMode(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (_xhttpModeOptions.contains(trimmed)) return trimmed;
    return '';
  }

  static const _xhttpModeOptions = <String>[
    '',
    'stream-up',
    'packet-up',
    'stream-one',
  ];

  /// Known uTLS fingerprints the xray-core runtime accepts (see
  /// xtls/xray-core/transport/internet/tls/utls.go). Empty = "Auto", which
  /// lets the Android builder pick chrome for xhttp and nothing otherwise.
  /// 360 / qq are kept in the list for completeness — the embedded
  /// libxray.so supports them — but they're unusual outside CN traffic.
  static const _fingerprintOptions = <String>[
    '',
    'chrome',
    'firefox',
    'safari',
    'ios',
    'android',
    'edge',
    '360',
    'qq',
    'random',
    'randomized',
  ];

  /// Returns the fingerprint dropdown list with [current] appended when
  /// it's a non-standard imported value, so the dropdown can render it
  /// without losing the underlying string on first save.
  static List<String> _extendedFingerprintOptions(String current) {
    final trimmed = current.trim();
    if (trimmed.isEmpty || _fingerprintOptions.contains(trimmed)) {
      return _fingerprintOptions;
    }
    return [..._fingerprintOptions, trimmed];
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _uuidController.dispose();
    _pathController.dispose();
    _serviceNameController.dispose();
    _hostController.dispose();
    _sniController.dispose();
    _alpnController.dispose();
    _shortIdController.dispose();
    _publicKeyController.dispose();
    _obfsPasswordController.dispose();
    _hopPortsController.dispose();
    _xhttpPaddingController.dispose();
    _xhttpMaxPostController.dispose();
    _xhttpMinIntervalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final updatedServer = _serverFromFields();

    setState(() => _isSaving = true);
    final error = await widget.controller.updateServer(
      originalName: widget.server.name,
      updatedServer: updatedServer,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      _showMessage(error);
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _copyConfig(_ServerCopyAction action) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final server = _serverFromFields();
    final text = switch (action) {
      _ServerCopyAction.url => ServerConfigExporter.toServerUrl(server),
      _ServerCopyAction.json => ServerConfigExporter.toXrayJson(server),
    };
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showMessage(
      action == _ServerCopyAction.url
          ? 'Server URL copied to clipboard.'
          : 'Server JSON copied to clipboard.',
    );
  }

  bool get _isHysteria2 => _protocol == ServerProtocol.hysteria2;

  void _onProtocolChanged(ServerProtocol next) {
    if (next == _protocol) return;
    setState(() {
      _protocol = next;
      if (next == ServerProtocol.hysteria2 &&
          _alpnController.text.trim().isEmpty) {
        _alpnController.text = 'h3';
      }
    });
  }

  ServerConfig _serverFromFields() {
    final port = int.parse(_portController.text.trim());
    if (_isHysteria2) {
      return widget.server.copyWith(
        name: _aliasController.text.trim(),
        address: _addressController.text.trim(),
        port: port,
        uuid: _uuidController.text.trim(),
        serverProtocol: ServerProtocol.hysteria2,
        transport: VlessTransport.tcp,
        security: VlessSecurity.tls,
        transportPath: '/',
        transportServiceName: '',
        transportHost: '',
        transportMode: '',
        xhttpPadding: '',
        xhttpMaxPostBytes: '',
        xhttpMinPostInterval: '',
        sni: _sniController.text.trim(),
        alpn: _alpnController.text.trim().isEmpty
            ? 'h3'
            : _alpnController.text.trim(),
        tlsInsecure: _tlsInsecure,
        flow: '',
        fingerprint: '',
        realityShortId: '',
        realityPublicKey: '',
        realitySpiderX: '',
        hysteria2ObfsPassword: _obfsPasswordController.text.trim(),
        hysteria2HopPorts: _hopPortsController.text.trim(),
      );
    }

    final isXhttp = _transport == VlessTransport.xhttp;
    return widget.server.copyWith(
      name: _aliasController.text.trim(),
      address: _addressController.text.trim(),
      port: port,
      uuid: _uuidController.text.trim(),
      serverProtocol: ServerProtocol.vless,
      transport: _transport,
      security: _security,
      transportPath: _pathController.text.trim(),
      transportServiceName: _serviceNameController.text.trim(),
      transportHost: _hostController.text.trim(),
      // Drop xhttp-only fields when the user has switched away from xhttp.
      // Keeping them around would silently leak old padding / mode into a
      // share-link export of, say, a ws server.
      transportMode: isXhttp ? _xhttpMode : '',
      xhttpPadding: isXhttp ? _xhttpPaddingController.text.trim() : '',
      xhttpMaxPostBytes: isXhttp ? _xhttpMaxPostController.text.trim() : '',
      xhttpMinPostInterval: isXhttp
          ? _xhttpMinIntervalController.text.trim()
          : '',
      sni: _sniController.text.trim(),
      alpn: _alpnController.text.trim(),
      tlsInsecure: _tlsInsecure,
      // fingerprint applies to both Reality and plain TLS; the Android
      // builder ignores it for security=none, so it's safe to persist
      // even when the current security selection wouldn't use it.
      fingerprint: _fingerprint.trim(),
      realityShortId: _shortIdController.text.trim(),
      realityPublicKey: _publicKeyController.text.trim(),
      hysteria2ObfsPassword: '',
      hysteria2HopPorts: '',
    );
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        final dl = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl.editServerDeleteConfirmTitle),
          content: Text(dl.editServerDeleteConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dl.editServerDeleteCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogTheme.colorScheme.error,
                foregroundColor: dialogTheme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(dl.editServerDeleteConfirmAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    await widget.controller.removeServer(widget.server.name);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return OrientationGate(
      controller: widget.controller,
      child: Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(l.editServerTitle),
              actions: [
                PopupMenuButton<_ServerCopyAction>(
                  enabled: !_isBusy,
                  tooltip: l.editServerCopyTooltip,
                  icon: const Icon(Icons.file_upload_rounded),
                  onSelected: _copyConfig,
                  itemBuilder: (context) {
                    final m = AppLocalizations.of(context);
                    return [
                      PopupMenuItem<_ServerCopyAction>(
                        value: _ServerCopyAction.url,
                        child: ListTile(
                          leading: const Icon(Icons.link_rounded),
                          title: Text(m.editServerCopyAsUrl),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem<_ServerCopyAction>(
                        value: _ServerCopyAction.json,
                        child: ListTile(
                          leading: const Icon(Icons.data_object_rounded),
                          title: Text(m.editServerCopyAsJson),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ];
                  },
                ),
                IconButton(
                  tooltip: l.editServerDelete,
                  onPressed: _isBusy ? null : _confirmAndDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: _isBusy
                        ? theme.disabledColor
                        : theme.colorScheme.error,
                  ),
                ),
                IconButton(
                  tooltip: l.editServerSave,
                  onPressed: _isBusy ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                ),
              ],
            ),
          ];
        },
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProtocolSelector(
                  protocols: _supportedProtocols,
                  selected: _protocol,
                  enabled: !_isBusy,
                  onSelected: _onProtocolChanged,
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: l.editServerSectionPrimary,
                  children: [
                    _buildTextField(
                      controller: _aliasController,
                      label: l.editServerAliasLabel,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l.editServerAliasRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _addressController,
                      label: l.editServerAddressLabel,
                      mono: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l.editServerAddressRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _portController,
                      label: l.editServerPortLabel,
                      keyboardType: TextInputType.number,
                      mono: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l.editServerPortRequired;
                        }
                        final port = int.tryParse(value.trim());
                        if (port == null || port < 1 || port > 65535) {
                          return l.editServerPortInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _uuidController,
                      label: _isHysteria2
                          ? l.editServerPasswordLabel
                          : l.editServerUuidLabel,
                      mono: true,
                      validator: (value) {
                        if (_isHysteria2 &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    if (!_isHysteria2) ...[
                      const SizedBox(height: 14),
                      _buildTransportField(),
                      const SizedBox(height: 14),
                      _buildSecurityField(),
                    ],
                  ],
                ),
                if (!_isHysteria2) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: l.editServerSectionTransport,
                    children: [
                      if (_transport == VlessTransport.ws ||
                          _transport == VlessTransport.http ||
                          _transport == VlessTransport.httpupgrade ||
                          _transport == VlessTransport.xhttp) ...[
                        _buildTextField(
                          controller: _pathController,
                          label: l.editServerPathLabel,
                          mono: true,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _hostController,
                          label: l.editServerHostLabel,
                          mono: true,
                        ),
                      ],
                      if (_transport == VlessTransport.grpc) ...[
                        _buildTextField(
                          controller: _serviceNameController,
                          label: l.editServerServiceNameLabel,
                          mono: true,
                        ),
                      ],
                      if (_transport == VlessTransport.tcp)
                        _buildTextField(
                          controller: _hostController,
                          label: l.editServerHostLabel,
                          mono: true,
                        ),
                      if (_transport == VlessTransport.xhttp) ...[
                        const SizedBox(height: 18),
                        _buildXhttpTuning(l, theme),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  title: l.editServerSectionTls,
                  children: [
                    _buildTextField(
                      controller: _sniController,
                      label: l.editServerSniLabel,
                      mono: true,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _alpnController,
                      label: l.editServerAlpnLabel,
                      mono: true,
                    ),
                    const SizedBox(height: 14),
                    _buildFingerprintField(),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      value: _tlsInsecure,
                      onChanged: _isBusy
                          ? null
                          : (value) => setState(() => _tlsInsecure = value),
                      title: Text(l.editServerAllowInsecureLabel),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_isHysteria2) ...[
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _obfsPasswordController,
                        label: l.editServerObfsPasswordLabel,
                        mono: true,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _hopPortsController,
                        label: l.editServerHopPortsLabel,
                        mono: true,
                      ),
                    ],
                    if (!_isHysteria2 &&
                        _security == VlessSecurity.reality) ...[
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _shortIdController,
                        label: l.editServerShortIdLabel,
                        mono: true,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _publicKeyController,
                        label: l.editServerPublicKeyLabel,
                        mono: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildTransportField() {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<VlessTransport>(
      initialValue: _transport,
      decoration: InputDecoration(labelText: l.editServerTransportLabel),
      items: VlessTransport.values
          .map(
            (transport) => DropdownMenuItem<VlessTransport>(
              value: transport,
              child: Text(_transportLabel(l, transport)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _transport = value);
      },
    );
  }

  Widget _buildFingerprintField() {
    final l = AppLocalizations.of(context);
    final options = _extendedFingerprintOptions(_fingerprint);
    return DropdownButtonFormField<String>(
      initialValue: _fingerprint,
      decoration: InputDecoration(
        labelText: l.editServerFingerprintLabel,
        helperText: l.editServerFingerprintHelper,
      ),
      items: options
          .map(
            (fp) => DropdownMenuItem<String>(
              value: fp,
              child: Text(
                fp.isEmpty ? l.editServerFingerprintAuto : fp,
                style: TextStyle(fontFamily: fp.isEmpty ? null : 'monospace'),
              ),
            ),
          )
          .toList(),
      onChanged: _isBusy
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _fingerprint = value);
            },
    );
  }

  Widget _buildSecurityField() {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<VlessSecurity>(
      initialValue: _security,
      decoration: InputDecoration(labelText: l.editServerSecurityLabel),
      items: VlessSecurity.values
          .map(
            (security) => DropdownMenuItem<VlessSecurity>(
              value: security,
              child: Text(_securityLabel(l, security)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _security = value);
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool mono = false,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontFamily: mono ? 'monospace' : null,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
      ),
    );
  }

  /// xhttp-specific tuning row: mode dropdown + three "extra" overrides.
  /// Rendered inline inside the Transport section when xhttp is the
  /// active transport. Each field is optional — leaving it blank lets
  /// XrayConfigBuilder apply its curated default (mode=stream-up,
  /// padding=100-1000, etc.), which is the recommended setup for DPI
  /// white-list networks.
  Widget _buildXhttpTuning(AppLocalizations l, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.editServerXhttpSubheading,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _xhttpMode,
          decoration: InputDecoration(
            labelText: l.editServerXhttpModeLabel,
            helperText: l.editServerXhttpModeHelper,
          ),
          items: _xhttpModeOptions
              .map(
                (mode) => DropdownMenuItem<String>(
                  value: mode,
                  child: Text(
                    mode.isEmpty ? l.editServerXhttpModeAuto : mode,
                    style: TextStyle(
                      fontFamily: mode.isEmpty ? null : 'monospace',
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: _isBusy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _xhttpMode = value);
                },
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _xhttpPaddingController,
          label: l.editServerXhttpPaddingLabel,
          helperText: l.editServerXhttpPaddingHelper,
          mono: true,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _xhttpMaxPostController,
          label: l.editServerXhttpMaxPostLabel,
          helperText: l.editServerXhttpMaxPostHelper,
          mono: true,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _xhttpMinIntervalController,
          label: l.editServerXhttpMinIntervalLabel,
          helperText: l.editServerXhttpMinIntervalHelper,
          mono: true,
        ),
      ],
    );
  }

  String _transportLabel(AppLocalizations l, VlessTransport transport) {
    switch (transport) {
      case VlessTransport.tcp:
        return l.transportTcp;
      case VlessTransport.ws:
        return l.transportWs;
      case VlessTransport.grpc:
        return l.transportGrpc;
      case VlessTransport.http:
        return l.transportHttp;
      case VlessTransport.httpupgrade:
        return l.transportHttpUpgrade;
      case VlessTransport.xhttp:
        return l.transportXhttp;
    }
  }

  String _securityLabel(AppLocalizations l, VlessSecurity security) {
    switch (security) {
      case VlessSecurity.none:
        return l.securityNone;
      case VlessSecurity.tls:
        return l.securityTls;
      case VlessSecurity.reality:
        return l.securityReality;
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
