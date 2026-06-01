import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';

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

  test(
    'reorders favorites independently from the manual server list',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      await repository.saveServers([
        _server('A', pinned: true),
        _server('B', pinned: true),
        _server('C'),
      ]);

      final controller = VpnController(repository);
      await controller.bootstrap();

      expect(_names(controller.favoriteServers), ['A', 'B']);

      await controller.reorderFavoriteServers(0, 2);

      expect(_names(controller.favoriteServers), ['B', 'A']);
      expect(_names(controller.manualServers), ['A', 'B', 'C']);
      expect(repository.load().favoriteServerNames, ['B', 'A']);

      controller.dispose();

      final restored = VpnController(repository);
      await restored.bootstrap();
      expect(_names(restored.favoriteServers), ['B', 'A']);
      restored.dispose();
    },
  );

  test('removeFavorite unpins the node without deleting it', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveServers([
      _server('A', pinned: true),
      _server('B', pinned: true),
    ]);
    await repository.saveFavoriteServerNames(['B', 'A']);

    final controller = VpnController(repository);
    await controller.bootstrap();

    await controller.removeFavorite('B');

    expect(_names(controller.favoriteServers), ['A']);
    expect(_names(controller.manualServers), ['A', 'B']);
    expect(controller.manualServers.last.isPinned, isFalse);
    expect(repository.load().favoriteServerNames, ['A']);

    controller.dispose();
  });

  test('renamed favorite keeps its position in the favorites order', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveServers([
      _server('A', pinned: true),
      _server('B', pinned: true),
    ]);
    await repository.saveFavoriteServerNames(['B', 'A']);

    final controller = VpnController(repository);
    await controller.bootstrap();

    final error = await controller.updateServer(
      originalName: 'A',
      updatedServer: _server('C', pinned: true),
    );

    expect(error, isNull);
    expect(_names(controller.favoriteServers), ['B', 'C']);
    expect(repository.load().favoriteServerNames, ['B', 'C']);

    controller.dispose();
  });
}

List<String> _names(List<ServerConfig> servers) =>
    servers.map((server) => server.name).toList(growable: false);

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
