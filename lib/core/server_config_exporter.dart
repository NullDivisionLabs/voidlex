import 'dart:convert';

import 'models/server_config.dart';

class ServerConfigExporter {
  const ServerConfigExporter._();

  static String toServerUrl(ServerConfig server) {
    switch (server.serverProtocol) {
      case ServerProtocol.vless:
        return toVlessUrl(server);
      case ServerProtocol.hysteria2:
        return toHysteria2Url(server);
    }
  }

  static String toVlessUrl(ServerConfig server) {
    final query = <String, String>{
      'type': server.transport.wireName,
      'security': server.security.wireName,
    };
    _addQuery(query, 'path', server.transportPath);
    _addQuery(query, 'host', server.transportHost);
    _addQuery(query, 'serviceName', server.transportServiceName);
    _addQuery(query, 'mode', server.transportMode);
    _addQuery(query, 'xPadding', server.xhttpPadding);
    _addQuery(query, 'scMaxEachPostBytes', server.xhttpMaxPostBytes);
    _addQuery(query, 'scMinPostsIntervalMs', server.xhttpMinPostInterval);
    _addQuery(query, 'sni', server.sni);
    _addQuery(query, 'alpn', server.alpn);
    _addQuery(query, 'flow', server.flow);
    _addQuery(query, 'fp', server.fingerprint);
    _addQuery(query, 'pbk', server.realityPublicKey);
    _addQuery(query, 'sid', server.realityShortId);
    _addQuery(query, 'spx', server.realitySpiderX);
    if (server.tlsInsecure) {
      query['allowInsecure'] = '1';
    }

    return Uri(
      scheme: 'vless',
      userInfo: server.uuid,
      host: server.address,
      port: server.port,
      queryParameters: query,
      fragment: server.name,
    ).toString();
  }

  static String toHysteria2Url(ServerConfig server) {
    final query = <String, String>{};
    _addQuery(query, 'sni', server.sni);
    _addQuery(query, 'alpn', server.alpn.isEmpty ? 'h3' : server.alpn);
    if (server.tlsInsecure) query['insecure'] = '1';
    if (server.hysteria2ObfsPassword.trim().isNotEmpty) {
      query['obfs'] = 'salamander';
      query['obfs-password'] = server.hysteria2ObfsPassword.trim();
    }

    final queryText = Uri(queryParameters: query).query;
    final fragment = Uri.encodeComponent(server.name);
    final host = _formatHost(server.address);
    final portSpec = server.hysteria2HopPorts.trim().isEmpty
        ? server.port.toString()
        : server.hysteria2HopPorts.trim();
    return 'hysteria2://${Uri.encodeComponent(server.uuid)}@$host:$portSpec/'
        '${queryText.isEmpty ? '' : '?$queryText'}'
        '${fragment.isEmpty ? '' : '#$fragment'}';
  }

  static String toXrayJson(ServerConfig server) =>
      const JsonEncoder.withIndent('  ').convert(toXrayConfig(server));

  static Map<String, dynamic> toXrayConfig(ServerConfig server) {
    // Hysteria2 is not a real Xray-core outbound; emit a sing-box config
    // instead, which is the runtime that actually carries Hysteria2 in
    // this app and the format other tunnels (mihomo, sing-box) can read.
    if (server.isHysteria2) return _singBoxConfig(server);
    return {
      'log': {'loglevel': 'warning'},
      'dns': {
        'queryStrategy': 'UseIPv4',
        'servers': ['1.1.1.1', '8.8.8.8'],
      },
      'inbounds': [
        {
          'tag': 'socks',
          'listen': '127.0.0.1',
          'port': 10808,
          'protocol': 'socks',
          'settings': {'udp': true},
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls', 'quic'],
          },
        },
        {
          'tag': 'http',
          'listen': '127.0.0.1',
          'port': 10809,
          'protocol': 'http',
          'settings': {},
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls', 'quic'],
          },
        },
      ],
      'outbounds': [
        _vlessOutbound(server),
        {'protocol': 'freedom', 'tag': 'direct'},
        {'protocol': 'blackhole', 'tag': 'block'},
      ],
      'routing': {'domainStrategy': 'IPIfNonMatch', 'rules': <Object>[]},
      'remarks': server.name,
    };
  }

  static Map<String, dynamic> _singBoxConfig(ServerConfig server) {
    return {
      'log': {'level': 'warn', 'timestamp': true},
      'outbounds': [
        _singBoxHysteria2Outbound(server),
        {'type': 'direct', 'tag': 'direct'},
      ],
      'remarks': server.name,
    };
  }

  static Map<String, dynamic> _singBoxHysteria2Outbound(ServerConfig server) {
    final outbound = <String, dynamic>{
      'type': 'hysteria2',
      'tag': 'proxy',
      'server': server.address,
      'server_port': server.port,
      'password': server.uuid,
      'tls': _singBoxHysteria2Tls(server),
    };
    final hopPorts = _formatHopPortsForSingBox(server.hysteria2HopPorts);
    if (hopPorts != null) outbound['server_ports'] = hopPorts;
    if (server.hysteria2ObfsPassword.trim().isNotEmpty) {
      outbound['obfs'] = {
        'type': 'salamander',
        'password': server.hysteria2ObfsPassword.trim(),
      };
    }
    return outbound;
  }

  static Map<String, dynamic> _singBoxHysteria2Tls(ServerConfig server) {
    return <String, dynamic>{
      'enabled': true,
      'server_name': server.effectiveSni,
      'insecure': server.tlsInsecure,
      'alpn': _csvList(server.alpn.isEmpty ? 'h3' : server.alpn),
    };
  }

  static List<String>? _formatHopPortsForSingBox(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final segments = <String>[];
    for (final part in trimmed.split(',')) {
      final piece = part.trim();
      if (piece.isEmpty) return null;
      if (piece.contains('-')) {
        final bounds = piece.split('-');
        if (bounds.length != 2) return null;
        final low = int.tryParse(bounds[0].trim());
        final high = int.tryParse(bounds[1].trim());
        if (low == null || high == null) return null;
        if (low < 1 || high > 65535 || low > high) return null;
        segments.add('$low:$high');
      } else {
        final port = int.tryParse(piece);
        if (port == null || port < 1 || port > 65535) return null;
        segments.add('$port:$port');
      }
    }
    return segments.isEmpty ? null : segments;
  }

  static Map<String, dynamic> _vlessOutbound(ServerConfig server) {
    final outbound = {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': server.address,
            'port': server.port,
            'users': [
              {
                'id': server.uuid,
                'encryption': 'none',
                'flow': server.flow,
                'level': 8,
                'security': 'auto',
              },
            ],
          },
        ],
      },
      'streamSettings': _streamSettings(server),
    };

    return outbound;
  }

  static Map<String, dynamic> _streamSettings(ServerConfig server) {
    final stream = <String, dynamic>{
      'network': server.transport.wireName,
      'security': server.security.wireName,
    };

    final transportSettings = _transportSettings(server);
    if (transportSettings != null) {
      stream[transportSettings.key] = transportSettings.value;
    }

    switch (server.security) {
      case VlessSecurity.none:
        break;
      case VlessSecurity.tls:
        stream['tlsSettings'] = _tlsSettings(server);
      case VlessSecurity.reality:
        stream['realitySettings'] = _realitySettings(server);
    }

    return stream;
  }

  static Map<String, dynamic> _tlsSettings(ServerConfig server) {
    final settings = <String, dynamic>{
      'serverName': server.effectiveSni,
      'allowInsecure': server.tlsInsecure,
    };
    final alpn = _csvList(server.alpn);
    if (alpn.isNotEmpty) settings['alpn'] = alpn;
    if (server.fingerprint.trim().isNotEmpty) {
      settings['fingerprint'] = server.fingerprint.trim();
    }
    return settings;
  }

  static Map<String, dynamic> _realitySettings(ServerConfig server) {
    final settings = <String, dynamic>{
      'serverName': server.effectiveSni,
      'publicKey': server.realityPublicKey,
      'shortId': server.realityShortId,
      'fingerprint': server.fingerprint,
      'show': false,
      'allowInsecure': server.tlsInsecure,
    };
    if (server.realitySpiderX.trim().isNotEmpty) {
      settings['spiderX'] = server.realitySpiderX.trim();
    }
    return settings;
  }

  static MapEntry<String, Map<String, dynamic>>? _transportSettings(
    ServerConfig server,
  ) {
    switch (server.transport) {
      case VlessTransport.tcp:
        return null;
      case VlessTransport.ws:
        return MapEntry('wsSettings', {
          'path': _pathOrSlash(server.transportPath),
          if (server.transportHost.trim().isNotEmpty)
            'headers': {'Host': server.transportHost.trim()},
        });
      case VlessTransport.grpc:
        return MapEntry('grpcSettings', {
          'serviceName': server.transportServiceName.trim(),
          if (server.transportHost.trim().isNotEmpty)
            'authority': server.transportHost.trim(),
        });
      case VlessTransport.http:
        return MapEntry('httpSettings', {
          'path': _pathOrSlash(server.transportPath),
          if (server.transportHost.trim().isNotEmpty)
            'host': [server.transportHost.trim()],
        });
      case VlessTransport.httpupgrade:
        return MapEntry('httpupgradeSettings', {
          'path': _pathOrSlash(server.transportPath),
          if (server.transportHost.trim().isNotEmpty)
            'host': server.transportHost.trim(),
        });
      case VlessTransport.xhttp:
        return MapEntry('xhttpSettings', {
          'path': _pathOrSlash(server.transportPath),
          if (server.transportHost.trim().isNotEmpty)
            'host': server.transportHost.trim(),
          if (server.transportMode.trim().isNotEmpty)
            'mode': server.transportMode.trim(),
          'extra': ?_xhttpExtraExport(server),
        });
    }
  }

  /// Emits the xhttp `extra` block for exported Xray JSON. We only include
  /// it if the user pinned at least one of the override fields — for plain
  /// "no override" configs the export stays minimal so importers don't
  /// see surprising defaults. The Android runtime applies its own curated
  /// defaults at build time regardless of this.
  static Map<String, dynamic>? _xhttpExtraExport(ServerConfig server) {
    final pad = server.xhttpPadding.trim();
    final maxPost = server.xhttpMaxPostBytes.trim();
    final minInterval = server.xhttpMinPostInterval.trim();
    if (pad.isEmpty && maxPost.isEmpty && minInterval.isEmpty) return null;
    return <String, dynamic>{
      if (pad.isNotEmpty) 'xPaddingBytes': pad,
      if (maxPost.isNotEmpty) 'scMaxEachPostBytes': maxPost,
      if (minInterval.isNotEmpty) 'scMinPostsIntervalMs': minInterval,
    };
  }

  static void _addQuery(Map<String, String> query, String key, String value) {
    if (value.trim().isEmpty) return;
    query[key] = value.trim();
  }

  static List<String> _csvList(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  static String _pathOrSlash(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '/' : trimmed;
  }

  static String _formatHost(String host) {
    final trimmed = host.trim();
    if (trimmed.contains(':') &&
        !trimmed.startsWith('[') &&
        !trimmed.endsWith(']')) {
      return '[$trimmed]';
    }
    return trimmed;
  }
}
