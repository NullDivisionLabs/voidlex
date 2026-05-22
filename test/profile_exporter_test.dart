import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/core/app_routing.dart';
import 'package:voidtunnel/core/models/server_config.dart';
import 'package:voidtunnel/core/models/server_subscription.dart';
import 'package:voidtunnel/core/profile_exporter.dart';
import 'package:voidtunnel/core/routing_preset.dart';

void main() {
  test('exports full profile with manual nodes subscriptions and presets', () {
    final manual = _server('Manual A', pinned: true, ping: '42 ms');
    final subscription = _subscription(
      server: _server('Sub A', pinned: true, ping: '95 ms'),
    );
    final preset = _preset({'Manual A', 'Sub A'});

    final decoded = _decode(
      ProfileExporter.exportJson(
        manualNodes: [manual],
        subscriptions: [subscription],
        routingPresets: [RoutingPreset.main(), preset],
        selectedRoutingPresetId: preset.id,
        protectSubscriptions: false,
        exportedAt: DateTime.utc(2026, 5, 14, 10),
      ),
    );

    expect(decoded['format'], ProfileExporter.format);
    expect(decoded['version'], ProfileExporter.version);
    expect(decoded['exportedAt'], '2026-05-14T10:00:00.000Z');

    final profile = decoded['profile'] as Map<String, dynamic>;
    expect(profile['selectedRoutingPresetId'], preset.id);
    expect(profile['manualNodes'], hasLength(1));
    expect(profile['subscriptions'], hasLength(1));
    expect(profile['routingPresets'], hasLength(2));

    final subscriptionJson =
        (profile['subscriptions'] as List).single as Map<String, dynamic>;
    expect(subscriptionJson['name'], 'Provider');
    expect(subscriptionJson['servers'], hasLength(1));

    final presetJson = (profile['routingPresets'] as List)
        .whereType<Map<String, dynamic>>()
        .firstWhere((entry) => entry['id'] == preset.id);
    expect(presetJson['serverNames'], containsAll(['Manual A', 'Sub A']));
  });

  test(
    'protected subscriptions are encrypted into protectedSubscriptions and preset bindings are narrowed',
    () {
      final preset = _preset({'Manual A', 'Sub A'});

      final decoded = _decode(
        ProfileExporter.exportJson(
          manualNodes: [_server('Manual A')],
          subscriptions: [_subscription(server: _server('Sub A'))],
          routingPresets: [preset],
          selectedRoutingPresetId: preset.id,
          protectSubscriptions: true,
          protectedSubscriptionLinks: const [
            'voidtunnel://1/dummy-encrypted-blob',
          ],
          exportedAt: DateTime.utc(2026, 5, 14, 10),
        ),
      );

      final profile = decoded['profile'] as Map<String, dynamic>;
      expect(profile['manualNodes'], hasLength(1));
      expect(profile['subscriptions'], isEmpty);
      expect(profile['protectedSubscriptions'], hasLength(1));
      expect(
        (profile['protectedSubscriptions'] as List).single,
        'voidtunnel://1/dummy-encrypted-blob',
      );

      final presetJson =
          (profile['routingPresets'] as List).single as Map<String, dynamic>;
      expect(presetJson['serverNames'], ['Manual A']);
    },
  );

  test(
    'unprotected export omits the protectedSubscriptions field entirely',
    () {
      final decoded = _decode(
        ProfileExporter.exportJson(
          manualNodes: [_server('Manual A')],
          subscriptions: [_subscription(server: _server('Sub A'))],
          routingPresets: [RoutingPreset.main()],
          selectedRoutingPresetId: RoutingPreset.mainId,
          protectSubscriptions: false,
          exportedAt: DateTime.utc(2026, 5, 14, 10),
        ),
      );
      final profile = decoded['profile'] as Map<String, dynamic>;
      expect(profile.containsKey('protectedSubscriptions'), isFalse);
    },
  );

  test('server transient fields are not exported', () {
    final decoded = _decode(
      ProfileExporter.exportJson(
        manualNodes: [_server('Manual A', pinned: true, ping: '42 ms')],
        subscriptions: [
          _subscription(server: _server('Sub A', pinned: true, ping: '95 ms')),
        ],
        routingPresets: [RoutingPreset.main()],
        selectedRoutingPresetId: RoutingPreset.mainId,
        protectSubscriptions: false,
        exportedAt: DateTime.utc(2026, 5, 14, 10),
      ),
    );

    final profile = decoded['profile'] as Map<String, dynamic>;
    final manualJson =
        (profile['manualNodes'] as List).single as Map<String, dynamic>;
    expect(manualJson, isNot(contains('isPinned')));
    expect(manualJson, isNot(contains('ping')));

    final subscriptionJson =
        (profile['subscriptions'] as List).single as Map<String, dynamic>;
    final subscriptionServerJson =
        (subscriptionJson['servers'] as List).single as Map<String, dynamic>;
    expect(subscriptionServerJson, isNot(contains('isPinned')));
    expect(subscriptionServerJson, isNot(contains('ping')));
  });
}

Map<String, dynamic> _decode(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

ServerConfig _server(String name, {bool pinned = false, String ping = '--'}) {
  return ServerConfig(
    name: name,
    address: '${name.toLowerCase().replaceAll(' ', '-')}.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
    isPinned: pinned,
    ping: ping,
  );
}

ServerSubscription _subscription({required ServerConfig server}) {
  return ServerSubscription(
    id: 'sub-1',
    name: 'Provider',
    url: 'https://provider.example.com/sub',
    servers: [server],
  );
}

RoutingPreset _preset(Set<String> serverNames) {
  return RoutingPreset(
    id: 'video',
    name: 'Video',
    appRoutingPolicy: AppRoutingPolicy.empty,
    routingRules: const [],
    serverNames: serverNames,
  );
}
