import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_localizations.dart';
import '../core/server_config_exporter.dart';
import '../core/server_importer.dart';
import '../core/models/server_config.dart';
import '../core/vpn_controller.dart';
import '../theme.dart';
import 'widgets/orientation_gate.dart';
import 'widgets/protocol_selector.dart';
import 'widgets/server_advanced_fields.dart';

enum _ServerCopyAction { url, json, qr }

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
  late final TextEditingController _jsonController;

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
  late bool _naiveQuic;
  late String _naiveQuicCongestionControl;
  late ServerAdvancedSettings _advanced;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isJsonMode = false;
  String? _jsonError;

  bool get _isBusy => _isSaving || _isDeleting;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController();
    _addressController = TextEditingController();
    _portController = TextEditingController();
    _uuidController = TextEditingController();
    _pathController = TextEditingController();
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
    _jsonController = TextEditingController();
    _loadServerIntoFields(widget.server);
  }

  void _loadServerIntoFields(ServerConfig server) {
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
    _xhttpPaddingController.text = server.xhttpPadding;
    _xhttpMaxPostController.text = server.xhttpMaxPostBytes;
    _xhttpMinIntervalController.text = server.xhttpMinPostInterval;
    _protocol = server.serverProtocol;
    _transport = server.transport;
    _security = server.security;
    _xhttpMode = _normalizeXhttpMode(server.transportMode);
    _fingerprint = server.fingerprint.trim();
    _tlsInsecure = server.tlsInsecure;
    _naiveQuic = server.naiveQuic;
    _naiveQuicCongestionControl = server.naiveQuicCongestionControl;
    _advanced = ServerAdvancedSettings.fromServer(server);
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
    _naiveUsernameController.dispose();
    _naivePasswordController.dispose();
    _xhttpPaddingController.dispose();
    _xhttpMaxPostController.dispose();
    _xhttpMinIntervalController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updatedServer = _currentEditedServer();
    if (updatedServer == null) return;

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
    final server = _currentEditedServer();
    if (server == null) return;
    final advancedOmitted = ServerConfigExporter.hasUrlOmittedAdvancedFields(
      server,
    );
    // QR export shows the share link as a scannable code rather than writing
    // to the clipboard.
    if (action == _ServerCopyAction.qr) {
      await _showQrDialog(
        ServerConfigExporter.toServerUrl(server),
        advancedOmitted: advancedOmitted,
      );
      return;
    }

    final text = switch (action) {
      _ServerCopyAction.url => ServerConfigExporter.toServerUrl(server),
      _ServerCopyAction.json => ServerConfigExporter.toXrayJson(server),
      _ServerCopyAction.qr => '',
    };
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    _showMessage(
      action == _ServerCopyAction.url && advancedOmitted
          ? l.editServerAdvancedUrlOmitted
          : action == _ServerCopyAction.url
          ? l.editServerUrlCopied
          : l.editServerJsonCopied,
    );
  }

  ServerConfig? _currentEditedServer() {
    if (_isJsonMode) return _serverFromJsonEditor();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return null;
    return _serverFromFields();
  }

  ServerConfig? _serverFromJsonEditor() {
    final result = const ServerImporter().parse(_jsonController.text);
    if (!result.isOk || result.configs.length != 1) {
      setState(() {
        _jsonError = AppLocalizations.of(context).editServerJsonInvalid;
      });
      return null;
    }
    return result.configs.single.copyWith(
      isPinned: widget.server.isPinned,
      ping: widget.server.ping,
    );
  }

  void _toggleJsonMode() {
    if (_isBusy) return;
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

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final server = _serverFromFields();
    setState(() {
      _jsonController.text = _editableJsonFor(server);
      _isJsonMode = true;
      _jsonError = null;
    });
  }

  String _editableJsonFor(ServerConfig server) {
    final json = Map<String, dynamic>.of(server.toJson())
      ..remove('isPinned')
      ..remove('ping');
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  Future<void> _showQrDialog(
    String data, {
    required bool advancedOmitted,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        final dl = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl.editServerQrTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  dl.editServerQrHint,
                  textAlign: TextAlign.center,
                  style: dialogTheme.textTheme.bodySmall,
                ),
                if (advancedOmitted) ...[
                  const SizedBox(height: 8),
                  Text(
                    dl.editServerAdvancedUrlOmitted,
                    textAlign: TextAlign.center,
                    style: dialogTheme.textTheme.bodySmall?.copyWith(
                      color: dialogTheme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SelectableText(
                  data,
                  textAlign: TextAlign.center,
                  style: dialogTheme.textTheme.bodySmall?.copyWith(
                    color: dialogTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(dl.done),
            ),
          ],
        );
      },
    );
  }

  bool get _isHysteria2 => _protocol == ServerProtocol.hysteria2;
  bool get _isNaive => _protocol == ServerProtocol.naive;
  bool get _isVless => _protocol == ServerProtocol.vless;

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
        vlessEncryption: '',
        fingerprint: '',
        realityShortId: '',
        realityPublicKey: '',
        realitySpiderX: '',
        realityMldsa65Verify: '',
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
        // Drop naive-only fields when the user has switched away from
        // NaiveProxy so stale credentials don't leak into exports.
        naiveUsername: '',
        naivePassword: '',
        naiveQuic: false,
        naiveQuicCongestionControl: '',
        naiveInsecureConcurrency: 0,
        naiveExtraHeaders: const {},
        naiveUdpOverTcp: false,
        naiveUdpOverTcpVersion: 0,
      );
    }
    if (_isNaive) {
      return widget.server.copyWith(
        name: _aliasController.text.trim(),
        address: _addressController.text.trim(),
        port: port,
        uuid: '',
        serverProtocol: ServerProtocol.naive,
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
        alpn: '',
        tlsInsecure: _tlsInsecure,
        flow: '',
        vlessEncryption: '',
        fingerprint: '',
        realityShortId: '',
        realityPublicKey: '',
        realitySpiderX: '',
        realityMldsa65Verify: '',
        hysteria2ObfsType: '',
        hysteria2ObfsPassword: '',
        hysteria2ObfsMinPacketSize: 0,
        hysteria2ObfsMaxPacketSize: 0,
        hysteria2HopPorts: '',
        hysteria2HopInterval: '',
        hysteria2HopIntervalMax: '',
        hysteria2UpMbps: 0,
        hysteria2DownMbps: 0,
        hysteria2Network: '',
        hysteria2BbrProfile: '',
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
      flow: _advanced.flow,
      vlessEncryption: _advanced.vlessEncryption,
      // fingerprint applies to both Reality and plain TLS; the Android
      // builder ignores it for security=none, so it's safe to persist
      // even when the current security selection wouldn't use it.
      fingerprint: _fingerprint.trim(),
      realityShortId: _shortIdController.text.trim(),
      realityPublicKey: _publicKeyController.text.trim(),
      realitySpiderX: _security == VlessSecurity.reality
          ? _advanced.realitySpiderX
          : '',
      realityMldsa65Verify: _security == VlessSecurity.reality
          ? _advanced.realityMldsa65Verify
          : '',
      hysteria2ObfsType: '',
      hysteria2ObfsPassword: '',
      hysteria2ObfsMinPacketSize: 0,
      hysteria2ObfsMaxPacketSize: 0,
      hysteria2HopPorts: '',
      hysteria2HopInterval: '',
      hysteria2HopIntervalMax: '',
      hysteria2UpMbps: 0,
      hysteria2DownMbps: 0,
      hysteria2Network: '',
      hysteria2BbrProfile: '',
      naiveUsername: '',
      naivePassword: '',
      naiveQuic: false,
      naiveQuicCongestionControl: '',
      naiveInsecureConcurrency: 0,
      naiveExtraHeaders: const {},
      naiveUdpOverTcp: false,
      naiveUdpOverTcpVersion: 0,
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
                leadingWidth: 104,
                titleSpacing: 0,
                leading: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    IconButton(
                      key: const ValueKey('edit-server-json-toggle'),
                      tooltip: _isJsonMode
                          ? l.editServerShowForm
                          : l.editServerShowJson,
                      onPressed: _isBusy ? null : _toggleJsonMode,
                      icon: Icon(
                        _isJsonMode
                            ? Icons.view_list_rounded
                            : Icons.data_object_rounded,
                      ),
                    ),
                  ],
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
                        PopupMenuItem<_ServerCopyAction>(
                          value: _ServerCopyAction.qr,
                          child: ListTile(
                            leading: const Icon(Icons.qr_code_rounded),
                            title: Text(m.editServerCopyAsQr),
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
          body: _isJsonMode
              ? _buildJsonEditor(theme, l)
              : Form(
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
                                onChanged: _isBusy
                                    ? null
                                    : (value) =>
                                          setState(() => _tlsInsecure = value),
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
                                onChanged: _isBusy
                                    ? null
                                    : (value) =>
                                          setState(() => _tlsInsecure = value),
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
                          enabled: !_isBusy,
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

  Widget _buildJsonEditor(ThemeData theme, AppLocalizations l) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: TextField(
        key: const ValueKey('edit-server-json-editor'),
        controller: _jsonController,
        enabled: !_isBusy,
        minLines: 24,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          height: 1.45,
        ),
        decoration: InputDecoration(
          labelText: l.editServerJsonEditorLabel,
          helperText: l.editServerJsonEditorHelper,
          errorText: _jsonError,
          alignLabelWithHint: true,
        ),
        onChanged: (_) {
          if (_jsonError == null) return;
          setState(() => _jsonError = null);
        },
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
      onChanged: _isBusy
          ? null
          : (value) {
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

  Widget _buildNaiveModeField() {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<bool>(
      initialValue: _naiveQuic,
      decoration: InputDecoration(labelText: l.editServerNaiveModeLabel),
      items: [
        DropdownMenuItem(value: false, child: Text(l.editServerNaiveModeHttps)),
        DropdownMenuItem(value: true, child: Text(l.editServerNaiveModeQuic)),
      ],
      onChanged: _isBusy
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
      onChanged: _isBusy
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
      onChanged: _isBusy
          ? null
          : (value) {
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
      enabled: !_isBusy,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontFamily: mono ? 'monospace' : null,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(labelText: label, helperText: helperText),
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
