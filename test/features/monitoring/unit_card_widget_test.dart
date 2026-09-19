import 'package:biocycle_proto/app/app_providers.dart';
import 'package:biocycle_proto/app/theme/app_theme.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:biocycle_proto/features/monitoring/presentation/unit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline memisahkan condition, DataState, dan last known', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 9, 19, 10);
    final result = UnitEvaluationResult(
      unitId: 1,
      condition: ConditionState.unknown,
      parameterResults: {
        for (final key in TelemetryParameterKeys.all)
          key: ParameterEvaluationResult(
            parameterKey: key,
            condition: ConditionState.unknown,
            dataState: DataState.offline,
            value: key.contains('Temperature') ? 30 : 65,
            measuredAt: now,
            reason: 'Perangkat sedang terputus.',
          ),
      },
      coverageComplete: false,
      reasons: const ['Perangkat sedang terputus.'],
      configVersion: 'demo-v1',
      evaluatedAt: now,
      isDeviceExplicitlyDisconnected: true,
    );
    final temperature = _measurement(
      1,
      TelemetryParameterKeys.substrateTemperature,
      30,
      now,
    );
    final moisture = _measurement(
      2,
      TelemetryParameterKeys.substrateMoisture,
      65,
      now,
    );
    final snapshot = UnitMonitoringSnapshot(
      unit: BsfUnit(
        id: 1,
        name: 'Unit Uji',
        kitCode: 'BCK-001',
        temperature: 30,
        humidity: 65,
        medium: 'Stabil',
        isConnected: false,
        updatedAt: now,
        lastSyncedAt: now,
        firmware: 'demo-1.0.0',
        thresholds: const UnitThresholds(),
      ),
      device: BsfDevice(
        id: 'demo-kit-001',
        unitId: 1,
        code: 'BCK-001',
        firmware: 'demo-1.0.0',
        isConnected: false,
        lastSeenAt: now,
      ),
      latest: {
        temperature.parameterKey: temperature,
        moisture.parameterKey: moisture,
      },
      evaluation: result,
      substrateTemperatureHistory: [temperature],
      substrateMoistureHistory: [moisture],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(child: UnitCard(snapshot: snapshot)),
          ),
        ),
      ),
    );

    expect(find.text('Belum dapat dinilai'), findsOneWidget);
    expect(find.textContaining('Perangkat terputus'), findsOneWidget);
    expect(find.text('Pembacaan terakhir'), findsNWidgets(2));
    expect(find.textContaining('Data sebagian'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TelemetryMeasurement _measurement(
  int id,
  String parameterKey,
  double value,
  DateTime timestamp,
) => TelemetryMeasurement(
  id: id,
  unitId: 1,
  deviceId: 'demo-kit-001',
  parameterKey: parameterKey,
  value: value,
  measuredAt: timestamp,
  receivedAt: timestamp,
  quality: 'valid',
  source: 'simulated',
  configVersion: 'demo-v1',
  sampleId: 'sample-$id',
);
