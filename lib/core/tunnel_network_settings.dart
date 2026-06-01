import 'dart:convert';

import 'bounded_json.dart';

class TunnelNetworkSettings {
  const TunnelNetworkSettings({
    this.useLocalDns = false,
    this.serverResolvingEnabled = false,
    this.packetAnalysisEnabled = true,
    this.blockUdp = false,
    this.networkStack = TunnelNetworkStack.system,
    this.mtu = defaultMtu,
    this.ipMode = TunnelIpMode.ipv4,
    this.xrayTunDnsEnabled = false,
    this.xrayTunDnsServer = defaultXrayTunDnsServer,
  });

  final bool useLocalDns;
  final bool serverResolvingEnabled;
  final bool packetAnalysisEnabled;
  final bool blockUdp;
  final TunnelNetworkStack networkStack;
  final int mtu;
  final TunnelIpMode ipMode;
  final bool xrayTunDnsEnabled;
  final String xrayTunDnsServer;

  static const defaults = TunnelNetworkSettings();
  static const minMtu = 1280;
  static const maxMtu = 9000;
  static const defaultMtu = 1500;
  static const defaultXrayTunDnsServer = '1.1.1.1';

  TunnelNetworkSettings copyWith({
    bool? useLocalDns,
    bool? serverResolvingEnabled,
    bool? packetAnalysisEnabled,
    bool? blockUdp,
    TunnelNetworkStack? networkStack,
    int? mtu,
    TunnelIpMode? ipMode,
    bool? xrayTunDnsEnabled,
    String? xrayTunDnsServer,
  }) {
    return TunnelNetworkSettings(
      useLocalDns: useLocalDns ?? this.useLocalDns,
      serverResolvingEnabled:
          serverResolvingEnabled ?? this.serverResolvingEnabled,
      packetAnalysisEnabled:
          packetAnalysisEnabled ?? this.packetAnalysisEnabled,
      blockUdp: blockUdp ?? this.blockUdp,
      networkStack: networkStack ?? this.networkStack,
      mtu: mtu ?? this.mtu,
      ipMode: ipMode ?? this.ipMode,
      xrayTunDnsEnabled: xrayTunDnsEnabled ?? this.xrayTunDnsEnabled,
      xrayTunDnsServer: xrayTunDnsServer ?? this.xrayTunDnsServer,
    );
  }

  TunnelNetworkSettings normalized() {
    final trimmedDns = xrayTunDnsServer.trim();
    return TunnelNetworkSettings(
      useLocalDns: useLocalDns,
      serverResolvingEnabled: serverResolvingEnabled,
      packetAnalysisEnabled: packetAnalysisEnabled,
      blockUdp: blockUdp,
      networkStack: networkStack,
      mtu: _clamp(mtu, minMtu, maxMtu),
      ipMode: ipMode,
      xrayTunDnsEnabled: xrayTunDnsEnabled,
      xrayTunDnsServer: trimmedDns.isEmpty ? defaultXrayTunDnsServer : trimmedDns,
    );
  }

  bool hasSameConfiguration(TunnelNetworkSettings other) {
    return useLocalDns == other.useLocalDns &&
        serverResolvingEnabled == other.serverResolvingEnabled &&
        packetAnalysisEnabled == other.packetAnalysisEnabled &&
        blockUdp == other.blockUdp &&
        networkStack == other.networkStack &&
        mtu == other.mtu &&
        ipMode == other.ipMode &&
        xrayTunDnsEnabled == other.xrayTunDnsEnabled &&
        xrayTunDnsServer == other.xrayTunDnsServer;
  }

  /// Returns true when [xrayTunDnsEnabled] is on AND a non-empty DNS address
  /// is configured. Used by the Xray TUN engine to decide whether to override
  /// the default upstream DNS resolver.
  bool get hasCustomXrayTunDns =>
      xrayTunDnsEnabled && xrayTunDnsServer.trim().isNotEmpty;

  Map<String, dynamic> toNativeArgs() {
    final normalized = this.normalized();
    return {
      'useLocalDns': normalized.useLocalDns,
      'serverResolvingEnabled': normalized.serverResolvingEnabled,
      'packetAnalysisEnabled': normalized.packetAnalysisEnabled,
      'blockUdp': normalized.blockUdp,
      'networkStack': normalized.networkStack.wireName,
      'tunMtu': normalized.mtu,
      'ipMode': normalized.ipMode.wireName,
      'xrayTunDnsEnabled': normalized.xrayTunDnsEnabled,
      'xrayTunDnsServer': normalized.xrayTunDnsServer,
    };
  }

  Map<String, dynamic> toJson() => {
    'useLocalDns': useLocalDns,
    'serverResolvingEnabled': serverResolvingEnabled,
    'packetAnalysisEnabled': packetAnalysisEnabled,
    'blockUdp': blockUdp,
    'networkStack': networkStack.wireName,
    'mtu': mtu,
    'ipMode': ipMode.wireName,
    'xrayTunDnsEnabled': xrayTunDnsEnabled,
    'xrayTunDnsServer': xrayTunDnsServer,
  };

  String encode() => jsonEncode(normalized().toJson());

  static TunnelNetworkSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = tryDecodeJson(raw, maxBytes: JsonPayloadLimits.settingsBlob);
      if (decoded is! Map<String, dynamic>) return defaults;
      return TunnelNetworkSettings(
        useLocalDns: decoded['useLocalDns'] as bool? ?? defaults.useLocalDns,
        serverResolvingEnabled:
            decoded['serverResolvingEnabled'] as bool? ??
            defaults.serverResolvingEnabled,
        packetAnalysisEnabled:
            decoded['packetAnalysisEnabled'] as bool? ??
            defaults.packetAnalysisEnabled,
        blockUdp: decoded['blockUdp'] as bool? ?? defaults.blockUdp,
        networkStack: TunnelNetworkStack.parse(
          decoded['networkStack'] as String?,
        ),
        mtu: _parseInt(decoded['mtu']) ?? defaults.mtu,
        ipMode: TunnelIpMode.parse(decoded['ipMode'] as String?),
        xrayTunDnsEnabled:
            decoded['xrayTunDnsEnabled'] as bool? ?? defaults.xrayTunDnsEnabled,
        xrayTunDnsServer:
            (decoded['xrayTunDnsServer'] as String?)?.trim().isNotEmpty == true
                ? (decoded['xrayTunDnsServer'] as String).trim()
                : defaults.xrayTunDnsServer,
      ).normalized();
    } on FormatException {
      return defaults;
    } on TypeError {
      return defaults;
    }
  }

  static int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

enum TunnelNetworkStack {
  system('system', 'System'),
  gvisor('gvisor', 'gVisor'),
  mixed('mixed', 'Mixed');

  const TunnelNetworkStack(this.wireName, this.label);
  final String wireName;
  final String label;

  static TunnelNetworkStack parse(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    for (final stack in values) {
      if (stack.wireName == normalized || stack.name == normalized) {
        return stack;
      }
    }
    return TunnelNetworkSettings.defaults.networkStack;
  }
}

enum TunnelIpMode {
  ipv4('ipv4', 'IPv4'),
  ipv6('ipv6', 'IPv6'),
  mixed('mixed', 'Mixed');

  const TunnelIpMode(this.wireName, this.label);
  final String wireName;
  final String label;

  static TunnelIpMode parse(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    for (final mode in values) {
      if (mode.wireName == normalized || mode.name == normalized) {
        return mode;
      }
    }
    return TunnelNetworkSettings.defaults.ipMode;
  }
}
