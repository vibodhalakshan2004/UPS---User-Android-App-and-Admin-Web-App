// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/core/theme.dart';

void main() {
  testWidgets('ThemeProvider toggles theme mode', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeProvider,
        child: Consumer<ThemeProvider>(
          builder: (context, tp, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: tp.themeMode,
            home: Scaffold(
              appBar: AppBar(title: const Text('Test')),
              body: Center(
                child: Text(
                  tp.themeMode.toString(),
                  key: const Key('mode'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('mode')), findsOneWidget);
    expect(themeProvider.themeMode, ThemeMode.system);

    themeProvider.toggleTheme();
    await tester.pump();
    expect(themeProvider.themeMode, ThemeMode.light);

    themeProvider.toggleTheme();
    await tester.pump();
    expect(themeProvider.themeMode, ThemeMode.dark);
  });
}
