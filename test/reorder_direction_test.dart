import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/models/server_subscription.dart';
import 'package:voidlex/core/routing_rule.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';

ServerConfig _server(String name, {bool pinned = false}) {
  return ServerConfig(
    name: name,
    address: '${name.toLowerCase()}.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
    isPinned: pinned,
  );
}

ServerSubscription _subscription(String id, String name) {
  return ServerSubscription(
    id: id,
    name: name,
    url: 'https://$id.example.com/sub',
    servers: [_server('$name-node')],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidlex.vpn/service');
  const stateChannel = MethodChannel('org.voidlex.vpn/state');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, null);
  });

  group('reorderServers', () {
    test('reorders downward to adjacent neighbor position without skipping or no-op', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ServerRepository(prefs);
      await repo.saveServers([_server('A'), _server('B'), _server('C')]);

      final controller = VpnController(repo);
      await controller.bootstrap();

      expect(controller.manualServers.map((s) => s.name).toList(), ['A', 'B', 'C']);

      // Drag A (0) to adjacent neighbor position 1 (as reported by onReorderItem)
      await controller.reorderServers(0, 1);

      expect(controller.manualServers.map((s) => s.name).toList(), ['B', 'A', 'C']);

      controller.dispose();
    });

    test('reorders downward to end of list', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ServerRepository(prefs);
      await repo.saveServers([_server('A'), _server('B'), _server('C')]);

      final controller = VpnController(repo);
      await controller.bootstrap();

      // Drag A (0) to end position 2
      await controller.reorderServers(0, 2);

      expect(controller.manualServers.map((s) => s.name).toList(), ['B', 'C', 'A']);

      controller.dispose();
    });

    test('reorders upward correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ServerRepository(prefs);
      await repo.saveServers([_server('A'), _server('B'), _server('C')]);

      final controller = VpnController(repo);
      await controller.bootstrap();

      // Drag C (2) to beginning 0
      await controller.reorderServers(2, 0);

      expect(controller.manualServers.map((s) => s.name).toList(), ['C', 'A', 'B']);

      controller.dispose();
    });
  });

  group('reorderSubscriptions', () {
    test('reorders downward to adjacent neighbor position', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ServerRepository(prefs);
      await repo.saveSubscriptions([
        _subscription('1', 'A'),
        _subscription('2', 'B'),
        _subscription('3', 'C'),
      ]);

      final controller = VpnController(repo);
      await controller.bootstrap();

      await controller.reorderSubscriptions(0, 1);
      expect(controller.subscriptions.map((s) => s.name).toList(), ['B', 'A', 'C']);

      controller.dispose();
    });

    test('reorders downward to end of list', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ServerRepository(prefs);
      await repo.saveSubscriptions([
        _subscription('1', 'A'),
        _subscription('2', 'B'),
        _subscription('3', 'C'),
      ]);

      final controller = VpnController(repo);
      await controller.bootstrap();

      await controller.reorderSubscriptions(0, 2);
      expect(controller.subscriptions.map((s) => s.name).toList(), ['B', 'C', 'A']);

      controller.dispose();
    });
  });

  group('reorderFavoriteServers', () {
    test('reorders favorites downward to adjacent neighbor', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ServerRepository(prefs);
      await repo.saveServers([
        _server('A', pinned: true),
        _server('B', pinned: true),
        _server('C', pinned: true),
      ]);

      final controller = VpnController(repo);
      await controller.bootstrap();

      expect(controller.favoriteServers.map((s) => s.name).toList(), ['A', 'B', 'C']);

      await controller.reorderFavoriteServers(0, 1);
      expect(controller.favoriteServers.map((s) => s.name).toList(), ['B', 'A', 'C']);

      controller.dispose();
    });
  });

  group('reorderRoutingRule', () {
    test('reorders routing rules downward and upward', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ServerRepository(prefs);

      final controller = VpnController(repo);
      await controller.bootstrap();

      final r1 = RoutingRule(
        id: 'r1',
        name: 'OpenAI',
        enabled: true,
        outbound: RoutingOutbound.proxy,
        domains: const ['openai.com'],
      );
      final r2 = RoutingRule(
        id: 'r2',
        name: 'Google',
        enabled: true,
        outbound: RoutingOutbound.direct,
        domains: const ['google.com'],
      );
      final r3 = RoutingRule(
        id: 'r3',
        name: 'Yandex',
        enabled: true,
        outbound: RoutingOutbound.block,
        domains: const ['yandex.ru'],
      );

      await controller.upsertRoutingRule(r1);
      await controller.upsertRoutingRule(r2);
      await controller.upsertRoutingRule(r3);

      expect(
        controller.selectedRoutingPreset.routingRules.map((r) => r.id).toList(),
        ['r1', 'r2', 'r3'],
      );

      // Move r1 (0) to adjacent 1
      await controller.reorderRoutingRule(0, 1);
      expect(
        controller.selectedRoutingPreset.routingRules.map((r) => r.id).toList(),
        ['r2', 'r1', 'r3'],
      );

      // Move r3 (2) to 0
      await controller.reorderRoutingRule(2, 0);
      expect(
        controller.selectedRoutingPreset.routingRules.map((r) => r.id).toList(),
        ['r3', 'r2', 'r1'],
      );

      controller.dispose();
    });
  });
}
