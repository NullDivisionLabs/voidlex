import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_config_exporter.dart';
import 'package:voidlex/core/server_importer.dart';
import 'package:voidlex/core/tun_engine_mode.dart';

void main() {
  test('VLESS advanced fields survive storage and feed Xray export', () {
    final original = _base(
      security: VlessSecurity.reality,
      flow: 'xtls-rprx-vision',
      vlessEncryption: 'mlkem768x25519plus',
      realitySpiderX: '/crawler',
      realityMldsa65Verify: 'verify-key',
    );

    final restored = ServerConfig.decodeList(
      ServerConfig.encodeList([original]),
    ).single;
    expect(restored.toJson(), original.toJson());

    final args = restored.toNativeArgs(
      isGlobalProxy: true,
      tunEngineMode: TunEngineMode.libbox,
    );
    expect(args['flow'], 'xtls-rprx-vision');
    expect(args['vlessEncryption'], 'mlkem768x25519plus');
    expect(args['spx'], '/crawler');
    expect(args['mldsa65Verify'], 'verify-key');

    final exported =
        jsonDecode(ServerConfigExporter.toXrayJson(restored))
            as Map<String, dynamic>;
    final outbound =
        (exported['outbounds'] as List).first as Map<String, dynamic>;
    final vnext = ((outbound['settings'] as Map)['vnext'] as List).first as Map;
    final user = (vnext['users'] as List).first as Map;
    expect(user['flow'], 'xtls-rprx-vision');
    expect(user['encryption'], 'mlkem768x25519plus');
    final reality =
        ((outbound['streamSettings'] as Map)['realitySettings'] as Map);
    expect(reality['spiderX'], '/crawler');
    expect(reality['mldsa65Verify'], 'verify-key');

    final url = ServerConfigExporter.toServerUrl(restored);
    expect(url, contains('flow=xtls-rprx-vision'));
    expect(url, contains('encryption=mlkem768x25519plus'));
    expect(url, contains('spx=%2Fcrawler'));
    expect(url, isNot(contains('mldsa65Verify')));
  });

  test('Hysteria2 advanced fields round-trip through sing-box JSON', () {
    final original = _base(
      protocol: ServerProtocol.hysteria2,
      security: VlessSecurity.tls,
      hysteria2ObfsType: 'gecko',
      hysteria2ObfsPassword: 'mask',
      hysteria2ObfsMinPacketSize: 512,
      hysteria2ObfsMaxPacketSize: 1200,
      hysteria2HopPorts: '443,8443-8445',
      hysteria2HopInterval: '20s',
      hysteria2HopIntervalMax: '40s',
      hysteria2UpMbps: 50,
      hysteria2DownMbps: 200,
      hysteria2Network: 'udp',
      hysteria2BbrProfile: 'aggressive',
    );

    final json = ServerConfigExporter.toXrayJson(original);
    final outbound =
        ((jsonDecode(json) as Map<String, dynamic>)['outbounds'] as List).first
            as Map<String, dynamic>;
    expect((outbound['obfs'] as Map)['type'], 'gecko');
    expect((outbound['obfs'] as Map)['min_packet_size'], 512);
    expect(outbound['hop_interval_max'], '40s');
    expect(outbound['up_mbps'], 50);
    expect(outbound['network'], 'udp');
    expect(outbound['bbr_profile'], 'aggressive');

    final restored = const ServerImporter().parse(json).configs.single;
    expect(restored.hysteria2ObfsType, 'gecko');
    expect(restored.hysteria2ObfsMaxPacketSize, 1200);
    expect(restored.hysteria2HopInterval, '20s');
    expect(restored.hysteria2DownMbps, 200);

    final url = ServerConfigExporter.toServerUrl(original);
    expect(url, contains('obfs=gecko'));
    expect(url, isNot(contains('up_mbps')));
  });

  test('Naive advanced fields round-trip through sing-box JSON only', () {
    final original = _base(
      protocol: ServerProtocol.naive,
      security: VlessSecurity.tls,
      naiveInsecureConcurrency: 4,
      naiveExtraHeaders: const {'X-Edge': 'void', 'Accept-Language': 'en'},
      naiveUdpOverTcp: true,
      naiveUdpOverTcpVersion: 2,
    );

    final json = ServerConfigExporter.toXrayJson(original);
    final outbound =
        ((jsonDecode(json) as Map<String, dynamic>)['outbounds'] as List).first
            as Map<String, dynamic>;
    expect(outbound['insecure_concurrency'], 4);
    expect((outbound['extra_headers'] as Map)['X-Edge'], 'void');
    expect((outbound['udp_over_tcp'] as Map)['version'], 2);

    final restored = const ServerImporter().parse(json).configs.single;
    expect(restored.naiveInsecureConcurrency, 4);
    expect(restored.naiveExtraHeaders['Accept-Language'], 'en');
    expect(restored.naiveUdpOverTcp, isTrue);
    expect(restored.naiveUdpOverTcpVersion, 2);

    final url = ServerConfigExporter.toServerUrl(original);
    expect(url, isNot(contains('insecure_concurrency')));
    expect(url, isNot(contains('extra_headers')));
  });

  test('Naive TLS insecure round-trips through sing-box JSON', () {
    final original = _base(
      protocol: ServerProtocol.naive,
      security: VlessSecurity.tls,
      tlsInsecure: true,
    );

    final json = ServerConfigExporter.toXrayJson(original);
    final outbound =
        ((jsonDecode(json) as Map<String, dynamic>)['outbounds'] as List).first
            as Map<String, dynamic>;
    expect((outbound['tls'] as Map)['insecure'], isTrue);

    final restored = const ServerImporter().parse(json).configs.single;
    expect(restored.tlsInsecure, isTrue);
  });
}

ServerConfig _base({
  ServerProtocol protocol = ServerProtocol.vless,
  VlessSecurity security = VlessSecurity.none,
  String flow = '',
  String vlessEncryption = '',
  String realitySpiderX = '',
  String realityMldsa65Verify = '',
  String hysteria2ObfsType = '',
  String hysteria2ObfsPassword = '',
  int hysteria2ObfsMinPacketSize = 0,
  int hysteria2ObfsMaxPacketSize = 0,
  String hysteria2HopPorts = '',
  String hysteria2HopInterval = '',
  String hysteria2HopIntervalMax = '',
  int hysteria2UpMbps = 0,
  int hysteria2DownMbps = 0,
  String hysteria2Network = '',
  String hysteria2BbrProfile = '',
  int naiveInsecureConcurrency = 0,
  Map<String, String> naiveExtraHeaders = const {},
  bool naiveUdpOverTcp = false,
  int naiveUdpOverTcpVersion = 0,
  bool tlsInsecure = false,
}) {
  return ServerConfig(
    name: 'Advanced',
    address: 'example.com',
    port: 443,
    uuid: protocol == ServerProtocol.naive
        ? ''
        : 'f1cba4a1-1f16-4176-9c71-d7508ccd4db1',
    transport: VlessTransport.tcp,
    security: security,
    serverProtocol: protocol,
    flow: flow,
    vlessEncryption: vlessEncryption,
    realitySpiderX: realitySpiderX,
    realityMldsa65Verify: realityMldsa65Verify,
    hysteria2ObfsType: hysteria2ObfsType,
    hysteria2ObfsPassword: hysteria2ObfsPassword,
    hysteria2ObfsMinPacketSize: hysteria2ObfsMinPacketSize,
    hysteria2ObfsMaxPacketSize: hysteria2ObfsMaxPacketSize,
    hysteria2HopPorts: hysteria2HopPorts,
    hysteria2HopInterval: hysteria2HopInterval,
    hysteria2HopIntervalMax: hysteria2HopIntervalMax,
    hysteria2UpMbps: hysteria2UpMbps,
    hysteria2DownMbps: hysteria2DownMbps,
    hysteria2Network: hysteria2Network,
    hysteria2BbrProfile: hysteria2BbrProfile,
    naiveInsecureConcurrency: naiveInsecureConcurrency,
    naiveExtraHeaders: naiveExtraHeaders,
    naiveUdpOverTcp: naiveUdpOverTcp,
    naiveUdpOverTcpVersion: naiveUdpOverTcpVersion,
    tlsInsecure: tlsInsecure,
  );
}
