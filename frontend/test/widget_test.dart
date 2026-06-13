// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farahdent_app/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    // Build app root widget and pump one frame
    await tester.pumpWidget(const FarahDentApp());

    // Allow splash timer to fire (avoid pumpAndSettle due to infinite progress animation)
    await tester.pump(const Duration(seconds: 2));

    // Smoke test: ensure a widget from first screen exists
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
