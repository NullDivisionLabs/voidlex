import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/server_latency_probe.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/tls_fingerprints.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('URL requires a complete HTTP(S) target', () {
    expect(
      UrlProbeTarget.normalize(' http://cp.cloudflare.com '),
      UrlProbeTarget.defaultUrl,
    );
    expect(
      UrlProbeTarget.normalize('https://example.com/check?q=1'),
      'https://example.com/check?q=1',
    );
    for (final invalid in [
      '',
      'example.com',
      'tcp://example.com',
      'http://user:password@example.com/',
      'https://example.com/#x',
      'http://example.com:0/',
      'https://example.com:65536/',
    ]) {
      expect(UrlProbeTarget.normalize(invalid), isNull, reason: invalid);
    }
  });

  test('default requires 204; custom URLs accept only 2xx', () {
    final standard = Uri.parse(UrlProbeTarget.defaultUrl);
    final custom = Uri.parse('https://example.com/health');
    expect(UrlProbeTarget.accepts(standard, 204), isTrue);
    for (final status in [200, 301, 403, 502]) {
      expect(UrlProbeTarget.accepts(standard, status), isFalse);
    }
    for (final status in [200, 204, 299]) {
      expect(UrlProbeTarget.accepts(custom, status), isTrue);
    }
    for (final status in [199, 300, 301, 407, 502]) {
      expect(UrlProbeTarget.accepts(custom, status), isFalse);
    }
    expect(UrlProbeResult.fromMap({'status': 'ok'}).label, 'ERR');
    expect(const UrlProbeResult('unsupported').label, 'N/A');
  });

  test(
    'new fingerprints are opt-in and existing selections survive hiding',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = ServerRepository(
        await SharedPreferences.getInstance(),
      );
      expect(repository.load().additionalTlsFingerprintsEnabled, isFalse);
      expect(repository.load().urlProbeUrl, UrlProbeTarget.defaultUrl);
      expect(TlsFingerprints.options(additionalEnabled: false), contains(''));
      expect(
        TlsFingerprints.options(additionalEnabled: false),
        isNot(contains('hellosafari_16_0')),
      );
      for (final current in [
        ...TlsFingerprints.additional,
        'imported-profile',
      ]) {
        expect(
          TlsFingerprints.options(additionalEnabled: false, current: current),
          contains(current),
        );
      }
      await repository.saveAdditionalTlsFingerprintsEnabled(true);
      await repository.saveUrlProbeUrl('https://example.com/check');
      expect(repository.load().additionalTlsFingerprintsEnabled, isTrue);
      expect(repository.load().urlProbeUrl, 'https://example.com/check');
      await repository.saveAdditionalTlsFingerprintsEnabled(false);
      expect(repository.load().additionalTlsFingerprintsEnabled, isFalse);
    },
  );

  for (final status in [204, 200, 301, 407, 502]) {
    test(
      'runtime uses proxy and reports HTTP $status without TCP fallback',
      () async {
        final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var count = 0;
        proxy.listen((request) async {
          count++;
          expect(request.method, 'GET');
          expect(request.uri.host, 'cp.cloudflare.com');
          request.response.statusCode = status;
          if (status == 301) {
            request.response.headers.set(
              HttpHeaders.locationHeader,
              'http://cp.cloudflare.com/redirected',
            );
          }
          await request.response.close();
        });
        try {
          final result = await HttpOverrides.runZoned(
            () => const ServerLatencyProbe().measureRuntimeUrl(
              proxyHost: '127.0.0.1',
              proxyPort: proxy.port,
              url: Uri.parse(UrlProbeTarget.defaultUrl),
            ),
            createHttpClient: (context) =>
                _RealHttpOverrides().createHttpClient(context),
          );
          expect(count, 1);
          expect(result.status, status == 204 ? 'ok' : 'error');
          if (status != 204) expect(result.detail, 'HTTP $status');
        } finally {
          await proxy.close(force: true);
        }
      },
    );
  }

  test('active runtime authenticates to the local proxy', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var authorized = false;
    proxy.listen((request) async {
      authorized =
          request.headers.value(HttpHeaders.proxyAuthorizationHeader) != null;
      request.response.statusCode = authorized ? 204 : 407;
      if (!authorized) {
        request.response.headers.set(
          HttpHeaders.proxyAuthenticateHeader,
          'Basic realm="Xray"',
        );
      }
      await request.response.close();
    });
    try {
      final result = await HttpOverrides.runZoned(
        () => const ServerLatencyProbe().measureRuntimeUrl(
          proxyHost: '127.0.0.1',
          proxyPort: proxy.port,
          proxyUser: 'user',
          proxyPassword: 'password',
          url: Uri.parse(UrlProbeTarget.defaultUrl),
        ),
        createHttpClient: (context) =>
            _RealHttpOverrides().createHttpClient(context),
      );
      expect(authorized, isTrue);
      expect(result.status, 'ok');
    } finally {
      await proxy.close(force: true);
    }
  });

  test('runtime bounds the whole response, including a stalled body', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    proxy.listen((request) async {
      request.response.statusCode = 200;
      request.response.contentLength = 100;
      request.response.write('x');
      await request.response.flush();
    });
    final watch = Stopwatch()..start();
    try {
      final result = await HttpOverrides.runZoned(
        () => const ServerLatencyProbe().measureRuntimeUrl(
          proxyHost: '127.0.0.1',
          proxyPort: proxy.port,
          url: Uri.parse('http://example.com/health'),
        ),
        createHttpClient: (context) =>
            _RealHttpOverrides().createHttpClient(context),
      );
      expect(result.status, 'timeout');
      expect(watch.elapsedMilliseconds, lessThan(4500));
    } finally {
      await proxy.close(force: true);
    }
  });
}

class _RealHttpOverrides extends HttpOverrides {}
