import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidtunnel/core/app_routing.dart';
import 'package:voidtunnel/core/models/server_config.dart';
import 'package:voidtunnel/core/routing_preset.dart';
import 'package:voidtunnel/core/server_repository.dart';
import 'package:voidtunnel/core/tun_engine_mode.dart';
import 'package:voidtunnel/core/tunnel_network_settings.dart';
import 'package:voidtunnel/core/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidtunnel.vpn/service');
  const stateChannel = MethodChannel('org.voidtunnel.vpn/state');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, null);
  });

  test(
    'server selection while reconnecting sends latest native config',
    () async {
      final starts = <Map<dynamic, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(serviceChannel, (call) async {
            switch (call.method) {
              case 'prepareVpn':
                return true;
              case 'startVpn':
                starts.add(Map<dynamic, dynamic>.from(call.arguments as Map));
                return true;
              default:
                return null;
            }
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(stateChannel, (_) async => null);

      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      await repository.saveNotificationPermissionAsked(true);
      await repository.saveSelected('A');
      await repository.saveServers([
        _server('A', 'a.example.com'),
        _server('B', 'b.example.com'),
      ]);
      await repository.saveRoutingPresets([
        RoutingPreset.main(),
        RoutingPreset(
          id: 'b-only',
          name: 'B only',
          appRoutingPolicy: const AppRoutingPolicy(
            mode: AppRoutingMode.proxy,
            proxyPackages: {'com.video.app'},
          ),
          routingRules: const [],
          serverNames: {'B'},
        ),
      ]);

      final controller = VpnController(repository);
      await controller.bootstrap();

      await controller.connect();
      expect(controller.connectionState, VpnConnectionState.connecting);
      expect(starts, hasLength(1));
      expect(starts.single['server'], 'a.example.com');
      expect(starts.single['appRoutingMode'], 'off');

      await controller.selectServer('B');

      expect(starts, hasLength(2));
      expect(starts.last['server'], 'b.example.com');
      expect(starts.last['appRoutingMode'], 'proxy');
      expect(starts.last['appRoutingPackages'], contains('com.video.app'));

      controller.dispose();
    },
  );

  test(
    'node preset is used even when another preset is selected for editing',
    () async {
      final starts = <Map<dynamic, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(serviceChannel, (call) async {
            switch (call.method) {
              case 'prepareVpn':
                return true;
              case 'startVpn':
                starts.add(Map<dynamic, dynamic>.from(call.arguments as Map));
                return true;
              default:
                return null;
            }
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(stateChannel, (_) async => null);

      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      await repository.saveNotificationPermissionAsked(true);
      await repository.saveSelected('B');
      await repository.saveSelectedRoutingPresetId(RoutingPreset.mainId);
      await repository.saveServers([
        _server('A', 'a.example.com'),
        _server('B', 'b.example.com'),
      ]);
      await repository.saveRoutingPresets([
        RoutingPreset.main(),
        RoutingPreset(
          id: 'b-only',
          name: 'B only',
          appRoutingPolicy: const AppRoutingPolicy(
            mode: AppRoutingMode.bypass,
            bypassPackages: {'com.chat.app'},
          ),
          routingRules: const [],
          serverNames: {'B'},
        ),
      ]);

      final controller = VpnController(repository);
      await controller.bootstrap();

      expect(controller.selectedRoutingPresetId, RoutingPreset.mainId);

      await controller.connect();

      expect(starts, hasLength(1));
      expect(starts.single['server'], 'b.example.com');
      expect(starts.single['appRoutingMode'], 'bypass');
      expect(starts.single['appRoutingPackages'], contains('com.chat.app'));
      expect(starts.single['routingPresetId'], 'b-only');
      expect(starts.single['routingPresetEditorId'], RoutingPreset.mainId);

      await controller.selectRoutingPreset('b-only');

      expect(starts, hasLength(1));

      controller.dispose();
    },
  );

  test('node preset binding tolerates normalized server names', () async {
    final starts = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (call) async {
          switch (call.method) {
            case 'prepareVpn':
              return true;
            case 'startVpn':
              starts.add(Map<dynamic, dynamic>.from(call.arguments as Map));
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, (_) async => null);

    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveNotificationPermissionAsked(true);
    await repository.saveSelected('B ');
    await repository.saveServers([_server('B ', 'b.example.com')]);
    await repository.saveSelectedRoutingPresetId(RoutingPreset.mainId);
    await repository.saveRoutingPresets([
      RoutingPreset.main(),
      RoutingPreset(
        id: 'b-only',
        name: 'B only',
        appRoutingPolicy: const AppRoutingPolicy(
          mode: AppRoutingMode.bypass,
          bypassPackages: {'com.chat.app'},
        ),
        routingRules: const [],
        serverNames: {'B'},
      ),
    ]);

    final controller = VpnController(repository);
    await controller.bootstrap();
    await controller.connect();

    expect(starts, hasLength(1));
    expect(starts.single['server'], 'b.example.com');
    expect(starts.single['appRoutingMode'], 'bypass');
    expect(starts.single['routingPresetId'], 'b-only');

    controller.dispose();
  });

  test(
    'restart-on-settings-change defers network settings reconnect until exit',
    () async {
      final starts = <Map<dynamic, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(serviceChannel, (call) async {
            switch (call.method) {
              case 'prepareVpn':
                return true;
              case 'startVpn':
                starts.add(Map<dynamic, dynamic>.from(call.arguments as Map));
                return true;
              default:
                return null;
            }
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(stateChannel, (_) async => null);

      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      await repository.saveNotificationPermissionAsked(true);
      await repository.saveRestartConnectionOnSettingsChanges(true);
      await repository.saveSelected('A');
      await repository.saveServers([_server('A', 'a.example.com')]);

      final controller = VpnController(repository);
      await controller.bootstrap();
      await controller.connect();

      expect(starts, hasLength(1));
      expect(starts.single['blockUdp'], isFalse);

      await controller.setTunnelNetworkSettings(
        TunnelNetworkSettings.defaults.copyWith(blockUdp: true),
      );

      expect(starts, hasLength(1));

      await controller.applyPendingNetworkSettingsRestart();

      expect(starts, hasLength(2));
      expect(starts.last['blockUdp'], isTrue);

      controller.dispose();
    },
  );

  test('restart-on-settings-change toggle gates deferred reconnects', () async {
    final starts = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (call) async {
          switch (call.method) {
            case 'prepareVpn':
              return true;
            case 'startVpn':
              starts.add(Map<dynamic, dynamic>.from(call.arguments as Map));
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, (_) async => null);

    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveNotificationPermissionAsked(true);
    await repository.saveSelected('A');
    await repository.saveServers([_server('A', 'a.example.com')]);

    final controller = VpnController(repository);
    await controller.bootstrap();
    await controller.connect();

    await controller.setTunnelNetworkSettings(
      TunnelNetworkSettings.defaults.copyWith(blockUdp: true),
    );
    await controller.applyPendingNetworkSettingsRestart();

    expect(starts, hasLength(1));

    controller.dispose();
  });

  test('immediate reconnect clears pending settings reconnect', () async {
    final starts = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (call) async {
          switch (call.method) {
            case 'prepareVpn':
              return true;
            case 'startVpn':
              starts.add(Map<dynamic, dynamic>.from(call.arguments as Map));
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, (_) async => null);

    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveNotificationPermissionAsked(true);
    await repository.saveRestartConnectionOnSettingsChanges(true);
    await repository.saveSelected('A');
    await repository.saveServers([_server('A', 'a.example.com')]);

    final controller = VpnController(repository);
    await controller.bootstrap();
    await controller.connect();

    await controller.setTunnelNetworkSettings(
      TunnelNetworkSettings.defaults.copyWith(blockUdp: true),
    );
    expect(starts, hasLength(1));

    await controller.setTunEngineMode(TunEngineMode.xray);
    expect(starts, hasLength(2));

    await controller.applyPendingNetworkSettingsRestart();
    expect(starts, hasLength(2));

    controller.dispose();
  });
}

ServerConfig _server(String name, String address) {
  return ServerConfig(
    name: name,
    address: address,
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
  );
}
