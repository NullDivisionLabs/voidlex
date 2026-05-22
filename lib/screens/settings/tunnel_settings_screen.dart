part of '../settings_screen.dart';

String _tunnelStackLabel(AppLocalizations l, TunnelNetworkStack stack) {
  return switch (stack) {
    TunnelNetworkStack.system => l.tunnelNetStackSystem,
    TunnelNetworkStack.gvisor => l.tunnelNetStackGvisor,
    TunnelNetworkStack.mixed => l.tunnelNetStackMixed,
  };
}

String _tunnelIpModeLabel(AppLocalizations l, TunnelIpMode mode) {
  return switch (mode) {
    TunnelIpMode.ipv4 => l.tunnelIpModeIpv4,
    TunnelIpMode.ipv6 => l.tunnelIpModeIpv6,
    TunnelIpMode.mixed => l.tunnelIpModeMixed,
  };
}

String _multiplexQuicLabel(AppLocalizations l, MultiplexQuicBehavior b) {
  return switch (b) {
    MultiplexQuicBehavior.reject => l.tunnelMuxQuicReject,
    MultiplexQuicBehavior.allow => l.tunnelMuxQuicAllow,
    MultiplexQuicBehavior.passthrough => l.tunnelMuxQuicPassthrough,
  };
}

class _TunnelSettingsScreen extends StatefulWidget {
  const _TunnelSettingsScreen({
    required this.controller,
    this.useTvChrome = false,
    this.allowTvChromeInAutoRotate = false,
  });

  final VpnController controller;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<_TunnelSettingsScreen> createState() => _TunnelSettingsScreenState();
}

class _TunnelSettingsScreenState extends State<_TunnelSettingsScreen> {
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  late final TextEditingController _fragmentLengthController;
  late final TextEditingController _fragmentIntervalController;
  late final TextEditingController _fragmentMaxSplitController;
  late final TextEditingController _noisePacketController;
  late final TextEditingController _noiseDelayController;
  bool _passwordObscured = true;
  bool _noiseSettingsExpanded = false;
  MultiplexSettings _multiplexSettings = const MultiplexSettings();
  TunnelNetworkSettings _tunnelNetworkSettings = TunnelNetworkSettings.defaults;
  late final TextEditingController _xrayTunDnsController;
  late final FocusNode _xrayTunDnsFocusNode;
  late final TextEditingController _mtuController;
  late final FocusNode _mtuFocusNode;
  bool _closing = false;

  static final _rangeInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
    LengthLimitingTextInputFormatter(16),
  ];

  @override
  void initState() {
    super.initState();
    _userController = TextEditingController(
      text: widget.controller.customProxyUser,
    );
    _passwordController = TextEditingController(
      text: widget.controller.customProxyPassword,
    );
    final fragment = widget.controller.tunnelFragmentSettings;
    _fragmentLengthController = TextEditingController(text: fragment.length);
    _fragmentIntervalController = TextEditingController(
      text: fragment.interval,
    );
    _fragmentMaxSplitController = TextEditingController(
      text: fragment.maxSplit,
    );
    _noisePacketController = TextEditingController(text: fragment.noisePacket);
    _noiseDelayController = TextEditingController(text: fragment.noiseDelay);
    _xrayTunDnsController = TextEditingController(
      text: widget.controller.tunnelNetworkSettings.xrayTunDnsServer,
    );
    _xrayTunDnsFocusNode = FocusNode();
    _xrayTunDnsFocusNode.addListener(_handleXrayTunDnsFocusChange);
    _mtuController = TextEditingController(
      text: widget.controller.tunnelNetworkSettings.mtu.toString(),
    );
    _mtuFocusNode = FocusNode();
    _mtuFocusNode.addListener(_handleMtuFocusChange);
    _noiseSettingsExpanded = fragment.noiseEnabled;
    _multiplexSettings = widget.controller.multiplexSettings;
    _tunnelNetworkSettings = widget.controller.tunnelNetworkSettings;
  }

  @override
  void dispose() {
    if (_mtuFocusNode.hasFocus) {
      // Persist any in-flight MTU edit before tearing the screen down.
      unawaited(_commitMtu(_mtuController.text));
    }
    if (_xrayTunDnsFocusNode.hasFocus) {
      unawaited(_commitXrayTunDnsServer(_xrayTunDnsController.text));
    }
    if (!_closing) {
      unawaited(widget.controller.applyPendingNetworkSettingsRestart());
    }
    _userController.dispose();
    _passwordController.dispose();
    _fragmentLengthController.dispose();
    _fragmentIntervalController.dispose();
    _fragmentMaxSplitController.dispose();
    _noisePacketController.dispose();
    _noiseDelayController.dispose();
    _xrayTunDnsController.dispose();
    _xrayTunDnsFocusNode
      ..removeListener(_handleXrayTunDnsFocusChange)
      ..dispose();
    _mtuController.dispose();
    _mtuFocusNode
      ..removeListener(_handleMtuFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleMtuFocusChange() {
    if (_mtuFocusNode.hasFocus) return;
    unawaited(_commitMtu(_mtuController.text));
  }

  void _handleXrayTunDnsFocusChange() {
    if (_xrayTunDnsFocusNode.hasFocus) return;
    unawaited(_commitXrayTunDnsServer(_xrayTunDnsController.text));
  }

  Future<void> _setXrayTunEnabled(bool enabled) async {
    final mode = enabled ? TunEngineMode.xray : TunEngineMode.libbox;
    if (widget.controller.tunEngineMode == mode) return;
    await widget.controller.setTunEngineMode(mode);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setBlockUdpEnabled(bool enabled) {
    return _updateTunnelNetworkSettings(
      (current) => current.copyWith(blockUdp: enabled),
    );
  }

  Future<void> _setCustomProxyAuthEnabled(bool enabled) async {
    await widget.controller.setUseCustomProxyAuth(enabled);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setTunnelFragmentSettings(
    TunnelFragmentSettings settings,
  ) async {
    await widget.controller.setTunnelFragmentSettings(settings);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setMultiplexSettings(MultiplexSettings settings) async {
    await widget.controller.setMultiplexSettings(settings);
    if (!mounted) return;
    setState(() {
      _multiplexSettings = widget.controller.multiplexSettings;
    });
  }

  Future<void> _updateMultiplexSettings(
    MultiplexSettings Function(MultiplexSettings current) update,
  ) async {
    await _setMultiplexSettings(update(widget.controller.multiplexSettings));
  }

  Future<void> _setMultiplexEnabled(bool enabled) {
    return _updateMultiplexSettings(
      (current) => current.copyWith(enabled: enabled),
    );
  }

  Future<void> _setMultiplexTcpConnections(int value) {
    return _updateMultiplexSettings(
      (current) => current.copyWith(tcpConnections: value),
    );
  }

  Future<void> _setMultiplexXudpConnections(int value) {
    return _updateMultiplexSettings(
      (current) => current.copyWith(xudpConnections: value),
    );
  }

  Future<void> _setMultiplexQuicBehavior(MultiplexQuicBehavior behavior) {
    return _updateMultiplexSettings(
      (current) => current.copyWith(quicBehavior: behavior),
    );
  }

  Future<void> _setTunnelNetworkSettings(TunnelNetworkSettings settings) async {
    await widget.controller.setTunnelNetworkSettings(settings);
    if (!mounted) return;
    setState(() {
      _tunnelNetworkSettings = widget.controller.tunnelNetworkSettings;
    });
  }

  Future<void> _updateTunnelNetworkSettings(
    TunnelNetworkSettings Function(TunnelNetworkSettings current) update,
  ) async {
    await _setTunnelNetworkSettings(
      update(widget.controller.tunnelNetworkSettings),
    );
  }

  Future<void> _setUseLocalDns(bool enabled) {
    return _updateTunnelNetworkSettings(
      (current) => current.copyWith(useLocalDns: enabled),
    );
  }

  Future<void> _setServerResolvingEnabled(bool enabled) {
    return _updateTunnelNetworkSettings(
      (current) => current.copyWith(serverResolvingEnabled: enabled),
    );
  }

  Future<void> _setPacketAnalysisEnabled(bool enabled) {
    return _updateTunnelNetworkSettings(
      (current) => current.copyWith(packetAnalysisEnabled: enabled),
    );
  }

  Future<void> _setNetworkStack(TunnelNetworkStack stack) {
    return _updateTunnelNetworkSettings(
      (current) => current.copyWith(networkStack: stack),
    );
  }

  Future<void> _setIpMode(TunnelIpMode mode) {
    return _updateTunnelNetworkSettings(
      (current) => current.copyWith(ipMode: mode),
    );
  }

  Future<void> _setXrayTunDnsEnabled(bool enabled) {
    return _updateTunnelNetworkSettings(
      (current) => current.copyWith(xrayTunDnsEnabled: enabled),
    );
  }

  Future<void> _commitXrayTunDnsServer(String value) async {
    final trimmed = value.trim();
    final current = widget.controller.tunnelNetworkSettings.xrayTunDnsServer;
    if (trimmed == current) return;
    final effective = trimmed.isEmpty
        ? TunnelNetworkSettings.defaultXrayTunDnsServer
        : trimmed;
    await _updateTunnelNetworkSettings(
      (current) => current.copyWith(xrayTunDnsServer: effective),
    );
    if (!mounted) return;
    _syncTextController(
      _xrayTunDnsController,
      widget.controller.tunnelNetworkSettings.xrayTunDnsServer,
    );
  }

  Future<void> _commitMtu(String value) async {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      _syncTextController(
        _mtuController,
        _tunnelNetworkSettings.mtu.toString(),
      );
      return;
    }
    await _updateTunnelNetworkSettings(
      (current) => current.copyWith(mtu: parsed),
    );
    if (!mounted) return;
    _syncTextController(
      _mtuController,
      widget.controller.tunnelNetworkSettings.mtu.toString(),
    );
  }

  Future<void> _updateTunnelFragmentSettings(
    TunnelFragmentSettings Function(TunnelFragmentSettings current) update,
  ) async {
    await _setTunnelFragmentSettings(
      update(widget.controller.tunnelFragmentSettings),
    );
  }

  void _syncFragmentTextFields(TunnelFragmentSettings fragment) {
    _syncTextController(_fragmentLengthController, fragment.length);
    _syncTextController(_fragmentIntervalController, fragment.interval);
    _syncTextController(_fragmentMaxSplitController, fragment.maxSplit);
    _syncTextController(_noisePacketController, fragment.noisePacket);
    _syncTextController(_noiseDelayController, fragment.noiseDelay);
  }

  void _syncTunnelNetworkTextFields(TunnelNetworkSettings settings) {
    // Don't overwrite text fields while the user is typing in them; another
    // setting flipping setState would otherwise revert their in-flight edit.
    // The focus listeners commit + sync on blur.
    if (!_mtuFocusNode.hasFocus) {
      _syncTextController(_mtuController, settings.mtu.toString());
    }
    if (!_xrayTunDnsFocusNode.hasFocus) {
      _syncTextController(_xrayTunDnsController, settings.xrayTunDnsServer);
    }
  }

  void _syncTextController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.text = value;
  }

  Future<void> _commitProxyUser(String value) async {
    final trimmed = value.trim();
    if (trimmed == widget.controller.customProxyUser) return;
    await widget.controller.setCustomProxyUser(trimmed);
  }

  Future<void> _commitProxyPassword(String value) async {
    if (value == widget.controller.customProxyPassword) return;
    await widget.controller.setCustomProxyPassword(value);
  }

  Future<void> _regenerateProxyCredentials() async {
    final user = _randomHex(16);
    final password = _randomHex(24);
    _userController.text = user;
    _passwordController.text = password;
    await widget.controller.setCustomProxyUser(user);
    await widget.controller.setCustomProxyPassword(password);
    if (!mounted) return;
    setState(() {});
  }

  static String _randomHex(int byteLength) {
    final rng = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < byteLength; i++) {
      buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<void> _commitFocusedTextFields() async {
    final commits = <Future<void>>[];
    if (_mtuFocusNode.hasFocus) {
      commits.add(_commitMtu(_mtuController.text));
    }
    if (_xrayTunDnsFocusNode.hasFocus) {
      commits.add(_commitXrayTunDnsServer(_xrayTunDnsController.text));
    }
    if (commits.isNotEmpty) {
      await Future.wait(commits);
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _commitFocusedTextFields();
    final controller = widget.controller;
    if (!mounted) return;
    Navigator.of(context).pop();
    unawaited(controller.applyPendingNetworkSettingsRestart());
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) => _buildBody(context, orientation),
    );
  }

  Widget _buildBody(BuildContext context, Orientation orientation) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final engine = widget.controller.tunEngineMode;
    final xrayTunEnabled = engine == TunEngineMode.xray;
    final useCustomProxyAuth = widget.controller.useCustomProxyAuth;
    final fragment = widget.controller.tunnelFragmentSettings;
    _multiplexSettings = widget.controller.multiplexSettings;
    _tunnelNetworkSettings = widget.controller.tunnelNetworkSettings;
    _syncFragmentTextFields(fragment);
    _syncTunnelNetworkTextFields(_tunnelNetworkSettings);
    if (!fragment.noiseEnabled && _noiseSettingsExpanded) {
      _noiseSettingsExpanded = false;
    }
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
        unawaited(_close());
      },
      child: Scaffold(
        appBar: useTvChrome
            ? null
            : AppBar(
                leading: IconButton(
                  onPressed: _close,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: Text(l.tunnelSettingsTitle),
              ),
        body: _TvSettingsBody(
          enabled: useTvChrome,
          title: l.tunnelSettingsTitle,
          subtitle: l.settingsTunnelSubtitle,
          onBack: _close,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      _CompactToggleRow(
                        icon: Icons.dns_rounded,
                        title: l.tunnelUseLocalDns,
                        value: _tunnelNetworkSettings.useLocalDns,
                        onChanged: _setUseLocalDns,
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      _CompactToggleRow(
                        icon: Icons.travel_explore_rounded,
                        title: l.tunnelEnableServerResolving,
                        value: _tunnelNetworkSettings.serverResolvingEnabled,
                        onChanged: _setServerResolvingEnabled,
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      _CompactToggleRow(
                        icon: Icons.analytics_rounded,
                        title: l.tunnelPacketAnalysis,
                        value: _tunnelNetworkSettings.packetAnalysisEnabled,
                        onChanged: _setPacketAnalysisEnabled,
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      _CompactValueRow(
                        icon: Icons.layers_rounded,
                        title: l.tunnelNetworkStack,
                        child: SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<TunnelNetworkStack>(
                            key: ValueKey(_tunnelNetworkSettings.networkStack),
                            initialValue: _tunnelNetworkSettings.networkStack,
                            isDense: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: TunnelNetworkStack.values
                                .map(
                                  (stack) => DropdownMenuItem(
                                    value: stack,
                                    child: Text(_tunnelStackLabel(l, stack)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              _setNetworkStack(value);
                            },
                          ),
                        ),
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      _CompactValueRow(
                        icon: Icons.settings_ethernet_rounded,
                        title: l.tunnelMtu,
                        child: SizedBox(
                          width: 96,
                          child: TextField(
                            controller: _mtuController,
                            focusNode: _mtuFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            textAlign: TextAlign.center,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              hintText: l.tunnelMtuHint,
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      _CompactValueRow(
                        icon: Icons.public_rounded,
                        title: l.tunnelIpMode,
                        child: SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<TunnelIpMode>(
                            key: ValueKey(_tunnelNetworkSettings.ipMode),
                            initialValue: _tunnelNetworkSettings.ipMode,
                            isDense: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: TunnelIpMode.values
                                .map(
                                  (mode) => DropdownMenuItem(
                                    value: mode,
                                    child: Text(_tunnelIpModeLabel(l, mode)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              _setIpMode(value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _TunnelFragmentSettingsCard(
                  settings: fragment,
                  lengthController: _fragmentLengthController,
                  intervalController: _fragmentIntervalController,
                  maxSplitController: _fragmentMaxSplitController,
                  noisePacketController: _noisePacketController,
                  noiseDelayController: _noiseDelayController,
                  rangeInputFormatters: _rangeInputFormatters,
                  onEnabledChanged: (enabled) => _updateTunnelFragmentSettings(
                    (current) => current.copyWith(enabled: enabled),
                  ),
                  onPacketsChanged: (packets) => _updateTunnelFragmentSettings(
                    (current) => current.copyWith(packets: packets),
                  ),
                  onLengthChanged: (length) => _updateTunnelFragmentSettings(
                    (current) => current.copyWith(length: length.trim()),
                  ),
                  onIntervalChanged: (interval) =>
                      _updateTunnelFragmentSettings(
                        (current) =>
                            current.copyWith(interval: interval.trim()),
                      ),
                  onMaxSplitChanged: (maxSplit) =>
                      _updateTunnelFragmentSettings(
                        (current) =>
                            current.copyWith(maxSplit: maxSplit.trim()),
                      ),
                  onNoiseEnabledChanged: (enabled) {
                    setState(() {
                      _noiseSettingsExpanded = enabled;
                    });
                    _updateTunnelFragmentSettings(
                      (current) => current.copyWith(noiseEnabled: enabled),
                    );
                  },
                  noiseSettingsExpanded: _noiseSettingsExpanded,
                  onNoiseHeaderTap: () {
                    if (!fragment.noiseEnabled) return;
                    setState(() {
                      _noiseSettingsExpanded = !_noiseSettingsExpanded;
                    });
                  },
                  onNoiseTypeChanged: (noiseType) =>
                      _updateTunnelFragmentSettings(
                        (current) => current.copyWith(noiseType: noiseType),
                      ),
                  onNoisePacketChanged: (packet) =>
                      _updateTunnelFragmentSettings(
                        (current) =>
                            current.copyWith(noisePacket: packet.trim()),
                      ),
                  onNoiseDelayChanged: (delay) => _updateTunnelFragmentSettings(
                    (current) => current.copyWith(noiseDelay: delay.trim()),
                  ),
                  onNoiseApplyToChanged: (applyTo) =>
                      _updateTunnelFragmentSettings(
                        (current) => current.copyWith(noiseApplyTo: applyTo),
                      ),
                ),
                const SizedBox(height: 12),
                _MultiplexSettingsCard(
                  settings: _multiplexSettings,
                  onEnabledChanged: _setMultiplexEnabled,
                  onTcpConnectionsChanged: _setMultiplexTcpConnections,
                  onXudpConnectionsChanged: _setMultiplexXudpConnections,
                  onQuicBehaviorChanged: _setMultiplexQuicBehavior,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      _CompactToggleRow(
                        icon: Icons.block_rounded,
                        title: l.tunnelBlockUdp,
                        description: l.tunnelBlockUdpDescription,
                        value: _tunnelNetworkSettings.blockUdp,
                        onChanged: _setBlockUdpEnabled,
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              xrayTunEnabled
                                  ? Icons.science_rounded
                                  : Icons.verified_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.tunnelXrayTun,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l.tunnelXrayTunDescription,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: xrayTunEnabled,
                              onChanged: _setXrayTunEnabled,
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      _CompactToggleRow(
                        icon: Icons.dns_rounded,
                        title: l.tunnelEnableDnsForTun,
                        value: _tunnelNetworkSettings.xrayTunDnsEnabled,
                        enabled: xrayTunEnabled,
                        onChanged: _setXrayTunDnsEnabled,
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: TextField(
                          controller: _xrayTunDnsController,
                          focusNode: _xrayTunDnsFocusNode,
                          enabled:
                              xrayTunEnabled &&
                              _tunnelNetworkSettings.xrayTunDnsEnabled,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _commitXrayTunDnsServer,
                          decoration: InputDecoration(
                            labelText: l.tunnelTunDnsLabel,
                            hintText: l.tunnelTunDnsHint,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.tunnelCustomSocksTitle,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    useCustomProxyAuth
                                        ? l.tunnelCustomSocksOnDescription
                                        : l.tunnelCustomSocksOffDescription,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: useCustomProxyAuth,
                              onChanged: _setCustomProxyAuthEnabled,
                            ),
                          ],
                        ),
                      ),
                      if (useCustomProxyAuth) ...[
                        Divider(height: 1, color: theme.dividerColor),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _userController,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: l.tunnelProxyUserLabel,
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: _commitProxyUser,
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _passwordController,
                                autocorrect: false,
                                enableSuggestions: false,
                                obscureText: _passwordObscured,
                                decoration: InputDecoration(
                                  labelText: l.tunnelProxyPasswordLabel,
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordObscured
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                    ),
                                    onPressed: () => setState(() {
                                      _passwordObscured = !_passwordObscured;
                                    }),
                                    tooltip: _passwordObscured
                                        ? l.show
                                        : l.hide,
                                  ),
                                ),
                                onChanged: _commitProxyPassword,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _regenerateProxyCredentials,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(l.tunnelRegenerate),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l.tunnelProxyInboundHelp,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TunnelFragmentSettingsCard extends StatelessWidget {
  const _TunnelFragmentSettingsCard({
    required this.settings,
    required this.lengthController,
    required this.intervalController,
    required this.maxSplitController,
    required this.noisePacketController,
    required this.noiseDelayController,
    required this.rangeInputFormatters,
    required this.onEnabledChanged,
    required this.onPacketsChanged,
    required this.onLengthChanged,
    required this.onIntervalChanged,
    required this.onMaxSplitChanged,
    required this.onNoiseEnabledChanged,
    required this.noiseSettingsExpanded,
    required this.onNoiseHeaderTap,
    required this.onNoiseTypeChanged,
    required this.onNoisePacketChanged,
    required this.onNoiseDelayChanged,
    required this.onNoiseApplyToChanged,
  });

  static const _packetOptions = [
    _DropdownOption('tlshello', 'tlshello'),
    _DropdownOption('1-1', '1-1'),
    _DropdownOption('1-2', '1-2'),
    _DropdownOption('1-3', '1-3'),
  ];

  final TunnelFragmentSettings settings;
  final TextEditingController lengthController;
  final TextEditingController intervalController;
  final TextEditingController maxSplitController;
  final TextEditingController noisePacketController;
  final TextEditingController noiseDelayController;
  final List<TextInputFormatter> rangeInputFormatters;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onPacketsChanged;
  final ValueChanged<String> onLengthChanged;
  final ValueChanged<String> onIntervalChanged;
  final ValueChanged<String> onMaxSplitChanged;
  final ValueChanged<bool> onNoiseEnabledChanged;
  final bool noiseSettingsExpanded;
  final VoidCallback onNoiseHeaderTap;
  final ValueChanged<String> onNoiseTypeChanged;
  final ValueChanged<String> onNoisePacketChanged;
  final ValueChanged<String> onNoiseDelayChanged;
  final ValueChanged<String> onNoiseApplyToChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final noiseTypeOptions = [
      _DropdownOption('rand', l.tunnelNoiseTypeRandom),
      _DropdownOption('str', l.tunnelNoiseTypeString),
      _DropdownOption('hex', l.tunnelNoiseTypeHex),
      _DropdownOption('base64', l.tunnelNoiseTypeBase64),
    ];
    final applyToOptions = [
      _DropdownOption('ip', l.tunnelNoiseApplyIp),
      _DropdownOption('ipv4', l.tunnelNoiseApplyIpv4),
      _DropdownOption('ipv6', l.tunnelNoiseApplyIpv6),
    ];
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.auto_fix_high_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.tunnelFragmentEnable,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.enabled
                            ? l.tunnelFragmentOnDescription
                            : l.tunnelFragmentOffDescription,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(value: settings.enabled, onChanged: onEnabledChanged),
              ],
            ),
          ),
          if (settings.enabled) ...[
            Divider(height: 1, color: theme.dividerColor),
            _FragmentSettingRow(
              label: l.tunnelFragmentPackets,
              child: _FragmentDropdown(
                value: settings.packets,
                options: _packetOptions,
                onChanged: onPacketsChanged,
              ),
            ),
            _FragmentSettingRow(
              label: l.tunnelFragmentLength,
              child: _FragmentTextField(
                controller: lengthController,
                inputFormatters: rangeInputFormatters,
                onChanged: onLengthChanged,
              ),
            ),
            _FragmentSettingRow(
              label: l.tunnelFragmentInterval,
              child: _FragmentTextField(
                controller: intervalController,
                inputFormatters: rangeInputFormatters,
                onChanged: onIntervalChanged,
              ),
            ),
            _FragmentSettingRow(
              label: l.tunnelFragmentMaxSplit,
              child: _FragmentTextField(
                controller: maxSplitController,
                inputFormatters: rangeInputFormatters,
                onChanged: onMaxSplitChanged,
              ),
            ),
            InkWell(
              onTap: onNoiseHeaderTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.tunnelNoiseSettings,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      noiseSettingsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: settings.noiseEnabled
                          ? theme.iconTheme.color
                          : theme.disabledColor,
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: settings.noiseEnabled,
                      onChanged: onNoiseEnabledChanged,
                    ),
                  ],
                ),
              ),
            ),
            if (settings.noiseEnabled && noiseSettingsExpanded) ...[
              Divider(height: 1, color: theme.dividerColor),
              _FragmentSettingRow(
                label: l.tunnelNoiseType,
                child: _FragmentDropdown(
                  value: settings.noiseType,
                  options: noiseTypeOptions,
                  onChanged: onNoiseTypeChanged,
                ),
              ),
              _FragmentSettingRow(
                label: settings.noiseType == 'rand'
                    ? l.tunnelNoisePacketLengthRange
                    : l.tunnelNoisePacket,
                child: _FragmentTextField(
                  controller: noisePacketController,
                  inputFormatters: settings.noiseType == 'rand'
                      ? rangeInputFormatters
                      : const <TextInputFormatter>[],
                  onChanged: onNoisePacketChanged,
                ),
              ),
              _FragmentSettingRow(
                label: l.tunnelNoiseDelay,
                child: _FragmentTextField(
                  controller: noiseDelayController,
                  inputFormatters: rangeInputFormatters,
                  onChanged: onNoiseDelayChanged,
                ),
              ),
              _FragmentSettingRow(
                label: l.tunnelNoiseApplyTo,
                showDivider: false,
                child: _FragmentDropdown(
                  value: settings.noiseApplyTo,
                  options: applyToOptions,
                  onChanged: onNoiseApplyToChanged,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FragmentSettingRow extends StatelessWidget {
  const _FragmentSettingRow({
    required this.label,
    required this.child,
    this.showDivider = true,
  });

  final String label;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: theme.dividerColor))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          );
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelWidget, const SizedBox(height: 8), child],
            );
          }
          return Row(
            children: [
              Expanded(child: labelWidget),
              const SizedBox(width: 14),
              SizedBox(
                width: min(220.0, constraints.maxWidth * 0.42),
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MultiplexSettingsCard extends StatelessWidget {
  const _MultiplexSettingsCard({
    required this.settings,
    required this.onEnabledChanged,
    required this.onTcpConnectionsChanged,
    required this.onXudpConnectionsChanged,
    required this.onQuicBehaviorChanged,
  });

  final MultiplexSettings settings;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onTcpConnectionsChanged;
  final ValueChanged<int> onXudpConnectionsChanged;
  final ValueChanged<MultiplexQuicBehavior> onQuicBehaviorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.hub_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.tunnelMuxEnable,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.enabled
                            ? l.tunnelMuxOnDescription
                            : l.tunnelMuxOffDescription,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(value: settings.enabled, onChanged: onEnabledChanged),
              ],
            ),
          ),
          if (settings.enabled) ...[
            Divider(height: 1, color: theme.dividerColor),
            _FragmentSettingRow(
              label: l.tunnelMuxTcpConnections,
              child: _MultiplexConnectionsStepper(
                value: settings.tcpConnections,
                min: MultiplexSettings.minConnections,
                max: MultiplexSettings.maxTcpConnections,
                onChanged: onTcpConnectionsChanged,
              ),
            ),
            _FragmentSettingRow(
              label: l.tunnelMuxXudpConnections,
              child: _MultiplexConnectionsStepper(
                value: settings.xudpConnections,
                min: MultiplexSettings.minConnections,
                max: MultiplexSettings.maxXudpConnections,
                onChanged: onXudpConnectionsChanged,
              ),
            ),
            _FragmentSettingRow(
              label: l.tunnelMuxQuicBehavior,
              showDivider: false,
              child: DropdownButtonFormField<MultiplexQuicBehavior>(
                key: ValueKey(settings.quicBehavior),
                initialValue: settings.quicBehavior,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: MultiplexQuicBehavior.values
                    .map(
                      (behavior) => DropdownMenuItem<MultiplexQuicBehavior>(
                        value: behavior,
                        child: Text(_multiplexQuicLabel(l, behavior)),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next == null) return;
                  onQuicBehaviorChanged(next);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MultiplexConnectionsStepper extends StatelessWidget {
  const _MultiplexConnectionsStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: l.decrease,
          onPressed: value <= min ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_rounded),
        ),
        Expanded(
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: l.increase,
          onPressed: value >= max ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _CompactToggleRow extends StatelessWidget {
  const _CompactToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = enabled ? theme.colorScheme.primary : theme.disabledColor;
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: enabled ? null : theme.disabledColor,
    );
    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: enabled ? null : theme.disabledColor,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: description == null
                ? Text(title, style: titleStyle)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle),
                      const SizedBox(height: 2),
                      Text(description!, style: descriptionStyle),
                    ],
                  ),
          ),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _CompactValueRow extends StatelessWidget {
  const _CompactValueRow({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _FragmentDropdown extends StatelessWidget {
  const _FragmentDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<_DropdownOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...options,
      if (options.every((option) => option.value != value))
        _DropdownOption(value, value),
    ];
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }
}

class _FragmentTextField extends StatelessWidget {
  const _FragmentTextField({
    required this.controller,
    required this.inputFormatters,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: inputFormatters,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
    );
  }
}

class _DropdownOption {
  const _DropdownOption(this.value, this.label);

  final String value;
  final String label;
}
