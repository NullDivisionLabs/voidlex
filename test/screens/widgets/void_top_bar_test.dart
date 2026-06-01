import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voidlex/screens/widgets/void_top_bar.dart';
import 'package:voidlex/theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('bridge badge long press exposes disable action', (tester) async {
    var disableCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: VoidTopBar(
            version: 'v1.0.1-beta',
            rightBadge: 'BRIDGE MODE',
            onRightBadgeDisable: () => disableCount += 1,
          ),
        ),
      ),
    );

    await tester.longPress(find.text('BRIDGE MODE'));
    await tester.pumpAndSettle();

    expect(find.text('Disable'), findsOneWidget);

    await tester.tap(find.text('Disable'));
    await tester.pumpAndSettle();

    expect(disableCount, 1);
  });
}
