import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/core/app_routing.dart';
import 'package:voidtunnel/core/hysteria2_parser.dart';
import 'package:voidtunnel/core/models/server_config.dart';
import 'package:voidtunnel/core/models/server_subscription.dart';
import 'package:voidtunnel/core/routing_rule.dart';
import 'package:voidtunnel/core/server_config_exporter.dart';
import 'package:voidtunnel/core/server_importer.dart';
import 'package:voidtunnel/core/server_subscription_importer.dart';
import 'package:voidtunnel/core/tun_engine_mode.dart';
import 'package:voidtunnel/core/vless_parser.dart';

void main() {
  const parser = VlessParser();
  const hysteria2Parser = Hysteria2Parser();
  const validUuid = 'f1cba4a1-1f16-4176-9c71-d7508ccd4db1';

  group('VlessParser.parse — success paths', () {
    test('parses TLS+gRPC link with all fields', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=grpc&security=tls&sni=example.net&serviceName=my-svc&fp=chrome&alpn=h2#Main',
      );
      expect(result.isOk, isTrue);
      final cfg = result.config!;
      expect(cfg.name, 'Main');
      expect(cfg.address, 'example.net');
      expect(cfg.port, 443);
      expect(cfg.uuid, validUuid);
      expect(cfg.transport, VlessTransport.grpc);
      expect(cfg.security, VlessSecurity.tls);
      expect(cfg.transportServiceName, 'my-svc');
      expect(cfg.sni, 'example.net');
      expect(cfg.fingerprint, 'chrome');
      expect(cfg.alpn, 'h2');
      expect(cfg.isPinned, isFalse);
    });

    test('parses WS+TLS with path and host', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=ws&security=tls&path=%2Fapi&host=cdn.example.net&sni=example.net#WS',
      );
      expect(result.isOk, isTrue);
      final cfg = result.config!;
      expect(cfg.transport, VlessTransport.ws);
      expect(cfg.transportPath, '/api');
      expect(cfg.transportHost, 'cdn.example.net');
    });

    test('parses Reality link', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=tcp&security=reality&pbk=pubkey&sid=short&spx=%2F&fp=chrome&sni=example.net#Reality',
      );
      expect(result.isOk, isTrue);
      final cfg = result.config!;
      expect(cfg.security, VlessSecurity.reality);
      expect(cfg.realityPublicKey, 'pubkey');
      expect(cfg.realityShortId, 'short');
      expect(cfg.realitySpiderX, '/');
    });

    test('uses host or authority as TLS SNI fallback', () {
      final result = parser.parse(
        'vless://$validUuid@195.211.124.172:443?type=tcp&security=reality&host=www.microsoft.com&fp=chrome&public_key=pubkey&short_id=abcd&spider_x=%2F#Reality',
      );

      expect(result.isOk, isTrue);
      final cfg = result.config!;
      expect(cfg.address, '195.211.124.172');
      expect(cfg.sni, 'www.microsoft.com');
      expect(cfg.transportHost, 'www.microsoft.com');
      expect(cfg.realityPublicKey, 'pubkey');
      expect(cfg.realityShortId, 'abcd');
      expect(cfg.realitySpiderX, '/');
    });

    test('parses common VLESS URL aliases', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=http-upgrade&security=tls&authority=edge.example.net&service-name=svc&peer=tls.example.net&allowInsecure=1#Alias',
      );

      expect(result.isOk, isTrue);
      final cfg = result.config!;
      expect(cfg.transport, VlessTransport.httpupgrade);
      expect(cfg.transportHost, 'edge.example.net');
      expect(cfg.transportServiceName, 'svc');
      expect(cfg.sni, 'tls.example.net');
      expect(cfg.tlsInsecure, isTrue);
    });

    test('defaults to tcp transport when type is absent', () {
      final result = parser.parse('vless://$validUuid@example.net:443');
      expect(result.isOk, isTrue);
      expect(result.config!.transport, VlessTransport.tcp);
      expect(result.config!.security, VlessSecurity.none);
    });

    test('defaults to port 443 when missing', () {
      final result = parser.parse('vless://$validUuid@example.net');
      expect(result.isOk, isTrue);
      expect(result.config!.port, 443);
    });

    test('deduplicates name against existingNames', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443#Main',
        existingNames: {'Main'},
      );
      expect(result.isOk, isTrue);
      expect(result.config!.name, 'Main (2)');
    });

    test('deduplicates name past index 2', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443#Main',
        existingNames: {'Main', 'Main (2)', 'Main (3)'},
      );
      expect(result.isOk, isTrue);
      expect(result.config!.name, 'Main (4)');
    });

    test('accepts httpupgrade transport', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=httpupgrade&security=tls#Hup',
      );
      expect(result.isOk, isTrue);
      expect(result.config!.transport, VlessTransport.httpupgrade);
    });

    test('accepts http transport', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=http&security=tls&path=%2Fhttp&host=edge.example.net#HTTP',
      );
      expect(result.isOk, isTrue);
      final cfg = result.config!;
      expect(cfg.transport, VlessTransport.http);
      expect(cfg.transportPath, '/http');
      expect(cfg.transportHost, 'edge.example.net');
    });

    test('accepts xhttp transport', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=xhttp&security=tls&path=%2Fxhttp&mode=auto#XHTTP',
      );
      expect(result.isOk, isTrue);
      expect(result.config!.transport, VlessTransport.xhttp);
      expect(result.config!.transportMode, 'auto');
    });
  });

  group('VlessParser.parse — error paths', () {
    test('rejects non-vless scheme', () {
      final result = parser.parse('vmess://whatever');
      expect(result.isError, isTrue);
      expect(result.error!.code, VlessParseError.notVlessScheme);
    });

    test('rejects empty string', () {
      final result = parser.parse('');
      expect(result.error!.code, VlessParseError.notVlessScheme);
    });

    test('rejects link without UUID', () {
      final result = parser.parse('vless://@example.net:443');
      expect(result.error!.code, VlessParseError.missingUuid);
    });

    test('rejects malformed UUID', () {
      final result = parser.parse('vless://not-a-uuid@example.net:443');
      expect(result.error!.code, VlessParseError.invalidUuid);
    });

    test('rejects link without host', () {
      final result = parser.parse('vless://$validUuid@:443');
      expect(
        result.error!.code,
        anyOf(VlessParseError.missingHost, VlessParseError.malformedUri),
      );
    });

    test('rejects unsupported transport', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=quic',
      );
      expect(result.error!.code, VlessParseError.unsupportedTransport);
    });

    test('rejects unsupported security', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?security=xtls',
      );
      expect(result.error!.code, VlessParseError.unsupportedSecurity);
    });
  });

  group('Hysteria2Parser.parse', () {
    test('parses URI-practical hysteria2 link with all fields', () {
      final result = hysteria2Parser.parse(
        'hysteria2://secret@example.net:443?'
        'sni=edge.example.net&insecure=1&alpn=h3&'
        'obfs=salamander&obfs-password=mask#HY2',
      );

      expect(result.isOk, isTrue);
      final cfg = result.config!;
      expect(cfg.serverProtocol, ServerProtocol.hysteria2);
      expect(cfg.protocol, 'hysteria2');
      expect(cfg.name, 'HY2');
      expect(cfg.address, 'example.net');
      expect(cfg.port, 443);
      expect(cfg.uuid, 'secret');
      expect(cfg.security, VlessSecurity.tls);
      expect(cfg.sni, 'edge.example.net');
      expect(cfg.tlsInsecure, isTrue);
      expect(cfg.alpn, 'h3');
      expect(cfg.hysteria2ObfsPassword, 'mask');
    });

    test('parses hy2 alias with decoded auth and default port', () {
      final result = hysteria2Parser.parse(
        'hy2://pa%3Ass@example.net?sni=edge.example.net#Alias',
      );

      expect(result.isOk, isTrue);
      final cfg = result.config!;
      expect(cfg.uuid, 'pa:ss');
      expect(cfg.port, 443);
      expect(cfg.alpn, 'h3');
      expect(cfg.name, 'Alias');
    });

    test('parses port hopping and stores original port spec', () {
      final result = hysteria2Parser.parse(
        'hysteria2://secret@example.net:443,8443-8445#Hop',
      );

      expect(result.isOk, isTrue);
      expect(result.config!.port, 443);
      expect(result.config!.hysteria2HopPorts, '443,8443-8445');
    });

    test('deduplicates imported names', () {
      final result = hysteria2Parser.parse(
        'hysteria2://secret@example.net:443#Node',
        existingNames: {'Node'},
      );

      expect(result.isOk, isTrue);
      expect(result.config!.name, 'Node (2)');
    });

    test('rejects unsupported obfuscation', () {
      final result = hysteria2Parser.parse(
        'hysteria2://secret@example.net:443?obfs=unknown#Bad',
      );

      expect(result.isError, isTrue);
      expect(result.error!.code, Hysteria2ParseError.unsupportedObfs);
    });
  });

  group('ServerConfig JSON round-trip', () {
    test('serializes and deserializes without loss', () {
      final result = parser.parse(
        'vless://$validUuid@example.net:443?type=grpc&security=tls&serviceName=svc&sni=example.net#RT',
      );
      final original = result.config!;
      final encoded = ServerConfig.encodeList([original]);
      final decoded = ServerConfig.decodeList(encoded);
      expect(decoded, hasLength(1));
      final round = decoded.first;
      expect(round.name, original.name);
      expect(round.address, original.address);
      expect(round.port, original.port);
      expect(round.transport, original.transport);
      expect(round.security, original.security);
      expect(round.transportServiceName, original.transportServiceName);
      expect(round.sni, original.sni);
      expect(round.transportMode, original.transportMode);
      expect(round.realitySpiderX, original.realitySpiderX);
    });

    test('tolerates corrupted storage', () {
      expect(ServerConfig.decodeList('{not json'), isEmpty);
      expect(ServerConfig.decodeList('{"servers":[]}'), isEmpty);
    });

    test('serializes and deserializes Hysteria2 without loss', () {
      final original = hysteria2Parser
          .parse(
            'hysteria2://secret@example.net:443?'
            'sni=edge.example.net&insecure=1&alpn=h3&'
            'obfs=salamander&obfs-password=mask#HY2',
          )
          .config!
          .copyWith(hysteria2HopPorts: '443,8443-8445');
      final encoded = ServerConfig.encodeList([original]);
      final decoded = ServerConfig.decodeList(encoded);

      expect(decoded, hasLength(1));
      final round = decoded.single;
      expect(round.serverProtocol, ServerProtocol.hysteria2);
      expect(round.uuid, original.uuid);
      expect(round.alpn, original.alpn);
      expect(round.tlsInsecure, isTrue);
      expect(round.hysteria2ObfsPassword, 'mask');
      expect(round.hysteria2HopPorts, '443,8443-8445');
    });
  });

  group('ServerImporter', () {
    const importer = ServerImporter();

    test('imports a single app server JSON object', () {
      final result = importer.parse('''
{
  "name": "JSON Node",
  "address": "json.example.net",
  "port": 8443,
  "uuid": "$validUuid",
  "transport": "ws",
  "security": "tls",
  "transportPath": "/ws",
  "transportHost": "cdn.example.net",
  "sni": "json.example.net"
}
''');

      expect(result.isOk, isTrue);
      expect(result.configs, hasLength(1));
      final cfg = result.configs.first;
      expect(cfg.name, 'JSON Node');
      expect(cfg.address, 'json.example.net');
      expect(cfg.port, 8443);
      expect(cfg.transport, VlessTransport.ws);
      expect(cfg.security, VlessSecurity.tls);
      expect(cfg.transportPath, '/ws');
      expect(cfg.transportHost, 'cdn.example.net');
    });

    test('imports a list of app server JSON objects with unique names', () {
      final result = importer.parse(
        ServerConfig.encodeList([
          ServerConfig(
            name: 'Node',
            address: 'one.example.net',
            port: 443,
            uuid: validUuid,
            transport: VlessTransport.tcp,
            security: VlessSecurity.none,
          ),
          ServerConfig(
            name: 'Node',
            address: 'two.example.net',
            port: 443,
            uuid: validUuid,
            transport: VlessTransport.grpc,
            security: VlessSecurity.tls,
          ),
        ]),
      );

      expect(result.isOk, isTrue);
      expect(result.configs.map((config) => config.name), ['Node', 'Node (2)']);
    });

    test('imports VLESS outbound from Xray JSON config', () {
      final result = importer.parse('''
{
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "xray.example.net",
            "port": 443,
            "users": [
              {"id": "$validUuid", "flow": "xtls-rprx-vision"}
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "reality",
        "grpcSettings": {"serviceName": "svc"},
        "realitySettings": {
          "serverName": "www.example.net",
          "publicKey": "public",
          "shortId": "abcd",
          "fingerprint": "chrome",
          "spiderX": "/"
        }
      }
    }
  ]
}
''');

      expect(result.isOk, isTrue);
      final cfg = result.configs.single;
      expect(cfg.name, 'proxy');
      expect(cfg.address, 'xray.example.net');
      expect(cfg.transport, VlessTransport.grpc);
      expect(cfg.security, VlessSecurity.reality);
      expect(cfg.transportServiceName, 'svc');
      expect(cfg.sni, 'www.example.net');
      expect(cfg.realityPublicKey, 'public');
      expect(cfg.realityShortId, 'abcd');
      expect(cfg.realitySpiderX, '/');
      expect(cfg.flow, 'xtls-rprx-vision');
    });

    test('uses top-level remarks for full Xray config imports', () {
      final result = importer.parse('''
{
  "remarks": "USA",
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "serverusa.goodbyevpn.pro",
            "port": 443,
            "users": [
              {
                "id": "$validUuid",
                "encryption": "none",
                "flow": "",
                "level": 8,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "grpcSettings": {
          "authority": "edge.example.net",
          "multiMode": true,
          "serviceName": "grpc"
        },
        "network": "grpc",
        "realitySettings": {
          "allowInsecure": false,
          "fingerprint": "",
          "publicKey": "public",
          "serverName": "twitch.tv",
          "shortId": "bb47001994bd2014",
          "show": false
        },
        "security": "reality"
      }
    },
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "block"}
  ]
}
''');

      expect(result.isOk, isTrue);
      final cfg = result.configs.single;
      expect(cfg.name, 'USA');
      expect(cfg.address, 'serverusa.goodbyevpn.pro');
      expect(cfg.transport, VlessTransport.grpc);
      expect(cfg.transportServiceName, 'grpc');
      expect(cfg.transportHost, 'edge.example.net');
      expect(cfg.security, VlessSecurity.reality);
      expect(cfg.sni, 'twitch.tv');
      expect(cfg.realityPublicKey, 'public');
      expect(cfg.realityShortId, 'bb47001994bd2014');
    });

    test('exports Xray JSON that round-trips through importer', () {
      final server = ServerConfig(
        name: 'USA',
        address: 'serverusa.goodbyevpn.pro',
        port: 443,
        uuid: validUuid,
        transport: VlessTransport.grpc,
        security: VlessSecurity.reality,
        transportServiceName: 'grpc',
        transportHost: 'edge.example.net',
        sni: 'twitch.tv',
        realityPublicKey: 'public',
        realityShortId: 'bb47001994bd2014',
      );

      final exported = ServerConfigExporter.toXrayJson(server);
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      expect(decoded['address'], isNull);
      expect(decoded['remarks'], 'USA');
      expect(decoded['inbounds'], isA<List>());
      expect(decoded['outbounds'], isA<List>());

      final outbounds = decoded['outbounds'] as List<dynamic>;
      final proxy = outbounds.first as Map<String, dynamic>;
      expect(proxy['protocol'], 'vless');
      expect(proxy['settings'], contains('vnext'));
      expect(proxy['streamSettings'], contains('realitySettings'));

      final imported = importer.parse(exported);
      expect(imported.isOk, isTrue);
      final round = imported.configs.single;
      expect(round.name, server.name);
      expect(round.address, server.address);
      expect(round.transport, server.transport);
      expect(round.security, server.security);
      expect(round.transportServiceName, server.transportServiceName);
      expect(round.transportHost, server.transportHost);
      expect(round.sni, server.sni);
      expect(round.realityPublicKey, server.realityPublicKey);
      expect(round.realityShortId, server.realityShortId);
    });

    test('exports Hysteria2 URL and sing-box JSON that round-trip', () {
      final server = ServerConfig(
        name: 'HY2',
        address: 'hy2.example.net',
        port: 443,
        uuid: 'secret',
        transport: VlessTransport.tcp,
        security: VlessSecurity.tls,
        serverProtocol: ServerProtocol.hysteria2,
        sni: 'edge.example.net',
        alpn: 'h3',
        tlsInsecure: true,
        hysteria2ObfsPassword: 'mask',
        hysteria2HopPorts: '443,8443-8445',
      );

      final url = ServerConfigExporter.toServerUrl(server);
      final parsedUrl = importer.parse(url);
      expect(parsedUrl.isOk, isTrue);
      expect(parsedUrl.configs.single.serverProtocol, ServerProtocol.hysteria2);
      expect(parsedUrl.configs.single.hysteria2HopPorts, '443,8443-8445');

      final exported = ServerConfigExporter.toXrayJson(server);
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      final proxy =
          (decoded['outbounds'] as List<dynamic>).first as Map<String, dynamic>;
      expect(proxy['type'], 'hysteria2');
      expect(proxy['server'], 'hy2.example.net');
      expect(proxy['server_port'], 443);
      expect(proxy['password'], 'secret');
      expect(proxy['server_ports'], ['443:443', '8443:8445']);
      expect(proxy['obfs'], containsPair('type', 'salamander'));
      expect(
        (proxy['tls'] as Map<String, dynamic>)['server_name'],
        'edge.example.net',
      );

      final imported = importer.parse(exported);
      expect(imported.isOk, isTrue);
      final round = imported.configs.single;
      expect(round.name, server.name);
      expect(round.address, server.address);
      expect(round.serverProtocol, ServerProtocol.hysteria2);
      expect(round.uuid, server.uuid);
      expect(round.sni, server.sni);
      expect(round.tlsInsecure, isTrue);
      expect(round.hysteria2ObfsPassword, server.hysteria2ObfsPassword);
      expect(round.hysteria2HopPorts, '443,8443-8445');
    });

    test('imports Hysteria2 app JSON object', () {
      final result = importer.parse('''
{
  "name": "HY2 JSON",
  "protocol": "hysteria2",
  "address": "json-hy2.example.net",
  "port": 8443,
  "uuid": "secret",
  "sni": "edge.example.net",
  "alpn": "h3",
  "tlsInsecure": true,
  "hysteria2ObfsPassword": "mask",
  "hysteria2HopPorts": "8443,9443-9445"
}
''');

      expect(result.isOk, isTrue);
      final cfg = result.configs.single;
      expect(cfg.serverProtocol, ServerProtocol.hysteria2);
      expect(cfg.address, 'json-hy2.example.net');
      expect(cfg.port, 8443);
      expect(cfg.uuid, 'secret');
      expect(cfg.hysteria2HopPorts, '8443,9443-9445');
    });
  });

  group('ServerSubscriptionImporter', () {
    const importer = ServerSubscriptionImporter();

    test('imports base64 subscription payload with multiple VLESS nodes', () {
      final payload = base64.encode(
        utf8.encode(
          [
            'vless://$validUuid@one.example.net:443?type=grpc&security=tls#Node',
            'vless://$validUuid@two.example.net:443?type=ws&security=tls#Node',
          ].join('\n'),
        ),
      );

      final result = importer.parsePayload(
        url: 'https://sub.example.net/list',
        id: 'sub_1',
        payload: payload,
        headers: {
          'profile-title': Uri.encodeComponent('Premium Nodes'),
          'subscription-userinfo':
              'upload=0; download=0; total=1073741824; expire=1893456000',
        },
      );

      expect(result.isOk, isTrue);
      final subscription = result.subscription!;
      expect(subscription.name, 'Premium Nodes');
      expect(subscription.url, 'https://sub.example.net/list');
      expect(subscription.expiresAt, DateTime.utc(2030));
      expect(subscription.trafficUsedBytes, 0);
      expect(subscription.trafficLimitBytes, 1073741824);
      expect(subscription.servers, hasLength(2));
      expect(subscription.servers.map((server) => server.name), [
        'Node',
        'Node (2)',
      ]);
      expect(subscription.servers.last.transport, VlessTransport.ws);

      final restored = ServerSubscription.decodeList(
        ServerSubscription.encodeList([subscription]),
      ).single;
      expect(restored.trafficUsedBytes, 0);
      expect(restored.trafficLimitBytes, 1073741824);
    });

    test('imports subscription traffic without a total limit as unlimited', () {
      final result = importer.parsePayload(
        url: 'https://sub.example.net/list',
        id: 'sub_1',
        payload:
            'vless://$validUuid@one.example.net:443?type=grpc&security=tls#Node',
        headers: const {
          'subscription-userinfo': 'upload=1048576; download=2097152',
        },
      );

      expect(result.isOk, isTrue);
      final subscription = result.subscription!;
      expect(subscription.trafficUsedBytes, 3145728);
      expect(subscription.trafficLimitBytes, isNull);
    });

    test('imports mixed base64 subscription payload with Hysteria2 nodes', () {
      final payload = base64.encode(
        utf8.encode(
          [
            'vless://$validUuid@one.example.net:443?type=grpc&security=tls#Node',
            'hy2://secret@hy2.example.net:443?sni=edge.example.net#Node',
          ].join('\n'),
        ),
      );

      final result = importer.parsePayload(
        url: 'https://sub.example.net/list',
        id: 'sub_1',
        payload: payload,
      );

      expect(result.isOk, isTrue);
      final servers = result.subscription!.servers;
      expect(servers, hasLength(2));
      expect(servers.first.serverProtocol, ServerProtocol.vless);
      expect(servers.last.serverProtocol, ServerProtocol.hysteria2);
      expect(servers.last.name, 'Node (2)');
      expect(servers.last.uuid, 'secret');
    });

    test('decodes base64 profile-title header', () {
      final title = base64.encode(utf8.encode('Header Title'));
      final result = importer.parsePayload(
        url: 'https://sub.example.net/list',
        id: 'sub_1',
        payload:
            'vless://$validUuid@one.example.net:443?type=tcp&security=none#One',
        headers: {'profile-title': 'base64:$title'},
      );

      expect(result.isOk, isTrue);
      expect(result.subscription!.name, 'Header Title');
    });

    test('recognizes only HTTP subscription URLs', () {
      expect(
        ServerSubscriptionImporter.tryParseSubscriptionUri(
          'https://sub.example.net/list',
        ),
        isNotNull,
      );
      expect(
        ServerSubscriptionImporter.tryParseSubscriptionUri(
          'vless://$validUuid@example.net:443',
        ),
        isNull,
      );
    });

    test('sends HWID header when importing from URL', () async {
      final payload =
          'vless://$validUuid@one.example.net:443?type=tcp&security=none#One';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final hwidFuture = server.first.then((request) async {
        final hwid = request.headers.value('X-HWID');
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write(payload);
        await request.response.close();
        return hwid;
      });

      final result = await importer.importFromUrl(
        'http://127.0.0.1:${server.port}/sub',
        id: 'sub_1',
        hwid: ' device-123 ',
      );
      final hwid = await hwidFuture;

      expect(result.isOk, isTrue);
      expect(hwid, 'device-123');
    });
  });

  group('ServerConfig native args', () {
    test('includes Hysteria2 protocol fields in native args', () {
      final config = hysteria2Parser
          .parse(
            'hysteria2://secret@hy2.example.net:443,8443-8445?'
            'sni=edge.example.net&insecure=1&alpn=h3&'
            'obfs=salamander&obfs-password=mask#HY2',
          )
          .config!;

      final args = config.toNativeArgs(
        isGlobalProxy: true,
        tunEngineMode: TunEngineMode.libbox,
      );

      expect(args['protocol'], 'hysteria2');
      expect(args['server'], 'hy2.example.net');
      expect(args['uuid'], 'secret');
      expect(args['tlsEnabled'], isTrue);
      expect(args['tlsSni'], 'edge.example.net');
      expect(args['tlsInsecure'], isTrue);
      expect(args['alpn'], 'h3');
      expect(args['hysteria2ObfsPassword'], 'mask');
      expect(args['hysteria2HopPorts'], '443,8443-8445');
    });

    test('global proxy suppresses preset app and routing rules', () {
      final config = parser
          .parse(
            'vless://$validUuid@global.example.net:443?type=tcp&security=tls&sni=global.example.net#Global',
          )
          .config!;

      final args = config.toNativeArgs(
        isGlobalProxy: true,
        tunEngineMode: TunEngineMode.libbox,
        appRoutingPolicy: const AppRoutingPolicy(
          mode: AppRoutingMode.bypass,
          bypassPackages: {'com.chat.app'},
        ),
        routingRules: [
          RoutingRule(
            id: 'block-video',
            name: 'Block video',
            enabled: true,
            outbound: RoutingOutbound.block,
            domains: const ['domain:video.example'],
          ),
        ],
      );

      expect(args['isGlobalProxy'], isTrue);
      expect(args['appRoutingMode'], 'off');
      expect(args['appRoutingPackages'], isEmpty);
      expect(jsonDecode(args['routingRulesJson'] as String), isEmpty);
    });
  });
}
