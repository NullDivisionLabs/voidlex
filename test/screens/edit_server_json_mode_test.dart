import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/server_config_exporter.dart';
import 'package:voidlex/core/tun_engine_mode.dart';
import 'package:voidlex/core/vpn_controller.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/edit_server_screen.dart';
import 'package:voidlex/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['state', 'speed', 'geodata_progress']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('org.voidlex.vpn/$name'),
            (_) async => null,
          );
    }
  });

  tearDown(() {
    for (final name in ['state', 'speed', 'geodata_progress']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('org.voidlex.vpn/$name'),
            null,
          );
    }
  });

  for (final transport in VlessTransport.values) {
    testWidgets('visible $transport fields survive save and native mapping', (
      tester,
    ) async {
      final server = _server().copyWith(
        transport: transport,
        security: VlessSecurity.tls,
        flow: '',
        realityPublicKey: '',
        sni: 'old.sni.example',
        alpn: 'h2',
        transportHost: 'old.host.example',
        transportPath: '/old-route',
        transportServiceName: 'old-service',
      );
      final controller = await _controllerWith(server);
      await tester.pumpWidget(_testApp(controller, server));
      await tester.pump();
      final changes = <String, String>{
        'Old node': 'Edited node',
        'old.example.com': 'edited.example.com',
        '443': '8443',
        '00000000-0000-0000-0000-000000000000':
            '11111111-1111-4111-8111-111111111111',
        'old.sni.example': 'new.sni.example',
        'h2': 'h2,http/1.1',
        if (transport == VlessTransport.grpc) 'old-service': 'new-service',
        if (transport != VlessTransport.tcp &&
            transport != VlessTransport.grpc) ...{
          'old.host.example': 'new.host.example',
          '/old-route': '/new-route',
        },
      };
      for (final change in changes.entries) {
        final field = find.byWidgetPredicate(
          (w) => w is TextFormField && w.controller?.text == change.key,
        );
        expect(
          field,
          findsOneWidget,
          reason: '${transport.name}: ${change.key}',
        );
        await tester.enterText(field, change.value);
      }
      _press(tester, find.widgetWithIcon(IconButton, Icons.save_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      final saved = controller.updatedServer!;
      await tester.runAsync(() => controller.repository.saveServers([saved]));
      final restored = controller.repository.load().servers.single;
      expect(restored.name, 'Edited node');
      expect(restored.address, 'edited.example.com');
      expect(restored.port, 8443);
      expect(restored.uuid, '11111111-1111-4111-8111-111111111111');
      expect(restored.sni, 'new.sni.example');
      expect(restored.alpn, 'h2,http/1.1');
      expect(restored.transport, transport);
      final args = restored.toNativeArgs(
        isGlobalProxy: true,
        tunEngineMode: TunEngineMode.libbox,
      );
      expect(args['server'], restored.address);
      expect(args['serverPort'], restored.port);
      expect(args['uuid'], restored.uuid);
      expect(args['transport'], transport.wireName);
      expect(args['tlsSni'], restored.sni);
      if (transport == VlessTransport.grpc) {
        expect(args['transportServiceName'], 'new-service');
      }
      if (transport != VlessTransport.tcp && transport != VlessTransport.grpc) {
        expect(args['transportPath'], '/new-route');
        expect(args['transportHost'], 'new.host.example');
      }
      final exported =
          jsonDecode(ServerConfigExporter.toXrayJson(restored)) as Map;
      final proxy = (exported['outbounds'] as List).first as Map;
      final endpoint =
          ((proxy['settings'] as Map)['vnext'] as List).first as Map;
      expect(endpoint['address'], restored.address);
      expect(endpoint['port'], restored.port);
      final stream = proxy['streamSettings'] as Map;
      expect((stream['tlsSettings'] as Map)['serverName'], restored.sni);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  for (final protocol in ServerProtocol.values) {
    testWidgets(
      'JSON to form to storage and export preserves $protocol draft',
      (tester) async {
        final server = _server();
        final controller = await _controllerWith(server);
        await tester.pumpWidget(_testApp(controller, server));
        await tester.pump();
        final toggle = find.byKey(const ValueKey('edit-server-json-toggle'));
        _press(tester, toggle);
        await tester.pump();
        final draft = server.copyWith(
          serverProtocol: protocol,
          transport: protocol == ServerProtocol.vless
              ? VlessTransport.xhttp
              : VlessTransport.tcp,
          security: protocol == ServerProtocol.vless
              ? VlessSecurity.reality
              : VlessSecurity.tls,
          flow: '',
          transportMode: 'packet-up',
          fingerprint: 'hellosafari_16_0',
          xhttpRawSettings: {
            'customSettings': {'enabled': true},
          },
          xhttpRawExtra: {'scMaxConcurrentPosts': 4},
          hysteria2RawOutbound: {'custom_outbound': 123},
          hysteria2RawObfs: {'custom_obfs': true},
          hysteria2RawTls: {
            'pin_sha256': ['pin'],
          },
          naiveUsername: 'user',
          naivePassword: 'password',
          naiveExtraHeaders: {'X-Test': 'value'},
        );
        await tester.enterText(
          find.byKey(const ValueKey('edit-server-json-editor')),
          jsonEncode(draft.toJson()),
        );
        _press(tester, toggle);
        await tester.pump();
        // Edit a visible field after leaving JSON mode. The old implementation
        // discarded hidden JSON edits by copying the original node here.
        final addressField = find.widgetWithText(
          TextFormField,
          'old.example.com',
        );
        await tester.enterText(addressField, 'form.example.com');
        _press(tester, toggle);
        await tester.pump();
        final editor = find.byKey(const ValueKey('edit-server-json-editor'));
        final secondJson =
            jsonDecode(tester.widget<TextField>(editor).controller!.text)
                as Map;
        expect(secondJson['address'], 'form.example.com');
        _press(tester, toggle);
        await tester.pump();
        _press(tester, find.widgetWithIcon(IconButton, Icons.save_rounded));
        await tester.pump(const Duration(milliseconds: 100));
        final saved = controller.updatedServer!;
        await tester.runAsync(() => controller.repository.saveServers([saved]));
        final reopened = controller.repository.load().servers.single;
        expect(reopened.toJson(), saved.toJson());
        expect(reopened.address, 'form.example.com');
        final args = reopened.toNativeArgs(
          isGlobalProxy: true,
          tunEngineMode: TunEngineMode.libbox,
        );
        expect(args['server'], 'form.example.com');
        final exported =
            jsonDecode(ServerConfigExporter.toXrayJson(reopened)) as Map;
        final outbound = (exported['outbounds'] as List).first as Map;
        switch (protocol) {
          case ServerProtocol.vless:
            expect(reopened.fingerprint, 'hellosafari_16_0');
            expect(args['fp'], 'hellosafari_16_0');
            expect(reopened.xhttpRawSettings, draft.xhttpRawSettings);
            expect(reopened.xhttpRawExtra, draft.xhttpRawExtra);
            final stream = outbound['streamSettings'] as Map;
            expect(
              (stream['realitySettings'] as Map)['fingerprint'],
              'hellosafari_16_0',
            );
            expect(
              ((stream['xhttpSettings'] as Map)['extra']
                  as Map)['scMaxConcurrentPosts'],
              4,
            );
          case ServerProtocol.hysteria2:
            expect(reopened.hysteria2RawOutbound, draft.hysteria2RawOutbound);
            expect(reopened.hysteria2RawObfs, draft.hysteria2RawObfs);
            expect(reopened.hysteria2RawTls, draft.hysteria2RawTls);
            expect(outbound['custom_outbound'], 123);
            expect((outbound['tls'] as Map)['pin_sha256'], ['pin']);
          case ServerProtocol.naive:
            expect(reopened.naiveExtraHeaders, {'X-Test': 'value'});
            expect(outbound['extra_headers'], {'X-Test': 'value'});
        }
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  testWidgets(
    'JSON toggle keeps app bar actions and applies JSON to the form',
    (tester) async {
      final server = _server();
      final controller = await _controllerWith(server);
      await tester.pumpWidget(_testApp(controller, server));
      await tester.pump();

      final toggle = find.byKey(const ValueKey('edit-server-json-toggle'));
      _press(tester, toggle);
      await tester.pump();

      final editor = find.byKey(const ValueKey('edit-server-json-editor'));
      expect(editor, findsOneWidget);
      expect(find.byIcon(Icons.file_upload_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.save_rounded), findsOneWidget);

      final jsonController = tester.widget<TextField>(editor).controller!;
      expect(jsonController.text, contains('"address": "old.example.com"'));
      expect(jsonController.text, contains('"flow": "xtls-rprx-vision"'));

      final edited = Map<String, dynamic>.of(server.toJson())
        ..['address'] = 'json.example.com'
        ..['flow'] = 'xtls-rprx-vision-udp443';
      await tester.enterText(editor, jsonEncode(edited));
      _press(tester, toggle);
      await tester.pump();

      expect(
        find.widgetWithText(TextFormField, 'json.example.com'),
        findsOneWidget,
      );
      expect(find.text('xtls-rprx-vision-udp443'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'save validates and persists the server directly from JSON mode',
    (tester) async {
      final server = _server();
      final controller = await _controllerWith(server);
      await tester.pumpWidget(_testApp(controller, server));
      await tester.pump();

      final toggle = find.byKey(const ValueKey('edit-server-json-toggle'));
      _press(tester, toggle);
      await tester.pump();
      final editor = find.byKey(const ValueKey('edit-server-json-editor'));
      final save = find.widgetWithIcon(IconButton, Icons.save_rounded);

      await tester.enterText(editor, '{}');
      _press(tester, save);
      await tester.pump();
      expect(
        find.text(
          'JSON must contain exactly one valid supported server configuration.',
        ),
        findsOneWidget,
      );
      expect(controller.updatedServer, isNull);

      final edited = Map<String, dynamic>.of(server.toJson())
        ..['name'] = 'JSON node'
        ..['address'] = 'saved.example.com';
      await tester.enterText(editor, jsonEncode(edited));
      _press(tester, save);
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.updatedServer?.name, 'JSON node');
      expect(controller.updatedServer?.address, 'saved.example.com');
      expect(controller.updatedServer?.isPinned, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'JSON editor displays line numbers, ruling, and indicates syntax errors with line/column',
    (tester) async {
      final server = _server();
      final controller = await _controllerWith(server);
      await tester.pumpWidget(_testApp(controller, server));
      await tester.pump();

      final toggle = find.byKey(const ValueKey('edit-server-json-toggle'));
      _press(tester, toggle);
      await tester.pump();

      // Check that line numbers are present in the gutter
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);

      // Enter syntax error: missing colon
      final editor = find.byKey(const ValueKey('edit-server-json-editor'));
      await tester.enterText(editor, '{\n  "name" "broken"\n}');
      await tester.pump();

      // Should display exact line and column
      expect(find.textContaining('Line 2, col 10:'), findsOneWidget);
      expect(find.text('L2:C10'), findsOneWidget);

      // Format button should be disabled during syntax error
      final formatBtn = find.widgetWithIcon(IconButton, Icons.auto_fix_high_rounded);
      expect(formatBtn, findsOneWidget);
      expect(tester.widget<IconButton>(formatBtn).onPressed, isNull);

      // Fix syntax error and click format
      await tester.enterText(
        editor,
        '{"name":"fixed","address":"test.com","port":443,"serverProtocol":"vless","uuid":"00000000-0000-0000-0000-000000000000"}',
      );
      await tester.pump();

      expect(tester.widget<IconButton>(formatBtn).onPressed, isNotNull);
      _press(tester, formatBtn);
      await tester.pump();

      final formattedText = tester.widget<TextField>(editor).controller!.text;
      expect(formattedText, contains('{\n  "name": "fixed",'));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

Future<_TestVpnController> _controllerWith(ServerConfig server) async {
  final prefs = await SharedPreferences.getInstance();
  final repository = ServerRepository(prefs);
  return _TestVpnController(repository);
}

Widget _testApp(VpnController controller, ServerConfig server) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: EditServerScreen(controller: controller, server: server),
  );
}

void _press(WidgetTester tester, Finder finder) {
  tester.widget<IconButton>(finder).onPressed!();
}

ServerConfig _server() {
  return const ServerConfig(
    name: 'Old node',
    address: 'old.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.reality,
    flow: 'xtls-rprx-vision',
    realityPublicKey: 'public-key',
    isPinned: true,
  );
}

class _TestVpnController extends VpnController {
  _TestVpnController(super.repository);

  ServerConfig? updatedServer;

  @override
  Future<String?> updateServer({
    required String originalName,
    required ServerConfig updatedServer,
  }) async {
    this.updatedServer = updatedServer;
    return null;
  }
}
