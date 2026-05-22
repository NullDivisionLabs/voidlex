import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidtunnel/core/app_routing.dart';
import 'package:voidtunnel/core/deep_link_channel.dart';
import 'package:voidtunnel/core/installed_apps.dart';
import 'package:voidtunnel/core/models/server_config.dart';
import 'package:voidtunnel/core/models/server_subscription.dart';
import 'package:voidtunnel/core/profile_exporter.dart';
import 'package:voidtunnel/core/profile_importer.dart';
import 'package:voidtunnel/core/routing_preset.dart';
import 'package:voidtunnel/core/routing_rule.dart';
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

  test('replace import applies profile data and selected preset', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveServers([_server('Existing')]);
    final importedPreset = _preset('video', {'Manual A', 'Sub A'});
    final profile = ProfileExporter.exportJson(
      manualNodes: [_server('Manual A')],
      subscriptions: [_subscription(server: _server('Sub A'))],
      routingPresets: [RoutingPreset.main(), importedPreset],
      selectedRoutingPresetId: importedPreset.id,
      protectSubscriptions: false,
      exportedAt: DateTime.utc(2026, 5, 14, 10),
    );

    final controller = _controller(repository);
    await controller.bootstrap();

    final result = await controller.importProfileFromJsonString(
      profile,
      replaceExisting: true,
    );

    expect(result.manualNodeCount, 1);
    expect(result.subscriptionCount, 1);
    expect(result.routingPresetCount, 2);
    expect(controller.manualServers.map((server) => server.name), ['Manual A']);
    expect(controller.subscriptions.single.name, 'Provider');
    expect(controller.subscriptions.single.servers.single.name, 'Sub A');
    expect(controller.selectedRoutingPresetId, importedPreset.id);

    controller.dispose();
  });

  test(
    'append import deduplicates server names and remaps preset bindings',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      await repository.saveServers([_server('Manual A')]);
      final importedPreset = _preset('video', {'Manual A'});
      final profile = ProfileExporter.exportJson(
        manualNodes: [_server('Manual A')],
        subscriptions: const [],
        routingPresets: [importedPreset],
        selectedRoutingPresetId: importedPreset.id,
        protectSubscriptions: false,
        exportedAt: DateTime.utc(2026, 5, 14, 10),
      );

      final controller = _controller(repository);
      await controller.bootstrap();

      final result = await controller.importProfileFromJsonString(
        profile,
        replaceExisting: false,
      );

      expect(result.manualNodeCount, 1);
      expect(controller.manualServers.map((server) => server.name), [
        'Manual A',
        'Manual A (2)',
      ]);
      final appendedPreset = controller.routingPresets.firstWhere(
        (preset) => preset.name == 'Video',
      );
      expect(appendedPreset.serverNames, {'Manual A (2)'});

      controller.dispose();
    },
  );

  test(
    'append import converts source main preset into node-bound preset',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      await repository.saveServers([_server('Existing')]);
      final main = RoutingPreset.main(
        appRoutingPolicy: const AppRoutingPolicy(
          mode: AppRoutingMode.proxy,
          proxyPackages: {'com.video.app'},
        ),
        routingRules: [
          RoutingRule(
            id: 'rule',
            name: 'Video',
            enabled: true,
            outbound: RoutingOutbound.proxy,
            domains: const ['geosite:youtube'],
          ),
        ],
      );
      final profile = ProfileExporter.exportJson(
        manualNodes: [_server('Imported')],
        subscriptions: const [],
        routingPresets: [main],
        selectedRoutingPresetId: RoutingPreset.mainId,
        protectSubscriptions: false,
        exportedAt: DateTime.utc(2026, 5, 14, 10),
      );

      final controller = _controller(repository);
      await controller.bootstrap();

      await controller.importProfileFromJsonString(
        profile,
        replaceExisting: false,
      );

      final importedMain = controller.routingPresets.firstWhere(
        (preset) => preset.name == 'Imported Main',
      );
      expect(importedMain.isMain, isFalse);
      expect(importedMain.serverNames, {'Imported'});
      expect(importedMain.routingRules.single.name, 'Video');
      expect(importedMain.appRoutingPolicy.proxyPackages, {'com.video.app'});

      controller.dispose();
    },
  );

  test(
    'import drops per-app packages that are not installed on the device',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      final imported = RoutingPreset(
        id: 'video',
        name: 'Video',
        appRoutingPolicy: const AppRoutingPolicy(
          mode: AppRoutingMode.proxy,
          proxyPackages: {'com.installed.app', 'com.missing.app'},
          bypassPackages: {'com.also.missing'},
        ),
        routingRules: const [],
        serverNames: {'Manual A'},
      );
      final profile = ProfileExporter.exportJson(
        manualNodes: [_server('Manual A')],
        subscriptions: const [],
        routingPresets: [imported],
        selectedRoutingPresetId: imported.id,
        protectSubscriptions: false,
        exportedAt: DateTime.utc(2026, 5, 14, 10),
      );

      final controller = _controller(
        repository,
        installedAppsBridge: _FakeInstalledAppsBridge({'com.installed.app'}),
      );
      await controller.bootstrap();

      final result = await controller.importProfileFromJsonString(
        profile,
        replaceExisting: true,
      );

      expect(result.droppedAppRoutingPackageCount, 2);
      final preset = controller.routingPresets.firstWhere(
        (preset) => preset.name == 'Video',
      );
      expect(preset.appRoutingPolicy.proxyPackages, {'com.installed.app'});
      expect(preset.appRoutingPolicy.bypassPackages, isEmpty);

      controller.dispose();
    },
  );

  test(
    'import keeps packages when installed apps cannot be enumerated',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      final imported = RoutingPreset(
        id: 'video',
        name: 'Video',
        appRoutingPolicy: const AppRoutingPolicy(
          mode: AppRoutingMode.proxy,
          proxyPackages: {'com.installed.app', 'com.missing.app'},
        ),
        routingRules: const [],
        serverNames: {'Manual A'},
      );
      final profile = ProfileExporter.exportJson(
        manualNodes: [_server('Manual A')],
        subscriptions: const [],
        routingPresets: [imported],
        selectedRoutingPresetId: imported.id,
        protectSubscriptions: false,
        exportedAt: DateTime.utc(2026, 5, 14, 10),
      );

      final controller = _controller(
        repository,
        installedAppsBridge: _FakeInstalledAppsBridge(null),
      );
      await controller.bootstrap();

      final result = await controller.importProfileFromJsonString(
        profile,
        replaceExisting: true,
      );

      expect(result.droppedAppRoutingPackageCount, 0);
      final preset = controller.routingPresets.firstWhere(
        (preset) => preset.name == 'Video',
      );
      expect(preset.appRoutingPolicy.proxyPackages, {
        'com.installed.app',
        'com.missing.app',
      });

      controller.dispose();
    },
  );

  test('parser rejects non-profile JSON', () {
    expect(
      () => ProfileImportPayload.parse('{"servers":[]}'),
      throwsA(
        isA<ProfileImportException>().having(
          (error) => error.code,
          'code',
          ProfileImportError.unsupportedFormat,
        ),
      ),
    );
  });
}

VpnController _controller(
  ServerRepository repository, {
  InstalledAppsBridge? installedAppsBridge,
}) {
  return VpnController(
    repository,
    deepLinkChannel: _NoopDeepLinkChannel(),
    installedAppsBridge: installedAppsBridge,
  );
}

class _NoopDeepLinkChannel extends DeepLinkChannel {
  @override
  Future<String?> consumeInitial() async => null;

  @override
  Stream<String> get incomingLinks => const Stream.empty();
}

class _FakeInstalledAppsBridge extends InstalledAppsBridge {
  const _FakeInstalledAppsBridge(this._packageNames);

  final Set<String>? _packageNames;

  @override
  Future<Set<String>?> listPackageNames() async => _packageNames;
}

ServerConfig _server(String name) {
  return ServerConfig(
    name: name,
    address: '${name.toLowerCase().replaceAll(' ', '-')}.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
  );
}

ServerSubscription _subscription({required ServerConfig server}) {
  return ServerSubscription(
    id: 'sub-1',
    name: 'Provider',
    url: 'https://provider.example.com/sub',
    servers: [server],
  );
}

RoutingPreset _preset(String id, Set<String> serverNames) {
  return RoutingPreset(
    id: id,
    name: 'Video',
    appRoutingPolicy: AppRoutingPolicy.empty,
    routingRules: const [],
    serverNames: serverNames,
  );
}
