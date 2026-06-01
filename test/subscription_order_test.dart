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

  test('reorders subscriptions and persists their order', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveSubscriptions([
      _subscription('sub-a', 'A'),
      _subscription('sub-b', 'B'),
      _subscription('sub-c', 'C'),
    ]);

    final controller = VpnController(repository);
    await controller.bootstrap();

    expect(_subscriptionNames(controller.subscriptions), ['A', 'B', 'C']);

    await controller.reorderSubscriptions(0, 3);

    expect(_subscriptionNames(controller.subscriptions), ['B', 'C', 'A']);
    expect(_subscriptionNames(repository.load().subscriptions), [
      'B',
      'C',
      'A',
    ]);

    controller.dispose();

    final restored = VpnController(repository);
    await restored.bootstrap();
    expect(_subscriptionNames(restored.subscriptions), ['B', 'C', 'A']);
    restored.dispose();
  });

  test('persists collapsed subscription sections', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveSubscriptions([
      _subscription('sub-a', 'A'),
      _subscription('sub-b', 'B'),
    ]);

    final controller = VpnController(repository);
    await controller.bootstrap();

    expect(controller.isSubscriptionCollapsed('sub-a'), isFalse);
    expect(controller.isSubscriptionCollapsed('sub-b'), isFalse);

    await controller.setSubscriptionCollapsed('sub-b', true);

    expect(controller.isSubscriptionCollapsed('sub-b'), isTrue);
    expect(repository.load().collapsedSubscriptionIds, ['sub-b']);

    controller.dispose();

    final restored = VpnController(repository);
    await restored.bootstrap();

    expect(restored.isSubscriptionCollapsed('sub-a'), isFalse);
    expect(restored.isSubscriptionCollapsed('sub-b'), isTrue);

    await restored.setSubscriptionCollapsed('sub-b', false);

    expect(restored.isSubscriptionCollapsed('sub-b'), isFalse);
    expect(repository.load().collapsedSubscriptionIds, isEmpty);

    restored.dispose();
  });
}

List<String> _subscriptionNames(List<ServerSubscription> subscriptions) =>
    subscriptions
        .map((subscription) => subscription.name)
        .toList(growable: false);

ServerSubscription _subscription(String id, String name) {
  return ServerSubscription(
    id: id,
    name: name,
    url: 'https://$id.example.com/sub',
    servers: [_server('$name-node')],
  );
}

ServerConfig _server(String name) {
  return ServerConfig(
    name: name,
    address: '${name.toLowerCase()}.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
  );
}
