import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';

const service = MethodChannel('org.voidlex.vpn/service');
const state = MethodChannel('org.voidlex.vpn/state');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(state, (_) async => null);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(service, null);
    messenger.setMockMethodCallHandler(state, null);
  });

  test(
    'first connected event starts the active connection URL probe',
    () async {
      messenger.setMockMethodCallHandler(service, (_) async => null);
      final controller = await _controller();
      addTearDown(controller.dispose);
      Future<void> emit(String value) async {
        await messenger.handlePlatformMessage(
          state.name,
          const StandardMethodCodec().encodeSuccessEnvelope({'state': value}),
          (_) {},
        );
        await Future<void>.delayed(Duration.zero);
      }

      await emit('connecting');
      expect(controller.activeConnectionPing, '--');
      await emit('connected');
      expect(controller.connectionState, VpnConnectionState.connected);
      expect(controller.activeConnectionPing, isNot('--'));
      await emit('disconnected');
      expect(controller.activeConnectionPing, '--');
    },
  );

  test(
    'two independent probes, no entry hop, credentials and fp retained',
    () async {
      var active = 0;
      var peak = 0;
      final args = <Map>[];
      messenger.setMockMethodCallHandler(service, (call) async {
        if (call.method != 'probeServerUrl') return null;
        final data = call.arguments as Map;
        args.add(data);
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        active--;
        return {
          'requestId': data['requestId'],
          'status': 'ok',
          'latencyMs': 42,
        };
      });
      final controller = await _controller(count: 4);
      await controller.scanManualLatencies();
      expect(peak, 2);
      expect(args, hasLength(4));
      expect(args.map((a) => a['requestId']).toSet(), hasLength(4));
      for (final data in args) {
        expect(data['isGlobalProxy'], true);
        expect(data['fp'], 'hellosafari_16_0');
        expect(data['uuid'], '00000000-0000-0000-0000-000000000000');
        expect(data.containsKey('entryServer'), false);
      }
      expect(
        controller.manualServers.map((n) => n.ping),
        everyElement('42 ms'),
      );
      expect(controller.activeConnectionPing, '--');
      controller.dispose();
    },
  );

  test(
    'editing config discards a late success and invalidates saved ping',
    () async {
      final pending = Completer<Map>();
      final began = Completer<Map>();
      messenger.setMockMethodCallHandler(service, (call) async {
        if (call.method == 'probeServerUrl') {
          began.complete(call.arguments as Map);
          return pending.future;
        }
        return null;
      });
      final controller = await _controller();
      final scan = controller.scanManualLatencies();
      final args = await began.future;
      final old = controller.manualServers.single;
      final notifier = controller.pingListenableFor(old.name);
      await controller.updateServer(
        originalName: old.name,
        updatedServer: old.copyWith(fingerprint: 'helloios_14'),
      );
      expect(controller.pingForServer(old.name), '--');
      expect(notifier.value, '--');
      pending.complete({
        'requestId': args['requestId'],
        'status': 'ok',
        'latencyMs': 1,
      });
      await scan;
      expect(controller.manualServers.single.ping, '--');
      expect(
        controller.repository.load().servers.single.fingerprint,
        'helloios_14',
      );
      controller.dispose();
    },
  );

  test('TCP results from older app versions are invalidated once', () async {
    messenger.setMockMethodCallHandler(service, (_) async => null);
    final controller = await _controller();
    expect(controller.manualServers.single.ping, '--');
    expect(controller.repository.hasUrlProbeResults, isTrue);
    controller.dispose();
  });

  test('cancel drops late replies and clears unfinished rows', () async {
    final pending = Completer<Map>();
    final began = Completer<Map>();
    messenger.setMockMethodCallHandler(service, (call) async {
      if (call.method == 'probeServerUrl') {
        began.complete(call.arguments as Map);
        return pending.future;
      }
      return null;
    });
    final controller = await _controller();
    final scan = controller.scanManualLatencies();
    final args = await began.future;
    await controller.cancelUrlProbes();
    expect(controller.pingForServer('Node 0'), '--');
    pending.complete({
      'requestId': args['requestId'],
      'status': 'ok',
      'latencyMs': 1,
    });
    await scan;
    expect(controller.manualServers.single.ping, '--');
    controller.dispose();
  });

  test('unsupported platform is neutral and never calls TCP', () async {
    messenger.setMockMethodCallHandler(service, (call) async {
      if (call.method == 'probeServerUrl') throw MissingPluginException();
      return null;
    });
    final controller = await _controller();
    await controller.scanManualLatencies();
    expect(controller.manualServers.single.ping, 'N/A');
    controller.dispose();
  });

  for (final restart in [false, true]) {
    for (final index in [0, 1]) {
      test(
        'edit ${index == 0 ? 'entry' : 'exit'} hop, auto-reconnect=$restart',
        () async {
          final starts = <Map>[];
          messenger.setMockMethodCallHandler(service, (call) async {
            if (call.method == 'prepareVpn') return true;
            if (call.method == 'startVpn') {
              starts.add(call.arguments as Map);
              return true;
            }
            return null;
          });
          final controller = await _controller(
            count: 2,
            exit: true,
            restart: restart,
          );
          await controller.connect();
          expect(starts, hasLength(1));
          final old = controller.manualServers[index];
          await controller.updateServer(
            originalName: old.name,
            updatedServer: old.copyWith(address: 'edited.example.com'),
          );
          expect(starts, hasLength(restart ? 2 : 1));
          if (restart) {
            expect(
              starts.last[index == 1 ? 'server' : 'entryServer'],
              'edited.example.com',
            );
          }
          controller.dispose();
        },
      );
    }
  }
}

Future<VpnController> _controller({
  int count = 1,
  bool exit = false,
  bool restart = false,
}) async {
  final repository = ServerRepository(await SharedPreferences.getInstance());
  await repository.saveNotificationPermissionAsked(true);
  await repository.saveRestartConnectionOnSettingsChanges(restart);
  await repository.saveServers(
    List.generate(
      count,
      (index) => ServerConfig(
        name: 'Node $index',
        address: 'node$index.example.com',
        port: 443,
        uuid: '00000000-0000-0000-0000-000000000000',
        transport: VlessTransport.tcp,
        security: VlessSecurity.tls,
        fingerprint: 'hellosafari_16_0',
        ping: '7 ms',
      ),
    ),
  );
  await repository.saveSelected('Node 0');
  if (exit) await repository.saveExitNodeName('Node 1');
  final controller = VpnController(repository);
  await controller.bootstrap();
  return controller;
}
