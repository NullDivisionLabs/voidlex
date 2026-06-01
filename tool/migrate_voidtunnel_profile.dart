// One-shot migration tool: rewrite an old VoidTunnel profile JSON export to
// the new VoidLex format. Old `voidtunnel://1/...` protected-subscription
// codes are decrypted with the legacy codec parameters and re-encrypted with
// the current VoidLex codec.
//
// Usage:
//   dart run tool/migrate_voidtunnel_profile.dart <input.json> [<input2.json> ...]
//
// Each input file produces a sibling output file with `voidtunnel-` in the
// filename replaced by `voidlex-` (or `.migrated.json` appended if the
// pattern is not present).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:voidlex/core/subscription_link_codec.dart';

Future<int> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/migrate_voidtunnel_profile.dart <input.json> [...]',
    );
    return 64;
  }

  final oldCodec = _LegacyVoidtunnelCodec();
  const newCodec = SubscriptionLinkCodec();
  var hadError = false;

  for (final inputPath in args) {
    final inFile = File(inputPath);
    if (!await inFile.exists()) {
      stderr.writeln('skip: file not found: $inputPath');
      hadError = true;
      continue;
    }

    final raw = await inFile.readAsString();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      stderr.writeln('skip: $inputPath: invalid JSON: ${e.message}');
      hadError = true;
      continue;
    }
    if (decoded is! Map) {
      stderr.writeln('skip: $inputPath: root is not a JSON object');
      hadError = true;
      continue;
    }
    final root = Map<String, dynamic>.from(decoded);

    final originalFormat = root['format'];
    if (originalFormat != 'voidtunnel.profile' &&
        originalFormat != 'voidlex.profile') {
      stderr.writeln(
        'skip: $inputPath: unexpected format "$originalFormat" '
        '(expected voidtunnel.profile or voidlex.profile)',
      );
      hadError = true;
      continue;
    }
    root['format'] = 'voidlex.profile';

    final profileRaw = root['profile'];
    if (profileRaw is! Map) {
      stderr.writeln('skip: $inputPath: "profile" is not an object');
      hadError = true;
      continue;
    }
    final profile = Map<String, dynamic>.from(profileRaw);

    final protectedRaw = profile['protectedSubscriptions'];
    var migratedCount = 0;
    var preservedCount = 0;
    var failedCount = 0;
    if (protectedRaw is List) {
      final migrated = <String>[];
      for (final entry in protectedRaw) {
        if (entry is! String) {
          stderr.writeln(
            '  warn: non-string entry in protectedSubscriptions, dropped',
          );
          failedCount++;
          continue;
        }
        final trimmed = entry.trim();
        if (trimmed.startsWith('voidlex://')) {
          migrated.add(trimmed);
          preservedCount++;
          continue;
        }
        if (!trimmed.startsWith('voidtunnel://')) {
          stderr.writeln(
            '  warn: unknown subscription scheme in "$trimmed", left as-is',
          );
          migrated.add(trimmed);
          preservedCount++;
          continue;
        }
        try {
          final decodedLink = await oldCodec.decode(trimmed);
          final reEncoded = await newCodec.encode(
            url: decodedLink.url,
            name: decodedLink.name,
          );
          migrated.add(reEncoded);
          migratedCount++;
        } on _LegacyCodecException catch (e) {
          stderr.writeln(
            '  error: failed to decrypt legacy subscription: ${e.message}',
          );
          failedCount++;
        }
      }
      profile['protectedSubscriptions'] = migrated;
    }

    root['profile'] = profile;

    final outputPath = _deriveOutputPath(inputPath);
    final encoder = const JsonEncoder.withIndent('  ');
    await File(outputPath).writeAsString('${encoder.convert(root)}\n');

    stdout.writeln(
      'wrote $outputPath '
      '(migrated=$migratedCount preserved=$preservedCount '
      'failed=$failedCount)',
    );
    if (failedCount > 0) hadError = true;
  }

  return hadError ? 1 : 0;
}

String _deriveOutputPath(String input) {
  final lastSlash = input.lastIndexOf(RegExp(r'[\\/]'));
  final dir = lastSlash < 0 ? '' : input.substring(0, lastSlash + 1);
  final name = lastSlash < 0 ? input : input.substring(lastSlash + 1);
  if (name.contains('voidtunnel')) {
    return '$dir${name.replaceFirst('voidtunnel', 'voidlex')}';
  }
  if (name.toLowerCase().endsWith('.json')) {
    return '$dir${name.substring(0, name.length - 5)}.voidlex.json';
  }
  return '$input.voidlex';
}

// ----------------------------------------------------------------------------
// Legacy codec — bit-for-bit reproduction of the pre-rename
// SubscriptionLinkCodec that produced the `voidtunnel://1/...` codes inside
// these JSON exports. Only used for decryption during migration.
// ----------------------------------------------------------------------------

class _LegacyDecodedLink {
  const _LegacyDecodedLink({required this.url, this.name});
  final String url;
  final String? name;
}

class _LegacyCodecException implements Exception {
  const _LegacyCodecException(this.message);
  final String message;
  @override
  String toString() => '_LegacyCodecException: $message';
}

class _LegacyVoidtunnelCodec {
  static const String _scheme = 'voidtunnel';
  static const int _currentVersion = 1;
  static const List<int> _magic = [0x56, 0x54, 0x4E, 0x31]; // "VTN1"
  static const int _flagHasName = 0x01;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const String _hkdfInfo = 'voidtunnel.subscription.v1';
  static const List<int> _appSecret = <int>[
    0x9A, 0xC3, 0xE1, 0x4F, 0x77, 0x2B, 0xD8, 0x05,
    0x68, 0xA1, 0x10, 0xEE, 0x3C, 0xB9, 0x52, 0x6D,
    0x4F, 0x1E, 0x8A, 0x73, 0x29, 0xC0, 0x5B, 0xF4,
    0x84, 0x17, 0xD2, 0x66, 0x9B, 0x3D, 0xAE, 0x21,
  ];

  static final AesGcm _aead = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<_LegacyDecodedLink> decode(String linkOrCode) async {
    final trimmed = linkOrCode.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.toLowerCase() != _scheme) {
      throw const _LegacyCodecException('not a voidtunnel:// URI');
    }

    final raw = StringBuffer();
    if (uri.host.isNotEmpty) raw.write(uri.host);
    if (uri.path.isNotEmpty) {
      if (raw.isNotEmpty && !uri.path.startsWith('/')) raw.write('/');
      raw.write(uri.path);
    }
    final segments = raw
        .toString()
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (segments.length < 2) {
      throw const _LegacyCodecException('missing version or payload segment');
    }
    final version = int.tryParse(segments[0]);
    if (version != _currentVersion) {
      throw _LegacyCodecException(
        'unsupported subscription link version: $version',
      );
    }

    final Uint8List blob;
    try {
      blob = _base64UrlDecode(segments[1]);
    } on FormatException catch (e) {
      throw _LegacyCodecException('bad base64: ${e.message}');
    }

    const headerLen = 4 + 1 + 1;
    const minLen = headerLen + _saltLength + _nonceLength + 16;
    if (blob.length < minLen) {
      throw const _LegacyCodecException('payload too short');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (blob[i] != _magic[i]) {
        throw const _LegacyCodecException('magic mismatch (expected VTN1)');
      }
    }
    if (blob[4] != _currentVersion) {
      throw _LegacyCodecException('unsupported payload version: ${blob[4]}');
    }
    final flags = blob[5];

    var offset = headerLen;
    final salt = blob.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final nonce = blob.sublist(offset, offset + _nonceLength);
    offset += _nonceLength;
    final cipherEnd = blob.length - 16;
    final cipherText = blob.sublist(offset, cipherEnd);
    final tag = blob.sublist(cipherEnd);

    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(_appSecret),
      nonce: salt,
      info: utf8.encode(_hkdfInfo),
    );
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));

    final List<int> plaintext;
    try {
      plaintext = await _aead.decrypt(secretBox, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const _LegacyCodecException(
        'authentication failed — payload was not encrypted with the legacy '
        'voidtunnel app secret',
      );
    }

    return _unpackPlaintext(plaintext, hasName: (flags & _flagHasName) != 0);
  }

  _LegacyDecodedLink _unpackPlaintext(
    List<int> plaintext, {
    required bool hasName,
  }) {
    var offset = 0;

    int readVarint() {
      var result = 0;
      var shift = 0;
      while (true) {
        if (offset >= plaintext.length) {
          throw const _LegacyCodecException('truncated varint');
        }
        final b = plaintext[offset++];
        result |= (b & 0x7F) << shift;
        if ((b & 0x80) == 0) return result;
        shift += 7;
        if (shift > 63) {
          throw const _LegacyCodecException('varint too large');
        }
      }
    }

    Uint8List takeBytes(int length) {
      if (length < 0 || offset + length > plaintext.length) {
        throw const _LegacyCodecException('truncated payload');
      }
      final out = Uint8List.fromList(
        plaintext.sublist(offset, offset + length),
      );
      offset += length;
      return out;
    }

    final urlLen = readVarint();
    final urlBytes = takeBytes(urlLen);
    final url = utf8.decode(urlBytes);
    if (url.isEmpty) {
      throw const _LegacyCodecException('URL is empty');
    }
    String? name;
    if (hasName && offset < plaintext.length) {
      final nameLen = readVarint();
      final nameBytes = takeBytes(nameLen);
      name = utf8.decode(nameBytes);
      if (name.isEmpty) name = null;
    }
    return _LegacyDecodedLink(url: url, name: name);
  }

  Uint8List _base64UrlDecode(String input) {
    final padded = input.padRight(
      input.length + (4 - input.length % 4) % 4,
      '=',
    );
    return base64Url.decode(padded);
  }
}
