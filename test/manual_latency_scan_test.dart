import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/models/server_subscription.dart';
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

  test('scanManualLatencies leaves subscription nodes untouched', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveServers([_server('Manual A')]);
    await repository.saveSubscriptions([
      ServerSubscription(
        id: 'sub-1',
        name: 'Provider',
        url: 'https://provider.example.com/sub',
        servers: [_server('Sub A')],
      ),
    ]);

    final controller = VpnController(repository);
    await controller.bootstrap();

    await controller.scanManualLatencies();

    expect(controller.manualServers.single.ping, isNot('--'));
    expect(controller.subscriptions.single.servers.single.ping, '--');

    controller.dispose();
  });

  test('pingForServer exposes latest manual ping', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveServers([_server('Manual A')]);

    final controller = VpnController(repository);
    await controller.bootstrap();

    expect(controller.pingForServer('Manual A'), '--');
    await controller.scanManualLatencies();
    expect(controller.pingForServer('Manual A'), isNot('--'));

    controller.dispose();
  });

  test('isScanningLatencyListenable toggles during manual scan', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveServers([_server('Manual A')]);

    final controller = VpnController(repository);
    await controller.bootstrap();

    final flags = <bool>[];
    void capture() => flags.add(controller.isScanningLatencyListenable.value);
    controller.isScanningLatencyListenable.addListener(capture);

    final scan = controller.scanManualLatencies();
    expect(flags, contains(true));
    await scan;
    expect(controller.isScanningLatencyListenable.value, isFalse);

    controller.dispose();
  });

  test('renaming a manual server prunes its stale ping listenable', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveServers([_server('Manual A')]);

    final controller = VpnController(repository);
    await controller.bootstrap();

    // Lazily materialise the per-server ping listenable.
    final before = controller.pingListenableFor('Manual A');

    // A rename leaves the inventory count unchanged — exactly the case the old
    // count-based prune gate missed, so the notifier keyed on the old name used
    // to linger for the lifetime of the controller.
    final error = await controller.updateServer(
      originalName: 'Manual A',
      updatedServer: _server('Manual B'),
    );
    expect(error, isNull);

    // The stale listenable must have been pruned, so re-requesting the old name
    // hands back a fresh instance rather than the leaked one.
    final after = controller.pingListenableFor('Manual A');
    expect(identical(before, after), isFalse);

    controller.dispose();
  });
}

ServerConfig _server(String name) {
  return ServerConfig(
    name: name,
    address: '127.0.0.1',
    port: 1,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
  );
}
