import 'package:biocycle_proto/core/config/demo_configuration.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_evaluator.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelemetryEvaluator Pure Domain Tests', () {
    const config = DemoConfiguration();
    const evaluator = TelemetryEvaluator(config: config);
    final now = DateTime.utc(2026, 9, 19, 12, 0, 0);

    const activeDevice = BsfDevice(
      id: 'demo-kit-001',
      unitId: 1,
      code: 'BCK-001',
      firmware: 'demo-1.0.0',
      isConnected: true,
      lastSeenAt: null,
    );

    TelemetryMeasurement makeMeasurement(
      String key,
      double? value, {
      Duration age = const Duration(seconds: 5),
      String quality = 'valid',
    }) => TelemetryMeasurement(
      id: 1,
      unitId: 1,
      deviceId: 'demo-kit-001',
      parameterKey: key,
      value: value,
      measuredAt: now.subtract(age),
      receivedAt: now.subtract(age),
      quality: quality,
      source: 'simulated',
      configVersion: 'demo-v1',
      sampleId: 'test-1',
    );

    test('exact boundaries for substrateTemperature: 26..35 optimal, 35.1..38 attention, >38 critical', () {
      final measurements = {
        TelemetryParameterKeys.ambientTemperature: makeMeasurement(
          TelemetryParameterKeys.ambientTemperature,
          29.0,
        ),
        TelemetryParameterKeys.ambientHumidity: makeMeasurement(
          TelemetryParameterKeys.ambientHumidity,
          65.0,
        ),
        TelemetryParameterKeys.substrateMoisture: makeMeasurement(
          TelemetryParameterKeys.substrateMoisture,
          65.0,
        ),
        TelemetryParameterKeys.substrateTemperature: makeMeasurement(
          TelemetryParameterKeys.substrateTemperature,
          30.0,
        ),
      };

      // Optimal case (30.0 °C)
      var result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.optimal);
      expect(
        result
            .parameterResults[TelemetryParameterKeys.substrateTemperature]
            ?.condition,
        ConditionState.optimal,
      );

      // Boundary: exactly 35.0 °C is optimal
      measurements[TelemetryParameterKeys.substrateTemperature] =
          makeMeasurement(TelemetryParameterKeys.substrateTemperature, 35.0);
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.optimal);

      // Boundary: 35.1 °C is attention
      measurements[TelemetryParameterKeys.substrateTemperature] =
          makeMeasurement(TelemetryParameterKeys.substrateTemperature, 35.1);
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.attention);

      // Boundary: exactly 38.0 °C is attention
      measurements[TelemetryParameterKeys.substrateTemperature] =
          makeMeasurement(TelemetryParameterKeys.substrateTemperature, 38.0);
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.attention);

      // Boundary: 38.1 °C is critical
      measurements[TelemetryParameterKeys.substrateTemperature] =
          makeMeasurement(TelemetryParameterKeys.substrateTemperature, 38.1);
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.critical);

      // Low boundary: exactly 26.0 °C is optimal
      measurements[TelemetryParameterKeys.substrateTemperature] =
          makeMeasurement(TelemetryParameterKeys.substrateTemperature, 26.0);
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.optimal);

      // Low boundary: 25.9 °C is attention
      measurements[TelemetryParameterKeys.substrateTemperature] =
          makeMeasurement(TelemetryParameterKeys.substrateTemperature, 25.9);
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.attention);
    });

    test('exact boundaries for substrateMoisture: 50..80 optimal, <50 or >80 attention', () {
      final measurements = {
        TelemetryParameterKeys.ambientTemperature: makeMeasurement(
          TelemetryParameterKeys.ambientTemperature,
          29.0,
        ),
        TelemetryParameterKeys.ambientHumidity: makeMeasurement(
          TelemetryParameterKeys.ambientHumidity,
          65.0,
        ),
        TelemetryParameterKeys.substrateTemperature: makeMeasurement(
          TelemetryParameterKeys.substrateTemperature,
          30.0,
        ),
        TelemetryParameterKeys.substrateMoisture: makeMeasurement(
          TelemetryParameterKeys.substrateMoisture,
          80.0,
        ),
      };

      // Exactly 80.0% is optimal
      var result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.optimal);

      // 80.1% is attention (wet)
      measurements[TelemetryParameterKeys.substrateMoisture] = makeMeasurement(
        TelemetryParameterKeys.substrateMoisture,
        80.1,
      );
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.attention);

      // Exactly 50.0% is optimal
      measurements[TelemetryParameterKeys.substrateMoisture] = makeMeasurement(
        TelemetryParameterKeys.substrateMoisture,
        50.0,
      );
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.optimal);

      // 49.9% is attention (dry)
      measurements[TelemetryParameterKeys.substrateMoisture] = makeMeasurement(
        TelemetryParameterKeys.substrateMoisture,
        49.9,
      );
      result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      expect(result.condition, ConditionState.attention);
    });

    test(
      'device offline marks DataState.offline and overall condition unknown',
      () {
        final measurements = {
          TelemetryParameterKeys.substrateTemperature: makeMeasurement(
            TelemetryParameterKeys.substrateTemperature,
            30.0,
          ),
        };

        const offlineDevice = BsfDevice(
          id: 'demo-kit-001',
          unitId: 1,
          code: 'BCK-001',
          firmware: 'demo-1.0.0',
          isConnected: false,
          lastSeenAt: null,
        );

        final result = evaluator.evaluateUnit(
          unitId: 1,
          device: offlineDevice,
          latestMeasurements: measurements,
          currentTime: now,
        );

        expect(result.condition, ConditionState.unknown);
        expect(
          result
              .parameterResults[TelemetryParameterKeys.substrateTemperature]
              ?.dataState,
          DataState.offline,
        );
      },
    );

    test(
      'stale data (> 300s) yields unknown condition and DataState.stale',
      () {
        final measurements = {
          TelemetryParameterKeys.ambientTemperature: makeMeasurement(
            TelemetryParameterKeys.ambientTemperature,
            29.0,
          ),
          TelemetryParameterKeys.ambientHumidity: makeMeasurement(
            TelemetryParameterKeys.ambientHumidity,
            65.0,
          ),
          TelemetryParameterKeys.substrateMoisture: makeMeasurement(
            TelemetryParameterKeys.substrateMoisture,
            65.0,
          ),
          TelemetryParameterKeys.substrateTemperature: makeMeasurement(
            TelemetryParameterKeys.substrateTemperature,
            30.0,
            age: const Duration(seconds: 350), // > 300s
          ),
        };

        final result = evaluator.evaluateUnit(
          unitId: 1,
          device: activeDevice,
          latestMeasurements: measurements,
          currentTime: now,
        );

        expect(
          result
              .parameterResults[TelemetryParameterKeys.substrateTemperature]
              ?.dataState,
          DataState.stale,
        );
        expect(
          result.condition,
          ConditionState.unknown,
        ); // Invariant: partial or stale is unknown!
      },
    );

    test('partial data (missing probe) produces unknown overall condition, not optimal', () {
      final measurements = {
        TelemetryParameterKeys.substrateTemperature: makeMeasurement(
          TelemetryParameterKeys.substrateTemperature,
          30.0,
        ),
        // other probes missing!
      };

      final result = evaluator.evaluateUnit(
        unitId: 1,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );

      expect(result.coverageComplete, isFalse);
      expect(result.condition, ConditionState.unknown);
    });
  });
}
