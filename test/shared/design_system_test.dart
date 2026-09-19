import 'package:biocycle_proto/app/theme/app_theme.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:biocycle_proto/shared/widgets/freshness_indicator.dart';
import 'package:biocycle_proto/shared/widgets/metric_value.dart';
import 'package:biocycle_proto/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject(Widget child, {double scale = 1, bool modeTerik = false}) =>
      MaterialApp(
        theme: buildAppTheme(modeTerik: modeTerik),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('MetricValue memakai format Indonesia dan null yang jujur', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MetricValue(label: 'Suhu substrat', value: 30.5, unit: '°C'),
            MetricValue(label: 'Kelembapan substrat', value: null, unit: '%'),
          ],
        ),
      ),
    );

    expect(find.text('30,5'), findsOneWidget);
    expect(find.text('Tidak tersedia'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(MetricValue).first).label,
      contains('30,5 °C'),
    );
  });

  testWidgets('komponen status tetap terbaca pada skala teks besar', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        const SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusBadge(condition: ConditionState.critical),
              FreshnessIndicator(state: DataState.sensorError),
              MetricValue(
                label: 'Kelembapan substrat',
                value: 65,
                unit: '%',
                decimalDigits: 0,
              ),
            ],
          ),
        ),
        scale: 1.5,
        modeTerik: true,
      ),
    );

    expect(find.text('Kritis'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Sensor bermasalah'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('warna teks utama memenuhi kontras AA pada kedua mode', () {
    for (final modeTerik in [false, true]) {
      final theme = buildAppTheme(modeTerik: modeTerik);
      final tokens = theme.extension<BioCycleTheme>()!;
      expect(
        _contrast(AppColors.ink, tokens.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(tokens.textSecondary, tokens.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrast(tokens.outline, tokens.sunken), greaterThanOrEqualTo(3));
    }
  });
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
