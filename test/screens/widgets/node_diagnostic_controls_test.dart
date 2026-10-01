import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/app_locale.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_latency_probe.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/settings_screen.dart';
import 'package:voidlex/screens/widgets/node_diagnostic_controls.dart';
import 'package:voidlex/screens/widgets/server_node_tile.dart';
import 'package:voidlex/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['service', 'state', 'speed', 'geodata_progress']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('org.voidlex.vpn/$name'),
            (_) async => null,
          );
    }
  });
  tearDown(() {
    for (final name in ['service', 'state', 'speed', 'geodata_progress']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('org.voidlex.vpn/$name'),
            null,
          );
    }
  });
  Future<_Controller> controller(
    NodeDiagnosticMode mode, {
    bool menu = false,
  }) async {
    final value = _Controller(
      ServerRepository(await SharedPreferences.getInstance()),
      mode,
      menu,
    );
    addTearDown(value.dispose);
    return value;
  }

  testWidgets('home mode popup changes URL to TCP', (tester) async {
    final c = await controller(NodeDiagnosticMode.url);
    await tester.pumpWidget(_app(NodeDiagnosticModeSelector(controller: c)));
    await tester.tap(
      find.byKey(const ValueKey('node-diagnostic-mode-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is CheckedPopupMenuItem<NodeDiagnosticMode> &&
            widget.value == NodeDiagnosticMode.tcp,
      ),
    );
    await tester.pumpAndSettle();
    expect(c.nodeDiagnosticMode, NodeDiagnosticMode.tcp);
    expect(find.text('TCP'), findsOneWidget);
  });

  for (final enabled in [false, true]) {
    for (final mode in NodeDiagnosticMode.values) {
      testWidgets('node menu enabled=$enabled default=${mode.label}', (
        tester,
      ) async {
        final c = await controller(mode, menu: enabled);
        ServerMenuAction? selected;
        await tester.pumpWidget(
          _app(
            ServerNodeTile(
              controller: c,
              server: _node,
              isSelected: false,
              isExitNode: false,
              hasPreset: false,
              presetName: null,
              onTap: () {},
              onMenuAction: (action) => selected = action,
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        final label = mode == NodeDiagnosticMode.tcp
            ? 'URL diagnostic'
            : 'TCP diagnostic';
        expect(find.text(label), enabled ? findsOneWidget : findsNothing);
        if (enabled) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(selected, ServerMenuAction.diagnose);
        }
      });
    }
  }

  testWidgets('settings URL tool remains usable when default is TCP', (
    tester,
  ) async {
    final c = await controller(NodeDiagnosticMode.tcp);
    await tester.pumpWidget(
      _app(
        SettingsScreen(
          controller: c,
          isDarkTheme: false,
          onThemeModeChanged: (_) {},
          localePreference: AppLocalePreference.english,
          onLocalePreferenceChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Application'));
    await tester.tap(find.text('Application'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('URL diagnostic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('URL diagnostic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_node.name));
    await tester.pumpAndSettle();
    expect(c.urlCalls, 1);
    expect(c.tcpCalls, 0);
    expect(find.text('55 ms'), findsOneWidget);
    expect(c.nodeDiagnosticMode, NodeDiagnosticMode.tcp);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

const _node = ServerConfig(
  name: 'Node',
  address: 'example.com',
  port: 443,
  uuid: '00000000-0000-0000-0000-000000000000',
  transport: VlessTransport.tcp,
  security: VlessSecurity.tls,
);

class _Controller extends VpnController {
  _Controller(super.repository, this.mode, this.menu);
  NodeDiagnosticMode mode;
  bool menu;
  int urlCalls = 0;
  int tcpCalls = 0;
  @override
  NodeDiagnosticMode get nodeDiagnosticMode => mode;
  @override
  NodeDiagnosticMode get alternateNodeDiagnosticMode => mode.alternate;
  @override
  bool get nodeDiagnosticMenuEnabled => menu;
  @override
  List<ServerConfig> get servers => [_node];
  @override
  Future<void> setNodeDiagnosticMode(NodeDiagnosticMode value) async {
    mode = value;
    notifyListeners();
  }

  @override
  Future<UrlProbeResult> diagnoseServerUrl(ServerConfig server) async {
    urlCalls++;
    return const UrlProbeResult('ok', latencyMs: 55);
  }

  @override
  Future<String> diagnoseServerTcp(ServerConfig server) async {
    tcpCalls++;
    return '3 ms';
  }
}
