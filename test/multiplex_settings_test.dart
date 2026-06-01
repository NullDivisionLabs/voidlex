import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/multiplex_settings.dart';

void main() {
  test('exports multiplex settings for native Xray mux', () {
    final args = const MultiplexSettings(
      enabled: true,
      tcpConnections: 16,
      xudpConnections: -1,
      quicBehavior: MultiplexQuicBehavior.passthrough,
    ).toNativeArgs();

    expect(args['muxEnabled'], isTrue);
    expect(args['muxTcpConcurrency'], 16);
    expect(args['muxXudpConcurrency'], -1);
    expect(args['muxQuicBehavior'], 'skip');
  });

  test('normalizes connection bounds and quic behavior', () {
    final settings = MultiplexSettings.decode(
      jsonEncode({
        'enabled': true,
        'tcpConnections': 1024,
        'xudpConnections': 2048,
        'quicBehavior': 'passthrough',
      }),
    );

    expect(settings.tcpConnections, MultiplexSettings.maxTcpConnections);
    expect(settings.xudpConnections, MultiplexSettings.maxXudpConnections);
    expect(settings.quicBehavior, MultiplexQuicBehavior.passthrough);
  });
}
