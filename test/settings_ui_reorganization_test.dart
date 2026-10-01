import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/app_locale.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/settings_screen.dart';
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

  Future<_FakeController> createController() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ServerRepository(prefs);
    final controller = _FakeController(repo);
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets(
    'localization: settingsGroupNodes translates to Диагностика and Diagnostics',
    (tester) async {
      late AppLocalizations ru;
      late AppLocalizations en;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Builder(
            builder: (context) {
              ru = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(ru.settingsGroupNodes, 'Диагностика');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              en = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(en.settingsGroupNodes, 'Diagnostics');
    },
  );

  testWidgets(
    'tunnel settings: additional TLS fingerprints toggle is in Advanced section',
    (tester) async {
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('ListTile background color or ink splashes may be invisible')) {
          return;
        }
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      final controller = await createController();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return SettingsScreen(
                controller: controller,
                isDarkTheme: false,
                onThemeModeChanged: (_) {},
                localePreference: AppLocalePreference.russian,
                onLocalePreferenceChanged: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Tunnel Settings
      await tester.tap(find.text(l.settingsTunnelTitle));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;

      // Verify Advanced section has additional TLS fingerprints
      final tlsFinder = find.text(l.additionalTlsFingerprintsTitle);
      for (var i = 0; i < 15 && tlsFinder.evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(tlsFinder, findsOneWidget);

      // Toggle it via tapping Switch
      expect(controller.additionalTlsFingerprintsEnabled, isFalse);
      final switchFinder = find.descendant(
        of: find.ancestor(
          of: tlsFinder,
          matching: find.byType(Row),
        ),
        matching: find.byType(Switch),
      );
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(controller.additionalTlsFingerprintsEnabled, isTrue);
    },
  );

  testWidgets(
    'application settings: interface has node diagnostic menu and diagnostics section is ordered',
    (tester) async {
      final controller = await createController();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return SettingsScreen(
                controller: controller,
                isDarkTheme: false,
                onThemeModeChanged: (_) {},
                localePreference: AppLocalePreference.russian,
                onLocalePreferenceChanged: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Application Settings
      await tester.tap(find.text(l.settingsApplicationTitle));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      Future<void> scrollDownUntil(Finder finder) async {
        for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
          await tester.drag(scrollable, const Offset(0, -250));
          await tester.pumpAndSettle();
        }
      }

      // 1. Verify "Диагностика в меню ноды" is in the Interface section
      final menuDiagFinder = find.text(l.nodeDiagnosticMenuTitle);
      await scrollDownUntil(menuDiagFinder);
      expect(menuDiagFinder, findsOneWidget);
      expect(controller.nodeDiagnosticMenuEnabled, isFalse);
      await tester.tap(menuDiagFinder);
      await tester.pumpAndSettle();
      expect(controller.nodeDiagnosticMenuEnabled, isTrue);

      // 2. Verify Section name is "Диагностика"
      final diagSectionFinder = find.text(l.settingsGroupNodes.toUpperCase());
      await scrollDownUntil(diagSectionFinder);
      expect(diagSectionFinder, findsOneWidget);

      // 3. Verify TLS fingerprints is NOT in Application Settings
      expect(find.text(l.additionalTlsFingerprintsTitle), findsNothing);

      // 4. Verify ordered items in Diagnostics section
      final defaultDiagFinder = find.text(l.nodeDiagnosticModeTitle);
      final autoSortFinder = find.text(l.applicationSettingsAutoSortServersByPingTitle);
      final tcpTargetFinder = find.text(l.applicationSettingsPingTargetTitle);
      final urlTargetFinder = find.text(l.urlProbeTargetTitle);
      final tcpDiagFinder = find.text(l.tcpDiagnosticTitle);
      final urlDiagFinder = find.text(l.urlDiagnosticTitle);

      await scrollDownUntil(defaultDiagFinder);
      expect(defaultDiagFinder, findsOneWidget);
      await scrollDownUntil(autoSortFinder);
      expect(autoSortFinder, findsOneWidget);
      await scrollDownUntil(tcpTargetFinder);
      expect(tcpTargetFinder, findsOneWidget);
      await scrollDownUntil(urlTargetFinder);
      expect(urlTargetFinder, findsOneWidget);
      await scrollDownUntil(tcpDiagFinder);
      expect(tcpDiagFinder, findsOneWidget);
      await scrollDownUntil(urlDiagFinder);
      expect(urlDiagFinder, findsOneWidget);
    },
  );
}

class _FakeController extends VpnController {
  _FakeController(super.repository);

  bool _tlsFingerprints = false;
  bool _menuEnabled = false;

  @override
  bool get additionalTlsFingerprintsEnabled => _tlsFingerprints;

  @override
  Future<void> setAdditionalTlsFingerprintsEnabled(bool value) async {
    _tlsFingerprints = value;
    notifyListeners();
  }

  @override
  bool get nodeDiagnosticMenuEnabled => _menuEnabled;

  @override
  Future<void> setNodeDiagnosticMenuEnabled(bool value) async {
    _menuEnabled = value;
    notifyListeners();
  }

  @override
  List<ServerConfig> get servers => [];
}
