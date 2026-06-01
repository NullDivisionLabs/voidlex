import 'dart:convert';

import '../bounded_json.dart';

import '../app_routing.dart';
import '../routing_rule.dart';
import '../tun_engine_mode.dart';

enum VlessTransport {
  tcp,
  ws,
  grpc,
  http,
  httpupgrade,
  xhttp;

  String get wireName => name;

  static VlessTransport? tryParse(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '');
    for (final t in VlessTransport.values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

enum VlessSecurity {
  none,
  tls,
  reality;

  bool get tlsEnabled =>
      this == VlessSecurity.tls || this == VlessSecurity.reality;

  String get wireName => name;

  static VlessSecurity? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return VlessSecurity.none;
    final v = raw.trim().toLowerCase();
    for (final s in VlessSecurity.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

enum ServerProtocol {
  vless,
  hysteria2;

  String get wireName {
    switch (this) {
      case ServerProtocol.vless:
        return 'vless';
      case ServerProtocol.hysteria2:
        return 'hysteria2';
    }
  }

  static ServerProtocol? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final v = raw.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '');
    return switch (v) {
      'vless' => ServerProtocol.vless,
      'hysteria' || 'hysteria2' || 'hy2' => ServerProtocol.hysteria2,
      _ => null,
    };
  }
}

class ServerConfig {
  const ServerConfig({
    required this.name,
    required this.address,
    required this.port,
    required this.uuid,
    required this.transport,
    required this.security,
    this.serverProtocol = ServerProtocol.vless,
    this.transportPath = '/',
    this.transportServiceName = '',
    this.transportHost = '',
    this.transportMode = '',
    this.xhttpPadding = '',
    this.xhttpMaxPostBytes = '',
    this.xhttpMinPostInterval = '',
    this.sni = '',
    this.alpn = '',
    this.flow = '',
    this.fingerprint = '',
    this.realityPublicKey = '',
    this.realityShortId = '',
    this.realitySpiderX = '',
    this.tlsInsecure = false,
    this.hysteria2ObfsPassword = '',
    this.hysteria2HopPorts = '',
    this.isPinned = false,
    this.ping = '--',
  });

  final String name;
  final String address;
  final int port;
  final String uuid;
  final VlessTransport transport;
  final VlessSecurity security;
  final ServerProtocol serverProtocol;
  final String transportPath;
  final String transportServiceName;
  final String transportHost;
  final String transportMode;

  /// xhttp `extra.xPaddingBytes` override. Blank ⇒ Android runtime picks
  /// the curated default ("100-1000"). Exposed so a share link / manual
  /// edit can pin the padding to whatever the server expects.
  final String xhttpPadding;

  /// xhttp `extra.scMaxEachPostBytes` override. Caps per-POST payload size
  /// in packet-up mode; harmless under stream-up. Blank ⇒ runtime default.
  final String xhttpMaxPostBytes;

  /// xhttp `extra.scMinPostsIntervalMs` override. Min spacing between
  /// successive POSTs in packet-up. Blank ⇒ runtime default.
  final String xhttpMinPostInterval;

  final String sni;
  final String alpn;
  final String flow;
  final String fingerprint;
  final String realityPublicKey;
  final String realityShortId;
  final String realitySpiderX;
  final bool tlsInsecure;
  final String hysteria2ObfsPassword;
  final String hysteria2HopPorts;
  final bool isPinned;
  final String ping;

  String get id => name;

  String get protocol => serverProtocol.wireName;

  bool get isVless => serverProtocol == ServerProtocol.vless;
  bool get isHysteria2 => serverProtocol == ServerProtocol.hysteria2;

  String get effectiveSni => sni.isNotEmpty ? sni : address;

  ServerConfig copyWith({
    String? name,
    String? address,
    int? port,
    String? uuid,
    VlessTransport? transport,
    VlessSecurity? security,
    ServerProtocol? serverProtocol,
    String? transportPath,
    String? transportServiceName,
    String? transportHost,
    String? transportMode,
    String? xhttpPadding,
    String? xhttpMaxPostBytes,
    String? xhttpMinPostInterval,
    String? sni,
    String? alpn,
    String? flow,
    String? fingerprint,
    String? realityPublicKey,
    String? realityShortId,
    String? realitySpiderX,
    bool? tlsInsecure,
    String? hysteria2ObfsPassword,
    String? hysteria2HopPorts,
    bool? isPinned,
    String? ping,
  }) {
    return ServerConfig(
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      uuid: uuid ?? this.uuid,
      transport: transport ?? this.transport,
      security: security ?? this.security,
      serverProtocol: serverProtocol ?? this.serverProtocol,
      transportPath: transportPath ?? this.transportPath,
      transportServiceName: transportServiceName ?? this.transportServiceName,
      transportHost: transportHost ?? this.transportHost,
      transportMode: transportMode ?? this.transportMode,
      xhttpPadding: xhttpPadding ?? this.xhttpPadding,
      xhttpMaxPostBytes: xhttpMaxPostBytes ?? this.xhttpMaxPostBytes,
      xhttpMinPostInterval: xhttpMinPostInterval ?? this.xhttpMinPostInterval,
      sni: sni ?? this.sni,
      alpn: alpn ?? this.alpn,
      flow: flow ?? this.flow,
      fingerprint: fingerprint ?? this.fingerprint,
      realityPublicKey: realityPublicKey ?? this.realityPublicKey,
      realityShortId: realityShortId ?? this.realityShortId,
      realitySpiderX: realitySpiderX ?? this.realitySpiderX,
      tlsInsecure: tlsInsecure ?? this.tlsInsecure,
      hysteria2ObfsPassword:
          hysteria2ObfsPassword ?? this.hysteria2ObfsPassword,
      hysteria2HopPorts: hysteria2HopPorts ?? this.hysteria2HopPorts,
      isPinned: isPinned ?? this.isPinned,
      ping: ping ?? this.ping,
    );
  }

  /// Sort key for ordering by measured latency (from [ServerLatencyProbe] / UI).
  /// Lower is better; failures and unknown values map to the end of the list.
  static int pingOrderKey(String ping) {
    final s = ping.trim();
    if (s == '...') return 5200000;
    if (s == '--') return 5100000;
    final u = s.toUpperCase();
    if (u == 'ERR') return 5000000;
    if (u == '>5S') return 4500000;
    if (u.startsWith('>')) {
      final m = RegExp(r'^>(\d+)').firstMatch(u);
      if (m != null) return 4000000 + int.parse(m.group(1)!);
      return 4600000;
    }
    final m = RegExp(r'^(\d+)').firstMatch(s);
    if (m != null) return int.parse(m.group(1)!);
    return 5100000;
  }

  Map<String, dynamic> toNativeArgs({
    required bool isGlobalProxy,
    required TunEngineMode tunEngineMode,
    AppRoutingPolicy appRoutingPolicy = AppRoutingPolicy.empty,
    List<RoutingRule> routingRules = const [],
    ServerConfig? entryServer,
  }) {
    final effectiveAppRoutingPolicy = isGlobalProxy
        ? AppRoutingPolicy.empty
        : appRoutingPolicy;
    final activeRules = isGlobalProxy
        ? const <Map<String, dynamic>>[]
        : routingRules
              .where((rule) => rule.enabled && rule.hasMatcher)
              .map((rule) => rule.toExportJson())
              .toList(growable: false);
    final args = <String, dynamic>{
      'isGlobalProxy': isGlobalProxy,
      'tunEngine': tunEngineMode.wireName,
      'appRoutingMode': effectiveAppRoutingPolicy.mode.wireName,
      'appRoutingPackages': effectiveAppRoutingPolicy.packages.toList(),
      'routingRulesJson': jsonEncode(activeRules),
      ..._nativeServerArgs(),
    };
    final bridgeEntry = entryServer;
    if (bridgeEntry != null && bridgeEntry.name != name) {
      args.addAll(bridgeEntry._nativeServerArgs(prefix: 'entry'));
    }
    return args;
  }

  Map<String, dynamic> _nativeServerArgs({String prefix = ''}) {
    String key(String base) {
      if (prefix.isEmpty) return base;
      return '$prefix${base[0].toUpperCase()}${base.substring(1)}';
    }

    return <String, dynamic>{
      key('server'): address,
      key('serverPort'): port,
      key('protocol'): serverProtocol.wireName,
      key('uuid'): uuid,
      key('transport'): transport.wireName,
      key('transportPath'): transportPath,
      key('transportServiceName'): transportServiceName,
      key('transportHost'): transportHost,
      key('transportMode'): transportMode,
      key('xhttpPadding'): xhttpPadding,
      key('xhttpMaxPostBytes'): xhttpMaxPostBytes,
      key('xhttpMinPostInterval'): xhttpMinPostInterval,
      key('tlsEnabled'): security.tlsEnabled,
      key('tlsSni'): effectiveSni,
      key('tlsInsecure'): tlsInsecure,
      key('flow'): flow,
      key('alpn'): alpn,
      key('security'): security.wireName,
      key('pbk'): realityPublicKey,
      key('sid'): realityShortId,
      key('spx'): realitySpiderX,
      key('fp'): fingerprint,
      key('hysteria2ObfsPassword'): hysteria2ObfsPassword,
      key('hysteria2HopPorts'): hysteria2HopPorts,
    };
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'port': port,
    'protocol': serverProtocol.wireName,
    'uuid': uuid,
    'transport': transport.wireName,
    'security': security.wireName,
    'transportPath': transportPath,
    'transportServiceName': transportServiceName,
    'transportHost': transportHost,
    'transportMode': transportMode,
    'xhttpPadding': xhttpPadding,
    'xhttpMaxPostBytes': xhttpMaxPostBytes,
    'xhttpMinPostInterval': xhttpMinPostInterval,
    'sni': sni,
    'alpn': alpn,
    'flow': flow,
    'fingerprint': fingerprint,
    'realityPublicKey': realityPublicKey,
    'realityShortId': realityShortId,
    'realitySpiderX': realitySpiderX,
    'tlsInsecure': tlsInsecure,
    'hysteria2ObfsPassword': hysteria2ObfsPassword,
    'hysteria2HopPorts': hysteria2HopPorts,
    'isPinned': isPinned,
    'ping': ping,
  };

  static ServerConfig? fromJson(Map<String, dynamic> json) {
    final protocol =
        ServerProtocol.tryParse(json['protocol'] as String?) ??
        ServerProtocol.vless;
    final transport =
        VlessTransport.tryParse(json['transport'] as String?) ??
        (protocol == ServerProtocol.hysteria2 ? VlessTransport.tcp : null);
    final security =
        VlessSecurity.tryParse(json['security'] as String?) ??
        (protocol == ServerProtocol.hysteria2 ? VlessSecurity.tls : null);
    if (transport == null || security == null) return null;
    return ServerConfig(
      name:
          json['name'] as String? ??
          (protocol == ServerProtocol.hysteria2
              ? 'Imported Hysteria2'
              : 'Imported VLESS'),
      address: json['address'] as String? ?? '',
      port: _int(json['port']) ?? 443,
      uuid: json['uuid'] as String? ?? '',
      transport: transport,
      security: security,
      serverProtocol: protocol,
      transportPath: json['transportPath'] as String? ?? '/',
      transportServiceName: json['transportServiceName'] as String? ?? '',
      transportHost: json['transportHost'] as String? ?? '',
      transportMode: json['transportMode'] as String? ?? '',
      xhttpPadding: json['xhttpPadding'] as String? ?? '',
      xhttpMaxPostBytes: json['xhttpMaxPostBytes'] as String? ?? '',
      xhttpMinPostInterval: json['xhttpMinPostInterval'] as String? ?? '',
      sni: json['sni'] as String? ?? '',
      alpn: json['alpn'] as String? ?? '',
      flow: json['flow'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      realityPublicKey: json['realityPublicKey'] as String? ?? '',
      realityShortId: json['realityShortId'] as String? ?? '',
      realitySpiderX: json['realitySpiderX'] as String? ?? '',
      tlsInsecure: json['tlsInsecure'] as bool? ?? false,
      hysteria2ObfsPassword: json['hysteria2ObfsPassword'] as String? ?? '',
      hysteria2HopPorts: json['hysteria2HopPorts'] as String? ?? '',
      isPinned: json['isPinned'] as bool? ?? false,
      ping: (json['ping'] as String?)?.trim().isNotEmpty == true
          ? json['ping'] as String
          : '--',
    );
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num && value % 1 == 0) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static List<ServerConfig> decodeList(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = decodeJson(raw, maxBytes: JsonPayloadLimits.serverCatalog);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ServerConfig.fromJson)
          .whereType<ServerConfig>()
          .toList();
    } on FormatException {
      return const [];
    } on JsonPayloadTooLargeException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  static String encodeList(List<ServerConfig> servers) {
    return jsonEncode(servers.map((s) => s.toJson()).toList());
  }
}
