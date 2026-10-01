import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_latency_probe.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = MethodChannel('org.voidlex.vpn/service');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({'void.urlProbeResultsVersion': 1});
    for (final name in ['state', 'speed', 'geodata_progress']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('org.voidlex.vpn/$name'),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(service, (_) async => null);
  });
  tearDown(() {
    for (final name in ['service', 'state', 'speed', 'geodata_progress']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('org.voidlex.vpn/$name'),
        null,
      );
    }
  });

  Future<VpnController> controllerFor(ServerConfig server) async {
    final repository = ServerRepository(await SharedPreferences.getInstance());
    await repository.saveServers([server]);
    final controller = VpnController(repository);
    await controller.bootstrap();
    addTearDown(controller.dispose);
    return controller;
  }

  test(
    'default URL and disabled menu, choices survive restart and reset pings',
    () async {
      final controller = await controllerFor(_server(1));
      expect(controller.nodeDiagnosticMode, NodeDiagnosticMode.url);
      expect(controller.nodeDiagnosticMenuEnabled, false);
      expect(controller.pingForServer('Node'), '27 ms');
      await controller.setNodeDiagnosticMode(NodeDiagnosticMode.tcp);
      await controller.setNodeDiagnosticMenuEnabled(true);
      expect(controller.pingForServer('Node'), '--');
      expect(controller.alternateNodeDiagnosticMode, NodeDiagnosticMode.url);
      final reopened = VpnController(controller.repository);
      await reopened.bootstrap();
      addTearDown(reopened.dispose);
      expect(reopened.nodeDiagnosticMode, NodeDiagnosticMode.tcp);
      expect(reopened.nodeDiagnosticMenuEnabled, true);
      await reopened.setNodeDiagnosticMode(NodeDiagnosticMode.url);
      expect(reopened.alternateNodeDiagnosticMode, NodeDiagnosticMode.tcp);
      await reopened.setNodeDiagnosticMenuEnabled(false);
      expect(reopened.repository.load().nodeDiagnosticMenuEnabled, false);
    },
  );

  test(
    'TCP scan dials configured endpoint and explicit URL does not overwrite it',
    () async {
      final endpoint = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      var tcpConnections = 0;
      final subscription = endpoint.listen((socket) {
        tcpConnections++;
        socket.destroy();
      });
      addTearDown(() async {
        await subscription.cancel();
        await endpoint.close();
      });
      var urlCalls = 0;
      messenger.setMockMethodCallHandler(service, (call) async {
        if (call.method == 'probeServerUrl') {
          urlCalls++;
          return {
            'requestId': (call.arguments as Map)['requestId'],
            'status': 'error',
            'detail': 'HTTP 403',
          };
        }
        return null;
      });
      final controller = await controllerFor(_server(endpoint.port));
      await controller.setNodeDiagnosticMode(NodeDiagnosticMode.tcp);
      await controller.scanManualLatencies();
      final ping = controller.pingForServer('Node');
      expect(ping, matches(r'^\d+ ms$'));
      expect(urlCalls, 0);
      final diagnostic = await controller.diagnoseServerUrl(
        controller.manualServers.single,
      );
      expect(diagnostic.status, 'error');
      expect(diagnostic.detail, 'HTTP 403');
      expect(urlCalls, 1);
      expect(controller.pingForServer('Node'), ping);
      expect(controller.isScanningLatency, false);
      await controller.setUrlProbeUrl('https://example.com/test');
      expect(controller.pingForServer('Node'), ping);
      await controller.setLatencyProbeTarget(
        LatencyProbeTarget.custom(host: '127.0.0.1', port: endpoint.port),
      );
      expect(controller.pingForServer('Node'), '--');
      await Future<void>.delayed(Duration.zero);
      expect(tcpConnections, greaterThan(0));
    },
  );

  test(
    'URL scan uses native outbound and explicit TCP leaves its result alone',
    () async {
      final endpoint = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = endpoint.listen((socket) => socket.destroy());
      addTearDown(() async {
        await subscription.cancel();
        await endpoint.close();
      });
      messenger.setMockMethodCallHandler(
        service,
        (call) async => call.method == 'probeServerUrl'
            ? {
                'requestId': (call.arguments as Map)['requestId'],
                'status': 'ok',
                'latencyMs': 55,
              }
            : null,
      );
      final controller = await controllerFor(_server(endpoint.port));
      await controller.scanManualLatencies();
      expect(controller.pingForServer('Node'), '55 ms');
      expect(
        await controller.diagnoseServerTcp(controller.manualServers.single),
        matches(r'^\d+ ms$'),
      );
      expect(controller.pingForServer('Node'), '55 ms');
    },
  );

  test('switching default during URL scan drops the old reply', () async {
    final started = Completer<Map>();
    final pending = Completer<Map>();
    messenger.setMockMethodCallHandler(service, (call) async {
      if (call.method == 'probeServerUrl') {
        started.complete(call.arguments as Map);
        return pending.future;
      }
      return null;
    });
    final controller = await controllerFor(_server(1));
    final scan = controller.scanManualLatencies();
    final args = await started.future;
    await controller.setNodeDiagnosticMode(NodeDiagnosticMode.tcp);
    pending.complete({
      'requestId': args['requestId'],
      'status': 'ok',
      'latencyMs': 1,
    });
    await scan;
    expect(controller.pingForServer('Node'), '--');
    expect(controller.repository.load().servers.single.ping, '--');
  });
}

ServerConfig _server(int port) => ServerConfig(
  name: 'Node',
  address: '127.0.0.1',
  port: port,
  uuid: '00000000-0000-0000-0000-000000000000',
  transport: VlessTransport.tcp,
  security: VlessSecurity.none,
  ping: '27 ms',
);
