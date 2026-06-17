import 'bounded_json.dart';
import 'hysteria2_parser.dart';
import 'models/server_config.dart';
import 'models/server_subscription.dart';
import 'naive_parser.dart';
import 'server_link_parse_utils.dart';
import 'vless_parser.dart';

enum ServerImportError {
  empty,
  invalidVless,
  invalidHysteria2,
  invalidNaive,
  invalidJson,
  unsupportedFormat,
  invalidSubscription,
  subscriptionNetwork,
}

class ServerImportException implements Exception {
  const ServerImportException(
    this.code,
    this.message, {
    this.vlessError,
    this.hysteria2Error,
    this.naiveError,
  });

  final ServerImportError code;
  final String message;
  final VlessParseException? vlessError;
  final Hysteria2ParseException? hysteria2Error;
  final NaiveParseException? naiveError;

  @override
  String toString() => 'ServerImportException($code): $message';
}

class ServerImportResult {
  const ServerImportResult._({
    this.configs = const [],
    this.subscription,
    this.error,
  });

  final List<ServerConfig> configs;
  final ServerSubscription? subscription;
  final ServerImportException? error;

  int get importedCount => subscription?.servers.length ?? configs.length;
  bool get isOk => configs.isNotEmpty || subscription != null;
  bool get isError => error != null;

  factory ServerImportResult.ok(List<ServerConfig> configs) =>
      ServerImportResult._(configs: List.unmodifiable(configs));

  factory ServerImportResult.subscription(ServerSubscription subscription) =>
      ServerImportResult._(subscription: subscription);

  factory ServerImportResult.fail(
    ServerImportError code,
    String message, {
    VlessParseException? vlessError,
    Hysteria2ParseException? hysteria2Error,
    NaiveParseException? naiveError,
  }) => ServerImportResult._(
    error: ServerImportException(
      code,
      message,
      vlessError: vlessError,
      hysteria2Error: hysteria2Error,
      naiveError: naiveError,
    ),
  );
}

class ServerImporter {
  const ServerImporter({
    this.vlessParser = const VlessParser(),
    this.hysteria2Parser = const Hysteria2Parser(),
    this.naiveParser = const NaiveParser(),
  });

  final VlessParser vlessParser;
  final Hysteria2Parser hysteria2Parser;
  final NaiveParser naiveParser;

  ServerImportResult parse(String raw, {Set<String> existingNames = const {}}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return ServerImportResult.fail(ServerImportError.empty, 'Input is empty');
    }

    final lines = trimmed
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isNotEmpty && _isSupportedServerLink(lines.first)) {
      return _parseServerLinkLines(lines, existingNames);
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return _parseJson(trimmed, existingNames);
    }

    return ServerImportResult.fail(
      ServerImportError.unsupportedFormat,
      'Input is not a supported server link or JSON config',
    );
  }

  bool _isSupportedServerLink(String raw) {
    final lower = raw.trimLeft().toLowerCase();
    return lower.startsWith('vless://') ||
        lower.startsWith('hysteria2://') ||
        lower.startsWith('hy2://') ||
        lower.startsWith('naive://') ||
        lower.startsWith('naive+https://') ||
        lower.startsWith('naive+quic://');
  }

  ServerImportResult _parseServerLinkLines(
    List<String> lines,
    Set<String> existingNames,
  ) {
    final names = Set<String>.of(existingNames);
    final configs = <ServerConfig>[];
    for (final line in lines) {
      final lower = line.trimLeft().toLowerCase();
      final ServerConfig config;
      if (lower.startsWith('vless://')) {
        final result = vlessParser.parse(line, existingNames: names);
        if (result.isError) {
          return ServerImportResult.fail(
            ServerImportError.invalidVless,
            result.error!.message,
            vlessError: result.error,
          );
        }
        config = result.config!;
      } else if (lower.startsWith('hysteria2://') ||
          lower.startsWith('hy2://')) {
        final result = hysteria2Parser.parse(line, existingNames: names);
        if (result.isError) {
          return ServerImportResult.fail(
            ServerImportError.invalidHysteria2,
            result.error!.message,
            hysteria2Error: result.error,
          );
        }
        config = result.config!;
      } else {
        final result = naiveParser.parse(line, existingNames: names);
        if (result.isError) {
          return ServerImportResult.fail(
            ServerImportError.invalidNaive,
            result.error!.message,
            naiveError: result.error,
          );
        }
        config = result.config!;
      }
      configs.add(config);
      names.add(config.name);
    }
    return ServerImportResult.ok(configs);
  }

  ServerImportResult _parseJson(String raw, Set<String> existingNames) {
    final dynamic decoded;
    try {
      decoded = decodeJson(raw, maxBytes: JsonPayloadLimits.serverCatalog);
    } on JsonPayloadTooLargeException {
      return ServerImportResult.fail(
        ServerImportError.invalidJson,
        'JSON payload is too large',
      );
    } on FormatException catch (e) {
      return ServerImportResult.fail(ServerImportError.invalidJson, e.message);
    }

    final configs = _collectConfigs(decoded, existingNames);
    if (configs.isEmpty) {
      return ServerImportResult.fail(
        ServerImportError.unsupportedFormat,
        'JSON does not contain supported server settings',
      );
    }
    return ServerImportResult.ok(configs);
  }

  List<ServerConfig> _collectConfigs(Object? value, Set<String> existingNames) {
    final names = Set<String>.of(existingNames);
    final configs = <ServerConfig>[];

    void addConfig(ServerConfig config) {
      if (config.address.trim().isEmpty) return;
      if (config.port < 1 || config.port > 65535) return;
      // VLESS and Hysteria2 require their UUID/auth value. NaiveProxy
      // authentication is optional and stored in dedicated fields.
      if (!config.isNaive && config.uuid.isEmpty) return;
      final fallback = config.isHysteria2
          ? 'Imported Hysteria2'
          : config.isNaive
          ? 'Imported NaiveProxy'
          : 'Imported VLESS';
      final name = ensureUniqueServerName(
        config.name,
        names,
        fallback: fallback,
      );
      configs.add(config.copyWith(name: name));
      names.add(name);
    }

    void collect(Object? node) {
      if (node is List) {
        for (final item in node) {
          collect(item);
        }
        return;
      }

      final map = _stringMap(node);
      if (map == null) return;

      final appConfig = _appServerConfig(map);
      if (appConfig != null) {
        addConfig(appConfig);
        return;
      }

      final singBoxConfig = _singBoxOutboundConfig(map);
      if (singBoxConfig != null) {
        addConfig(singBoxConfig);
        return;
      }

      final servers = map['servers'];
      if (servers is List) {
        collect(servers);
      }

      final proxies = map['proxies'];
      if (proxies is List) {
        collect(proxies);
      }

      final outbounds = map['outbounds'];
      if (outbounds is List) {
        final fallbackName =
            _string(map['remarks']) ??
            _string(map['remark']) ??
            _string(map['name']);
        for (final outbound in outbounds) {
          final outboundMap = _stringMap(outbound);
          if (outboundMap == null) continue;
          for (final config in _xrayOutboundConfigs(
            outboundMap,
            fallbackName: fallbackName,
          )) {
            addConfig(config);
          }
          final singBoxOutbound = _singBoxOutboundConfig(
            outboundMap,
            fallbackName: fallbackName,
          );
          if (singBoxOutbound != null) addConfig(singBoxOutbound);
        }
      }

      final protocol = _string(map['protocol'])?.toLowerCase();
      if (protocol == 'vless') {
        for (final config in _xrayOutboundConfigs(map)) {
          addConfig(config);
        }
      }
    }

    collect(value);
    return configs;
  }

  ServerConfig? _appServerConfig(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.of(raw);
    map['protocol'] ??= _string(raw['serverProtocol']);
    final protocol =
        ServerProtocol.tryParse(_string(map['protocol'])) ??
        ServerProtocol.vless;
    map['address'] ??= _string(raw['server']) ?? _string(raw['host']);
    final port =
        _int(raw['serverPort']) ??
        _int(raw['server_port']) ??
        _int(raw['port']);
    if (port != null) map['port'] = port;
    map['uuid'] ??=
        _string(raw['id']) ??
        _string(raw['uuid']) ??
        _string(raw['auth']) ??
        _string(raw['password']);
    if (protocol == ServerProtocol.hysteria2) {
      map['transport'] ??= 'tcp';
      map['security'] ??= 'tls';
      map['alpn'] ??= _joinStringList(raw['alpn']);
      map['hysteria2ObfsPassword'] ??=
          _string(raw['hysteria2ObfsPassword']) ??
          _string(raw['obfsPassword']) ??
          _string(raw['obfs-password']);
      map['hysteria2ObfsType'] ??=
          _string(raw['hysteria2ObfsType']) ?? _string(raw['obfsType']);
      map['hysteria2ObfsMinPacketSize'] ??=
          _int(raw['hysteria2ObfsMinPacketSize']) ??
          _int(raw['obfsMinPacketSize']);
      map['hysteria2ObfsMaxPacketSize'] ??=
          _int(raw['hysteria2ObfsMaxPacketSize']) ??
          _int(raw['obfsMaxPacketSize']);
      map['hysteria2HopPorts'] ??=
          _string(raw['hysteria2HopPorts']) ??
          _string(raw['ports']) ??
          _string(raw['hopPorts']);
      map['hysteria2HopInterval'] ??=
          _string(raw['hysteria2HopInterval']) ?? _string(raw['hop_interval']);
      map['hysteria2HopIntervalMax'] ??=
          _string(raw['hysteria2HopIntervalMax']) ??
          _string(raw['hop_interval_max']);
      map['hysteria2UpMbps'] ??=
          _int(raw['hysteria2UpMbps']) ?? _int(raw['up_mbps']);
      map['hysteria2DownMbps'] ??=
          _int(raw['hysteria2DownMbps']) ?? _int(raw['down_mbps']);
      map['hysteria2Network'] ??=
          _string(raw['hysteria2Network']) ?? _string(raw['network']);
      map['hysteria2BbrProfile'] ??=
          _string(raw['hysteria2BbrProfile']) ?? _string(raw['bbr_profile']);
    } else if (protocol == ServerProtocol.naive) {
      map['uuid'] = '';
      map['transport'] ??= 'tcp';
      map['security'] ??= 'tls';
      map['naiveUsername'] ??=
          _string(raw['naiveUsername']) ?? _string(raw['username']);
      map['naivePassword'] ??=
          _string(raw['naivePassword']) ?? _string(raw['password']);
      map['naiveQuic'] ??= _bool(raw['naiveQuic']) ?? _bool(raw['quic']);
      map['naiveQuicCongestionControl'] ??=
          _string(raw['naiveQuicCongestionControl']) ??
          _string(raw['quic_congestion_control']);
      map['naiveInsecureConcurrency'] ??=
          _int(raw['naiveInsecureConcurrency']) ??
          _int(raw['insecure_concurrency']);
      map['naiveExtraHeaders'] ??= raw['extra_headers'];
      map['naiveUdpOverTcp'] ??=
          _bool(raw['naiveUdpOverTcp']) ??
          _bool(_stringMap(raw['udp_over_tcp'])?['enabled']);
      map['naiveUdpOverTcpVersion'] ??=
          _int(raw['naiveUdpOverTcpVersion']) ??
          _int(_stringMap(raw['udp_over_tcp'])?['version']);
    } else {
      map['transport'] ??= _string(raw['network']) ?? _string(raw['type']);
    }
    if (map['security'] == null) {
      final tlsEnabled = raw['tlsEnabled'];
      if (tlsEnabled is bool) {
        map['security'] = tlsEnabled ? 'tls' : 'none';
      }
    }
    map['transportPath'] ??= _string(raw['path']);
    map['vlessEncryption'] ??= _string(raw['encryption']);
    map['transportServiceName'] ??=
        _string(raw['serviceName']) ?? _string(raw['service_name']);
    map['transportHost'] ??=
        _string(raw['hostHeader']) ?? _string(raw['authority']);
    map['sni'] ??=
        _string(raw['serverName']) ??
        _string(raw['server_name']) ??
        _string(raw['tlsSni']) ??
        _string(raw['sni']) ??
        _string(raw['peer']);
    map['realityPublicKey'] ??=
        _string(raw['pbk']) ??
        _string(raw['publicKey']) ??
        _string(raw['public_key']) ??
        _string(raw['public-key']);
    map['realityShortId'] ??=
        _string(raw['sid']) ??
        _string(raw['shortId']) ??
        _string(raw['short_id']) ??
        _string(raw['short-id']);
    map['realitySpiderX'] ??=
        _string(raw['spx']) ??
        _string(raw['spiderX']) ??
        _string(raw['spider_x']) ??
        _string(raw['spider-x']);
    map['realityMldsa65Verify'] ??=
        _string(raw['mldsa65Verify']) ?? _string(raw['mldsa65_verify']);
    map['tlsInsecure'] ??=
        _bool(raw['tlsInsecure']) ??
        _bool(raw['allowInsecure']) ??
        _bool(raw['allow_insecure']) ??
        _bool(raw['insecure']);

    final config = ServerConfig.fromJson(map);
    if (config == null) return null;
    if (config.address.trim().isEmpty) return null;
    if (config.security.tlsEnabled &&
        config.sni.isEmpty &&
        config.transportHost.isNotEmpty) {
      return config.copyWith(sni: config.transportHost);
    }
    return config;
  }

  List<ServerConfig> _xrayOutboundConfigs(
    Map<String, dynamic> outbound, {
    String? fallbackName,
  }) {
    if (_string(outbound['protocol'])?.toLowerCase() != 'vless') {
      return const [];
    }

    final settings = _stringMap(outbound['settings']);
    final stream = _stringMap(outbound['streamSettings']);
    final vnext = settings?['vnext'];
    if (settings == null || vnext is! List) return const [];

    final streamConfig = _streamConfig(stream);
    final configs = <ServerConfig>[];
    for (final rawVnext in vnext) {
      final node = _stringMap(rawVnext);
      if (node == null) continue;
      final address = _string(node['address']);
      final port = _int(node['port']) ?? 443;
      if (address == null || port < 1 || port > 65535) continue;
      final users = node['users'];
      if (users is! List) continue;
      for (final rawUser in users) {
        final user = _stringMap(rawUser);
        if (user == null) continue;
        final uuid = _string(user['id']) ?? _string(user['uuid']);
        if (uuid == null) continue;
        configs.add(
          ServerConfig(
            name: fallbackName ?? _string(outbound['tag']) ?? address,
            address: address,
            port: port,
            uuid: uuid,
            transport: streamConfig.transport,
            security: streamConfig.security,
            transportPath: streamConfig.transportPath,
            transportServiceName: streamConfig.transportServiceName,
            transportHost: streamConfig.transportHost,
            transportMode: streamConfig.transportMode,
            xhttpPadding: streamConfig.xhttpPadding,
            xhttpMaxPostBytes: streamConfig.xhttpMaxPostBytes,
            xhttpMinPostInterval: streamConfig.xhttpMinPostInterval,
            sni: streamConfig.sni,
            alpn: streamConfig.alpn,
            flow: _string(user['flow']) ?? '',
            vlessEncryption: _string(user['encryption']) ?? '',
            fingerprint: streamConfig.fingerprint,
            realityPublicKey: streamConfig.realityPublicKey,
            realityShortId: streamConfig.realityShortId,
            realitySpiderX: streamConfig.realitySpiderX,
            realityMldsa65Verify: streamConfig.realityMldsa65Verify,
            tlsInsecure: streamConfig.tlsInsecure,
          ),
        );
      }
    }
    return configs;
  }

  ServerConfig? _singBoxOutboundConfig(
    Map<String, dynamic> outbound, {
    String? fallbackName,
  }) {
    final type = _string(outbound['type'])?.toLowerCase();
    if (type == 'hysteria2' || type == 'hy2') {
      return _singBoxHysteria2OutboundConfig(
        outbound,
        fallbackName: fallbackName,
      );
    }
    if (type == 'naive') {
      return _singBoxNaiveOutboundConfig(outbound, fallbackName: fallbackName);
    }
    if (type != 'vless') return null;
    final address = _string(outbound['server']);
    final port =
        _int(outbound['server_port']) ??
        _int(outbound['serverPort']) ??
        _int(outbound['port']);
    final uuid = _string(outbound['uuid']) ?? _string(outbound['password']);
    if (address == null || port == null || uuid == null) return null;

    final transport = _stringMap(outbound['transport']);
    final tls = _stringMap(outbound['tls']);
    final reality = _stringMap(tls?['reality']);
    final tlsEnabled = tls?['enabled'] == true;
    final security = reality?['enabled'] == true
        ? VlessSecurity.reality
        : (tlsEnabled ? VlessSecurity.tls : VlessSecurity.none);
    final transportType = _string(transport?['type']) ?? 'tcp';

    return ServerConfig(
      name: fallbackName ?? _string(outbound['tag']) ?? address,
      address: address,
      port: port,
      uuid: uuid,
      transport: _transportFromWire(transportType),
      security: security,
      transportPath: _string(transport?['path']) ?? '/',
      transportServiceName: _string(transport?['service_name']) ?? '',
      transportHost: _transportHostFromSingBox(transport),
      sni: _string(tls?['server_name']) ?? '',
      alpn: _joinStringList(tls?['alpn']),
      flow: _string(outbound['flow']) ?? '',
      vlessEncryption: _string(outbound['encryption']) ?? '',
      fingerprint: _string(_stringMap(tls?['utls'])?['fingerprint']) ?? '',
      realityPublicKey: _string(reality?['public_key']) ?? '',
      realityShortId: _string(reality?['short_id']) ?? '',
      realityMldsa65Verify: _string(reality?['mldsa65_verify']) ?? '',
      tlsInsecure:
          _bool(tls?['insecure']) ??
          _bool(tls?['skip_cert_verify']) ??
          _bool(tls?['skip-cert-verify']) ??
          false,
    );
  }

  ServerConfig? _singBoxHysteria2OutboundConfig(
    Map<String, dynamic> outbound, {
    String? fallbackName,
  }) {
    final address = _string(outbound['server']);
    final port =
        _int(outbound['server_port']) ??
        _int(outbound['serverPort']) ??
        _int(outbound['port']);
    final auth =
        _string(outbound['password']) ??
        _string(outbound['auth']) ??
        _string(outbound['uuid']);
    if (address == null || port == null || auth == null) return null;

    final tls = _stringMap(outbound['tls']);
    final obfs = _stringMap(outbound['obfs']);
    final obfsType = (_string(obfs?['type']) ?? _string(outbound['obfs']))
        ?.toLowerCase();

    return ServerConfig(
      name:
          fallbackName ??
          _string(outbound['tag']) ??
          _string(outbound['name']) ??
          address,
      address: address,
      port: port,
      uuid: auth,
      transport: VlessTransport.tcp,
      security: VlessSecurity.tls,
      serverProtocol: ServerProtocol.hysteria2,
      sni:
          _string(tls?['server_name']) ??
          _string(tls?['serverName']) ??
          _string(outbound['sni']) ??
          '',
      alpn:
          _nonEmpty(_joinStringList(tls?['alpn'])) ??
          _nonEmpty(_joinStringList(outbound['alpn'])) ??
          'h3',
      tlsInsecure:
          _bool(tls?['insecure']) ??
          _bool(tls?['skip_cert_verify']) ??
          _bool(tls?['skip-cert-verify']) ??
          _bool(outbound['skip-cert-verify']) ??
          false,
      hysteria2ObfsPassword: obfsType == 'salamander' || obfsType == 'gecko'
          ? (_string(obfs?['password']) ??
                _string(outbound['obfs-password']) ??
                _string(outbound['obfsPassword']) ??
                '')
          : '',
      hysteria2ObfsType: obfsType ?? '',
      hysteria2ObfsMinPacketSize: _int(obfs?['min_packet_size']) ?? 0,
      hysteria2ObfsMaxPacketSize: _int(obfs?['max_packet_size']) ?? 0,
      hysteria2HopPorts:
          _hopPortsFromSingBox(outbound['server_ports']) ??
          _string(outbound['ports']) ??
          '',
      hysteria2HopInterval: _string(outbound['hop_interval']) ?? '',
      hysteria2HopIntervalMax: _string(outbound['hop_interval_max']) ?? '',
      hysteria2UpMbps: _int(outbound['up_mbps']) ?? 0,
      hysteria2DownMbps: _int(outbound['down_mbps']) ?? 0,
      hysteria2Network: _string(outbound['network']) ?? '',
      hysteria2BbrProfile: _string(outbound['bbr_profile']) ?? '',
    );
  }

  ServerConfig? _singBoxNaiveOutboundConfig(
    Map<String, dynamic> outbound, {
    String? fallbackName,
  }) {
    final address = _string(outbound['server']);
    final port =
        _int(outbound['server_port']) ??
        _int(outbound['serverPort']) ??
        _int(outbound['port']);
    if (address == null || port == null) return null;

    final tls = _stringMap(outbound['tls']);
    final extraHeaders = _stringMap(outbound['extra_headers']);
    final udpOverTcp = _stringMap(outbound['udp_over_tcp']);
    return ServerConfig(
      name:
          fallbackName ??
          _string(outbound['tag']) ??
          _string(outbound['name']) ??
          address,
      address: address,
      port: port,
      uuid: '',
      transport: VlessTransport.tcp,
      security: VlessSecurity.tls,
      serverProtocol: ServerProtocol.naive,
      sni:
          _string(tls?['server_name']) ??
          _string(tls?['serverName']) ??
          _string(outbound['sni']) ??
          '',
      tlsInsecure:
          _bool(tls?['insecure']) ??
          _bool(tls?['skip_cert_verify']) ??
          _bool(tls?['skip-cert-verify']) ??
          false,
      naiveUsername: _string(outbound['username']) ?? '',
      naivePassword: _string(outbound['password']) ?? '',
      naiveQuic: _bool(outbound['quic']) ?? false,
      naiveQuicCongestionControl:
          _string(outbound['quic_congestion_control']) ?? '',
      naiveInsecureConcurrency: _int(outbound['insecure_concurrency']) ?? 0,
      naiveExtraHeaders: extraHeaders == null
          ? const {}
          : {
              for (final entry in extraHeaders.entries)
                if (entry.value is String) entry.key: entry.value as String,
            },
      naiveUdpOverTcp: _bool(udpOverTcp?['enabled']) ?? false,
      naiveUdpOverTcpVersion: _int(udpOverTcp?['version']) ?? 0,
    );
  }

  String? _hopPortsFromSingBox(Object? raw) {
    if (raw is! List) return null;
    final segments = <String>[];
    for (final item in raw) {
      final value = _string(item);
      if (value == null) continue;
      // sing-box uses `low:high`; normalize to our `low-high` form, and
      // collapse single-port ranges (`443:443`) to just `443`.
      final parts = value.split(':');
      if (parts.length == 1) {
        segments.add(parts[0].trim());
      } else if (parts.length == 2) {
        final low = parts[0].trim();
        final high = parts[1].trim();
        segments.add(low == high ? low : '$low-$high');
      }
    }
    return segments.isEmpty ? null : segments.join(',');
  }

  _StreamImportConfig _streamConfig(Map<String, dynamic>? stream) {
    if (stream == null) return const _StreamImportConfig();

    final network = _string(stream['network']) ?? 'tcp';
    final securityRaw = (_string(stream['security']) ?? 'none').toLowerCase();
    final tls = _stringMap(stream['tlsSettings']);
    final reality = _stringMap(stream['realitySettings']);

    final security = securityRaw == 'reality'
        ? VlessSecurity.reality
        : (securityRaw == 'tls' ? VlessSecurity.tls : VlessSecurity.none);

    final transport = _transportFromWire(network);
    final ws = _stringMap(stream['wsSettings']);
    final grpc = _stringMap(stream['grpcSettings']);
    final http = _stringMap(stream['httpSettings']);
    final httpUpgrade = _stringMap(stream['httpupgradeSettings']);
    final xhttp = _stringMap(stream['xhttpSettings']);
    final xhttpExtra = _stringMap(xhttp?['extra']);
    final transportMap =
        ws ?? grpc ?? http ?? httpUpgrade ?? xhttp ?? const <String, dynamic>{};

    return _StreamImportConfig(
      transport: transport,
      security: security,
      transportPath: _string(transportMap['path']) ?? '/',
      transportServiceName: _string(grpc?['serviceName']) ?? '',
      transportHost:
          _string(grpc?['authority']) ?? _transportHostFromXray(transportMap),
      transportMode: _string(xhttp?['mode']) ?? '',
      xhttpPadding: _string(xhttpExtra?['xPaddingBytes']) ?? '',
      xhttpMaxPostBytes: _string(xhttpExtra?['scMaxEachPostBytes']) ?? '',
      xhttpMinPostInterval: _string(xhttpExtra?['scMinPostsIntervalMs']) ?? '',
      sni: _string(reality?['serverName']) ?? _string(tls?['serverName']) ?? '',
      alpn: _joinStringList(tls?['alpn']),
      fingerprint:
          _string(reality?['fingerprint']) ??
          _string(tls?['fingerprint']) ??
          '',
      realityPublicKey: _string(reality?['publicKey']) ?? '',
      realityShortId: _firstString(reality?['shortId']) ?? '',
      realitySpiderX: _string(reality?['spiderX']) ?? '',
      realityMldsa65Verify: _string(reality?['mldsa65Verify']) ?? '',
      tlsInsecure:
          tls?['allowInsecure'] == true || reality?['allowInsecure'] == true,
    );
  }

  VlessTransport _transportFromWire(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '');
    return VlessTransport.tryParse(normalized) ?? VlessTransport.tcp;
  }

  String _transportHostFromXray(Map<String, dynamic>? map) {
    final headers = _stringMap(map?['headers']);
    final host = headers?['Host'] ?? headers?['host'] ?? map?['host'];
    return _firstString(host) ?? '';
  }

  String _transportHostFromSingBox(Map<String, dynamic>? map) {
    final headers = _stringMap(map?['headers']);
    return _firstString(headers?['Host'] ?? headers?['host']) ?? '';
  }

  Map<String, dynamic>? _stringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _firstString(Object? value) {
    final direct = _string(value);
    if (direct != null) return direct;
    if (value is List) {
      for (final item in value) {
        final itemString = _string(item);
        if (itemString != null) return itemString;
      }
    }
    return null;
  }

  String _joinStringList(Object? value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .join(',');
    }
    return _string(value) ?? '';
  }

  String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num && value % 1 == 0) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool? _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
    }
    if (value is String) {
      return switch (value.trim().toLowerCase()) {
        '1' || 'true' || 'yes' => true,
        '0' || 'false' || 'no' => false,
        _ => null,
      };
    }
    return null;
  }
}

class _StreamImportConfig {
  const _StreamImportConfig({
    this.transport = VlessTransport.tcp,
    this.security = VlessSecurity.none,
    this.transportPath = '/',
    this.transportServiceName = '',
    this.transportHost = '',
    this.transportMode = '',
    this.xhttpPadding = '',
    this.xhttpMaxPostBytes = '',
    this.xhttpMinPostInterval = '',
    this.sni = '',
    this.alpn = '',
    this.fingerprint = '',
    this.realityPublicKey = '',
    this.realityShortId = '',
    this.realitySpiderX = '',
    this.realityMldsa65Verify = '',
    this.tlsInsecure = false,
  });

  final VlessTransport transport;
  final VlessSecurity security;
  final String transportPath;
  final String transportServiceName;
  final String transportHost;
  final String transportMode;
  final String xhttpPadding;
  final String xhttpMaxPostBytes;
  final String xhttpMinPostInterval;
  final String sni;
  final String alpn;
  final String fingerprint;
  final String realityPublicKey;
  final String realityShortId;
  final String realitySpiderX;
  final String realityMldsa65Verify;
  final bool tlsInsecure;
}
