import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/server_latency_probe.dart';

void main() {
  group('LatencyProbeTarget', () {
    test('empty input keeps the per-node endpoint', () {
      final target = LatencyProbeTarget.tryParse('')!;
      expect(target.usesServerEndpoint, isTrue);
      expect(target.encode(), isEmpty);
    });

    test('parses host, host:port, and URL inputs', () {
      expect(
        LatencyProbeTarget.tryParse('example.com')?.encode(),
        'example.com:443',
      );
      expect(
        LatencyProbeTarget.tryParse('example.com:8443')?.encode(),
        'example.com:8443',
      );
      expect(
        LatencyProbeTarget.tryParse('http://example.com')?.encode(),
        'example.com:80',
      );
    });

    test('rejects invalid custom targets', () {
      expect(LatencyProbeTarget.tryParse('http://'), isNull);
      expect(LatencyProbeTarget.tryParse('example.com:70000'), isNull);
      expect(LatencyProbeTarget.tryParse('mailto:user@example.com'), isNull);
    });

    test('rejects targets carrying userinfo, path, query or fragment', () {
      // Without these checks, the fallback "tcp://$value" prepend would let
      // an "@" silently reinterpret the input as just the host after it.
      expect(LatencyProbeTarget.tryParse('user@example.com'), isNull);
      expect(LatencyProbeTarget.tryParse('user:pass@example.com'), isNull);
      expect(LatencyProbeTarget.tryParse('http://example.com/path'), isNull);
      expect(LatencyProbeTarget.tryParse('http://example.com?q=1'), isNull);
      expect(LatencyProbeTarget.tryParse('http://example.com#frag'), isNull);
    });

    test('rejects a trailing colon with no port', () {
      expect(LatencyProbeTarget.tryParse('example.com:'), isNull);
      expect(LatencyProbeTarget.tryParse('http://example.com:'), isNull);
    });

    test('keeps custom target values accessible for settings', () {
      final target = LatencyProbeTarget.tryParse('example.com:2053')!;
      expect(target.host, 'example.com');
      expect(target.port, 2053);
    });
  });
}
