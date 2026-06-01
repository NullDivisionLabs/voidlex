import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/subscription_link_codec.dart';

void main() {
  const codec = SubscriptionLinkCodec();

  test('looksLikeLink recognises voidlex scheme', () {
    expect(SubscriptionLinkCodec.looksLikeLink('voidlex://1/abc'), isTrue);
    expect(SubscriptionLinkCodec.looksLikeLink('VOIDLEX://1/abc'), isTrue);
    expect(SubscriptionLinkCodec.looksLikeLink('  voidlex://1/abc  '), isTrue);
    expect(SubscriptionLinkCodec.looksLikeLink('https://example.com'), isFalse);
    expect(SubscriptionLinkCodec.looksLikeLink(''), isFalse);
  });

  test('round-trip with name', () async {
    final link = await codec.encode(
      url: 'https://provider.example.com/sub?u=1',
      name: 'My Provider',
    );
    expect(link, startsWith('voidlex://1/'));
    final decoded = await codec.decode(link);
    expect(decoded.url, 'https://provider.example.com/sub?u=1');
    expect(decoded.name, 'My Provider');
  });

  test('round-trip without name', () async {
    final link = await codec.encode(url: 'https://example.com/sub');
    final decoded = await codec.decode(link);
    expect(decoded.url, 'https://example.com/sub');
    expect(decoded.name, isNull);
  });

  test('same input produces different output (random salt + nonce)', () async {
    final a = await codec.encode(url: 'https://example.com/sub');
    final b = await codec.encode(url: 'https://example.com/sub');
    expect(a, isNot(equals(b)));
    // But both decode to the same thing.
    expect((await codec.decode(a)).url, (await codec.decode(b)).url);
  });

  test('survives long URL', () async {
    final big = 'https://example.com/sub?token=${'A' * 2048}';
    final link = await codec.encode(url: big, name: 'Big');
    final decoded = await codec.decode(link);
    expect(decoded.url, big);
    expect(decoded.name, 'Big');
  });

  test('handles unicode in name', () async {
    final link = await codec.encode(
      url: 'https://example.com/sub',
      name: 'Провайдер №1 🔐',
    );
    final decoded = await codec.decode(link);
    expect(decoded.name, 'Провайдер №1 🔐');
  });

  test('rejects non-voidlex strings as notALink', () async {
    await expectLater(
      codec.decode('https://example.com'),
      throwsA(
        isA<SubscriptionLinkException>().having(
          (e) => e.code,
          'code',
          SubscriptionLinkError.notALink,
        ),
      ),
    );
  });

  test('rejects malformed base64 payload', () async {
    await expectLater(
      codec.decode('voidlex://1/!@#not-base64'),
      throwsA(
        isA<SubscriptionLinkException>().having(
          (e) => e.code,
          'code',
          anyOf(
            SubscriptionLinkError.malformed,
            SubscriptionLinkError.authentication,
          ),
        ),
      ),
    );
  });

  test('rejects truncated payload', () async {
    await expectLater(
      codec.decode('voidlex://1/${base64UrlEncode([1, 2, 3])}'),
      throwsA(
        isA<SubscriptionLinkException>().having(
          (e) => e.code,
          'code',
          SubscriptionLinkError.malformed,
        ),
      ),
    );
  });

  test('rejects unknown version segment', () async {
    final link = await codec.encode(url: 'https://example.com');
    final payload = link.split('/').last;
    final tampered = 'voidlex://99/$payload';
    await expectLater(
      codec.decode(tampered),
      throwsA(
        isA<SubscriptionLinkException>().having(
          (e) => e.code,
          'code',
          SubscriptionLinkError.unsupportedVersion,
        ),
      ),
    );
  });

  test('rejects tampered ciphertext with authentication error', () async {
    final link = await codec.encode(url: 'https://example.com/sub');
    final payload = link.split('/').last;
    // Flip a character somewhere in the middle of the base64 blob.
    final mid = payload.length ~/ 2;
    final flipped = payload[mid] == 'A' ? 'B' : 'A';
    final tampered =
        'voidlex://1/${payload.substring(0, mid)}$flipped${payload.substring(mid + 1)}';
    await expectLater(
      codec.decode(tampered),
      throwsA(
        isA<SubscriptionLinkException>().having(
          (e) => e.code,
          'code',
          anyOf(
            SubscriptionLinkError.authentication,
            SubscriptionLinkError.malformed,
          ),
        ),
      ),
    );
  });

  test('rejects empty URL on encode', () async {
    await expectLater(
      codec.encode(url: ''),
      throwsA(isA<SubscriptionLinkException>()),
    );
  });
}
