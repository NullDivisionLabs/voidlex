import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/tunnel_network_settings.dart';

void main() {
  test('exports tunnel network settings for native runtime', () {
    final args = const TunnelNetworkSettings(
      useLocalDns: true,
      serverResolvingEnabled: true,
      packetAnalysisEnabled: false,
      blockUdp: true,
      networkStack: TunnelNetworkStack.gvisor,
      mtu: 1500,
      ipMode: TunnelIpMode.mixed,
      xrayTunDnsEnabled: true,
      xrayTunDnsServer: '9.9.9.9',
    ).toNativeArgs();

    expect(args['useLocalDns'], isTrue);
    expect(args['serverResolvingEnabled'], isTrue);
    expect(args['packetAnalysisEnabled'], isFalse);
    expect(args['blockUdp'], isTrue);
    expect(args['networkStack'], 'gvisor');
    expect(args['tunMtu'], 1500);
    expect(args['ipMode'], 'mixed');
    expect(args['xrayTunDnsEnabled'], isTrue);
    expect(args['xrayTunDnsServer'], '9.9.9.9');
  });

  test('decodes stored tunnel network settings', () {
    final settings = TunnelNetworkSettings.decode(
      jsonEncode({
        'useLocalDns': true,
        'serverResolvingEnabled': true,
        'packetAnalysisEnabled': false,
        'blockUdp': true,
        'networkStack': 'mixed',
        'mtu': 12000,
        'ipMode': 'ipv6',
        'xrayTunDnsEnabled': true,
        'xrayTunDnsServer': '  8.8.8.8 ',
      }),
    );

    expect(settings.useLocalDns, isTrue);
    expect(settings.serverResolvingEnabled, isTrue);
    expect(settings.packetAnalysisEnabled, isFalse);
    expect(settings.blockUdp, isTrue);
    expect(settings.networkStack, TunnelNetworkStack.mixed);
    expect(settings.mtu, TunnelNetworkSettings.maxMtu);
    expect(settings.ipMode, TunnelIpMode.ipv6);
    expect(settings.xrayTunDnsEnabled, isTrue);
    expect(settings.xrayTunDnsServer, '8.8.8.8');
    expect(settings.hasCustomXrayTunDns, isTrue);
  });

  test('uses requested defaults for mtu and ip mode', () {
    const settings = TunnelNetworkSettings.defaults;

    expect(settings.networkStack, TunnelNetworkStack.system);
    expect(settings.blockUdp, isFalse);
    expect(settings.mtu, 1500);
    expect(settings.ipMode, TunnelIpMode.ipv4);
    expect(settings.xrayTunDnsEnabled, isFalse);
    expect(settings.xrayTunDnsServer, '1.1.1.1');
    expect(settings.hasCustomXrayTunDns, isFalse);
  });

  test('normalizes blank xray TUN DNS to default', () {
    final settings = const TunnelNetworkSettings(
      xrayTunDnsEnabled: true,
      xrayTunDnsServer: '   ',
    ).normalized();

    expect(settings.xrayTunDnsServer, '1.1.1.1');
    expect(settings.hasCustomXrayTunDns, isTrue);
  });
}
