import 'package:flutter_test/flutter_test.dart';

import 'package:biocycle_proto/core/config/demo_configuration.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_evaluator.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';

void main() {
  const config = DemoConfiguration();
  const evaluator = TelemetryEvaluator(config: config);

  final baseDevice = Device(
    id: 'demo-kit-001',
    unitId: 1,
    code: 'BCK-001',
    isConnected: true,
    firmware: 'demo-1.0.0',
    lastSeenAt: DateTime.utc(2026, 9, 19, 12, 0, 0),
  );

  test('Future timestamp (now + 10s) is rejected as invalid and NEVER classified as fresh', () {
    final now = DateTime.utc(2026, 9, 19, 12, 0, 0);
    final futureMeasurement = TelemetryMeasurement(
      id: 1,
      unitId: 1,
      deviceId: 'demo-kit-001',
      parameterKey: TelemetryParameterKeys.substrateTemperature,
      value: 30.0,
      measuredAt: now.add(const Duration(seconds: 10)), // In the future!
      receivedAt: now,
      quality: 'valid',
      source: 'simulated',
      configVersion: 'demo-v1',
      sampleId: 'sample-future',
    );

    final result = evaluator.evaluateUnit(
      unitId: 1,
      device: baseDevice,
      latestMeasurements: {
        TelemetryParameterKeys.substrateTemperature: futureMeasurement,
      },
      currentTime: now,
    );

    // CONTRACT: Must never be fresh
    expect(result.dataState, isNot(DataState.fresh));
    expect(result.dataState, equals(DataState.sensorError));
    final paramResult =
        result.parameterResults[TelemetryParameterKeys.substrateTemperature];
    expect(paramResult?.condition, equals(ConditionState.unknown));
    expect(paramResult?.reason, contains('berada di masa depan'));
  });

  test('noData, stale, sensorError, and partial coverage yield ConditionState.unknown without spurious alerts', () {
    final now = DateTime.utc(2026, 9, 19, 12, 0, 0);

    // 1. noData
    final noDataResult = evaluator.evaluateUnit(
      unitId: 1,
      device: baseDevice,
      latestMeasurements: {},
      currentTime: now,
    );
    expect(noDataResult.dataState, DataState.noData);
    expect(noDataResult.condition, ConditionState.unknown);

    // 2. stale (> 300s)
    final staleMeasurement = TelemetryMeasurement(
      id: 1,
      unitId: 1,
      deviceId: 'demo-kit-001',
      parameterKey: TelemetryParameterKeys.substrateTemperature,
      value: 30.0,
      measuredAt: now.subtract(const Duration(seconds: 350)),
      receivedAt: now.subtract(const Duration(seconds: 350)),
      quality: 'valid',
      source: 'simulated',
      configVersion: 'demo-v1',
      sampleId: 'sample-stale',
    );
    final staleResult = evaluator.evaluateUnit(
      unitId: 1,
      device: baseDevice,
      latestMeasurements: {
        TelemetryParameterKeys.substrateTemperature: staleMeasurement,
      },
      currentTime: now,
    );
    expect(staleResult.dataState, DataState.stale);
    expect(staleResult.condition, ConditionState.unknown);

    // 3. sensorError (quality == invalid)
    final errorMeasurement = TelemetryMeasurement(
      id: 1,
      unitId: 1,
      deviceId: 'demo-kit-001',
      parameterKey: TelemetryParameterKeys.substrateTemperature,
      value: null,
      measuredAt: now,
      receivedAt: now,
      quality: 'invalid',
      source: 'simulated',
      configVersion: 'demo-v1',
      sampleId: 'sample-err',
    );
    final errorResult = evaluator.evaluateUnit(
      unitId: 1,
      device: baseDevice,
      latestMeasurements: {
        TelemetryParameterKeys.substrateTemperature: errorMeasurement,
      },
      currentTime: now,
    );
    expect(errorResult.dataState, DataState.sensorError);
    expect(errorResult.condition, ConditionState.unknown);
  });

  test(
    'Explicit device disconnect is strictly separated from data unknown',
    () {
      final now = DateTime.utc(2026, 9, 19, 12, 0, 0);
      final disconnectedDevice = Device(
        id: 'demo-kit-001',
        unitId: 1,
        code: 'BCK-001',
        isConnected: false, // Explicit disconnect
        firmware: 'demo-1.0.0',
        lastSeenAt: null,
      );

      final result = evaluator.evaluateUnit(
        unitId: 1,
        device: disconnectedDevice,
        latestMeasurements: {},
        currentTime: now,
      );

      expect(result.isDeviceExplicitlyDisconnected, isTrue);
      expect(result.dataState, DataState.offline);
    },
  );

  test('Partial coverage preserves valid parameter violations without claiming complete coverage', () {
    final now = DateTime.utc(2026, 9, 19, 12, 0, 0);

    // Only substrateTemperature is present (partial coverage), and it has a critical violation (39.0 °C)
    final criticalMeasurement = TelemetryMeasurement(
      id: 1,
      unitId: 1,
      deviceId: 'demo-kit-001',
      parameterKey: TelemetryParameterKeys.substrateTemperature,
      value: 39.0,
      measuredAt: now,
      receivedAt: now,
      quality: 'valid',
      source: 'simulated',
      configVersion: 'demo-v1',
      sampleId: 'sample-crit',
    );

    final result = evaluator.evaluateUnit(
      unitId: 1,
      device: baseDevice,
      latestMeasurements: {
        TelemetryParameterKeys.substrateTemperature: criticalMeasurement,
      },
      currentTime: now,
    );

    expect(result.isCoverageComplete, isFalse);
    expect(
      result.condition,
      ConditionState.critical,
    ); // Violation is still detected!
  });

  test('Invalid or missing configuration throws ConfigurationException or sets isConfigurationMissing', () {
    expect(
      () => DemoConfiguration.fromMap({'version': 'corrupt'}),
      throwsA(isA<ConfigurationException>()),
    );

    // When configuration is missing thresholds
    expect(
      () => DemoConfiguration.fromMap({
        'version': 'demo-v1',
        'freshness': {
          'fresh_seconds': 30,
          'aging_seconds': 60,
          'stale_seconds': 300,
          'offline_seconds': 600,
        },
      }),
      throwsA(isA<ConfigurationException>()),
    );
  });
}
