import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/screens/widgets/section_header.dart';

void main() {
  testWidgets('busy indicator hides after fixed duration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: VoidIconActionButton(
              icon: Icons.network_ping_rounded,
              onTap: null,
              busy: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.network_ping_rounded), findsNothing);

    await tester.pump(const Duration(milliseconds: 1499));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.network_ping_rounded), findsOneWidget);
  });
}
