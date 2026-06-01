import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/bounded_json.dart';

void main() {
  test('decodeJson rejects payloads over the byte limit', () {
    final oversized = jsonEncode({
      'data': 'x' * (JsonPayloadLimits.settingsBlob + 1),
    });
    expect(
      () => decodeJson(oversized, maxBytes: JsonPayloadLimits.settingsBlob),
      throwsA(isA<JsonPayloadTooLargeException>()),
    );
  });

  test('decodeJson accepts payloads within the byte limit', () {
    expect(
      decodeJson('{"ok":true}', maxBytes: JsonPayloadLimits.settingsBlob),
      {'ok': true},
    );
  });

  test('tryDecodeJson returns null for oversize payloads', () {
    final oversized = jsonEncode({
      'data': 'x' * (JsonPayloadLimits.settingsBlob + 64),
    });
    expect(
      tryDecodeJson(oversized, maxBytes: JsonPayloadLimits.settingsBlob),
      isNull,
    );
  });
}
