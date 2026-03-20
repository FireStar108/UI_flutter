// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ui/app.dart' as app;

void main() {
  testWidgets('App build smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const app.App());

    // Verify that the app title or some core widget exists.
    // For now, just ensuring it doesn't crash on build.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
