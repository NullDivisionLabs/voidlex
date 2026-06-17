import 'package:flutter/material.dart';

import '../../core/models/server_config.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';

class ServerAdvancedSettings {
  const ServerAdvancedSettings({
    this.flow = '',
    this.vlessEncryption = '',
    this.realitySpiderX = '',
    this.realityMldsa65Verify = '',
    this.hysteria2ObfsType = '',
    this.hysteria2ObfsPassword = '',
    this.hysteria2ObfsMinPacketSize = 0,
    this.hysteria2ObfsMaxPacketSize = 0,
    this.hysteria2HopPorts = '',
    this.hysteria2HopInterval = '',
    this.hysteria2HopIntervalMax = '',
    this.hysteria2UpMbps = 0,
    this.hysteria2DownMbps = 0,
    this.hysteria2Network = '',
    this.hysteria2BbrProfile = '',
    this.naiveInsecureConcurrency = 0,
    this.naiveExtraHeaders = const {},
    this.naiveUdpOverTcp = false,
    this.naiveUdpOverTcpVersion = 0,
  });

  factory ServerAdvancedSettings.fromServer(ServerConfig server) {
    return ServerAdvancedSettings(
      flow: server.flow,
      vlessEncryption: server.vlessEncryption,
      realitySpiderX: server.realitySpiderX,
      realityMldsa65Verify: server.realityMldsa65Verify,
      hysteria2ObfsType: server.effectiveHysteria2ObfsType,
      hysteria2ObfsPassword: server.hysteria2ObfsPassword,
      hysteria2ObfsMinPacketSize: server.hysteria2ObfsMinPacketSize,
      hysteria2ObfsMaxPacketSize: server.hysteria2ObfsMaxPacketSize,
      hysteria2HopPorts: server.hysteria2HopPorts,
      hysteria2HopInterval: server.hysteria2HopInterval,
      hysteria2HopIntervalMax: server.hysteria2HopIntervalMax,
      hysteria2UpMbps: server.hysteria2UpMbps,
      hysteria2DownMbps: server.hysteria2DownMbps,
      hysteria2Network: server.hysteria2Network,
      hysteria2BbrProfile: server.hysteria2BbrProfile,
      naiveInsecureConcurrency: server.naiveInsecureConcurrency,
      naiveExtraHeaders: server.naiveExtraHeaders,
      naiveUdpOverTcp: server.naiveUdpOverTcp,
      naiveUdpOverTcpVersion: server.naiveUdpOverTcpVersion,
    );
  }

  final String flow;
  final String vlessEncryption;
  final String realitySpiderX;
  final String realityMldsa65Verify;
  final String hysteria2ObfsType;
  final String hysteria2ObfsPassword;
  final int hysteria2ObfsMinPacketSize;
  final int hysteria2ObfsMaxPacketSize;
  final String hysteria2HopPorts;
  final String hysteria2HopInterval;
  final String hysteria2HopIntervalMax;
  final int hysteria2UpMbps;
  final int hysteria2DownMbps;
  final String hysteria2Network;
  final String hysteria2BbrProfile;
  final int naiveInsecureConcurrency;
  final Map<String, String> naiveExtraHeaders;
  final bool naiveUdpOverTcp;
  final int naiveUdpOverTcpVersion;

  bool get hasValues =>
      flow.isNotEmpty ||
      vlessEncryption.isNotEmpty ||
      realitySpiderX.isNotEmpty ||
      realityMldsa65Verify.isNotEmpty ||
      hysteria2ObfsType.isNotEmpty ||
      hysteria2ObfsPassword.isNotEmpty ||
      hysteria2ObfsMinPacketSize > 0 ||
      hysteria2ObfsMaxPacketSize > 0 ||
      hysteria2HopPorts.isNotEmpty ||
      hysteria2HopInterval.isNotEmpty ||
      hysteria2HopIntervalMax.isNotEmpty ||
      hysteria2UpMbps > 0 ||
      hysteria2DownMbps > 0 ||
      hysteria2Network.isNotEmpty ||
      hysteria2BbrProfile.isNotEmpty ||
      naiveInsecureConcurrency > 0 ||
      naiveExtraHeaders.isNotEmpty ||
      naiveUdpOverTcp;
}

class ServerAdvancedFields extends StatefulWidget {
  const ServerAdvancedFields({
    super.key,
    required this.protocol,
    required this.security,
    required this.enabled,
    required this.initial,
    required this.onChanged,
  });

  final ServerProtocol protocol;
  final VlessSecurity security;
  final bool enabled;
  final ServerAdvancedSettings initial;
  final ValueChanged<ServerAdvancedSettings> onChanged;

  @override
  State<ServerAdvancedFields> createState() => _ServerAdvancedFieldsState();
}

class _ServerAdvancedFieldsState extends State<ServerAdvancedFields> {
  static const _flowOptions = [
    '',
    'xtls-rprx-vision',
    'xtls-rprx-vision-udp443',
  ];
  static const _obfsOptions = ['', 'salamander', 'gecko'];
  static const _networkOptions = ['', 'tcp', 'udp'];
  static const _bbrOptions = ['', 'standard', 'conservative', 'aggressive'];

  late String _flow;
  late String _obfsType;
  late String _network;
  late String _bbrProfile;
  late bool _udpOverTcp;
  late int _udpOverTcpVersion;

  late final TextEditingController _encryptionController;
  late final TextEditingController _spiderXController;
  late final TextEditingController _mldsaController;
  late final TextEditingController _obfsPasswordController;
  late final TextEditingController _obfsMinController;
  late final TextEditingController _obfsMaxController;
  late final TextEditingController _hopPortsController;
  late final TextEditingController _hopIntervalController;
  late final TextEditingController _hopIntervalMaxController;
  late final TextEditingController _upMbpsController;
  late final TextEditingController _downMbpsController;
  late final TextEditingController _insecureConcurrencyController;
  late final List<_HeaderDraft> _headers;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _flow = initial.flow;
    _obfsType = initial.hysteria2ObfsType;
    _network = initial.hysteria2Network;
    _bbrProfile = initial.hysteria2BbrProfile;
    _udpOverTcp = initial.naiveUdpOverTcp;
    _udpOverTcpVersion = initial.naiveUdpOverTcpVersion;
    _encryptionController = TextEditingController(
      text: initial.vlessEncryption,
    );
    _spiderXController = TextEditingController(text: initial.realitySpiderX);
    _mldsaController = TextEditingController(
      text: initial.realityMldsa65Verify,
    );
    _obfsPasswordController = TextEditingController(
      text: initial.hysteria2ObfsPassword,
    );
    _obfsMinController = _intController(initial.hysteria2ObfsMinPacketSize);
    _obfsMaxController = _intController(initial.hysteria2ObfsMaxPacketSize);
    _hopPortsController = TextEditingController(
      text: initial.hysteria2HopPorts,
    );
    _hopIntervalController = TextEditingController(
      text: initial.hysteria2HopInterval,
    );
    _hopIntervalMaxController = TextEditingController(
      text: initial.hysteria2HopIntervalMax,
    );
    _upMbpsController = _intController(initial.hysteria2UpMbps);
    _downMbpsController = _intController(initial.hysteria2DownMbps);
    _insecureConcurrencyController = _intController(
      initial.naiveInsecureConcurrency,
    );
    _headers = initial.naiveExtraHeaders.entries
        .map((entry) => _HeaderDraft(entry.key, entry.value))
        .toList();
  }

  TextEditingController _intController(int value) =>
      TextEditingController(text: value > 0 ? value.toString() : '');

  @override
  void dispose() {
    _encryptionController.dispose();
    _spiderXController.dispose();
    _mldsaController.dispose();
    _obfsPasswordController.dispose();
    _obfsMinController.dispose();
    _obfsMaxController.dispose();
    _hopPortsController.dispose();
    _hopIntervalController.dispose();
    _hopIntervalMaxController.dispose();
    _upMbpsController.dispose();
    _downMbpsController.dispose();
    _insecureConcurrencyController.dispose();
    for (final header in _headers) {
      header.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      ServerAdvancedSettings(
        flow: widget.protocol == ServerProtocol.vless ? _flow.trim() : '',
        vlessEncryption: widget.protocol == ServerProtocol.vless
            ? _encryptionController.text.trim()
            : '',
        realitySpiderX:
            widget.protocol == ServerProtocol.vless &&
                widget.security == VlessSecurity.reality
            ? _spiderXController.text.trim()
            : '',
        realityMldsa65Verify:
            widget.protocol == ServerProtocol.vless &&
                widget.security == VlessSecurity.reality
            ? _mldsaController.text.trim()
            : '',
        hysteria2ObfsType: widget.protocol == ServerProtocol.hysteria2
            ? _obfsType
            : '',
        hysteria2ObfsPassword:
            widget.protocol == ServerProtocol.hysteria2 && _obfsType.isNotEmpty
            ? _obfsPasswordController.text.trim()
            : '',
        hysteria2ObfsMinPacketSize:
            widget.protocol == ServerProtocol.hysteria2 && _obfsType == 'gecko'
            ? _int(_obfsMinController)
            : 0,
        hysteria2ObfsMaxPacketSize:
            widget.protocol == ServerProtocol.hysteria2 && _obfsType == 'gecko'
            ? _int(_obfsMaxController)
            : 0,
        hysteria2HopPorts: widget.protocol == ServerProtocol.hysteria2
            ? _hopPortsController.text.trim()
            : '',
        hysteria2HopInterval: widget.protocol == ServerProtocol.hysteria2
            ? _hopIntervalController.text.trim()
            : '',
        hysteria2HopIntervalMax: widget.protocol == ServerProtocol.hysteria2
            ? _hopIntervalMaxController.text.trim()
            : '',
        hysteria2UpMbps: widget.protocol == ServerProtocol.hysteria2
            ? _int(_upMbpsController)
            : 0,
        hysteria2DownMbps: widget.protocol == ServerProtocol.hysteria2
            ? _int(_downMbpsController)
            : 0,
        hysteria2Network: widget.protocol == ServerProtocol.hysteria2
            ? _network
            : '',
        hysteria2BbrProfile: widget.protocol == ServerProtocol.hysteria2
            ? _bbrProfile
            : '',
        naiveInsecureConcurrency: widget.protocol == ServerProtocol.naive
            ? _int(_insecureConcurrencyController)
            : 0,
        naiveExtraHeaders: widget.protocol == ServerProtocol.naive
            ? {
                for (final header in _headers)
                  if (header.key.text.trim().isNotEmpty)
                    header.key.text.trim(): header.value.text,
              }
            : const {},
        naiveUdpOverTcp: widget.protocol == ServerProtocol.naive && _udpOverTcp,
        naiveUdpOverTcpVersion:
            widget.protocol == ServerProtocol.naive && _udpOverTcp
            ? _udpOverTcpVersion
            : 0,
      ),
    );
  }

  int _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = VoidTokens.of(context);
    return Material(
      color: t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: widget.initial.hasValues,
        title: Text(
          l.editServerAdvancedTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          if (widget.protocol == ServerProtocol.vless) ..._vlessFields(l),
          if (widget.protocol == ServerProtocol.hysteria2)
            ..._hysteria2Fields(l),
          if (widget.protocol == ServerProtocol.naive) ..._naiveFields(l),
        ],
      ),
    );
  }

  List<Widget> _vlessFields(AppLocalizations l) {
    final flows = _withCurrent(_flowOptions, _flow);
    return [
      _dropdown(
        value: _flow,
        label: l.editServerFlowLabel,
        values: flows,
        labelFor: (value) => value.isEmpty ? l.editServerAuto : value,
        onChanged: (value) {
          setState(() => _flow = value);
          _emit();
        },
      ),
      const SizedBox(height: 12),
      _text(
        controller: _encryptionController,
        label: l.editServerEncryptionLabel,
      ),
      if (widget.security == VlessSecurity.reality) ...[
        const SizedBox(height: 12),
        _text(
          controller: _spiderXController,
          label: l.editServerRealitySpiderXLabel,
        ),
        const SizedBox(height: 12),
        _text(
          controller: _mldsaController,
          label: l.editServerRealityMldsaLabel,
        ),
      ],
    ];
  }

  List<Widget> _hysteria2Fields(AppLocalizations l) {
    return [
      _dropdown(
        value: _obfsType,
        label: l.editServerHysteriaObfsTypeLabel,
        values: _withCurrent(_obfsOptions, _obfsType),
        labelFor: (value) => switch (value) {
          '' => l.editServerHysteriaObfsNone,
          'salamander' => 'Salamander',
          'gecko' => 'Gecko',
          _ => value,
        },
        onChanged: (value) {
          setState(() => _obfsType = value);
          _emit();
        },
      ),
      if (_obfsType.isNotEmpty) ...[
        const SizedBox(height: 12),
        _text(
          controller: _obfsPasswordController,
          label: l.editServerObfsPasswordLabel,
          validator: (value) => value == null || value.trim().isEmpty
              ? l.editServerAdvancedObfsPasswordRequired
              : null,
        ),
      ],
      if (_obfsType == 'gecko') ...[
        const SizedBox(height: 12),
        _integer(
          controller: _obfsMinController,
          label: l.editServerHysteriaObfsMinPacketLabel,
          max: 2048,
        ),
        const SizedBox(height: 12),
        _integer(
          controller: _obfsMaxController,
          label: l.editServerHysteriaObfsMaxPacketLabel,
          max: 2048,
          validator: (value) {
            final normal = _optionalPositiveInt(value, l, max: 2048);
            if (normal != null) return normal;
            final min = _int(_obfsMinController);
            final max = int.tryParse(value?.trim() ?? '') ?? 0;
            return min > 0 && max > 0 && max < min
                ? l.editServerAdvancedRangeOrder
                : null;
          },
        ),
      ],
      const SizedBox(height: 12),
      _text(controller: _hopPortsController, label: l.editServerHopPortsLabel),
      const SizedBox(height: 12),
      _text(
        controller: _hopIntervalController,
        label: l.editServerHysteriaHopIntervalLabel,
        validator: (value) => _duration(value, l),
      ),
      const SizedBox(height: 12),
      _text(
        controller: _hopIntervalMaxController,
        label: l.editServerHysteriaHopIntervalMaxLabel,
        validator: (value) => _duration(value, l),
      ),
      const SizedBox(height: 12),
      _integer(
        controller: _upMbpsController,
        label: l.editServerHysteriaUpMbpsLabel,
      ),
      const SizedBox(height: 12),
      _integer(
        controller: _downMbpsController,
        label: l.editServerHysteriaDownMbpsLabel,
      ),
      const SizedBox(height: 12),
      _dropdown(
        value: _network,
        label: l.editServerHysteriaNetworkLabel,
        values: _withCurrent(_networkOptions, _network),
        labelFor: (value) => switch (value) {
          '' => l.editServerHysteriaNetworkBoth,
          'tcp' => 'TCP',
          'udp' => 'UDP',
          _ => value,
        },
        onChanged: (value) {
          setState(() => _network = value);
          _emit();
        },
      ),
      const SizedBox(height: 12),
      _dropdown(
        value: _bbrProfile,
        label: l.editServerHysteriaBbrProfileLabel,
        values: _withCurrent(_bbrOptions, _bbrProfile),
        labelFor: (value) => value.isEmpty ? l.editServerAuto : value,
        onChanged: (value) {
          setState(() => _bbrProfile = value);
          _emit();
        },
      ),
    ];
  }

  List<Widget> _naiveFields(AppLocalizations l) {
    return [
      _integer(
        controller: _insecureConcurrencyController,
        label: l.editServerNaiveInsecureConcurrencyLabel,
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l.editServerNaiveExtraHeadersLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 8),
      ..._headerRows(l),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.enabled
              ? () {
                  setState(() => _headers.add(_HeaderDraft('', '')));
                  _emit();
                }
              : null,
          icon: const Icon(Icons.add_rounded),
          label: Text(l.editServerNaiveAddHeader),
        ),
      ),
      SwitchListTile.adaptive(
        value: _udpOverTcp,
        onChanged: widget.enabled
            ? (value) {
                setState(() => _udpOverTcp = value);
                _emit();
              }
            : null,
        title: Text(l.editServerNaiveUdpOverTcpLabel),
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      if (_udpOverTcp) ...[
        const SizedBox(height: 12),
        _dropdown<int>(
          value: _udpOverTcpVersion,
          label: l.editServerNaiveUdpOverTcpVersionLabel,
          values: const [0, 1, 2],
          labelFor: (value) => value == 0 ? l.editServerAuto : value.toString(),
          onChanged: (value) {
            setState(() => _udpOverTcpVersion = value);
            _emit();
          },
        ),
      ],
    ];
  }

  List<Widget> _headerRows(AppLocalizations l) {
    return [
      for (var index = 0; index < _headers.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _text(
                  controller: _headers[index].key,
                  label: l.editServerNaiveHeaderNameLabel,
                  validator: (value) {
                    final key = value?.trim() ?? '';
                    if (key.isEmpty) return l.editServerAdvancedHeaderRequired;
                    if (key.contains('\r') || key.contains('\n')) {
                      return l.editServerAdvancedHeaderNewline;
                    }
                    final matches = _headers
                        .where(
                          (header) =>
                              header.key.text.trim().toLowerCase() ==
                              key.toLowerCase(),
                        )
                        .length;
                    return matches > 1
                        ? l.editServerAdvancedHeaderDuplicate
                        : null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _text(
                  controller: _headers[index].value,
                  label: l.editServerNaiveHeaderValueLabel,
                  validator: (value) =>
                      value?.contains(RegExp(r'[\r\n]')) == true
                      ? l.editServerAdvancedHeaderNewline
                      : null,
                ),
              ),
              IconButton(
                onPressed: widget.enabled
                    ? () {
                        final removed = _headers.removeAt(index);
                        removed.dispose();
                        setState(() {});
                        _emit();
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
    ];
  }

  List<T> _withCurrent<T>(List<T> options, T current) =>
      options.contains(current) ? options : [...options, current];

  Widget _fieldLabel(String label) {
    final style = Theme.of(context).inputDecorationTheme.labelStyle;
    return Text(label, style: style);
  }

  Widget _fieldShell({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration get _plainDecoration => const InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  Widget _text({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return _fieldShell(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: widget.enabled,
        maxLines: 1,
        validator: validator,
        onChanged: (_) => _emit(),
        style: _monoFieldStyle,
        decoration: _plainDecoration,
      ),
    );
  }

  TextStyle get _monoFieldStyle => const TextStyle(
    fontFamily: 'monospace',
    fontWeight: FontWeight.w500,
  );

  Widget _integer({
    required TextEditingController controller,
    required String label,
    int? max,
    String? Function(String?)? validator,
  }) {
    return _text(
      controller: controller,
      label: label,
      validator:
          validator ??
          (value) => _optionalPositiveInt(
            value,
            AppLocalizations.of(context),
            max: max,
          ),
    );
  }

  String? _optionalPositiveInt(String? value, AppLocalizations l, {int? max}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0 || (max != null && parsed > max)) {
      return max == null
          ? l.editServerAdvancedPositiveInteger
          : l.editServerAdvancedIntegerMax;
    }
    return null;
  }

  String? _duration(String? value, AppLocalizations l) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    return RegExp(r'^(?:\d+(?:ns|us|ms|s|m|h))+$').hasMatch(raw)
        ? null
        : l.editServerAdvancedDurationInvalid;
  }

  Widget _dropdown<T>({
    required T value,
    required String label,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    return _fieldShell(
      label: label,
      child: DropdownButtonFormField<T>(
        isExpanded: true,
        isDense: true,
        initialValue: value,
        decoration: _plainDecoration,
        selectedItemBuilder: (context) => [
          for (final item in values)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                labelFor(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _monoFieldStyle,
              ),
            ),
        ],
        items: values
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelFor(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _monoFieldStyle,
                ),
              ),
            )
            .toList(),
        onChanged: widget.enabled
            ? (next) {
                if (next != null) onChanged(next);
              }
            : null,
      ),
    );
  }
}

class _HeaderDraft {
  _HeaderDraft(String key, String value)
    : key = TextEditingController(text: key),
      value = TextEditingController(text: value);

  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}
