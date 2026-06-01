import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Result of decoding a `voidlex://1/...` blob: the original subscription
/// URL and the optional human-readable name that was packed into it.
class DecodedSubscriptionLink {
  const DecodedSubscriptionLink({required this.url, this.name});

  final String url;
  final String? name;
}

enum SubscriptionLinkError {
  notALink,
  malformed,
  unsupportedVersion,
  authentication,
}

class SubscriptionLinkException implements Exception {
  const SubscriptionLinkException(this.code, this.message);

  final SubscriptionLinkError code;
  final String message;

  @override
  String toString() => 'SubscriptionLinkException($code): $message';
}

/// Encodes/decodes encrypted subscription codes of the form
/// `voidlex://1/<base64url(payload)>`.
///
/// The encryption is intentionally **obfuscation-grade**: the master key is
/// baked into the app source, so anyone with the APK can derive it. The goal
/// is to keep subscription URLs out of plain-text profile backups and shared
/// strings, not to defeat reverse-engineering.
///
/// Payload binary layout (all multi-byte fields are big-endian where
/// applicable; varints use unsigned LEB128):
///
///   magic     : 4 bytes  "VLX1"
///   version   : 1 byte   0x01
///   flags     : 1 byte   bit0 = hasName
///   salt      : 16 bytes (random per encode, fed to HKDF)
///   nonce     : 12 bytes (random per encode, fed to AES-GCM)
///   ciphertext + 16-byte GCM tag
///
/// Plaintext inside the AEAD:
///   varint(urlLen) || urlUtf8 || [varint(nameLen) || nameUtf8]
class SubscriptionLinkCodec {
  const SubscriptionLinkCodec();

  static const String scheme = 'voidlex';
  static const int _currentVersion = 1;
  static const String _versionPath = '1';
  static const List<int> _magic = [0x56, 0x4C, 0x58, 0x31]; // "VLX1"
  static const int _flagHasName = 0x01;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const String _hkdfInfo = 'voidlex.subscription.v1';

  // App-baked master secret. Generated once for VoidLex; treat it as a
  // fixed-but-private constant. Rotating it would invalidate all previously
  // shared codes, so don't change it casually — bump the version byte and
  // route through a multi-key decoder if a rotation is ever needed.
  static const List<int> _appSecret = <int>[
    0x9A, 0xC3, 0xE1, 0x4F, 0x77, 0x2B, 0xD8, 0x05,
    0x68, 0xA1, 0x10, 0xEE, 0x3C, 0xB9, 0x52, 0x6D,
    0x4F, 0x1E, 0x8A, 0x73, 0x29, 0xC0, 0x5B, 0xF4,
    0x84, 0x17, 0xD2, 0x66, 0x9B, 0x3D, 0xAE, 0x21,
  ];

  static final AesGcm _aead = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final Random _random = Random.secure();

  /// True when [raw] looks like a `voidlex://...` URL. Cheap check; does not
  /// validate the payload.
  static bool looksLikeLink(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length < scheme.length + 3) return false;
    return trimmed.toLowerCase().startsWith('$scheme://');
  }

  /// Encrypts [url] (+ optional [name]) and returns a `voidlex://1/...`
  /// string. `salt` and `nonce` parameters are exposed for deterministic
  /// testing only — production callers should leave them null so fresh random
  /// values are used.
  Future<String> encode({
    required String url,
    String? name,
    List<int>? salt,
    List<int>? nonce,
  }) async {
    if (url.isEmpty) {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'URL is empty',
      );
    }
    final saltBytes = _ensureRandomBytes(salt, _saltLength);
    final nonceBytes = _ensureRandomBytes(nonce, _nonceLength);
    final key = await _deriveKey(saltBytes);

    final plaintext = _packPlaintext(url: url, name: name);
    final secretBox = await _aead.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonceBytes,
    );

    final flags = (name != null && name.isNotEmpty) ? _flagHasName : 0;
    final payload = BytesBuilder(copy: false)
      ..add(_magic)
      ..addByte(_currentVersion)
      ..addByte(flags)
      ..add(saltBytes)
      ..add(nonceBytes)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);

    return '$scheme://$_versionPath/${_base64UrlNoPad(payload.toBytes())}';
  }

  /// Decodes a `voidlex://1/...` string back to [DecodedSubscriptionLink].
  /// Throws [SubscriptionLinkException] on any malformed input, unknown
  /// version, or authentication failure.
  Future<DecodedSubscriptionLink> decode(String linkOrCode) async {
    final trimmed = linkOrCode.trim();
    if (!looksLikeLink(trimmed)) {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.notALink,
        'Not a voidlex:// link',
      );
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.toLowerCase() != scheme) {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'Cannot parse URI',
      );
    }

    // Both `voidlex://1/abc...` and `voidlex:1/abc...` end up with the
    // version as the first segment and the base64url payload as the second.
    // Reassemble from `host + path` to be tolerant of either form.
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
      throw const SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'Missing version or payload segment',
      );
    }
    final version = int.tryParse(segments[0]);
    if (version == null) {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'Version segment is not an integer',
      );
    }
    if (version != _currentVersion) {
      throw SubscriptionLinkException(
        SubscriptionLinkError.unsupportedVersion,
        'Unsupported subscription link version: $version',
      );
    }

    final Uint8List blob;
    try {
      blob = _base64UrlDecode(segments[1]);
    } on FormatException catch (e) {
      throw SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'Bad base64: ${e.message}',
      );
    }

    const headerLen = 4 /*magic*/ + 1 /*ver*/ + 1 /*flags*/;
    const minLen = headerLen + _saltLength + _nonceLength + 16 /*GCM tag*/;
    if (blob.length < minLen) {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'Payload too short',
      );
    }
    for (var i = 0; i < _magic.length; i++) {
      if (blob[i] != _magic[i]) {
        throw const SubscriptionLinkException(
          SubscriptionLinkError.malformed,
          'Magic mismatch',
        );
      }
    }
    if (blob[4] != _currentVersion) {
      throw SubscriptionLinkException(
        SubscriptionLinkError.unsupportedVersion,
        'Unsupported payload version: ${blob[4]}',
      );
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

    final key = await _deriveKey(salt);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));

    final List<int> plaintext;
    try {
      plaintext = await _aead.decrypt(secretBox, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.authentication,
        'Authentication failed — corrupted or foreign code',
      );
    }

    return _unpackPlaintext(plaintext, hasName: (flags & _flagHasName) != 0);
  }

  Future<SecretKey> _deriveKey(List<int> salt) {
    return _hkdf.deriveKey(
      secretKey: SecretKey(_appSecret),
      nonce: salt,
      info: utf8.encode(_hkdfInfo),
    );
  }

  Uint8List _packPlaintext({required String url, String? name}) {
    final builder = BytesBuilder(copy: false);
    final urlBytes = utf8.encode(url);
    _writeVarint(builder, urlBytes.length);
    builder.add(urlBytes);
    if (name != null && name.isNotEmpty) {
      final nameBytes = utf8.encode(name);
      _writeVarint(builder, nameBytes.length);
      builder.add(nameBytes);
    }
    return builder.toBytes();
  }

  DecodedSubscriptionLink _unpackPlaintext(
    List<int> plaintext, {
    required bool hasName,
  }) {
    final reader = _VarintReader(plaintext);
    final urlLen = reader.readVarint();
    final urlBytes = reader.takeBytes(urlLen);
    String url;
    try {
      url = utf8.decode(urlBytes);
    } on FormatException {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'URL is not valid UTF-8',
      );
    }
    if (url.isEmpty) {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'URL is empty',
      );
    }
    String? name;
    if (hasName && reader.hasMore) {
      final nameLen = reader.readVarint();
      final nameBytes = reader.takeBytes(nameLen);
      try {
        name = utf8.decode(nameBytes);
      } on FormatException {
        throw const SubscriptionLinkException(
          SubscriptionLinkError.malformed,
          'Name is not valid UTF-8',
        );
      }
      if (name.isEmpty) name = null;
    }
    return DecodedSubscriptionLink(url: url, name: name);
  }

  Uint8List _ensureRandomBytes(List<int>? supplied, int length) {
    if (supplied != null) {
      if (supplied.length != length) {
        throw ArgumentError(
          'Expected $length bytes, got ${supplied.length}',
        );
      }
      return Uint8List.fromList(supplied);
    }
    final result = Uint8List(length);
    for (var i = 0; i < length; i++) {
      result[i] = _random.nextInt(256);
    }
    return result;
  }

  String _base64UrlNoPad(List<int> bytes) {
    final encoded = base64UrlEncode(bytes);
    final eq = encoded.indexOf('=');
    return eq < 0 ? encoded : encoded.substring(0, eq);
  }

  Uint8List _base64UrlDecode(String input) {
    final padded = input.padRight(input.length + (4 - input.length % 4) % 4, '=');
    return base64Url.decode(padded);
  }

  static void _writeVarint(BytesBuilder out, int value) {
    if (value < 0) {
      throw ArgumentError('Varint values must be non-negative');
    }
    var v = value;
    while (v >= 0x80) {
      out.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    out.addByte(v & 0x7F);
  }
}

class _VarintReader {
  _VarintReader(this._bytes);

  final List<int> _bytes;
  int _offset = 0;

  bool get hasMore => _offset < _bytes.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_offset >= _bytes.length) {
        throw const SubscriptionLinkException(
          SubscriptionLinkError.malformed,
          'Truncated varint',
        );
      }
      final b = _bytes[_offset++];
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) return result;
      shift += 7;
      if (shift > 63) {
        throw const SubscriptionLinkException(
          SubscriptionLinkError.malformed,
          'Varint too large',
        );
      }
    }
  }

  Uint8List takeBytes(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw const SubscriptionLinkException(
        SubscriptionLinkError.malformed,
        'Truncated payload',
      );
    }
    final result = Uint8List.fromList(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return result;
  }
}
