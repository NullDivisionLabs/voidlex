import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/widgets/server_advanced_fields.dart';
import 'package:voidlex/theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('existing VLESS advanced values auto-expand Reality fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        ServerAdvancedFields(
          protocol: ServerProtocol.vless,
          security: VlessSecurity.reality,
          enabled: true,
          initial: const ServerAdvancedSettings(flow: 'xtls-rprx-vision'),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VLESS flow'), findsOneWidget);
    expect(find.text('Reality spiderX'), findsOneWidget);
    expect(find.text('Reality ML-DSA-65 verify'), findsOneWidget);
  });

  testWidgets('Hysteria2 advanced section is collapsed for a new server', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        ServerAdvancedFields(
          protocol: ServerProtocol.hysteria2,
          security: VlessSecurity.tls,
          enabled: true,
          initial: const ServerAdvancedSettings(),
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Obfuscation'), findsNothing);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Obfuscation'), findsOneWidget);
    expect(find.text('Port hopping interval'), findsOneWidget);
    expect(find.text('Upload bandwidth (Mbps)'), findsOneWidget);
  });

  testWidgets('Naive advanced section renders structured header rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        ServerAdvancedFields(
          protocol: ServerProtocol.naive,
          security: VlessSecurity.tls,
          enabled: true,
          initial: const ServerAdvancedSettings(
            naiveExtraHeaders: {'X-Edge': 'void'},
          ),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Extra HTTP headers'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'X-Edge'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'void'), findsOneWidget);
    expect(find.text('UDP over TCP'), findsOneWidget);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Form(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}
