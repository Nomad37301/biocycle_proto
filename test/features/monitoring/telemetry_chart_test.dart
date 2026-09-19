import 'package:biocycle_proto/app/theme/app_theme.dart';
import 'package:biocycle_proto/core/config/demo_configuration.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:biocycle_proto/features/monitoring/presentation/telemetry_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 9, 19, 0);

  test('model memutus garis pada gap dan sampel invalid', () {
    final model = TelemetryChartModel.build(
      measurements: [
        measurement(1, start, 30),
        measurement(2, start.add(const Duration(hours: 1)), 31),
        measurement(
          3,
          start.add(const Duration(hours: 2)),
          null,
          quality: 'invalid',
        ),
        measurement(4, start.add(const Duration(hours: 5)), 32),
      ],
      parameterKey: TelemetryParameterKeys.substrateTemperature,
      configuration: const DemoConfiguration(),
    );

    expect(model.samples, hasLength(3));
    expect(model.segments, hasLength(2));
    expect(model.gapCount, greaterThanOrEqualTo(1));
    expect(model.segments.first.map((sample) => sample.id), [1, 2]);
    expect(model.segments.last.map((sample) => sample.id), [4]);
  });

  testWidgets('chart satu sampel menampilkan marker dan semantics aktual', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SizedBox(
            height: 300,
            width: 360,
            child: TelemetryChart(
              unitName: 'Unit 1',
              parameterKey: TelemetryParameterKeys.substrateTemperature,
              measurements: [measurement(1, start, 30)],
              rangeHours: 24,
              configuration: const DemoConfiguration(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Terakhir 30,0 °C'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(TelemetryChart)).label,
      contains('1 sampel valid'),
    );
    expect(tester.takeException(), isNull);
  });
}

TelemetryMeasurement measurement(
  int id,
  DateTime measuredAt,
  double? value, {
  String quality = 'valid',
}) => TelemetryMeasurement(
  id: id,
  unitId: 1,
  deviceId: 'demo-kit-001',
  parameterKey: TelemetryParameterKeys.substrateTemperature,
  value: value,
  measuredAt: measuredAt,
  receivedAt: measuredAt,
  quality: quality,
  source: 'simulated',
  configVersion: 'demo-v1',
  sampleId: 'sample-$id',
);
