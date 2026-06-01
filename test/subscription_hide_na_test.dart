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

  test('hideNaServers round-trips in subscription JSON', () {
    final sub = ServerSubscription(
      id: 'sub-1',
      name: 'Test',
      url: 'https://example.com/sub',
      servers: [_server('node-a')],
      hideNaServers: true,
    );
    final decoded = ServerSubscription.fromJson(sub.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.hideNaServers, isTrue);
  });

  test('persists hideNaServers per subscription', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveSubscriptions([
      _subscription('sub-a', hideNa: false),
      _subscription('sub-b', hideNa: true),
    ]);

    final controller = VpnController(repository);
    await controller.bootstrap();

    expect(controller.subscriptions[0].hideNaServers, isFalse);
    expect(controller.subscriptions[1].hideNaServers, isTrue);

    await controller.setSubscriptionHideNaServers('sub-a', true);

    expect(controller.subscriptions[0].hideNaServers, isTrue);
    expect(
      repository.load().subscriptions.firstWhere((s) => s.id == 'sub-a').hideNaServers,
      isTrue,
    );

    controller.dispose();
  });

  test('hides N/A servers but keeps pinned favorites visible', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    final na = _server('na-node', ping: 'ERR');
    final ok = _server('ok-node', ping: '42');
    final pinnedNa = _server('fav-na', ping: 'ERR', pinned: true);
    await repository.saveSubscriptions([
      ServerSubscription(
        id: 'sub-a',
        name: 'A',
        url: 'https://sub-a.example.com/sub',
        servers: [na, ok, pinnedNa],
        hideNaServers: true,
      ),
    ]);

    final controller = VpnController(repository);
    await controller.bootstrap();
    final sub = controller.subscriptions.single;

    expect(controller.shouldHideServerInSubscription(sub, na), isTrue);
    expect(controller.shouldHideServerInSubscription(sub, ok), isFalse);
    expect(controller.shouldHideServerInSubscription(sub, pinnedNa), isFalse);

    final visible = controller.visibleSubscriptionServers(sub);
    expect(visible.map((s) => s.name), ['ok-node', 'fav-na']);

    controller.dispose();
  });
}

ServerSubscription _subscription(String id, {required bool hideNa}) {
  return ServerSubscription(
    id: id,
    name: id,
    url: 'https://$id.example.com/sub',
    servers: [_server('$id-node')],
    hideNaServers: hideNa,
  );
}

ServerConfig _server(
  String name, {
  String ping = '--',
  bool pinned = false,
}) {
  return ServerConfig(
    name: name,
    address: '${name.toLowerCase()}.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
    isPinned: pinned,
    ping: ping,
  );
}
