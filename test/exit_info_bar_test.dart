import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/widgets/exit_info_bar.dart';
import 'package:voidlex/screens/widgets/global_proxy_pill.dart';
import 'package:voidlex/theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('exit and routing controls do not overflow on narrow widths', (
    tester,
  ) async {
    final previousOnError = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousOnError);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in <double>[320, 390, 600]) {
      await tester.binding.setSurfaceSize(Size(width, 640));
      await tester.pumpWidget(
        _testApp(
          Center(
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: GlobalProxyPill(
                      globalActive: false,
                      onChanged: (_) {},
                    ),
                  ),
                  const SizedBox(height: 14),
                  ExitInfoBar(
                    exitIp: 'Unavailable',
                    node: 'DE',
                    downloadSpeed: '999.99 MB/s',
                    uploadSpeed: '999.99 MB/s',
                    loadMemoryPssKb: () async => 512 * 1024,
                  ),
                  ExitInfoBar(
                    exitIp: '50.21.191.100',
                    node: 'United States IONOS Long Region',
                    downloadSpeed: '12.7 KB/s',
                    uploadSpeed: '1.42 MB/s',
                    loadMemoryPssKb: () async => null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('exit-info-bar-toggle')).first,
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('50.21.191.100'), findsOneWidget);
      expect(find.text('United States IONOS Long Region'), findsOneWidget);
      expect(find.text('EXIT'), findsNWidgets(2));
      expect(find.text('NODE'), findsNWidgets(2));
      expect(find.text('512.0 MB'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('exit-info-bar-toggle')).first,
      );
      await tester.pump(const Duration(milliseconds: 250));
    }

    final overflowErrors = errors.where(
      (error) => error.exceptionAsString().contains('overflowed by'),
    );
    expect(overflowErrors, isEmpty);
  });

  testWidgets('tap expands and tapping expanded panel collapses it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        ExitInfoBar(
          exitIp: '1.2.3.4',
          node: 'NL',
          downloadSpeed: '12.7 KB/s',
          uploadSpeed: '1.42 MB/s',
          loadMemoryPssKb: () async => 128 * 1024,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('exit-info-bar-details')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('exit-info-bar-toggle')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('exit-info-bar-details')), findsOneWidget);
    expect(find.text('12.7 KB/s'), findsOneWidget);
    expect(find.text('1.42 MB/s'), findsOneWidget);
    expect(find.text('128.0 MB'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exit-info-bar-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('exit-info-bar-details')), findsNothing);
  });

  testWidgets(
    'speed labels and value font sizes stay fixed while values change',
    (tester) async {
      Widget buildBar(String downloadSpeed, String uploadSpeed) {
        return _testApp(
          ExitInfoBar(
            exitIp: '1.2.3.4',
            node: 'NL',
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            loadMemoryPssKb: () async => null,
          ),
        );
      }

      await tester.pumpWidget(buildBar('0 B/s', '0 B/s'));
      await tester.tap(find.byKey(const ValueKey('exit-info-bar-toggle')));
      await tester.pumpAndSettle();

      final downLabel = find.byKey(
        const ValueKey('exit-info-speed-down-label'),
      );
      final upLabel = find.byKey(const ValueKey('exit-info-speed-up-label'));
      final downValue = find.byKey(
        const ValueKey('exit-info-speed-down-value'),
      );
      final upValue = find.byKey(const ValueKey('exit-info-speed-up-value'));
      final initialDownRect = tester.getRect(downLabel);
      final initialUpRect = tester.getRect(upLabel);
      final initialDownStyle = tester.widget<Text>(downValue).style;
      final initialUpStyle = tester.widget<Text>(upValue).style;

      await tester.pumpWidget(buildBar('999.99 MB/s', '128.42 KB/s'));
      await tester.pump();

      expect(tester.getRect(downLabel), initialDownRect);
      expect(tester.getRect(upLabel), initialUpRect);
      expect(tester.widget<Text>(downValue).style, initialDownStyle);
      expect(tester.widget<Text>(upValue).style, initialUpStyle);
      expect(tester.widget<Text>(downValue).overflow, TextOverflow.ellipsis);
      expect(tester.widget<Text>(upValue).overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets('metric labels stay English in Russian locale', (tester) async {
    await tester.pumpWidget(
      _testApp(
        ExitInfoBar(
          exitIp: '1.2.3.4',
          node: 'NL',
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          loadMemoryPssKb: () async => null,
        ),
        locale: const Locale('ru'),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('exit-info-bar-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('SPEED'), findsNothing);
    expect(find.text('DOWN'), findsOneWidget);
    expect(find.text('UP'), findsOneWidget);
    expect(find.text('MEM'), findsOneWidget);
    expect(find.text('СКОРОСТЬ'), findsNothing);
    expect(find.text('ВХОД'), findsNothing);
    expect(find.text('ВЫХОД'), findsNothing);
    expect(find.text('ПАМЯТЬ'), findsNothing);
  });

  testWidgets('memory polling runs only while expanded', (tester) async {
    var calls = 0;
    Future<int?> loadMemory() async {
      calls++;
      return null;
    }

    await tester.pumpWidget(
      _testApp(
        ExitInfoBar(
          exitIp: '1.2.3.4',
          node: 'NL',
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          loadMemoryPssKb: loadMemory,
          memoryPollInterval: const Duration(milliseconds: 100),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('exit-info-bar-toggle')));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('N/A'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    expect(calls, greaterThanOrEqualTo(2));
    final callsBeforeCollapse = calls;

    await tester.tap(find.byKey(const ValueKey('exit-info-bar-toggle')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, callsBeforeCollapse);

    await tester.tap(find.byKey(const ValueKey('exit-info-bar-toggle')));
    await tester.pump();
    expect(calls, callsBeforeCollapse + 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, callsBeforeCollapse + 1);
  });
}

Widget _testApp(Widget child, {Locale? locale}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}
