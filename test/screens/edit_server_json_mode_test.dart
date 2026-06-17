import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_repository.dart';
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
  });

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
