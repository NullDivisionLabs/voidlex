import 'models/server_config.dart';
import 'server_link_parse_utils.dart';

class Hysteria2ParseException implements Exception {
  const Hysteria2ParseException(this.code, this.message);

  final Hysteria2ParseError code;
  final String message;

  @override
  String toString() => 'Hysteria2ParseException($code): $message';
}

enum Hysteria2ParseError {
  notHysteria2Scheme,
  malformedUri,
  missingAuth,
  missingHost,
  invalidPort,
  unsupportedObfs,
  missingObfsPassword,
}

class Hysteria2ParseResult {
  const Hysteria2ParseResult._({this.config, this.error});

  final ServerConfig? config;
  final Hysteria2ParseException? error;

  bool get isOk => config != null;
  bool get isError => error != null;

  factory Hysteria2ParseResult.ok(ServerConfig cfg) =>
      Hysteria2ParseResult._(config: cfg);
  factory Hysteria2ParseResult.fail(Hysteria2ParseError code, String msg) =>
      Hysteria2ParseResult._(error: Hysteria2ParseException(code, msg));
}

class Hysteria2Parser {
  const Hysteria2Parser();

  Hysteria2ParseResult parse(
    String rawLink, {
    Set<String> existingNames = const {},
  }) {
    final link = rawLink.trim();
    final schemeEnd = link.indexOf('://');
    if (schemeEnd <= 0) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.notHysteria2Scheme,
        'Link does not start with hysteria2:// or hy2://',
      );
    }

    final scheme = link.substring(0, schemeEnd).toLowerCase();
    if (scheme != 'hysteria2' && scheme != 'hy2') {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.notHysteria2Scheme,
        'Link does not start with hysteria2:// or hy2://',
      );
    }

    final parsed = _parseLinkBody(link.substring(schemeEnd + 3));
    if (parsed == null) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.malformedUri,
        'URI cannot be parsed',
      );
    }

    final auth = _decodeComponent(parsed.auth);
    if (auth == null) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.malformedUri,
        'Auth cannot be decoded',
      );
    }
    if (auth.isEmpty) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.missingAuth,
        'Auth password is missing',
      );
    }

    if (parsed.host.trim().isEmpty) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.missingHost,
        'Host is missing',
      );
    }

    final portConfig = _parsePortSpec(parsed.portSpec);
    if (portConfig == null) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.invalidPort,
        'Port is out of range 1..65535',
      );
    }

    final query = _parseQuery(parsed.query);
    if (query == null) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.malformedUri,
        'Query cannot be decoded',
      );
    }

    final obfs = _firstQueryValue(query, const ['obfs'])?.toLowerCase();
    if (obfs != null && obfs != 'salamander') {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.unsupportedObfs,
        'Obfuscation "$obfs" is not supported',
      );
    }
    final obfsPassword =
        _firstQueryValue(query, const ['obfs-password', 'obfsPassword']) ?? '';
    if (obfs == 'salamander' && obfsPassword.isEmpty) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.missingObfsPassword,
        'Salamander obfuscation password is missing',
      );
    }

    final rawName = parsed.fragment.isNotEmpty
        ? _decodeComponent(parsed.fragment)
        : null;
    if (parsed.fragment.isNotEmpty && rawName == null) {
      return Hysteria2ParseResult.fail(
        Hysteria2ParseError.malformedUri,
        'Fragment cannot be decoded',
      );
    }
    final name = ensureUniqueServerName(
      rawName == null || rawName.trim().isEmpty
          ? 'Imported Hysteria2'
          : rawName.trim(),
      existingNames,
      fallback: 'Imported Hysteria2',
    );

    return Hysteria2ParseResult.ok(
      ServerConfig(
        name: name,
        address: parsed.host,
        port: portConfig.port,
        uuid: auth,
        transport: VlessTransport.tcp,
        security: VlessSecurity.tls,
        serverProtocol: ServerProtocol.hysteria2,
        sni:
            _firstQueryValue(query, const [
              'sni',
              'serverName',
              'server_name',
              'servername',
              'peer',
            ]) ??
            '',
        alpn: _firstQueryValue(query, const ['alpn']) ?? 'h3',
        tlsInsecure:
            _boolQueryValue(query, const [
              'insecure',
              'allowInsecure',
              'allow_insecure',
              'tlsInsecure',
            ]) ??
            false,
        hysteria2ObfsPassword: obfsPassword,
        hysteria2HopPorts: portConfig.hopPorts,
      ),
    );
  }

  _ParsedHysteria2Link? _parseLinkBody(String body) {
    var remaining = body;
    var fragment = '';
    final fragmentIndex = remaining.indexOf('#');
    if (fragmentIndex >= 0) {
      fragment = remaining.substring(fragmentIndex + 1);
      remaining = remaining.substring(0, fragmentIndex);
    }

    var query = '';
    final queryIndex = remaining.indexOf('?');
    if (queryIndex >= 0) {
      query = remaining.substring(queryIndex + 1);
      remaining = remaining.substring(0, queryIndex);
    }

    final slashIndex = remaining.indexOf('/');
    final authority = slashIndex >= 0
        ? remaining.substring(0, slashIndex)
        : remaining;
    if (authority.isEmpty) return null;

    final atIndex = authority.lastIndexOf('@');
    if (atIndex < 0) {
      return const _ParsedHysteria2Link(
        auth: '',
        host: '',
        portSpec: null,
        query: '',
        fragment: '',
      );
    }

    final auth = authority.substring(0, atIndex);
    final endpoint = authority.substring(atIndex + 1);
    final parsedEndpoint = _parseEndpoint(endpoint);
    if (parsedEndpoint == null) return null;

    return _ParsedHysteria2Link(
      auth: auth,
      host: parsedEndpoint.host,
      portSpec: parsedEndpoint.portSpec,
      query: query,
      fragment: fragment,
    );
  }

  _ParsedEndpoint? _parseEndpoint(String endpoint) {
    if (endpoint.isEmpty) return null;

    if (endpoint.startsWith('[')) {
      final close = endpoint.indexOf(']');
      if (close < 0) return null;
      final host = endpoint.substring(1, close);
      final suffix = endpoint.substring(close + 1);
      if (suffix.isEmpty) return _ParsedEndpoint(host: host);
      if (!suffix.startsWith(':')) return null;
      return _ParsedEndpoint(host: host, portSpec: suffix.substring(1));
    }

    final colonCount = ':'.allMatches(endpoint).length;
    if (colonCount == 1) {
      final colon = endpoint.lastIndexOf(':');
      return _ParsedEndpoint(
        host: endpoint.substring(0, colon),
        portSpec: endpoint.substring(colon + 1),
      );
    }

    return _ParsedEndpoint(host: endpoint);
  }

  _ParsedPortSpec? _parsePortSpec(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const _ParsedPortSpec(port: 443, hopPorts: '');
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    int? firstPort;
    for (final rawSegment in trimmed.split(',')) {
      final segment = rawSegment.trim();
      if (segment.isEmpty) return null;
      if (segment.contains('-')) {
        final parts = segment.split('-');
        if (parts.length != 2) return null;
        final low = int.tryParse(parts[0].trim());
        final high = int.tryParse(parts[1].trim());
        if (low == null || high == null) return null;
        if (low < 1 || high > 65535 || low > high) return null;
        firstPort ??= low;
      } else {
        final port = int.tryParse(segment);
        if (port == null || port < 1 || port > 65535) return null;
        firstPort ??= port;
      }
    }

    if (firstPort == null) return null;
    final isHopSpec = trimmed.contains(',') || trimmed.contains('-');
    return _ParsedPortSpec(port: firstPort, hopPorts: isHopSpec ? trimmed : '');
  }

  Map<String, String>? _parseQuery(String raw) {
    if (raw.isEmpty) return const {};
    try {
      return Uri.splitQueryString(raw);
    } on FormatException {
      return null;
    }
  }

  String? _firstQueryValue(Map<String, String> query, List<String> keys) {
    for (final key in keys) {
      for (final entry in query.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase() &&
            entry.value.isNotEmpty) {
          return entry.value;
        }
      }
    }
    return null;
  }

  bool? _boolQueryValue(Map<String, String> query, List<String> keys) =>
      parseQueryBoolFlag(_firstQueryValue(query, keys));

  String? _decodeComponent(String raw) {
    try {
      return Uri.decodeComponent(raw);
    } on FormatException {
      return null;
    }
  }

}

class _ParsedHysteria2Link {
  const _ParsedHysteria2Link({
    required this.auth,
    required this.host,
    required this.portSpec,
    required this.query,
    required this.fragment,
  });

  final String auth;
  final String host;
  final String? portSpec;
  final String query;
  final String fragment;
}

class _ParsedEndpoint {
  const _ParsedEndpoint({required this.host, this.portSpec});

  final String host;
  final String? portSpec;
}

class _ParsedPortSpec {
  const _ParsedPortSpec({required this.port, required this.hopPorts});

  final int port;
  final String hopPorts;
}
