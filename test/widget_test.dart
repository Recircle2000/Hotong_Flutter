// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

void main() {
  testWidgets('ScaleButton renders child and handles tap',
      (WidgetTester tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScaleButton(
            onTap: () => tapCount++,
            child: const Text('HSRO'),
          ),
        ),
      ),
    );

    expect(find.text('HSRO'), findsOneWidget);

    await tester.tap(find.text('HSRO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tapCount, 1);
  });
}
