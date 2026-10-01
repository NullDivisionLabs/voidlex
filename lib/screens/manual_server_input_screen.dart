import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../core/models/server_config.dart';
import '../core/server_importer.dart';
import '../core/vpn_controller.dart';
import '../core/tls_fingerprints.dart';
import '../theme.dart';
import 'widgets/lined_json_editor.dart';
import 'widgets/orientation_gate.dart';
import 'widgets/protocol_selector.dart';
import 'widgets/server_advanced_fields.dart';
import 'widgets/unsaved_changes_dialog.dart';
import 'widgets/xhttp_advanced_fields.dart';

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
  late final TextEditingController _xPaddingBytesController;
  late final TextEditingController _xPaddingKeyController;
  late final TextEditingController _xPaddingHeaderController;
  late final TextEditingController _sessionIDKeyController;
  late final TextEditingController _seqKeyController;
  late final TextEditingController _xhttpMaxPostController;
  late final TextEditingController _xhttpMinIntervalController;
  late final TextEditingController _jsonController;

  ServerProtocol _protocol = ServerProtocol.vless;
  VlessTransport _transport = VlessTransport.tcp;
  VlessSecurity _security = VlessSecurity.none;
  // xhttp mode: empty string leaves mode absent so Xray applies its stock
  // transport behaviour.
  String _xhttpMode = '';
  bool? _xPaddingObfsMode;
  String _xPaddingPlacement = '';
  String _xPaddingMethod = '';
  String _sessionIDPlacement = '';
  String _seqPlacement = '';
  // uTLS fingerprint. Empty = "Auto"; TLS generation may choose its runtime
  // default independently of the XHTTP extra settings.
  String _fingerprint = '';
  bool _tlsInsecure = false;
  bool _naiveQuic = false;
  String _naiveQuicCongestionControl = '';
  ServerAdvancedSettings _advanced = const ServerAdvancedSettings();
  ServerConfig? _draft;
  bool _isSaving = false;
  bool _isJsonMode = false;
  String? _jsonError;
  bool _credentialsObscured = true;
  bool _hasUnsavedChanges = false;

  void _markDirty() {
    if (_hasUnsavedChanges || _isSaving) return;
    setState(() => _hasUnsavedChanges = true);
  }

  Future<bool> _confirmLeave() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;
    final confirmed = await confirmDiscardUnsavedChanges(context);
    if (confirmed && mounted) {
      setState(() => _hasUnsavedChanges = false);
    }
    return confirmed;
  }

  Future<void> _handleBlockedPop() async {
    if (!await _confirmLeave() || !mounted) return;
    Navigator.of(context).pop();
  }

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
    _xPaddingBytesController = TextEditingController();
    _xPaddingKeyController = TextEditingController();
    _xPaddingHeaderController = TextEditingController();
    _sessionIDKeyController = TextEditingController();
    _seqKeyController = TextEditingController();
    _xhttpMaxPostController = TextEditingController();
    _xhttpMinIntervalController = TextEditingController();
    _jsonController = TextEditingController();
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
    _xPaddingBytesController.dispose();
    _xPaddingKeyController.dispose();
    _xPaddingHeaderController.dispose();
    _sessionIDKeyController.dispose();
    _seqKeyController.dispose();
    _xhttpMaxPostController.dispose();
    _xhttpMinIntervalController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final server = _currentEditedServer();
    if (server == null) return;

    setState(() => _isSaving = true);
    final error = await widget.controller.addServer(server);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (error == null) _hasUnsavedChanges = false;
    });

    if (error != null) {
      _showMessage(error);
      return;
    }

    Navigator.of(context).pop(true);
  }

  ServerConfig? _currentEditedServer() {
    if (_isJsonMode) return _serverFromJsonEditor();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return null;
    return _preserveDraftFields(_serverFromFields());
  }

  ServerConfig? _serverFromJsonEditor() {
    final result = const ServerImporter().parse(_jsonController.text);
    if (!result.isOk || result.configs.length != 1) {
      setState(() {
        _jsonError = AppLocalizations.of(context).editServerJsonInvalid;
      });
      return null;
    }
    return result.configs.single;
  }

  void _loadServerIntoFields(ServerConfig server) {
    _draft = server;
    _aliasController.text = server.name;
    _addressController.text = server.address;
    _portController.text = server.port.toString();
    _uuidController.text = server.uuid;
    _pathController.text = server.transportPath;
    _serviceNameController.text = server.transportServiceName;
    _hostController.text = server.transportHost;
    _sniController.text = server.sni;
    _alpnController.text = server.alpn;
    _shortIdController.text = server.realityShortId;
    _publicKeyController.text = server.realityPublicKey;
    _naiveUsernameController.text = server.naiveUsername;
    _naivePasswordController.text = server.naivePassword;
    _xPaddingBytesController.text = server.xPaddingBytes;
    _xPaddingKeyController.text = server.xPaddingKey;
    _xPaddingHeaderController.text = server.xPaddingHeader;
    _sessionIDKeyController.text = server.sessionIDKey;
    _seqKeyController.text = server.seqKey;
    _xhttpMaxPostController.text = server.xhttpMaxPostBytes;
    _xhttpMinIntervalController.text = server.xhttpMinPostInterval;
    _protocol = server.serverProtocol;
    _transport = server.transport;
    _security = server.security;
    _xhttpMode = server.transportMode.trim().toLowerCase();
    _xPaddingObfsMode = server.xPaddingObfsMode;
    _xPaddingPlacement = server.xPaddingPlacement;
    _xPaddingMethod = server.xPaddingMethod;
    _sessionIDPlacement = server.sessionIDPlacement;
    _seqPlacement = server.seqPlacement;
    _fingerprint = server.fingerprint.trim();
    _tlsInsecure = server.tlsInsecure;
    _naiveQuic = server.naiveQuic;
    _naiveQuicCongestionControl = server.naiveQuicCongestionControl;
    _advanced = ServerAdvancedSettings.fromServer(server);
  }

  void _toggleJsonMode() {
    if (_isSaving) return;
    if (_isJsonMode) {
      final server = _serverFromJsonEditor();
      if (server == null) return;
      setState(() {
        _loadServerIntoFields(server);
        _isJsonMode = false;
        _jsonError = null;
      });
      return;
    }

    final server = _preserveDraftFields(_serverFromFieldsSafe());
    setState(() {
      _jsonController.text = _editableJsonFor(server);
      _isJsonMode = true;
      _jsonError = null;
    });
  }

  ServerConfig _preserveDraftFields(ServerConfig server) {
    final draft = _draft;
    if (draft == null) return server;
    final isXhttp =
        server.serverProtocol == ServerProtocol.vless &&
        server.transport == VlessTransport.xhttp;
    final isHysteria2 = server.serverProtocol == ServerProtocol.hysteria2;
    // These supported JSON fields have no corresponding form controls.
    return server.copyWith(
      xhttpRawSettings: isXhttp ? draft.xhttpRawSettings : const {},
      xhttpRawExtra: isXhttp ? draft.xhttpRawExtra : const {},
      hysteria2RawOutbound: isHysteria2 ? draft.hysteria2RawOutbound : const {},
      hysteria2RawObfs: isHysteria2 ? draft.hysteria2RawObfs : const {},
      hysteria2RawTls: isHysteria2 ? draft.hysteria2RawTls : const {},
    );
  }

  ServerConfig _serverFromFieldsSafe() {
    final port = int.tryParse(_portController.text.trim()) ?? 443;
    final alias = _aliasController.text.trim();
    final address = _addressController.text.trim();
    final uuid = _uuidController.text.trim();
    return ServerConfig(
      name: alias.isEmpty ? 'New Server' : alias,
      address: address.isEmpty ? '127.0.0.1' : address,
      port: port,
      uuid: uuid.isEmpty ? '00000000-0000-0000-0000-000000000000' : uuid,
      serverProtocol: _protocol,
      transport: _transport,
      security: _security,
      transportPath: _pathController.text.trim(),
      transportServiceName: _serviceNameController.text.trim(),
      transportHost: _hostController.text.trim(),
      transportMode: _xhttpMode,
      xPaddingObfsMode: _xPaddingObfsMode,
      xPaddingPlacement: _xPaddingPlacement,
      xPaddingKey: _xPaddingKeyController.text.trim(),
      xPaddingHeader: _xPaddingHeaderController.text.trim(),
      xPaddingMethod: _xPaddingMethod,
      xPaddingBytes: _xPaddingBytesController.text.trim(),
      sessionIDPlacement: _sessionIDPlacement,
      sessionIDKey: _sessionIDKeyController.text.trim(),
      seqPlacement: _seqPlacement,
      seqKey: _seqKeyController.text.trim(),
      xhttpMaxPostBytes: _xhttpMaxPostController.text.trim(),
      xhttpMinPostInterval: _xhttpMinIntervalController.text.trim(),
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
      naiveUsername: _naiveUsernameController.text.trim(),
      naivePassword: _naivePasswordController.text,
      naiveQuic: _naiveQuic,
      naiveQuicCongestionControl: _naiveQuic ? _naiveQuicCongestionControl : '',
      naiveInsecureConcurrency: _advanced.naiveInsecureConcurrency,
      naiveExtraHeaders: _advanced.naiveExtraHeaders,
      naiveUdpOverTcp: _advanced.naiveUdpOverTcp,
      naiveUdpOverTcpVersion: _advanced.naiveUdpOverTcp
          ? _advanced.naiveUdpOverTcpVersion
          : 0,
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

  String _editableJsonFor(ServerConfig server) {
    final json = Map<String, dynamic>.of(server.toJson())
      ..remove('isPinned')
      ..remove('ping');
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  Widget _buildJsonEditor(ThemeData theme, AppLocalizations l) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l.editServerJsonEditorHelper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          LinedJsonEditor(
            controller: _jsonController,
            enabled: !_isSaving,
            externalError: _jsonError,
            onChanged: (_) {
              if (_jsonError == null) {
                _markDirty();
                return;
              }
              setState(() {
                _jsonError = null;
                _hasUnsavedChanges = true;
              });
            },
          ),
        ],
      ),
    );
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
      xPaddingObfsMode: isXhttp ? _xPaddingObfsMode : null,
      xPaddingPlacement: isXhttp ? _xPaddingPlacement : '',
      xPaddingKey: isXhttp ? _xPaddingKeyController.text.trim() : '',
      xPaddingHeader: isXhttp ? _xPaddingHeaderController.text.trim() : '',
      xPaddingMethod: isXhttp ? _xPaddingMethod : '',
      xPaddingBytes: isXhttp ? _xPaddingBytesController.text.trim() : '',
      sessionIDPlacement: isXhttp ? _sessionIDPlacement : '',
      sessionIDKey: isXhttp ? _sessionIDKeyController.text.trim() : '',
      seqPlacement: isXhttp ? _seqPlacement : '',
      seqKey: isXhttp ? _seqKeyController.text.trim() : '',
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
      _hasUnsavedChanges = true;
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
      onExitRequested: _confirmLeave,
      child: PopScope(
        canPop: !_hasUnsavedChanges && !_isSaving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBlockedPop();
        },
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
                  leadingWidth: 104,
                  titleSpacing: 0,
                  leading: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      IconButton(
                        key: const ValueKey('manual-server-json-toggle'),
                        tooltip: _isJsonMode
                            ? l.editServerShowForm
                            : l.editServerShowJson,
                        onPressed: _isSaving ? null : _toggleJsonMode,
                        icon: Icon(
                          _isJsonMode
                              ? Icons.view_list_rounded
                              : Icons.data_object_rounded,
                        ),
                      ),
                    ],
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
            body: _isJsonMode
                ? _buildJsonEditor(theme, l)
                : Form(
                    key: _formKey,
                    onChanged: _markDirty,
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
                                  if (port == null ||
                                      port < 1 ||
                                      port > 65535) {
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
                                  secret: true,
                                ),
                              ] else
                                _buildTextField(
                                  controller: _uuidController,
                                  label: _isHysteria2
                                      ? l.editServerPasswordLabel
                                      : l.editServerUuidLabel,
                                  mono: true,
                                  secret: _isHysteria2,
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
                                  _buildXhttpFields(),
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
                                      : (value) => setState(() {
                                          _tlsInsecure = value;
                                          _hasUnsavedChanges = true;
                                        }),
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
                                      : (value) => setState(() {
                                          _tlsInsecure = value;
                                          _hasUnsavedChanges = true;
                                        }),
                                  title: Text(l.editServerAllowInsecureLabel),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                              if (_isVless &&
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
                          ServerAdvancedFields(
                            protocol: _protocol,
                            security: _security,
                            enabled: !_isSaving,
                            initial: _advanced,
                            onChanged: (value) {
                              _advanced = value;
                              _markDirty();
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
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
      items:
          TlsFingerprints.options(
                additionalEnabled:
                    widget.controller.additionalTlsFingerprintsEnabled,
                current: _fingerprint,
              )
              .map(
                (fp) => DropdownMenuItem<String>(
                  value: fp,
                  child: Text(
                    fp.isEmpty
                        ? l.editServerFingerprintAuto
                        : TlsFingerprints.label(fp),
                    style: TextStyle(
                      fontFamily: fp.isEmpty ? null : 'monospace',
                    ),
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
    bool secret = false,
    String? helperText,
  }) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      enabled: !_isSaving,
      obscureText: secret && _credentialsObscured,
      autocorrect: !secret,
      enableSuggestions: !secret,
      smartDashesType: secret
          ? SmartDashesType.disabled
          : SmartDashesType.enabled,
      smartQuotesType: secret
          ? SmartQuotesType.disabled
          : SmartQuotesType.enabled,
      autofillHints: secret ? const <String>[] : null,
      style: TextStyle(
        fontFamily: mono ? 'monospace' : null,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixIcon: secret
            ? IconButton(
                tooltip: _credentialsObscured ? l.show : l.hide,
                onPressed: _isSaving
                    ? null
                    : () => setState(
                        () => _credentialsObscured = !_credentialsObscured,
                      ),
                icon: Icon(
                  _credentialsObscured
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildXhttpFields() => XhttpAdvancedFields(
    enabled: !_isSaving,
    mode: _xhttpMode,
    onModeChanged: (value) => setState(() => _xhttpMode = value),
    obfsEnabled: _xPaddingObfsMode == true,
    onObfsEnabledChanged: (value) => setState(() {
      _xPaddingObfsMode = value;
      _hasUnsavedChanges = true;
    }),
    paddingPlacement: _xPaddingPlacement,
    onPaddingPlacementChanged: (value) =>
        setState(() => _xPaddingPlacement = value),
    paddingMethod: _xPaddingMethod,
    onPaddingMethodChanged: (value) => setState(() => _xPaddingMethod = value),
    sessionIDPlacement: _sessionIDPlacement,
    onSessionIDPlacementChanged: (value) =>
        setState(() => _sessionIDPlacement = value),
    seqPlacement: _seqPlacement,
    onSeqPlacementChanged: (value) => setState(() => _seqPlacement = value),
    paddingKeyController: _xPaddingKeyController,
    paddingHeaderController: _xPaddingHeaderController,
    paddingBytesController: _xPaddingBytesController,
    sessionIDKeyController: _sessionIDKeyController,
    seqKeyController: _seqKeyController,
    maxPostController: _xhttpMaxPostController,
    minIntervalController: _xhttpMinIntervalController,
    onApplyCdnWafPreset: _applyCdnWafPreset,
  );

  void _applyCdnWafPreset() {
    const preset = XhttpAdvancedFields.cdnWafPreset;
    setState(() {
      _xPaddingObfsMode = preset.xPaddingObfsMode;
      _xPaddingPlacement = preset.xPaddingPlacement;
      _xPaddingMethod = preset.xPaddingMethod;
      _sessionIDPlacement = preset.sessionIDPlacement;
      _seqPlacement = preset.seqPlacement;
      _xPaddingHeaderController.text = preset.xPaddingHeader;
      _xPaddingKeyController.text = preset.xPaddingKey;
      _xPaddingBytesController.text = preset.xPaddingBytes;
      _sessionIDKeyController.text = preset.sessionIDKey;
      _seqKeyController.text = preset.seqKey;
      _hasUnsavedChanges = true;
    });
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
    return Material(
      color: t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }
}
