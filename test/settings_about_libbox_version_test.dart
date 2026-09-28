import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/app_locale.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/settings_screen.dart';
import 'package:voidlex/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidlex.vpn/service');
  var failLibboxVersion = false;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    failLibboxVersion = false;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (call) async {
          return switch (call.method) {
            'getLibboxVersion' when failLibboxVersion =>
              throw PlatformException(code: 'libbox_version_unavailable'),
            'getLibboxVersion' => '1.14.0',
            'getDeviceHwid' => 'test-hwid',
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, null);
  });

  for (final useTvChrome in [false, true]) {
    testWidgets(
      '${useTvChrome ? 'TV' : 'mobile'} About shows the packaged libbox version',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final controller = VpnController(ServerRepository(prefs));
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(
              controller: controller,
              isDarkTheme: false,
              onThemeModeChanged: (_) {},
              localePreference: AppLocalePreference.english,
              onLocalePreferenceChanged: (_) {},
              showBottomDock: !useTvChrome,
              useTvChrome: useTvChrome,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1.14.0'), findsOneWidget);
      },
    );
  }

  testWidgets('About shows a dash when the runtime version is unavailable', (
    tester,
  ) async {
    failLibboxVersion = true;
    final prefs = await SharedPreferences.getInstance();
    final controller = VpnController(ServerRepository(prefs));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          controller: controller,
          isDarkTheme: false,
          onThemeModeChanged: (_) {},
          localePreference: AppLocalePreference.english,
          onLocalePreferenceChanged: (_) {},
          showBottomDock: true,
          useTvChrome: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
  });
}
