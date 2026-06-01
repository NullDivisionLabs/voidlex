part of '../settings_screen.dart';

class _RoutingRuleEditorScreen extends StatefulWidget {
  const _RoutingRuleEditorScreen({
    required this.controller,
    this.initial,
    this.useTvChrome = false,
    this.allowTvChromeInAutoRotate = false,
  });

  final VpnController controller;
  final RoutingRule? initial;
  final bool useTvChrome;
  final bool allowTvChromeInAutoRotate;

  @override
  State<_RoutingRuleEditorScreen> createState() =>
      _RoutingRuleEditorScreenState();
}

class _RoutingRuleEditorScreenState extends State<_RoutingRuleEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  bool _enabled = true;
  bool _saving = false;
  RoutingOutbound _outbound = RoutingOutbound.proxy;
  final Set<String> _networks = <String>{};
  final Set<String> _protocols = <String>{};

  @override
  void initState() {
    super.initState();
    final rule = widget.initial;
    if (rule == null) return;
    _nameController.text = rule.name;
    _domainController.text = rule.domains.join('\n');
    _ipController.text = rule.ips.join('\n');
    _portController.text = rule.port;
    _enabled = rule.enabled;
    _outbound = rule.outbound;
    _networks.addAll(rule.networks);
    _protocols.addAll(rule.protocols);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domainController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _toggleValue(Set<String> values, String value, bool selected) {
    setState(() {
      if (selected) {
        values.add(value);
      } else {
        values.remove(value);
      }
    });
  }

  Future<void> _saveRule() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    final domains = _parseList(_domainController.text);
    final ips = _parseList(_ipController.text);
    final port = _portController.text.trim().replaceAll(' ', '');
    final hasMatcher =
        domains.isNotEmpty ||
        ips.isNotEmpty ||
        port.isNotEmpty ||
        _networks.isNotEmpty ||
        _protocols.isNotEmpty;
    if (!hasMatcher) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.routingRuleMatcherRequired)));
      return;
    }

    setState(() => _saving = true);
    final existing = widget.initial;
    final rule = (existing ?? RoutingRule.fresh()).copyWith(
      name: _nameController.text.trim().isEmpty
          ? l.untitled
          : _nameController.text.trim(),
      enabled: _enabled,
      outbound: _outbound,
      domains: domains,
      ips: ips,
      port: port,
      networks: _networks.toList()..sort(),
      protocols: _protocols.toList()..sort(),
    );
    final wasConnected = widget.controller.isConnected;
    await widget.controller.upsertRoutingRule(rule);
    if (!mounted) return;
    Navigator.of(context).pop(wasConnected);
  }

  List<String> _parseList(String raw) {
    return raw
        .split(RegExp(r'[\n,;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  void _cycleOutbound() {
    final values = RoutingOutbound.values;
    final index = values.indexOf(_outbound);
    setState(() => _outbound = values[(index + 1) % values.length]);
  }

  Widget _buildEditorForm(
    ThemeData theme,
    AppLocalizations l,
    bool useTvChrome,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RuleField(
            label: l.routingRuleNameLabel,
            child: _geoUrlField(
              useTvChrome: useTvChrome,
              child: TextField(
                controller: _nameController,
                autofocus: useTvChrome,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.untitled,
                ),
              ),
            ),
          ),
          _RuleField(
            label: l.routingRuleEnabledLabel,
            child: Align(
              alignment: Alignment.centerRight,
              child: useTvChrome
                  ? TvCompactFocusRow(
                      onActivate: () => setState(() => _enabled = !_enabled),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TvSettingsNonFocusTrailing(
                          child: Switch(
                            value: _enabled,
                            onChanged: (value) =>
                                setState(() => _enabled = value),
                          ),
                        ),
                      ),
                    )
                  : Switch(
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
            ),
          ),
          _RuleField(
            label: l.routingRuleConnectionLabel,
            child: useTvChrome
                ? TvCompactFocusRow(
                    onActivate: _cycleOutbound,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _outbound.displayName,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ],
                      ),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<RoutingOutbound>(
                      value: _outbound,
                      borderRadius: BorderRadius.circular(12),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _outbound = value);
                      },
                      items: RoutingOutbound.values
                          .map(
                            (outbound) => DropdownMenuItem(
                              value: outbound,
                              child: Text(outbound.displayName),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
          _RuleField(
            label: l.routingRuleDomainLabel,
            child: _geoUrlField(
              useTvChrome: useTvChrome,
              child: TextField(
                controller: _domainController,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.routingRuleDomainHint,
                ),
              ),
            ),
          ),
          _RuleField(
            label: l.routingRuleIpLabel,
            child: _geoUrlField(
              useTvChrome: useTvChrome,
              child: TextField(
                controller: _ipController,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.routingRuleIpHint,
                ),
              ),
            ),
          ),
          _RuleField(
            label: l.routingRulePortLabel,
            child: _geoUrlField(
              useTvChrome: useTvChrome,
              child: TextField(
                controller: _portController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.routingRulePortHint,
                ),
              ),
            ),
          ),
          _RuleField(
            label: l.routingRuleNetworkLabel,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ruleFilterChip(
                  useTvChrome: useTvChrome,
                  label: l.transportTcp,
                  selected: _networks.contains('tcp'),
                  onSelected: (selected) =>
                      _toggleValue(_networks, 'tcp', selected),
                ),
                _ruleFilterChip(
                  useTvChrome: useTvChrome,
                  label: l.transportUdp,
                  selected: _networks.contains('udp'),
                  onSelected: (selected) =>
                      _toggleValue(_networks, 'udp', selected),
                ),
              ],
            ),
          ),
          _RuleField(
            label: l.routingRuleProtocolLabel,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ruleFilterChip(
                  useTvChrome: useTvChrome,
                  label: l.protocolChipHttp,
                  selected: _protocols.contains('http'),
                  onSelected: (selected) =>
                      _toggleValue(_protocols, 'http', selected),
                ),
                _ruleFilterChip(
                  useTvChrome: useTvChrome,
                  label: l.protocolChipTls,
                  selected: _protocols.contains('tls'),
                  onSelected: (selected) =>
                      _toggleValue(_protocols, 'tls', selected),
                ),
                _ruleFilterChip(
                  useTvChrome: useTvChrome,
                  label: l.protocolChipBittorrent,
                  selected: _protocols.contains('bittorrent'),
                  onSelected: (selected) =>
                      _toggleValue(_protocols, 'bittorrent', selected),
                ),
              ],
            ),
          ),
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
    final l = AppLocalizations.of(context);
    final useTvChrome = _useTvSettingsChrome(
      controller: widget.controller,
      requested: widget.useTvChrome,
      allowInAutoRotate: widget.allowTvChromeInAutoRotate,
      orientation: orientation,
    );
    final saveAction = IconButton(
      tooltip: l.routingRuleSaveTooltip,
      onPressed: _saving ? null : _saveRule,
      icon: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check_rounded),
    );
    return Scaffold(
      appBar: useTvChrome
          ? null
          : AppBar(
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(l.routingRuleEditorTitle),
              actions: [saveAction],
            ),
      body: _TvSettingsBody(
        enabled: useTvChrome,
        title: l.routingRuleEditorTitle,
        subtitle: l.routingCustomRulesHeading,
        actions: useTvChrome ? [saveAction] : const [],
        child: useTvChrome
            ? TvSettingsScrollView(child: _buildEditorForm(theme, l, true))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _buildEditorForm(theme, l, false),
              ),
      ),
    );
  }
}

Widget _ruleFilterChip({
  required bool useTvChrome,
  required String label,
  required bool selected,
  required ValueChanged<bool> onSelected,
}) {
  final chip = FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
  );
  if (!useTvChrome) return chip;
  return TvCompactFocusRow(
    onActivate: () => onSelected(!selected),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: TvSettingsNonFocusTrailing(child: chip),
    ),
  );
}

class _RuleField extends StatelessWidget {
  const _RuleField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
