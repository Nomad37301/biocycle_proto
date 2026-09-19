import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test widget tree can mount', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('BioCycle Smoke Test'))),
      ),
    );

    expect(find.text('BioCycle Smoke Test'), findsOneWidget);
  });
}
