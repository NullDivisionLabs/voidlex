import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test('Exit/Node info bar is visible by default', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);

    expect(repository.load().showExitNodeInfoBar, isTrue);
  });

  test('controller persists Exit/Node visibility without changing VPN state', (
    ) async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    final controller = VpnController(repository);
    await controller.bootstrap();
    final previousState = controller.connectionState;

    await controller.setShowExitNodeInfoBar(false);

    expect(controller.showExitNodeInfoBar, isFalse);
    expect(repository.load().showExitNodeInfoBar, isFalse);
    expect(controller.connectionState, previousState);
    controller.dispose();
  });
}
