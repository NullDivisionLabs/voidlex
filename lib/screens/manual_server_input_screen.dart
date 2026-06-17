import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../core/models/server_config.dart';
import '../core/vpn_controller.dart';
import '../theme.dart';
import 'widgets/orientation_gate.dart';
import 'widgets/protocol_selector.dart';
import 'widgets/server_advanced_fields.dart';

class ManualServerInputScreen extends StatefulWidget {
  const ManualServerInputScreen({super.key, required this.controller});

  final VpnController controller;

  @override
  State<ManualServerInputScreen> createState() =>
      _ManualServerInputScreenState();
}

class _ManualServerInputScreenState extends State<ManualServerInputScreen> {
  static const _supportedProtocols = <ServerProtocol>[
    ServerProtocol.vless,
    ServerProtocol.hysteria2,
    ServerProtocol.naive,
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
  late final TextEditingController _naiveUsernameController;
  late final TextEditingController _naivePasswordController;
  late final TextEditingController _xhttpPaddingController;
  late final TextEditingController _xhttpMaxPostController;
  late final TextEditingController _xhttpMinIntervalController;

  ServerProtocol _protocol = ServerProtocol.vless;
  VlessTransport _transport = VlessTransport.tcp;
  VlessSecurity _security = VlessSecurity.none;
  // xhttp mode: empty string = "Auto", otherwise one of _xhttpModeOptions.
  // Empty is the safe default — the Android side picks stream-up at build
  // time, which is the recommended setting for DPI white-list networks.
  String _xhttpMode = '';
  // uTLS fingerprint. Empty = "Auto (none)"; the Android builder picks
  // chrome specifically for xhttp at build time.
  String _fingerprint = '';
  bool _tlsInsecure = false;
  bool _naiveQuic = false;
  String _naiveQuicCongestionControl = '';
  ServerAdvancedSettings _advanced = const ServerAdvancedSettings();
  bool _isSaving = false;

  static const _xhttpModeOptions = <String>[
    '',
    'stream-up',
    'packet-up',
    'stream-one',
  ];

  /// Mirror of [EditServerScreen._fingerprintOptions]; see there for the
  /// rationale on which fingerprints are listed.
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

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController();
    _addressController = TextEditingController();
    _portController = TextEditingController(text: '443');
    _uuidController = TextEditingController();
    _pathController = TextEditingController(text: '/');
    _serviceNameController = TextEditingController();
    _hostController = TextEditingController();
    _sniController = TextEditingController();
    _alpnController = TextEditingController();
    _shortIdController = TextEditingController();
    _publicKeyController = TextEditingController();
    _naiveUsernameController = TextEditingController();
    _naivePasswordController = TextEditingController();
    _xhttpPaddingController = TextEditingController();
    _xhttpMaxPostController = TextEditingController();
    _xhttpMinIntervalController = TextEditingController();
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
    _naiveUsernameController.dispose();
    _naivePasswordController.dispose();
    _xhttpPaddingController.dispose();
    _xhttpMaxPostController.dispose();
    _xhttpMinIntervalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final server = _serverFromFields();

    setState(() => _isSaving = true);
    final error = await widget.controller.addServer(server);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      _showMessage(error);
      return;
    }

    Navigator.of(context).pop(true);
  }

  bool get _isHysteria2 => _protocol == ServerProtocol.hysteria2;
  bool get _isNaive => _protocol == ServerProtocol.naive;
  bool get _isVless => _protocol == ServerProtocol.vless;

  ServerConfig _serverFromFields() {
    if (_isHysteria2) {
      return ServerConfig(
        name: _aliasController.text.trim(),
        address: _addressController.text.trim(),
        port: int.parse(_portController.text.trim()),
        uuid: _uuidController.text.trim(),
        transport: VlessTransport.tcp,
        security: VlessSecurity.tls,
        serverProtocol: ServerProtocol.hysteria2,
        sni: _sniController.text.trim(),
        alpn: _alpnController.text.trim().isEmpty
            ? 'h3'
            : _alpnController.text.trim(),
        tlsInsecure: _tlsInsecure,
        hysteria2ObfsType: _advanced.hysteria2ObfsType,
        hysteria2ObfsPassword: _advanced.hysteria2ObfsPassword,
        hysteria2ObfsMinPacketSize: _advanced.hysteria2ObfsMinPacketSize,
        hysteria2ObfsMaxPacketSize: _advanced.hysteria2ObfsMaxPacketSize,
        hysteria2HopPorts: _advanced.hysteria2HopPorts,
        hysteria2HopInterval: _advanced.hysteria2HopInterval,
        hysteria2HopIntervalMax: _advanced.hysteria2HopIntervalMax,
        hysteria2UpMbps: _advanced.hysteria2UpMbps,
        hysteria2DownMbps: _advanced.hysteria2DownMbps,
        hysteria2Network: _advanced.hysteria2Network,
        hysteria2BbrProfile: _advanced.hysteria2BbrProfile,
      );
    }
    if (_isNaive) {
      return ServerConfig(
        name: _aliasController.text.trim(),
        address: _addressController.text.trim(),
        port: int.parse(_portController.text.trim()),
        uuid: '',
        transport: VlessTransport.tcp,
        security: VlessSecurity.tls,
        serverProtocol: ServerProtocol.naive,
        sni: _sniController.text.trim(),
        naiveUsername: _naiveUsernameController.text.trim(),
        naivePassword: _naivePasswordController.text,
        naiveQuic: _naiveQuic,
        naiveQuicCongestionControl: _naiveQuic
            ? _naiveQuicCongestionControl
            : '',
        naiveInsecureConcurrency: _advanced.naiveInsecureConcurrency,
        naiveExtraHeaders: _advanced.naiveExtraHeaders,
        naiveUdpOverTcp: _advanced.naiveUdpOverTcp,
        naiveUdpOverTcpVersion: _advanced.naiveUdpOverTcp
            ? _advanced.naiveUdpOverTcpVersion
            : 0,
        tlsInsecure: _tlsInsecure,
      );
    }

    final isXhttp = _transport == VlessTransport.xhttp;
    return ServerConfig(
      name: _aliasController.text.trim(),
      address: _addressController.text.trim(),
      port: int.parse(_portController.text.trim()),
      uuid: _uuidController.text.trim(),
      transport: _transport,
      security: _security,
      serverProtocol: ServerProtocol.vless,
      transportPath: _pathController.text.trim(),
      transportServiceName: _serviceNameController.text.trim(),
      transportHost: _hostController.text.trim(),
      // xhttp-only fields are kept blank for other transports so a fresh
      // ws / grpc / etc. entry doesn't carry stale padding/mode values
      // that would only show up under share-link export.
      transportMode: isXhttp ? _xhttpMode : '',
      xhttpPadding: isXhttp ? _xhttpPaddingController.text.trim() : '',
      xhttpMaxPostBytes: isXhttp ? _xhttpMaxPostController.text.trim() : '',
      xhttpMinPostInterval: isXhttp
          ? _xhttpMinIntervalController.text.trim()
          : '',
      sni: _sniController.text.trim(),
      alpn: _alpnController.text.trim(),
      tlsInsecure: _tlsInsecure,
      flow: _advanced.flow,
      vlessEncryption: _advanced.vlessEncryption,
      fingerprint: _fingerprint.trim(),
      realityShortId: _shortIdController.text.trim(),
      realityPublicKey: _publicKeyController.text.trim(),
      realitySpiderX: _security == VlessSecurity.reality
          ? _advanced.realitySpiderX
          : '',
      realityMldsa65Verify: _security == VlessSecurity.reality
          ? _advanced.realityMldsa65Verify
          : '',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
                title: Text(l.addServerTitle),
                actions: [
                  TextButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(
                      l.add,
                      style: TextStyle(
                        color: _isSaving
                            ? theme.disabledColor
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                    enabled: !_isSaving,
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
                      if (_isNaive) ...[
                        _buildTextField(
                          controller: _naiveUsernameController,
                          label: l.editServerNaiveUsernameLabel,
                          mono: true,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _naivePasswordController,
                          label: l.editServerNaivePasswordLabel,
                          mono: true,
                        ),
                      ] else
                        _buildTextField(
                          controller: _uuidController,
                          label: _isHysteria2
                              ? l.editServerPasswordLabel
                              : l.editServerUuidLabel,
                          mono: true,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return _isHysteria2
                                  ? l.editServerPasswordRequired
                                  : l.editServerUuidRequired;
                            }
                            return null;
                          },
                        ),
                      if (_isVless) ...[
                        const SizedBox(height: 14),
                        _buildTransportField(),
                        const SizedBox(height: 14),
                        _buildSecurityField(),
                      ],
                    ],
                  ),
                  if (_isVless) ...[
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
                        if (_transport == VlessTransport.grpc)
                          _buildTextField(
                            controller: _serviceNameController,
                            label: l.editServerServiceNameLabel,
                            mono: true,
                          ),
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
                      if (_isNaive) ...[
                        const SizedBox(height: 14),
                        _buildNaiveModeField(),
                        if (_naiveQuic) ...[
                          const SizedBox(height: 14),
                          _buildNaiveCongestionControlField(),
                        ],
                        const SizedBox(height: 14),
                        SwitchListTile.adaptive(
                          value: _tlsInsecure,
                          onChanged: _isSaving
                              ? null
                              : (value) => setState(() => _tlsInsecure = value),
                          title: Text(l.editServerAllowInsecureLabel),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ] else ...[
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
                          onChanged: _isSaving
                              ? null
                              : (value) => setState(() => _tlsInsecure = value),
                          title: Text(l.editServerAllowInsecureLabel),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                      if (_isVless && _security == VlessSecurity.reality) ...[
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
                  ServerAdvancedFields(
                    protocol: _protocol,
                    security: _security,
                    enabled: !_isSaving,
                    initial: _advanced,
                    onChanged: (value) => _advanced = value,
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
    // No need to extend the option list here (manual entry starts blank);
    // the edit screen handles imported non-standard values via its own
    // extended list.
    return DropdownButtonFormField<String>(
      initialValue: _fingerprint,
      decoration: InputDecoration(
        labelText: l.editServerFingerprintLabel,
        helperText: l.editServerFingerprintHelper,
      ),
      items: _fingerprintOptions
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
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _fingerprint = value);
            },
    );
  }

  Widget _buildNaiveModeField() {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<bool>(
      initialValue: _naiveQuic,
      decoration: InputDecoration(labelText: l.editServerNaiveModeLabel),
      items: [
        DropdownMenuItem(value: false, child: Text(l.editServerNaiveModeHttps)),
        DropdownMenuItem(value: true, child: Text(l.editServerNaiveModeQuic)),
      ],
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _naiveQuic = value);
            },
    );
  }

  Widget _buildNaiveCongestionControlField() {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      initialValue: _naiveQuicCongestionControl,
      decoration: InputDecoration(
        labelText: l.editServerNaiveCongestionControlLabel,
      ),
      items: const ['', 'bbr', 'bbr2', 'cubic', 'reno']
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(
                value.isEmpty ? l.editServerNaiveCongestionControlAuto : value,
              ),
            ),
          )
          .toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _naiveQuicCongestionControl = value);
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
      enabled: !_isSaving,
      style: TextStyle(
        fontFamily: mono ? 'monospace' : null,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(labelText: label, helperText: helperText),
    );
  }

  /// xhttp-specific tuning row, mirroring [EditServerScreen]. See that
  /// implementation for rationale on the defaults — Android's
  /// XrayConfigBuilder substitutes stream-up + 100-1000 padding etc.
  /// whenever any of these fields stays blank, which is the recommended
  /// setup for DPI white-list networks.
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
          onChanged: _isSaving
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
