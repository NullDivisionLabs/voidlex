import 'models/server_config.dart';
import 'server_link_parse_utils.dart';

class VlessParseException implements Exception {
  const VlessParseException(this.code, this.message);

  final VlessParseError code;
  final String message;

  @override
  String toString() => 'VlessParseException($code): $message';
}

enum VlessParseError {
  notVlessScheme,
  malformedUri,
  missingUuid,
  invalidUuid,
  missingHost,
  invalidPort,
  unsupportedTransport,
  unsupportedSecurity,
}

class VlessParseResult {
  const VlessParseResult._({this.config, this.error});

  final ServerConfig? config;
  final VlessParseException? error;

  bool get isOk => config != null;
  bool get isError => error != null;

  factory VlessParseResult.ok(ServerConfig cfg) =>
      VlessParseResult._(config: cfg);
  factory VlessParseResult.fail(VlessParseError code, String msg) =>
      VlessParseResult._(error: VlessParseException(code, msg));
}

class VlessParser {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  const VlessParser();

  /// Parses a single vless:// URL. `existingNames` is used to deduplicate the
  /// human-readable name (fragment); callers may pass an empty set if they
  /// don't care about uniqueness.
  VlessParseResult parse(
    String rawLink, {
    Set<String> existingNames = const {},
  }) {
    final link = rawLink.trim();
    if (link.isEmpty || !link.toLowerCase().startsWith('vless://')) {
      return VlessParseResult.fail(
        VlessParseError.notVlessScheme,
        'Link does not start with vless://',
      );
    }

    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme.toLowerCase() != 'vless') {
      return VlessParseResult.fail(
        VlessParseError.malformedUri,
        'URI cannot be parsed',
      );
    }

    // Reading uri.queryParameters (and decoding components) can throw on
    // malformed percent-encoding, e.g. an incomplete UTF-8 escape like
    // `?sni=%E0%A4%A`. Untrusted input from QR codes, the clipboard, or
    // subscriptions must degrade to a graceful failure here rather than
    // crashing the import — mirroring Hysteria2Parser's defensive style.
    try {
      return _parseValidated(uri, existingNames);
    } on FormatException {
      return VlessParseResult.fail(
        VlessParseError.malformedUri,
        'URI contains invalid percent-encoding',
      );
    } on ArgumentError {
      return VlessParseResult.fail(
        VlessParseError.malformedUri,
        'URI contains invalid percent-encoding',
      );
    }
  }

  VlessParseResult _parseValidated(Uri uri, Set<String> existingNames) {
    final uuid = uri.userInfo.trim();
    if (uuid.isEmpty) {
      return VlessParseResult.fail(
        VlessParseError.missingUuid,
        'UUID (userinfo) is missing',
      );
    }
    if (!_uuidRegex.hasMatch(uuid)) {
      return VlessParseResult.fail(
        VlessParseError.invalidUuid,
        'UUID is not in RFC 4122 format',
      );
    }

    final host = uri.host.trim();
    if (host.isEmpty) {
      return VlessParseResult.fail(
        VlessParseError.missingHost,
        'Host is missing',
      );
    }

    final port = uri.hasPort ? uri.port : 443;
    if (port < 1 || port > 65535) {
      return VlessParseResult.fail(
        VlessParseError.invalidPort,
        'Port $port out of range 1..65535',
      );
    }

    final transportRaw =
        _firstQueryValue(uri, const ['type', 'transport']) ?? 'tcp';
    final transport = VlessTransport.tryParse(transportRaw);
    if (transport == null) {
      return VlessParseResult.fail(
        VlessParseError.unsupportedTransport,
        'Transport "$transportRaw" is not supported',
      );
    }
    final securityRaw = _firstQueryValue(uri, const ['security']) ?? 'none';
    final security = VlessSecurity.tryParse(securityRaw);
    if (security == null) {
      return VlessParseResult.fail(
        VlessParseError.unsupportedSecurity,
        'Security "$securityRaw" is not supported',
      );
    }

    final baseName = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : 'Imported VLESS';
    final name = ensureUniqueServerName(
      baseName,
      existingNames,
      fallback: 'Imported VLESS',
    );

    final transportHost =
        _firstQueryValue(uri, const ['host', 'authority']) ?? '';
    final explicitSni =
        _firstQueryValue(uri, const [
          'sni',
          'serverName',
          'server_name',
          'servername',
          'peer',
        ]) ??
        '';
    final sni = explicitSni.isNotEmpty || !security.tlsEnabled
        ? explicitSni
        : transportHost;

    final config = ServerConfig(
      name: name,
      address: host,
      port: port,
      uuid: uuid,
      transport: transport,
      security: security,
      transportPath: _firstQueryValue(uri, const ['path']) ?? '/',
      transportServiceName:
          _firstQueryValue(uri, const [
            'serviceName',
            'service_name',
            'service-name',
          ]) ??
          '',
      transportHost: transportHost,
      transportMode: _firstQueryValue(uri, const ['mode']) ?? '',
      xhttpPadding:
          _firstQueryValue(uri, const [
            'xPadding',
            'xPaddingBytes',
            'padding',
          ]) ??
          '',
      xhttpMaxPostBytes:
          _firstQueryValue(uri, const [
            'scMaxEachPostBytes',
            'maxPostBytes',
          ]) ??
          '',
      xhttpMinPostInterval:
          _firstQueryValue(uri, const [
            'scMinPostsIntervalMs',
            'minPostInterval',
          ]) ??
          '',
      sni: sni,
      alpn: _firstQueryValue(uri, const ['alpn']) ?? '',
      flow: _firstQueryValue(uri, const ['flow']) ?? '',
      fingerprint:
          _firstQueryValue(uri, const ['fp', 'fingerprint', 'utls']) ?? '',
      realityPublicKey:
          _firstQueryValue(uri, const [
            'pbk',
            'publicKey',
            'public_key',
            'public-key',
          ]) ??
          '',
      realityShortId:
          _firstQueryValue(uri, const [
            'sid',
            'shortId',
            'short_id',
            'short-id',
          ]) ??
          '',
      realitySpiderX:
          _firstQueryValue(uri, const [
            'spx',
            'spiderX',
            'spider_x',
            'spider-x',
          ]) ??
          '',
      tlsInsecure:
          _boolQueryValue(uri, const [
            'allowInsecure',
            'allow_insecure',
            'insecure',
            'tlsInsecure',
          ]) ??
          false,
    );

    return VlessParseResult.ok(config);
  }

  String? _firstQueryValue(Uri uri, List<String> keys) {
    for (final key in keys) {
      final v = uri.queryParameters[key];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  bool? _boolQueryValue(Uri uri, List<String> keys) =>
      parseQueryBoolFlag(_firstQueryValue(uri, keys));
}
