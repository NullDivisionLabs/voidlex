import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/geo_data.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/widgets/geo_data_auto_update_menu.dart';

void main() {
  testWidgets('geodata auto-update popup exposes and applies all intervals', (
    tester,
  ) async {
    var selected = GeoDataAutoUpdateInterval.disabled;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => GeoDataAutoUpdateMenuButton(
              interval: selected,
              onSelected: (value) {
                setState(() => selected = value);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();
    expect(find.text('Every day'), findsOneWidget);
    expect(find.text('Every 3 days'), findsOneWidget);
    expect(find.text('Every 7 days'), findsOneWidget);

    await tester.tap(find.text('Every 3 days'));
    await tester.pumpAndSettle();

    expect(selected, GeoDataAutoUpdateInterval.threeDays);
    expect(find.text('Every 3 days'), findsOneWidget);
  });
}
