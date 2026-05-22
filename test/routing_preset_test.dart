import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidtunnel/core/app_routing.dart';
import 'package:voidtunnel/core/routing_preset.dart';
import 'package:voidtunnel/core/routing_rule.dart';
import 'package:voidtunnel/core/server_repository.dart';

void main() {
  test('encodes server bindings and keeps main as the only default preset', () {
    final preset = RoutingPreset(
      id: 'video',
      name: 'Video',
      appRoutingPolicy: const AppRoutingPolicy(
        mode: AppRoutingMode.proxy,
        proxyPackages: {'com.video.app'},
      ),
      routingRules: [
        RoutingRule(
          id: 'rule',
          name: 'YouTube',
          enabled: true,
          outbound: RoutingOutbound.proxy,
          domains: const ['geosite:youtube'],
        ),
      ],
      serverNames: {'Exit A', 'Exit B'},
    );

    final decoded = RoutingPreset.decodeList(
      RoutingPreset.encodeList([preset]),
    ).single;

    expect(decoded.name, 'Video');
    expect(decoded.appRoutingPolicy.mode, AppRoutingMode.proxy);
    expect(decoded.appRoutingPolicy.packages, {'com.video.app'});
    expect(decoded.appRoutingPolicy.proxyPackages, {'com.video.app'});
    expect(decoded.appRoutingPolicy.bypassPackages, isEmpty);
    expect(decoded.routingRules.single.domains, ['geosite:youtube']);
    expect(decoded.serverNames, {'Exit A', 'Exit B'});
    expect(decoded.appliesToServer('Exit A'), isTrue);
    expect(decoded.appliesToServer('Exit C'), isFalse);
    expect(RoutingPreset.main().appliesToServer('Any'), isTrue);
    expect(RoutingPreset.fresh('Unassigned').appliesToServer('Any'), isFalse);
  });

  test('encodes separate app lists for proxy and bypass modes', () {
    final preset = RoutingPreset(
      id: 'apps',
      name: 'Apps',
      appRoutingPolicy: const AppRoutingPolicy(
        mode: AppRoutingMode.bypass,
        proxyPackages: {'com.proxy.app'},
        bypassPackages: {'com.bypass.app'},
      ),
      routingRules: const [],
    );

    final decoded = RoutingPreset.decodeList(
      RoutingPreset.encodeList([preset]),
    ).single;

    expect(decoded.appRoutingPolicy.mode, AppRoutingMode.bypass);
    expect(decoded.appRoutingPolicy.packages, {'com.bypass.app'});
    expect(decoded.appRoutingPolicy.proxyPackages, {'com.proxy.app'});
    expect(decoded.appRoutingPolicy.bypassPackages, {'com.bypass.app'});
  });

  test(
    'repository migrates legacy routing settings into Main preset',
    () async {
      final rule = RoutingRule(
        id: 'legacy-rule',
        name: 'Legacy',
        enabled: true,
        outbound: RoutingOutbound.direct,
        domains: const ['geosite:private'],
      );
      SharedPreferences.setMockInitialValues({
        'void.appRoutingMode': 'bypass',
        'void.appRoutingPackages': jsonEncode(['com.example.app']),
        'void.routingRules': RoutingRule.encodeListForStorage([rule]),
      });

      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      final snapshot = repository.load();

      expect(snapshot.routingPresets, hasLength(1));
      final main = snapshot.routingPresets.single;
      expect(main.id, RoutingPreset.mainId);
      expect(main.name, RoutingPreset.mainName);
      expect(main.appRoutingPolicy.mode, AppRoutingMode.bypass);
      expect(main.appRoutingPolicy.packages, {'com.example.app'});
      expect(main.appRoutingPolicy.proxyPackages, isEmpty);
      expect(main.appRoutingPolicy.bypassPackages, {'com.example.app'});
      expect(main.routingRules.single.name, 'Legacy');
      expect(main.routingRules.single.outbound, RoutingOutbound.direct);
    },
  );

  test('repository loads split app routing package lists', () async {
    SharedPreferences.setMockInitialValues({
      'void.appRoutingMode': 'proxy',
      'void.appRoutingPackages': jsonEncode(['com.legacy.active']),
      'void.appRoutingProxyPackages': jsonEncode(['com.proxy.app']),
      'void.appRoutingBypassPackages': jsonEncode(['com.bypass.app']),
    });

    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    final main = repository.load().routingPresets.single;

    expect(main.appRoutingPolicy.mode, AppRoutingMode.proxy);
    expect(main.appRoutingPolicy.packages, {'com.proxy.app'});
    expect(main.appRoutingPolicy.proxyPackages, {'com.proxy.app'});
    expect(main.appRoutingPolicy.bypassPackages, {'com.bypass.app'});
  });

}
