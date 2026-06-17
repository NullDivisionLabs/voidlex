import 'models/server_config.dart';
import 'server_link_parse_utils.dart';

class NaiveParseException implements Exception {
  const NaiveParseException(this.code, this.message);

  final NaiveParseError code;
  final String message;

  @override
  String toString() => 'NaiveParseException($code): $message';
}

enum NaiveParseError {
  notNaiveScheme,
  malformedUri,
  missingHost,
  invalidPort,
  invalidMode,
  invalidCongestionControl,
}

class NaiveParseResult {
  const NaiveParseResult._({this.config, this.error});

  final ServerConfig? config;
  final NaiveParseException? error;

  bool get isOk => config != null;
  bool get isError => error != null;

  factory NaiveParseResult.ok(ServerConfig config) =>
      NaiveParseResult._(config: config);
  factory NaiveParseResult.fail(NaiveParseError code, String message) =>
      NaiveParseResult._(error: NaiveParseException(code, message));
}

class NaiveParser {
  const NaiveParser();

  static const validCongestionControls = <String>{
    '',
    'bbr',
    'bbr2',
    'cubic',
    'reno',
  };

  NaiveParseResult parse(
    String rawLink, {
    Set<String> existingNames = const {},
  }) {
    final link = rawLink.trim();
    final uri = Uri.tryParse(link);
    if (uri == null) {
      return NaiveParseResult.fail(
        NaiveParseError.malformedUri,
        'URI cannot be parsed',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'naive' &&
        scheme != 'naive+https' &&
        scheme != 'naive+quic') {
      return NaiveParseResult.fail(
        NaiveParseError.notNaiveScheme,
        'Link does not start with naive://, naive+https://, or naive+quic://',
      );
    }
    if (uri.host.trim().isEmpty) {
      return NaiveParseResult.fail(
        NaiveParseError.missingHost,
        'Host is missing',
      );
    }

    // Reading uri.queryParameters (and decoding components) can throw on
    // malformed percent-encoding, e.g. an incomplete UTF-8 escape like
    // `?sni=%E0%A4%A`. Untrusted input from QR codes, the clipboard, or
    // subscriptions must degrade to a graceful failure here rather than
    // crashing the import — mirroring VlessParser's defensive style.
    try {
      return _parseValidated(uri, scheme, existingNames);
    } on FormatException {
      return NaiveParseResult.fail(
        NaiveParseError.malformedUri,
        'URI contains invalid percent-encoding',
      );
    } on ArgumentError {
      return NaiveParseResult.fail(
        NaiveParseError.malformedUri,
        'URI contains invalid percent-encoding',
      );
    }
  }

  NaiveParseResult _parseValidated(
    Uri uri,
    String scheme,
    Set<String> existingNames,
  ) {
    final port = uri.hasPort ? uri.port : 443;
    if (port < 1 || port > 65535) {
      return NaiveParseResult.fail(
        NaiveParseError.invalidPort,
        'Port is out of range 1..65535',
      );
    }

    final query = uri.queryParameters;
    final mode = query['mode']?.trim().toLowerCase();
    final bool quic;
    if (scheme == 'naive+quic') {
      quic = true;
    } else if (scheme == 'naive+https') {
      quic = false;
    } else if (mode == null || mode.isEmpty || mode == 'https') {
      final quicFlag = parseQueryBoolFlag(query['quic']);
      if (query.containsKey('quic') && quicFlag == null) {
        return NaiveParseResult.fail(
          NaiveParseError.invalidMode,
          'Naive quic flag must be 1, true, 0, or false',
        );
      }
      quic = quicFlag ?? false;
    } else if (mode == 'quic') {
      quic = true;
    } else {
      return NaiveParseResult.fail(
        NaiveParseError.invalidMode,
        'Naive mode must be https or quic',
      );
    }

    final congestionControl =
        (query['congestion_control'] ??
                query['congestion-control'] ??
                query['quic_congestion_control'] ??
                '')
            .trim()
            .toLowerCase();
    if (!validCongestionControls.contains(congestionControl)) {
      return NaiveParseResult.fail(
        NaiveParseError.invalidCongestionControl,
        'Unsupported QUIC congestion control: $congestionControl',
      );
    }

    final rawName = Uri.decodeComponent(uri.fragment).trim();
    final name = ensureUniqueServerName(
      rawName.isEmpty ? 'Imported NaiveProxy' : rawName,
      existingNames,
      fallback: 'Imported NaiveProxy',
    );

    return NaiveParseResult.ok(
      ServerConfig(
        name: name,
        address: uri.host,
        port: port,
        uuid: '',
        transport: VlessTransport.tcp,
        security: VlessSecurity.tls,
        serverProtocol: ServerProtocol.naive,
        sni: query['sni'] ?? query['server_name'] ?? query['serverName'] ?? '',
        naiveUsername: uri.userInfo.isEmpty
            ? ''
            : Uri.decodeComponent(uri.userInfo.split(':').first),
        naivePassword: _password(uri.userInfo),
        naiveQuic: quic,
        naiveQuicCongestionControl: quic ? congestionControl : '',
      ),
    );
  }

  String _password(String userInfo) {
    if (userInfo.isEmpty || !userInfo.contains(':')) return '';
    return Uri.decodeComponent(userInfo.substring(userInfo.indexOf(':') + 1));
  }
}
