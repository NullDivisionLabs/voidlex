import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidtunnel/core/models/server_config.dart';
import 'package:voidtunnel/core/models/server_subscription.dart';
import 'package:voidtunnel/core/server_repository.dart';
import 'package:voidtunnel/core/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidtunnel.vpn/service');
  const stateChannel = MethodChannel('org.voidtunnel.vpn/state');

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
