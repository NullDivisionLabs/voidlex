import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/app_message_code.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/tun_engine_mode.dart';
import 'package:voidlex/core/vpn_controller.dart';
import 'package:voidlex/core/run_mode.dart';

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

  test('rejects selecting a Hysteria2 or NaiveProxy bridge hop', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveSelected('VLESS');
    await repository.saveServers([
      _server('VLESS', ServerProtocol.vless),
      _server('HY2', ServerProtocol.hysteria2),
      _server('Naive', ServerProtocol.naive),
    ]);
    final controller = VpnController(repository);
    await controller.bootstrap();

    expect(
      await controller.toggleExitNode('HY2'),
      Msg.vpnDirectLibboxBridgeUnsupported,
    );
    expect(
      await controller.toggleExitNode('Naive'),
      Msg.vpnDirectLibboxBridgeUnsupported,
    );
    await controller.selectServer('HY2');
    expect(
      await controller.toggleExitNode('VLESS'),
      Msg.vpnDirectLibboxBridgeUnsupported,
    );

    controller.dispose();
  });

  test(
    'rejects a stale persisted Hysteria2 bridge before native start',
    () async {
      var nativeStartCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(serviceChannel, (call) async {
            if (call.method == 'startVpn') nativeStartCalled = true;
            return null;
          });
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      await repository.saveNotificationPermissionAsked(true);
      await repository.saveSelected('HY2');
      await repository.saveExitNodeName('VLESS');
      await repository.saveServers([
        _server('HY2', ServerProtocol.hysteria2),
        _server('VLESS', ServerProtocol.vless),
      ]);
      final controller = VpnController(repository);
      await controller.bootstrap();

      await controller.connect();

      expect(controller.lastError, Msg.vpnDirectLibboxBridgeUnsupported);
      expect(nativeStartCalled, isFalse);
      controller.dispose();
    },
  );

  test('rejects Hysteria2 in proxy-only mode before native start', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveNotificationPermissionAsked(true);
    await repository.saveSelected('HY2');
    await repository.saveServers([_server('HY2', ServerProtocol.hysteria2)]);
    await repository.saveRunMode(RunMode.proxyOnly);
    final controller = VpnController(repository);
    await controller.bootstrap();

    await controller.connect();

    expect(controller.lastError, Msg.vpnDirectLibboxTunOnly);
    controller.dispose();
  });

  test('rejects Hysteria2 with Xray TUN before native start', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveNotificationPermissionAsked(true);
    await repository.saveSelected('HY2');
    await repository.saveServers([_server('HY2', ServerProtocol.hysteria2)]);
    await repository.saveTunEngineMode(TunEngineMode.xray);
    final controller = VpnController(repository);
    await controller.bootstrap();

    await controller.connect();

    expect(controller.lastError, Msg.vpnDirectLibboxRequiresLibbox);
    controller.dispose();
  });
}

ServerConfig _server(String name, ServerProtocol protocol) {
  return ServerConfig(
    name: name,
    address: '${name.toLowerCase()}.example.com',
    port: 443,
    uuid: protocol == ServerProtocol.naive ? '' : 'secret',
    transport: VlessTransport.tcp,
    security: protocol == ServerProtocol.vless
        ? VlessSecurity.none
        : VlessSecurity.tls,
    serverProtocol: protocol,
  );
}
