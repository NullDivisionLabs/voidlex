import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/server_importer.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/subscription_link_codec.dart';
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

  test('blocks a plain HTTP subscription until explicit consent', () async {
    final controller = await _buildController();
    addTearDown(controller.dispose);

    final result = await controller.importServersFromString(
      'http://subscriptions.example/list',
    );

    expect(result.error?.code, ServerImportError.insecureSubscription);
    expect(controller.subscriptions, isEmpty);
  });

  test('blocks HTTP hidden inside an encrypted subscription code', () async {
    const codec = SubscriptionLinkCodec();
    final link = await codec.encode(
      url: 'http://subscriptions.example/list',
      name: 'Unsafe provider',
    );
    final controller = await _buildController();
    addTearDown(controller.dispose);

    final result = await controller.importServersFromString(link);

    expect(result.error?.code, ServerImportError.insecureSubscription);
    expect(controller.subscriptions, isEmpty);
  });
}

Future<VpnController> _buildController() async {
  final prefs = await SharedPreferences.getInstance();
  final controller = VpnController(ServerRepository(prefs));
  await controller.bootstrap();
  return controller;
}
