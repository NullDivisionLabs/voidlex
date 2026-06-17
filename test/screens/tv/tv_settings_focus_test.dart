import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/screens/tv/widgets/tv_settings_focus.dart';

void main() {
  testWidgets('vertical D-pad focus can leave a radio group', (tester) async {
    final firstNode = FocusNode();
    final secondNode = FocusNode();
    final afterNode = FocusNode();
    var selected = 0;

    addTearDown(firstNode.dispose);
    addTearDown(secondNode.dispose);
    addTearDown(afterNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RadioGroup<int>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) selected = value;
                },
                child: tvDpadEscapeRadioGroup(
                  enabled: true,
                  child: Column(
                    children: [
                      RadioListTile<int>(
                        autofocus: true,
                        focusNode: firstNode,
                        value: 0,
                        title: const Text('First'),
                      ),
                      RadioListTile<int>(
                        focusNode: secondNode,
                        value: 1,
                        title: const Text('Second'),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                focusNode: afterNode,
                onPressed: () {},
                child: const Text('After'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(firstNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(secondNode.hasFocus, isTrue);
    expect(selected, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(afterNode.hasFocus, isTrue);
    expect(selected, 0);
  });
}
