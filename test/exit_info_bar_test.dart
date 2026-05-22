import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voidtunnel/screens/widgets/exit_info_bar.dart';
import 'package:voidtunnel/screens/widgets/global_proxy_pill.dart';
import 'package:voidtunnel/theme.dart';

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
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
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
                    const ExitInfoBar(exitIp: 'Unavailable', node: 'DE'),
                    const ExitInfoBar(
                      exitIp: '50.21.191.100',
                      node: 'United States IONOS Long Region',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Sanity-check that the IP and node value still render at every width —
      // a previous Stack-based layout silently dropped them when the lane was
      // narrower than the label.
      expect(find.text('50.21.191.100'), findsOneWidget);
      expect(find.text('United States IONOS Long Region'), findsOneWidget);
      expect(find.text('EXIT'), findsNWidgets(2));
      expect(find.text('NODE'), findsNWidgets(2));
    }

    final overflowErrors = errors.where(
      (error) => error.exceptionAsString().contains('overflowed by'),
    );
    expect(overflowErrors, isEmpty);
  });
}
