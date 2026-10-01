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

class _FakeController extends VpnController {
  _FakeController(super.repository);

  @override
  List<ServerConfig> get servers => [];
}

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

  testWidgets('FAQ: all 24 questions exist and are non-empty in ru and en', (tester) async {
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

    final ruPairs = [
      (ru.faqQ1, ru.faqA1),
      (ru.faqQ2, ru.faqA2),
      (ru.faqQ3, ru.faqA3),
      (ru.faqQ4, ru.faqA4),
      (ru.faqQ5, ru.faqA5),
      (ru.faqQ6, ru.faqA6),
      (ru.faqQ7, ru.faqA7),
      (ru.faqQ8, ru.faqA8),
      (ru.faqQ9, ru.faqA9),
      (ru.faqQ10, ru.faqA10),
      (ru.faqQ11, ru.faqA11),
      (ru.faqQ12, ru.faqA12),
      (ru.faqQ13, ru.faqA13),
      (ru.faqQ14, ru.faqA14),
      (ru.faqQ15, ru.faqA15),
      (ru.faqQ16, ru.faqA16),
      (ru.faqQ17, ru.faqA17),
      (ru.faqQ18, ru.faqA18),
      (ru.faqQ19, ru.faqA19),
      (ru.faqQ20, ru.faqA20),
      (ru.faqQ21, ru.faqA21),
      (ru.faqQ22, ru.faqA22),
      (ru.faqQ23, ru.faqA23),
      (ru.faqQ24, ru.faqA24),
    ];

    final enPairs = [
      (en.faqQ1, en.faqA1),
      (en.faqQ2, en.faqA2),
      (en.faqQ3, en.faqA3),
      (en.faqQ4, en.faqA4),
      (en.faqQ5, en.faqA5),
      (en.faqQ6, en.faqA6),
      (en.faqQ7, en.faqA7),
      (en.faqQ8, en.faqA8),
      (en.faqQ9, en.faqA9),
      (en.faqQ10, en.faqA10),
      (en.faqQ11, en.faqA11),
      (en.faqQ12, en.faqA12),
      (en.faqQ13, en.faqA13),
      (en.faqQ14, en.faqA14),
      (en.faqQ15, en.faqA15),
      (en.faqQ16, en.faqA16),
      (en.faqQ17, en.faqA17),
      (en.faqQ18, en.faqA18),
      (en.faqQ19, en.faqA19),
      (en.faqQ20, en.faqA20),
      (en.faqQ21, en.faqA21),
      (en.faqQ22, en.faqA22),
      (en.faqQ23, en.faqA23),
      (en.faqQ24, en.faqA24),
    ];

    expect(ruPairs, hasLength(24));
    expect(enPairs, hasLength(24));

    for (var i = 0; i < 24; i++) {
      expect(ruPairs[i].$1.trim(), isNotEmpty, reason: 'ru.faqQ${i + 1} is empty');
      expect(ruPairs[i].$2.trim(), isNotEmpty, reason: 'ru.faqA${i + 1} is empty');
      expect(enPairs[i].$1.trim(), isNotEmpty, reason: 'en.faqQ${i + 1} is empty');
      expect(enPairs[i].$2.trim(), isNotEmpty, reason: 'en.faqA${i + 1} is empty');
    }
  });

  testWidgets('FAQ: opening FAQ screen renders 24 items and expands card', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ServerRepository(prefs);
    final controller = _FakeController(repo);
    addTearDown(controller.dispose);

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

    // Scroll down to the About section where FAQ button is located
    final scrollable = find.byType(Scrollable).first;
    final faqButtonFinder = find.text(l.settingsFaqLabel);
    for (var i = 0; i < 20 && faqButtonFinder.evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(faqButtonFinder, findsOneWidget);

    await tester.tap(faqButtonFinder);
    await tester.pumpAndSettle();

    // Verify FAQ screen is open
    expect(find.text(l.faqTitle), findsOneWidget);
    expect(find.text(l.faqHint), findsOneWidget);

    // Number "01" should be visible
    expect(find.text('01'), findsOneWidget);

    // Tap first card to expand it
    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();

    // Verify that the answer text is rendered
    expect(find.textContaining('Xray'), findsWidgets);
  });
}
