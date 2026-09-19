import 'package:biocycle_proto/app/theme/app_theme.dart';
import 'package:biocycle_proto/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 360.0, 600.0, 800.0, 1024.0]) {
    testWidgets('role selection reflow pada lebar ${width.toInt()}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(modeTerik: true),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: OnboardingScreen(),
            ),
          ),
        ),
      );

      expect(find.text('Pilih peran demo'), findsOneWidget);
      expect(find.text('Operator BSF'), findsOneWidget);
      expect(find.text('Penyedia Limbah'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Pembeli Hasil'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Pembeli Hasil'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
