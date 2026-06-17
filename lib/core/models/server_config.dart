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
  hysteria2,
  naive;

  String get wireName {
    switch (this) {
      case ServerProtocol.vless:
        return 'vless';
      case ServerProtocol.hysteria2:
        return 'hysteria2';
      case ServerProtocol.naive:
        return 'naive';
    }
  }

  static ServerProtocol? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final v = raw.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '');
    return switch (v) {
      'vless' => ServerProtocol.vless,
      'hysteria' || 'hysteria2' || 'hy2' => ServerProtocol.hysteria2,
      'naive' || 'naiveproxy' => ServerProtocol.naive,
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
    this.vlessEncryption = '',
    this.fingerprint = '',
    this.realityPublicKey = '',
    this.realityShortId = '',
    this.realitySpiderX = '',
    this.realityMldsa65Verify = '',
    this.tlsInsecure = false,
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
    this.naiveUsername = '',
    this.naivePassword = '',
    this.naiveQuic = false,
    this.naiveQuicCongestionControl = '',
    this.naiveInsecureConcurrency = 0,
    this.naiveExtraHeaders = const {},
    this.naiveUdpOverTcp = false,
    this.naiveUdpOverTcpVersion = 0,
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
  final String vlessEncryption;
  final String fingerprint;
  final String realityPublicKey;
  final String realityShortId;
  final String realitySpiderX;
  final String realityMldsa65Verify;
  final bool tlsInsecure;
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
  final String naiveUsername;
  final String naivePassword;
  final bool naiveQuic;
  final String naiveQuicCongestionControl;
  final int naiveInsecureConcurrency;
  final Map<String, String> naiveExtraHeaders;
  final bool naiveUdpOverTcp;
  final int naiveUdpOverTcpVersion;
  final bool isPinned;
  final String ping;

  String get id => name;

  String get protocol => serverProtocol.wireName;

  bool get isVless => serverProtocol == ServerProtocol.vless;
  bool get isHysteria2 => serverProtocol == ServerProtocol.hysteria2;
  bool get isNaive => serverProtocol == ServerProtocol.naive;
  bool get usesDirectLibbox => isHysteria2 || isNaive;

  String get effectiveSni => sni.isNotEmpty ? sni : address;
  String get effectiveVlessEncryption =>
      vlessEncryption.trim().isEmpty ? 'none' : vlessEncryption.trim();
  String get effectiveHysteria2ObfsType {
    final value = hysteria2ObfsType.trim().toLowerCase();
    if (value.isNotEmpty) return value;
    return hysteria2ObfsPassword.trim().isEmpty ? '' : 'salamander';
  }

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
    String? vlessEncryption,
    String? fingerprint,
    String? realityPublicKey,
    String? realityShortId,
    String? realitySpiderX,
    String? realityMldsa65Verify,
    bool? tlsInsecure,
    String? hysteria2ObfsType,
    String? hysteria2ObfsPassword,
    int? hysteria2ObfsMinPacketSize,
    int? hysteria2ObfsMaxPacketSize,
    String? hysteria2HopPorts,
    String? hysteria2HopInterval,
    String? hysteria2HopIntervalMax,
    int? hysteria2UpMbps,
    int? hysteria2DownMbps,
    String? hysteria2Network,
    String? hysteria2BbrProfile,
    String? naiveUsername,
    String? naivePassword,
    bool? naiveQuic,
    String? naiveQuicCongestionControl,
    int? naiveInsecureConcurrency,
    Map<String, String>? naiveExtraHeaders,
    bool? naiveUdpOverTcp,
    int? naiveUdpOverTcpVersion,
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
      vlessEncryption: vlessEncryption ?? this.vlessEncryption,
      fingerprint: fingerprint ?? this.fingerprint,
      realityPublicKey: realityPublicKey ?? this.realityPublicKey,
      realityShortId: realityShortId ?? this.realityShortId,
      realitySpiderX: realitySpiderX ?? this.realitySpiderX,
      realityMldsa65Verify: realityMldsa65Verify ?? this.realityMldsa65Verify,
      tlsInsecure: tlsInsecure ?? this.tlsInsecure,
      hysteria2ObfsType: hysteria2ObfsType ?? this.hysteria2ObfsType,
      hysteria2ObfsPassword:
          hysteria2ObfsPassword ?? this.hysteria2ObfsPassword,
      hysteria2ObfsMinPacketSize:
          hysteria2ObfsMinPacketSize ?? this.hysteria2ObfsMinPacketSize,
      hysteria2ObfsMaxPacketSize:
          hysteria2ObfsMaxPacketSize ?? this.hysteria2ObfsMaxPacketSize,
      hysteria2HopPorts: hysteria2HopPorts ?? this.hysteria2HopPorts,
      hysteria2HopInterval: hysteria2HopInterval ?? this.hysteria2HopInterval,
      hysteria2HopIntervalMax:
          hysteria2HopIntervalMax ?? this.hysteria2HopIntervalMax,
      hysteria2UpMbps: hysteria2UpMbps ?? this.hysteria2UpMbps,
      hysteria2DownMbps: hysteria2DownMbps ?? this.hysteria2DownMbps,
      hysteria2Network: hysteria2Network ?? this.hysteria2Network,
      hysteria2BbrProfile: hysteria2BbrProfile ?? this.hysteria2BbrProfile,
      naiveUsername: naiveUsername ?? this.naiveUsername,
      naivePassword: naivePassword ?? this.naivePassword,
      naiveQuic: naiveQuic ?? this.naiveQuic,
      naiveQuicCongestionControl:
          naiveQuicCongestionControl ?? this.naiveQuicCongestionControl,
      naiveInsecureConcurrency:
          naiveInsecureConcurrency ?? this.naiveInsecureConcurrency,
      naiveExtraHeaders: naiveExtraHeaders ?? this.naiveExtraHeaders,
      naiveUdpOverTcp: naiveUdpOverTcp ?? this.naiveUdpOverTcp,
      naiveUdpOverTcpVersion:
          naiveUdpOverTcpVersion ?? this.naiveUdpOverTcpVersion,
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
      key('vlessEncryption'): vlessEncryption,
      key('alpn'): alpn,
      key('security'): security.wireName,
      key('pbk'): realityPublicKey,
      key('sid'): realityShortId,
      key('spx'): realitySpiderX,
      key('mldsa65Verify'): realityMldsa65Verify,
      key('fp'): fingerprint,
      key('hysteria2ObfsType'): hysteria2ObfsType,
      key('hysteria2ObfsPassword'): hysteria2ObfsPassword,
      key('hysteria2ObfsMinPacketSize'): hysteria2ObfsMinPacketSize,
      key('hysteria2ObfsMaxPacketSize'): hysteria2ObfsMaxPacketSize,
      key('hysteria2HopPorts'): hysteria2HopPorts,
      key('hysteria2HopInterval'): hysteria2HopInterval,
      key('hysteria2HopIntervalMax'): hysteria2HopIntervalMax,
      key('hysteria2UpMbps'): hysteria2UpMbps,
      key('hysteria2DownMbps'): hysteria2DownMbps,
      key('hysteria2Network'): hysteria2Network,
      key('hysteria2BbrProfile'): hysteria2BbrProfile,
      key('naiveUsername'): naiveUsername,
      key('naivePassword'): naivePassword,
      key('naiveQuic'): naiveQuic,
      key('naiveQuicCongestionControl'): naiveQuicCongestionControl,
      key('naiveInsecureConcurrency'): naiveInsecureConcurrency,
      key('naiveExtraHeadersJson'): jsonEncode(naiveExtraHeaders),
      key('naiveUdpOverTcp'): naiveUdpOverTcp,
      key('naiveUdpOverTcpVersion'): naiveUdpOverTcpVersion,
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
    'vlessEncryption': vlessEncryption,
    'fingerprint': fingerprint,
    'realityPublicKey': realityPublicKey,
    'realityShortId': realityShortId,
    'realitySpiderX': realitySpiderX,
    'realityMldsa65Verify': realityMldsa65Verify,
    'tlsInsecure': tlsInsecure,
    'hysteria2ObfsType': hysteria2ObfsType,
    'hysteria2ObfsPassword': hysteria2ObfsPassword,
    'hysteria2ObfsMinPacketSize': hysteria2ObfsMinPacketSize,
    'hysteria2ObfsMaxPacketSize': hysteria2ObfsMaxPacketSize,
    'hysteria2HopPorts': hysteria2HopPorts,
    'hysteria2HopInterval': hysteria2HopInterval,
    'hysteria2HopIntervalMax': hysteria2HopIntervalMax,
    'hysteria2UpMbps': hysteria2UpMbps,
    'hysteria2DownMbps': hysteria2DownMbps,
    'hysteria2Network': hysteria2Network,
    'hysteria2BbrProfile': hysteria2BbrProfile,
    'naiveUsername': naiveUsername,
    'naivePassword': naivePassword,
    'naiveQuic': naiveQuic,
    'naiveQuicCongestionControl': naiveQuicCongestionControl,
    'naiveInsecureConcurrency': naiveInsecureConcurrency,
    'naiveExtraHeaders': naiveExtraHeaders,
    'naiveUdpOverTcp': naiveUdpOverTcp,
    'naiveUdpOverTcpVersion': naiveUdpOverTcpVersion,
    'isPinned': isPinned,
    'ping': ping,
  };

  static ServerConfig? fromJson(Map<String, dynamic> json) {
    final protocol =
        ServerProtocol.tryParse(json['protocol'] as String?) ??
        ServerProtocol.vless;
    final transport =
        VlessTransport.tryParse(json['transport'] as String?) ??
        (protocol != ServerProtocol.vless ? VlessTransport.tcp : null);
    final security =
        VlessSecurity.tryParse(json['security'] as String?) ??
        (protocol != ServerProtocol.vless ? VlessSecurity.tls : null);
    if (transport == null || security == null) return null;
    final naiveQuic = json['naiveQuic'] as bool? ?? false;
    final naiveCongestionControl = _naiveCongestionControl(
      json['naiveQuicCongestionControl'] as String?,
    );
    return ServerConfig(
      name:
          json['name'] as String? ??
          (protocol == ServerProtocol.hysteria2
              ? 'Imported Hysteria2'
              : protocol == ServerProtocol.naive
              ? 'Imported NaiveProxy'
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
      vlessEncryption: json['vlessEncryption'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      realityPublicKey: json['realityPublicKey'] as String? ?? '',
      realityShortId: json['realityShortId'] as String? ?? '',
      realitySpiderX: json['realitySpiderX'] as String? ?? '',
      realityMldsa65Verify: json['realityMldsa65Verify'] as String? ?? '',
      tlsInsecure: json['tlsInsecure'] as bool? ?? false,
      hysteria2ObfsType:
          json['hysteria2ObfsType'] as String? ??
          ((json['hysteria2ObfsPassword'] as String?)?.trim().isNotEmpty == true
              ? 'salamander'
              : ''),
      hysteria2ObfsPassword: json['hysteria2ObfsPassword'] as String? ?? '',
      hysteria2ObfsMinPacketSize: _nonNegativeInt(
        json['hysteria2ObfsMinPacketSize'],
      ),
      hysteria2ObfsMaxPacketSize: _nonNegativeInt(
        json['hysteria2ObfsMaxPacketSize'],
      ),
      hysteria2HopPorts: json['hysteria2HopPorts'] as String? ?? '',
      hysteria2HopInterval: json['hysteria2HopInterval'] as String? ?? '',
      hysteria2HopIntervalMax: json['hysteria2HopIntervalMax'] as String? ?? '',
      hysteria2UpMbps: _nonNegativeInt(json['hysteria2UpMbps']),
      hysteria2DownMbps: _nonNegativeInt(json['hysteria2DownMbps']),
      hysteria2Network: json['hysteria2Network'] as String? ?? '',
      hysteria2BbrProfile: json['hysteria2BbrProfile'] as String? ?? '',
      naiveUsername: json['naiveUsername'] as String? ?? '',
      naivePassword: json['naivePassword'] as String? ?? '',
      naiveQuic: naiveQuic,
      naiveQuicCongestionControl: naiveQuic ? naiveCongestionControl : '',
      naiveInsecureConcurrency: _nonNegativeInt(
        json['naiveInsecureConcurrency'],
      ),
      naiveExtraHeaders: _stringMap(json['naiveExtraHeaders']),
      naiveUdpOverTcp: json['naiveUdpOverTcp'] as bool? ?? false,
      naiveUdpOverTcpVersion: _nonNegativeInt(json['naiveUdpOverTcpVersion']),
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

  static int _nonNegativeInt(Object? value) {
    final parsed = _int(value);
    return parsed == null || parsed < 0 ? 0 : parsed;
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return Map.unmodifiable({
      for (final entry in value.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    });
  }

  static String _naiveCongestionControl(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return const {'', 'bbr', 'bbr2', 'cubic', 'reno'}.contains(value)
        ? value
        : '';
  }

  static List<ServerConfig> decodeList(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = decodeJson(
        raw,
        maxBytes: JsonPayloadLimits.serverCatalog,
      );
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
