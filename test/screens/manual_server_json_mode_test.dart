import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_config_exporter.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/manual_server_input_screen.dart';
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

  for (final protocol in [ServerProtocol.vless, ServerProtocol.hysteria2]) {
    for (final saveAsJson in [false, true]) {
      testWidgets(
        'manual $protocol JSON draft retains hidden fields when saved from ${saveAsJson ? 'JSON' : 'form'}',
        (tester) async {
          final controller = await _testController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(_testApp(controller));
          await tester.pump();
          final toggle = find.byKey(
            const ValueKey('manual-server-json-toggle'),
          );
          _press(tester, toggle);
          await tester.pump();
          final draft = ServerConfig(
            name: 'Draft node',
            address: 'draft.example.com',
            port: 443,
            uuid: '22222222-2222-4222-8222-222222222222',
            serverProtocol: protocol,
            transport: protocol == ServerProtocol.vless
                ? VlessTransport.xhttp
                : VlessTransport.tcp,
            security: VlessSecurity.tls,
            xhttpRawSettings: const {'noGRPCHeader': true},
            xhttpRawExtra: const {'scMaxConcurrentPosts': 4},
            hysteria2RawOutbound: const {'custom_outbound': 123},
            hysteria2RawObfs: const {'custom_obfs': true},
            hysteria2RawTls: const {
              'pin_sha256': ['pin'],
            },
          );
          final editor = find.byKey(const ValueKey('edit-server-json-editor'));
          await tester.enterText(editor, jsonEncode(draft.toJson()));
          _press(tester, toggle);
          await tester.pump();
          await tester.enterText(
            find.widgetWithText(TextFormField, 'draft.example.com'),
            'form.example.com',
          );
          if (saveAsJson) {
            _press(tester, toggle);
            await tester.pump();
            final regenerated =
                jsonDecode(tester.widget<TextField>(editor).controller!.text)
                    as Map;
            expect(regenerated['address'], 'form.example.com');
            if (protocol == ServerProtocol.vless) {
              expect(regenerated['xhttpRawExtra'], draft.xhttpRawExtra);
            } else {
              expect(regenerated['hysteria2RawTls'], draft.hysteria2RawTls);
            }
          }
          _pressText(tester, find.widgetWithText(TextButton, 'Add'));
          await tester.pump(const Duration(milliseconds: 100));
          final saved = controller.addedServer!;
          await tester.runAsync(
            () => controller.repository.saveServers([saved]),
          );
          final restored = controller.repository.load().servers.single;
          expect(restored.address, 'form.example.com');
          final exported =
              jsonDecode(ServerConfigExporter.toXrayJson(restored)) as Map;
          final outbound = (exported['outbounds'] as List).first as Map;
          if (protocol == ServerProtocol.vless) {
            expect(restored.xhttpRawSettings, draft.xhttpRawSettings);
            expect(restored.xhttpRawExtra, draft.xhttpRawExtra);
            final stream = outbound['streamSettings'] as Map;
            expect(
              ((stream['xhttpSettings'] as Map)['extra']
                  as Map)['scMaxConcurrentPosts'],
              4,
            );
          } else {
            expect(restored.hysteria2RawOutbound, draft.hysteria2RawOutbound);
            expect(restored.hysteria2RawObfs, draft.hysteria2RawObfs);
            expect(restored.hysteria2RawTls, draft.hysteria2RawTls);
            expect(outbound['custom_outbound'], 123);
            expect((outbound['tls'] as Map)['pin_sha256'], ['pin']);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'ManualServerInputScreen JSON mode allows creating server and toggles form',
    (tester) async {
      final controller = await _testController();
      await tester.pumpWidget(_testApp(controller));
      await tester.pump();

      // Check toggle button exists in AppBar
      final toggle = find.byKey(const ValueKey('manual-server-json-toggle'));
      expect(toggle, findsOneWidget);

      // Switch to JSON mode
      _press(tester, toggle);
      await tester.pump();

      // Check that editor is displayed
      final editor = find.byKey(const ValueKey('edit-server-json-editor'));
      expect(editor, findsOneWidget);

      // Gutter lines are visible
      expect(find.text('1'), findsWidgets);

      // Try saving with syntax error
      await tester.enterText(editor, '{\n  "name" "missing colon"\n}');
      await tester.pump();

      expect(find.textContaining('Line 2, col 10:'), findsOneWidget);

      final addBtn = find.widgetWithText(TextButton, 'Add');
      expect(addBtn, findsOneWidget);
      _pressText(tester, addBtn);
      await tester.pump();

      // Server should not be added
      expect(controller.addedServer, isNull);

      // Now enter valid VLESS JSON
      const validJson = '''{
  "name": "Manual JSON Node",
  "address": "manual.example.com",
  "port": 8443,
  "serverProtocol": "vless",
  "transport": "tcp",
  "security": "reality",
  "uuid": "22222222-2222-4222-8222-222222222222",
  "flow": "xtls-rprx-vision",
  "realityPublicKey": "manual-public-key"
}''';

      await tester.enterText(editor, validJson);
      await tester.pump();

      // Toggle back to form mode to verify fields populated
      _press(tester, toggle);
      await tester.pump();

      expect(
        find.widgetWithText(TextFormField, 'Manual JSON Node'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'manual.example.com'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, '8443'), findsOneWidget);

      // Toggle back to JSON mode and save
      _press(tester, toggle);
      await tester.pump();

      _pressText(tester, addBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.addedServer?.name, 'Manual JSON Node');
      expect(controller.addedServer?.address, 'manual.example.com');
      expect(controller.addedServer?.port, 8443);
      expect(
        controller.addedServer?.uuid,
        '22222222-2222-4222-8222-222222222222',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

Future<_ManualTestVpnController> _testController() async {
  final prefs = await SharedPreferences.getInstance();
  final repository = ServerRepository(prefs);
  return _ManualTestVpnController(repository);
}

Widget _testApp(VpnController controller) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ManualServerInputScreen(controller: controller),
  );
}

void _press(WidgetTester tester, Finder finder) {
  tester.widget<IconButton>(finder).onPressed!();
}

void _pressText(WidgetTester tester, Finder finder) {
  tester.widget<TextButton>(finder).onPressed!();
}

class _ManualTestVpnController extends VpnController {
  _ManualTestVpnController(super.repository);

  ServerConfig? addedServer;

  @override
  Future<String?> addServer(ServerConfig server) async {
    addedServer = server;
    return null;
  }
}
