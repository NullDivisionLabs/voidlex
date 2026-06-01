import 'dart:convert';

/// Upper bounds for JSON parsed in-app (UTF-8 byte length, not char count).
abstract final class JsonPayloadLimits {
  /// Full Void//Lex profile export/import.
  static const int profile = 4 * 1024 * 1024;

  /// Manual servers + subscription lists persisted in SharedPreferences.
  static const int serverCatalog = 3 * 1024 * 1024;

  /// Routing rules file import and routing-preset blobs.
  static const int routingDocument = 1024 * 1024;

  /// Tunnel/settings preference JSON (fragment, mux, network, policy, …).
  static const int settingsBlob = 512 * 1024;
}

/// Thrown when [raw] exceeds the configured UTF-8 byte cap before [jsonDecode].
class JsonPayloadTooLargeException implements Exception {
  JsonPayloadTooLargeException({
    required this.limitBytes,
    required this.actualBytes,
  });

  final int limitBytes;
  final int actualBytes;

  @override
  String toString() =>
      'JSON payload is too large ($actualBytes bytes, limit $limitBytes)';
}

int jsonUtf8ByteLength(String raw) => utf8.encode(raw).length;

Object? decodeJson(String raw, {required int maxBytes}) {
  final actualBytes = jsonUtf8ByteLength(raw);
  if (actualBytes > maxBytes) {
    throw JsonPayloadTooLargeException(
      limitBytes: maxBytes,
      actualBytes: actualBytes,
    );
  }
  return jsonDecode(raw);
}

/// Like [decodeJson], but returns null on malformed JSON or oversize payload.
Object? tryDecodeJson(String raw, {required int maxBytes}) {
  try {
    return decodeJson(raw, maxBytes: maxBytes);
  } on FormatException {
    return null;
  } on JsonPayloadTooLargeException {
    return null;
  }
}
