import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_message_code.dart';
import 'hysteria2_parser.dart';
import 'subscription_client_identity.dart';
import 'models/server_config.dart';
import 'models/server_subscription.dart';
import 'naive_parser.dart';
import 'server_importer.dart';
import 'vless_parser.dart';

enum ServerSubscriptionImportError {
  invalidUrl,
  network,
  empty,
  unsupportedFormat,
  invalidVless,
  invalidHysteria2,
  invalidNaive,
}

class ServerSubscriptionImportException implements Exception {
  const ServerSubscriptionImportException(
    this.code,
    this.message, {
    this.vlessError,
    this.hysteria2Error,
    this.naiveError,
  });

  final ServerSubscriptionImportError code;
  final String message;
  final VlessParseException? vlessError;
  final Hysteria2ParseException? hysteria2Error;
  final NaiveParseException? naiveError;

  @override
  String toString() => 'ServerSubscriptionImportException($code): $message';
}

class ServerSubscriptionImportResult {
  const ServerSubscriptionImportResult._({this.subscription, this.error});

  final ServerSubscription? subscription;
  final ServerSubscriptionImportException? error;

  bool get isOk => subscription != null;
  bool get isError => error != null;

  factory ServerSubscriptionImportResult.ok(ServerSubscription subscription) =>
      ServerSubscriptionImportResult._(subscription: subscription);

  factory ServerSubscriptionImportResult.fail(
    ServerSubscriptionImportError code,
    String message, {
    VlessParseException? vlessError,
    Hysteria2ParseException? hysteria2Error,
    NaiveParseException? naiveError,
  }) => ServerSubscriptionImportResult._(
    error: ServerSubscriptionImportException(
      code,
      message,
      vlessError: vlessError,
      hysteria2Error: hysteria2Error,
      naiveError: naiveError,
    ),
  );
}

extension ServerSubscriptionImportExceptionWire
    on ServerSubscriptionImportException {
  /// Stable wire form consumed by [localizeUserMessage].
  String toWireMessage() {
    switch (code) {
      case ServerSubscriptionImportError.invalidUrl:
        return Msg.subImportInvalidUrl;
      case ServerSubscriptionImportError.network:
        if (message == 'Subscription request timed out') {
          return Msg.subImportTimeout;
        }
        const httpPrefix = 'Subscription returned HTTP ';
        if (message.startsWith(httpPrefix)) {
          final c = int.tryParse(message.substring(httpPrefix.length));
          if (c != null) return Msg.subImportHttpStatus(c);
        }
        if (message == 'Subscription response is too large') {
          return Msg.subImportTooLarge;
        }
        if (message.startsWith('Subscription request failed:')) {
          return 'subImportRequestFailed:${message.substring('Subscription request failed:'.length)}';
        }
        return 'subImportGenericDetail:$message';
      case ServerSubscriptionImportError.empty:
        return Msg.subImportEmpty;
      case ServerSubscriptionImportError.unsupportedFormat:
        return message == 'Unsupported subscription JSON'
            ? Msg.subImportUnsupportedJson
            : 'subImportGenericDetail:$message';
      case ServerSubscriptionImportError.invalidVless:
      case ServerSubscriptionImportError.invalidHysteria2:
      case ServerSubscriptionImportError.invalidNaive:
        return 'subImportGenericDetail:$message';
    }
  }
}

class ServerSubscriptionImporter {
  const ServerSubscriptionImporter({
    this.vlessParser = const VlessParser(),
    this.hysteria2Parser = const Hysteria2Parser(),
    this.naiveParser = const NaiveParser(),
  });

  static const Duration _requestTimeout = Duration(seconds: 12);
  static const int _maxPayloadBytes = 1024 * 1024;

  final VlessParser vlessParser;
  final Hysteria2Parser hysteria2Parser;
  final NaiveParser naiveParser;

  static Uri? tryParseSubscriptionUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    return uri;
  }

  Future<ServerSubscriptionImportResult> importFromUrl(
    String rawUrl, {
    required String id,
    String? nameOverride,
    Set<String> existingNames = const {},
    String? hwid,
    bool allowInsecureTls = false,
  }) async {
    final uri = tryParseSubscriptionUri(rawUrl);
    if (uri == null) {
      return ServerSubscriptionImportResult.fail(
        ServerSubscriptionImportError.invalidUrl,
        'Enter a valid HTTP or HTTPS subscription URL',
      );
    }

    final _SubscriptionResponse response;
    try {
      response = await _fetch(
        uri,
        hwid: hwid,
        allowInsecureTls: allowInsecureTls,
      );
    } on TimeoutException {
      return ServerSubscriptionImportResult.fail(
        ServerSubscriptionImportError.network,
        'Subscription request timed out',
      );
    } on HttpException catch (e) {
      return ServerSubscriptionImportResult.fail(
        ServerSubscriptionImportError.network,
        e.message,
      );
    } on IOException catch (e) {
      return ServerSubscriptionImportResult.fail(
        ServerSubscriptionImportError.network,
        'Subscription request failed: $e',
      );
    }

    return parsePayload(
      url: uri.toString(),
      id: id,
      payload: response.body,
      headers: response.headers,
      nameOverride: nameOverride,
      existingNames: existingNames,
    );
  }

  ServerSubscriptionImportResult parsePayload({
    required String url,
    required String id,
    required String payload,
    Map<String, String> headers = const {},
    String? nameOverride,
    Set<String> existingNames = const {},
  }) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      return ServerSubscriptionImportResult.fail(
        ServerSubscriptionImportError.empty,
        'Subscription is empty',
      );
    }

    final configsResult = _parsePayloadConfigs(trimmed, existingNames);
    if (configsResult.error != null) {
      return ServerSubscriptionImportResult.fail(
        configsResult.error!.code,
        configsResult.error!.message,
        vlessError: configsResult.error!.vlessError,
        hysteria2Error: configsResult.error!.hysteria2Error,
        naiveError: configsResult.error!.naiveError,
      );
    }

    final configs = configsResult.configs;
    if (configs.isEmpty) {
      return ServerSubscriptionImportResult.fail(
        ServerSubscriptionImportError.unsupportedFormat,
        'Subscription does not contain supported nodes',
      );
    }

    final uri = Uri.tryParse(url);
    final name = _subscriptionName(
      uri: uri,
      headers: headers,
      nameOverride: nameOverride,
    );
    final expiresAt = _subscriptionExpiry(headers, trimmed);
    final traffic = _subscriptionTraffic(headers, trimmed);
    return ServerSubscriptionImportResult.ok(
      ServerSubscription(
        id: id,
        name: name,
        url: url,
        servers: List.unmodifiable(configs),
        updatedAt: DateTime.now().toUtc(),
        expiresAt: expiresAt,
        trafficUsedBytes: traffic?.usedBytes,
        trafficLimitBytes: traffic?.limitBytes,
      ),
    );
  }

  Future<_SubscriptionResponse> _fetch(
    Uri uri, {
    String? hwid,
    bool allowInsecureTls = false,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _requestTimeout;
      if (allowInsecureTls) {
        client.badCertificateCallback = (_, _, _) => true;
      }
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      request.followRedirects = true;
      request.maxRedirects = 5;
      SubscriptionClientIdentity.applyTo(request);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/plain, application/json;q=0.9, */*;q=0.8',
      );
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final trimmedHwid = hwid?.trim();
      if (trimmedHwid != null && trimmedHwid.isNotEmpty) {
        request.headers.set('X-HWID', trimmedHwid);
      }

      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Subscription returned HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) {
          headers[name.toLowerCase()] = values.join(',');
        }
      });

      final bytes = <int>[];
      await for (final chunk in response.timeout(_requestTimeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxPayloadBytes) {
          throw HttpException('Subscription response is too large', uri: uri);
        }
      }
      return _SubscriptionResponse(
        body: utf8.decode(bytes, allowMalformed: true),
        headers: headers,
      );
    } finally {
      client?.close(force: true);
    }
  }

  _PayloadParseResult _parsePayloadConfigs(
    String raw,
    Set<String> existingNames,
  ) {
    final candidates = <String>[raw];
    final decoded = _tryDecodeBase64Payload(raw);
    if (decoded != null && decoded.trim() != raw.trim()) {
      candidates.add(decoded);
    }

    _PayloadParseResult? linkFailure;
    for (final candidate in candidates) {
      final jsonResult = _tryParseJsonPayload(candidate, existingNames);
      if (jsonResult != null) return jsonResult;

      final links = _extractServerLinks(candidate);
      if (links.isEmpty) continue;

      final parsed = _parseServerLinks(links, existingNames);
      if (parsed.error == null || linkFailure == null) {
        linkFailure = parsed;
      }
      if (parsed.error == null && parsed.configs.isNotEmpty) return parsed;
    }

    return linkFailure ?? const _PayloadParseResult(configs: []);
  }

  _PayloadParseResult? _tryParseJsonPayload(
    String raw,
    Set<String> existingNames,
  ) {
    final trimmed = raw.trimLeft();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;

    final result = ServerImporter(
      vlessParser: vlessParser,
      hysteria2Parser: hysteria2Parser,
      naiveParser: naiveParser,
    ).parse(raw, existingNames: existingNames);
    if (result.isOk) {
      return _PayloadParseResult(configs: result.configs);
    }
    return _PayloadParseResult(
      configs: const [],
      error: ServerSubscriptionImportException(
        ServerSubscriptionImportError.unsupportedFormat,
        result.error?.message ?? 'Unsupported subscription JSON',
        vlessError: result.error?.vlessError,
        hysteria2Error: result.error?.hysteria2Error,
        naiveError: result.error?.naiveError,
      ),
    );
  }

  _PayloadParseResult _parseServerLinks(
    List<String> links,
    Set<String> existingNames,
  ) {
    final names = Set<String>.of(existingNames);
    final configs = <ServerConfig>[];

    for (final link in links) {
      final lower = link.trimLeft().toLowerCase();
      final ServerConfig config;
      if (lower.startsWith('vless://')) {
        final result = vlessParser.parse(link, existingNames: names);
        if (result.isError) {
          return _PayloadParseResult(
            configs: const [],
            error: ServerSubscriptionImportException(
              ServerSubscriptionImportError.invalidVless,
              result.error!.message,
              vlessError: result.error,
            ),
          );
        }
        config = result.config!;
      } else if (lower.startsWith('hysteria2://') ||
          lower.startsWith('hy2://')) {
        final result = hysteria2Parser.parse(link, existingNames: names);
        if (result.isError) {
          return _PayloadParseResult(
            configs: const [],
            error: ServerSubscriptionImportException(
              ServerSubscriptionImportError.invalidHysteria2,
              result.error!.message,
              hysteria2Error: result.error,
            ),
          );
        }
        config = result.config!;
      } else {
        final result = naiveParser.parse(link, existingNames: names);
        if (result.isError) {
          return _PayloadParseResult(
            configs: const [],
            error: ServerSubscriptionImportException(
              ServerSubscriptionImportError.invalidNaive,
              result.error!.message,
              naiveError: result.error,
            ),
          );
        }
        config = result.config!;
      }
      configs.add(config);
      names.add(config.name);
    }

    return _PayloadParseResult(configs: configs);
  }

  List<String> _extractServerLinks(String raw) {
    final matches = RegExp(
      r'''(?:vless|hysteria2|hy2|naive|naive\+https|naive\+quic)://[^\s<>"']+''',
      caseSensitive: false,
    ).allMatches(raw);
    return matches.map((match) => match.group(0)!.trim()).toList();
  }

  String? _tryDecodeBase64Payload(String raw) {
    final compact = raw.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 8) return null;
    final normalized = _normalizeBase64(compact);
    if (normalized == null) return null;
    try {
      final decoded = utf8.decode(
        base64.decode(normalized),
        allowMalformed: true,
      );
      final trimmed = decoded.trimLeft();
      if (trimmed.startsWith('{') ||
          trimmed.startsWith('[') ||
          _containsSupportedLink(decoded)) {
        return decoded;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  bool _containsSupportedLink(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('vless://') ||
        lower.contains('hysteria2://') ||
        lower.contains('hy2://') ||
        lower.contains('naive://') ||
        lower.contains('naive+https://') ||
        lower.contains('naive+quic://');
  }

  String? _normalizeBase64(String raw) {
    var normalized = raw.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = normalized.length % 4;
    if (remainder == 1) return null;
    if (remainder > 0) {
      normalized = normalized.padRight(normalized.length + 4 - remainder, '=');
    }
    return normalized;
  }

  String _subscriptionName({
    required Uri? uri,
    required Map<String, String> headers,
    String? nameOverride,
  }) {
    final override = _cleanName(nameOverride);
    if (override != null) return override;

    final profileTitle = _decodeHeaderTitle(headers['profile-title']);
    if (profileTitle != null) return profileTitle;

    final filename = _filenameFromContentDisposition(
      headers['content-disposition'],
    );
    if (filename != null) return filename;

    final host = uri?.host.trim();
    if (host != null && host.isNotEmpty) return host;
    return 'Subscription';
  }

  DateTime? _subscriptionExpiry(Map<String, String> headers, String payload) {
    final fromUserInfo = _expireFromKeyValueList(
      headers['subscription-userinfo'] ?? headers['subscription-user-info'],
    );
    if (fromUserInfo != null) return fromUserInfo;

    for (final key in const [
      'profile-expire',
      'profile-expiry',
      'subscription-expire',
      'subscription-expiry',
      'expire',
      'expires',
    ]) {
      final value = headers[key];
      final parsed = _parseExpireValue(value);
      if (parsed != null) return parsed;
    }

    return _expireFromKeyValueList(payload);
  }

  _SubscriptionTraffic? _subscriptionTraffic(
    Map<String, String> headers,
    String payload,
  ) {
    final fromUserInfo = _trafficFromKeyValueList(
      headers['subscription-userinfo'] ?? headers['subscription-user-info'],
    );
    if (fromUserInfo != null) return fromUserInfo;

    return _trafficFromKeyValueList(payload);
  }

  DateTime? _expireFromKeyValueList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(
      r'(?:^|[;,\s])expire(?:s|d|_at|-at)?\s*=\s*([^;,\s]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    return _parseExpireValue(match?.group(1));
  }

  DateTime? _parseExpireValue(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final numeric = int.tryParse(trimmed);
    if (numeric != null && numeric > 0) {
      final millis = numeric > 100000000000
          ? numeric
          : Duration(seconds: numeric).inMilliseconds;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }

    final httpDate = _tryParseHttpDate(trimmed);
    if (httpDate != null) return httpDate;

    final isoDate = DateTime.tryParse(trimmed);
    return isoDate?.toUtc();
  }

  _SubscriptionTraffic? _trafficFromKeyValueList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final upload = _bytesFromKeyValueList(raw, const [
      'upload',
      'uplink',
      'up',
    ]);
    final download = _bytesFromKeyValueList(raw, const [
      'download',
      'downlink',
      'down',
    ]);
    final explicitUsed = _bytesFromKeyValueList(raw, const [
      'used',
      'usage',
      'traffic',
      'used_traffic',
      'used-traffic',
    ]);
    final combinedUsed = upload == null && download == null
        ? null
        : (upload ?? 0) + (download ?? 0);
    final usedBytes = explicitUsed ?? combinedUsed;

    final total = _bytesFromKeyValueList(raw, const [
      'total',
      'limit',
      'transfer_enable',
      'transfer-enable',
    ]);
    final limitBytes = total == null || total <= 0 ? null : total;
    if (usedBytes == null && limitBytes == null) return null;

    return _SubscriptionTraffic(
      usedBytes: usedBytes ?? 0,
      limitBytes: limitBytes,
    );
  }

  int? _bytesFromKeyValueList(String raw, List<String> keys) {
    final pattern = keys.map(RegExp.escape).join('|');
    final match = RegExp(
      '(?:^|[;,\\s])(?:$pattern)\\s*=\\s*([^;,\\s]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    return _parseTrafficBytes(match?.group(1));
  }

  int? _parseTrafficBytes(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null || value < 0) return null;
    return value;
  }

  DateTime? _tryParseHttpDate(String raw) {
    try {
      return HttpDate.parse(raw).toUtc();
    } on Exception {
      return null;
    }
  }

  String? _decodeHeaderTitle(String? raw) {
    final cleaned = _cleanName(raw);
    if (cleaned == null) return null;
    if (cleaned.toLowerCase().startsWith('base64:')) {
      final decoded = _decodeBase64Text(cleaned.substring(7));
      return _cleanName(decoded);
    }
    try {
      return _cleanName(Uri.decodeComponent(cleaned));
    } on FormatException {
      return cleaned;
    }
  }

  String? _decodeBase64Text(String raw) {
    final normalized = _normalizeBase64(raw.trim());
    if (normalized == null) return null;
    try {
      return utf8.decode(base64.decode(normalized), allowMalformed: true);
    } on FormatException {
      return null;
    }
  }

  String? _filenameFromContentDisposition(String? raw) {
    if (raw == null) return null;
    final encoded = RegExp(
      r'''filename\*=UTF-8''([^;]+)''',
      caseSensitive: false,
    ).firstMatch(raw);
    if (encoded != null) {
      try {
        return _cleanName(Uri.decodeComponent(encoded.group(1)!));
      } on FormatException {
        return _cleanName(encoded.group(1));
      }
    }

    final plain = RegExp(
      r'''filename="?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(raw);
    return _cleanName(plain?.group(1));
  }

  String? _cleanName(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim().replaceAll(RegExp(r'\.(txt|json)$'), '');
    return cleaned.isEmpty ? null : cleaned;
  }
}

class _SubscriptionResponse {
  const _SubscriptionResponse({required this.body, required this.headers});

  final String body;
  final Map<String, String> headers;
}

class _PayloadParseResult {
  const _PayloadParseResult({required this.configs, this.error});

  final List<ServerConfig> configs;
  final ServerSubscriptionImportException? error;
}

class _SubscriptionTraffic {
  const _SubscriptionTraffic({
    required this.usedBytes,
    required this.limitBytes,
  });

  final int usedBytes;
  final int? limitBytes;
}
