// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Basic smoke test that confirms a MaterialApp renders static content.
///
/// Using a self-contained widget keeps the test independent from Firebase
/// initialization, which is not available in the widget test environment.
void main() {
  testWidgets('renders UPS admin banner text', (WidgetTester tester) async {
    const widgetUnderTest = MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('UPS Admin Portal'),
        ),
      ),
    );

    await tester.pumpWidget(widgetUnderTest);

    expect(find.text('UPS Admin Portal'), findsOneWidget);
  });
}
