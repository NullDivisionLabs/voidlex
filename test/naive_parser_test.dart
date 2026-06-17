import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/naive_parser.dart';
import 'package:voidlex/core/server_config_exporter.dart';
import 'package:voidlex/core/server_importer.dart';
import 'package:voidlex/core/server_subscription_importer.dart';
import 'package:voidlex/core/tun_engine_mode.dart';

void main() {
  const parser = NaiveParser();

  group('NaiveParser', () {
    test('parses HTTPS defaults, optional auth, SNI, and percent encoding', () {
      final result = parser.parse(
        'naive+https://user%40mail:p%3Aass@example.com?sni=edge.example.com#Main%20Naive',
      );

      expect(result.isOk, isTrue);
      final config = result.config!;
      expect(config.serverProtocol, ServerProtocol.naive);
      expect(config.address, 'example.com');
      expect(config.port, 443);
      expect(config.naiveUsername, 'user@mail');
      expect(config.naivePassword, 'p:ass');
      expect(config.sni, 'edge.example.com');
      expect(config.name, 'Main Naive');
      expect(config.naiveQuic, isFalse);
      expect(config.naiveQuicCongestionControl, isEmpty);
      expect(config.uuid, isEmpty);
    });

    test('parses QUIC, IPv6, congestion control, and unique name', () {
      final result = parser.parse(
        'naive+quic://[2001:db8::1]:8443?congestion_control=BBR2#Node',
        existingNames: {'Node'},
      );

      expect(result.isOk, isTrue);
      final config = result.config!;
      expect(config.address, '2001:db8::1');
      expect(config.port, 8443);
      expect(config.naiveQuic, isTrue);
      expect(config.naiveQuicCongestionControl, 'bbr2');
      expect(config.name, 'Node (2)');
    });

    test('supports generic scheme modes and scheme takes priority', () {
      expect(parser.parse('naive://example.com').config!.naiveQuic, isFalse);
      expect(
        parser.parse('naive://example.com?mode=quic').config!.naiveQuic,
        isTrue,
      );
      expect(
        parser.parse('naive://example.com?quic=true').config!.naiveQuic,
        isTrue,
      );
      expect(
        parser
            .parse('naive+https://example.com?mode=quic&quic=1')
            .config!
            .naiveQuic,
        isFalse,
      );
      expect(
        parser
            .parse('naive+quic://example.com?mode=https&quic=0')
            .config!
            .naiveQuic,
        isTrue,
      );
    });

    test('reports malformed percent-encoding instead of throwing', () {
      expect(
        parser.parse('naive://example.com?sni=%E0%A4%A').error!.code,
        NaiveParseError.malformedUri,
      );
      // Uri.tryParse normalizes a stray "%" in the fragment to "%25", so
      // this stays importable; the parser must not throw on it.
      final stray = parser.parse('naive://example.com#50%off');
      expect(stray.isOk, isTrue);
      expect(stray.config!.name, '50%off');
    });

    test('reports malformed links and invalid options', () {
      expect(
        parser.parse('https://example.com').error!.code,
        NaiveParseError.notNaiveScheme,
      );
      expect(parser.parse('naive://').error!.code, NaiveParseError.missingHost);
      expect(
        parser.parse('naive://example.com:70000').error!.code,
        NaiveParseError.invalidPort,
      );
      expect(
        parser.parse('naive://example.com?mode=tcp').error!.code,
        NaiveParseError.invalidMode,
      );
      expect(
        parser.parse('naive://example.com?quic=maybe').error!.code,
        NaiveParseError.invalidMode,
      );
      expect(
        parser
            .parse('naive+quic://example.com?congestion_control=vegas')
            .error!
            .code,
        NaiveParseError.invalidCongestionControl,
      );
    });
  });

  group('Naive import and export', () {
    const importer = ServerImporter();

    test('canonical link round-trip preserves Naive fields', () {
      final original = _naiveConfig();
      final link = ServerConfigExporter.toServerUrl(original);

      expect(link, startsWith('naive+quic://'));
      final restored = importer.parse(link).configs.single;
      expect(restored.name, original.name);
      expect(restored.address, original.address);
      expect(restored.port, original.port);
      expect(restored.naiveUsername, original.naiveUsername);
      expect(restored.naivePassword, original.naivePassword);
      expect(restored.sni, original.sni);
      expect(restored.naiveQuic, isTrue);
      expect(restored.naiveQuicCongestionControl, 'bbr');
    });

    test('sing-box JSON import and export omit unsupported fields', () {
      final exported =
          jsonDecode(
                ServerConfigExporter.toXrayJson(_naiveConfig(naiveQuic: false)),
              )
              as Map<String, dynamic>;
      final outbound =
          (exported['outbounds'] as List).first as Map<String, dynamic>;

      expect(outbound['type'], 'naive');
      expect(outbound['username'], 'user@mail');
      expect(outbound['password'], 'p:ass');
      expect(outbound.containsKey('quic'), isFalse);
      expect(outbound.containsKey('quic_congestion_control'), isFalse);
      expect(
        (outbound['tls'] as Map<String, dynamic>)['server_name'],
        'sni.example.com',
      );

      final restored = importer.parse(jsonEncode(exported)).configs.single;
      expect(restored.isNaive, isTrue);
      expect(restored.naiveUsername, 'user@mail');
      expect(restored.naivePassword, 'p:ass');
      expect(restored.naiveQuic, isFalse);
    });

    test('imports app JSON and mixed subscription links', () {
      final appResult = importer.parse(
        jsonEncode({
          'name': 'App Naive',
          'protocol': 'naive',
          'server': 'app.example.com',
          'server_port': 443,
          'username': 'app-user',
          'password': 'app-pass',
          'quic': true,
          'quic_congestion_control': 'cubic',
          'server_name': 'tls.example.com',
        }),
      );
      expect(appResult.configs.single.naiveQuicCongestionControl, 'cubic');

      const subscriptionImporter = ServerSubscriptionImporter();
      final subscription = subscriptionImporter.parsePayload(
        url: 'https://provider.example/sub',
        id: 'sub-1',
        payload: '''
naive+https://naive.example.com#Naive
vless://f1cba4a1-1f16-4176-9c71-d7508ccd4db1@vless.example.com:443#VLESS
''',
      );
      expect(subscription.isOk, isTrue);
      expect(subscription.subscription!.servers, hasLength(2));
      expect(subscription.subscription!.servers.first.isNaive, isTrue);
    });

    test('imports base64 subscription containing only naive links', () {
      const subscriptionImporter = ServerSubscriptionImporter();
      const payload =
          'naive+https://naive.example.com#Naive\n'
          'naive+quic://quic.example.com:8443#Quic\n';
      final subscription = subscriptionImporter.parsePayload(
        url: 'https://provider.example/sub',
        id: 'sub-2',
        payload: base64Encode(utf8.encode(payload)),
      );
      expect(subscription.isOk, isTrue);
      expect(subscription.subscription!.servers, hasLength(2));
      expect(
        subscription.subscription!.servers.every((s) => s.isNaive),
        isTrue,
      );
    });
  });

  group('Naive storage and native args', () {
    test('profile JSON and native arguments preserve all fields', () {
      final original = _naiveConfig();
      final restored = ServerConfig.decodeList(
        ServerConfig.encodeList([original]),
      ).single;

      expect(restored.toJson(), original.toJson());
      final args = restored.toNativeArgs(
        isGlobalProxy: true,
        tunEngineMode: TunEngineMode.libbox,
      );
      expect(args['protocol'], 'naive');
      expect(args['naiveUsername'], 'user@mail');
      expect(args['naivePassword'], 'p:ass');
      expect(args['naiveQuic'], isTrue);
      expect(args['naiveQuicCongestionControl'], 'bbr');
      expect(args['tlsSni'], 'sni.example.com');
    });

    test('legacy configs keep VLESS defaults', () {
      final restored = ServerConfig.fromJson({
        'name': 'Legacy',
        'address': 'legacy.example.com',
        'port': 443,
        'uuid': 'f1cba4a1-1f16-4176-9c71-d7508ccd4db1',
        'transport': 'tcp',
        'security': 'tls',
      });

      expect(restored!.serverProtocol, ServerProtocol.vless);
      expect(restored.naiveUsername, isEmpty);
      expect(restored.naiveQuic, isFalse);
    });
  });
}

ServerConfig _naiveConfig({bool naiveQuic = true}) {
  return ServerConfig(
    name: 'Naive Test',
    address: 'naive.example.com',
    port: 443,
    uuid: '',
    transport: VlessTransport.tcp,
    security: VlessSecurity.tls,
    serverProtocol: ServerProtocol.naive,
    sni: 'sni.example.com',
    naiveUsername: 'user@mail',
    naivePassword: 'p:ass',
    naiveQuic: naiveQuic,
    naiveQuicCongestionControl: naiveQuic ? 'bbr' : '',
  );
}
