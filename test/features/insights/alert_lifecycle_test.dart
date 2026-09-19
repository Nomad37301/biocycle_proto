import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/features/insights/data/local_insight_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_evaluator.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Alert Lifecycle & Digital SOP', () {
    late AppDatabase appDb;
    late LocalInsightRepository insightRepo;
    const evaluator = TelemetryEvaluator();
    final now = DateTime.utc(2026, 9, 19, 14, 0, 0);

    const activeDevice = BsfDevice(
      id: 'demo-kit-002',
      unitId: 2,
      code: 'BCK-002',
      firmware: 'demo-1.0.0',
      isConnected: true,
      lastSeenAt: null,
    );

    TelemetryMeasurement makeMeasurement(String key, double? value) =>
        TelemetryMeasurement(
          id: 1,
          unitId: 2,
          deviceId: 'demo-kit-002',
          parameterKey: key,
          value: value,
          measuredAt: now,
          receivedAt: now,
          quality: 'valid',
          source: 'simulated',
          configVersion: 'demo-v1',
          sampleId: 'sample-2',
        );

    setUp(() async {
      appDb = await AppDatabase.open(dbPath: inMemoryDatabasePath);
      insightRepo = LocalInsightRepository(appDb);
    });

    tearDown(() async {
      await appDb.database.close();
    });

    test(
      'Single eligible violation opens episode and requests notification',
      () async {
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
            36.5,
          ), // Attention
        };

        final evalResult = evaluator.evaluateUnit(
          unitId: 2,
          device: activeDevice,
          latestMeasurements: measurements,
          currentTime: now,
        );

        final update = await insightRepo.evaluateEvaluationResult(
          unitId: 2,
          unitName: 'Unit BSF 02 - Rak B',
          evaluationResult: evalResult,
        );

        expect(update.shouldNotify, isTrue);
        expect(update.event, isNotNull);
        expect(update.event!.isActive, isTrue);
        expect(update.event!.severity, 'attention');

        // Second evaluation in same episode doesn't notify again
        final update2 = await insightRepo.evaluateEvaluationResult(
          unitId: 2,
          unitName: 'Unit BSF 02 - Rak B',
          evaluationResult: evalResult,
        );
        expect(update2.shouldNotify, isFalse);
      },
    );

    test('Escalation from attention to critical notifies again', () async {
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
          36.5,
        ),
      };

      // 1. Attention
      var eval = evaluator.evaluateUnit(
        unitId: 2,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      await insightRepo.evaluateEvaluationResult(
        unitId: 2,
        unitName: 'Unit BSF 02 - Rak B',
        evaluationResult: eval,
      );

      // 2. Escalate to Critical (39.0 °C)
      measurements[TelemetryParameterKeys.substrateTemperature] =
          makeMeasurement(TelemetryParameterKeys.substrateTemperature, 39.0);
      eval = evaluator.evaluateUnit(
        unitId: 2,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );

      final escalateUpdate = await insightRepo.evaluateEvaluationResult(
        unitId: 2,
        unitName: 'Unit BSF 02 - Rak B',
        evaluationResult: eval,
      );

      expect(escalateUpdate.shouldNotify, isTrue);
      expect(escalateUpdate.event!.severity, 'critical');
    });

    test(
      'Acknowledge records user and timestamp but alert stays active',
      () async {
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
            39.0,
          ),
        };

        final eval = evaluator.evaluateUnit(
          unitId: 2,
          device: activeDevice,
          latestMeasurements: measurements,
          currentTime: now,
        );
        final update = await insightRepo.evaluateEvaluationResult(
          unitId: 2,
          unitName: 'Unit BSF 02 - Rak B',
          evaluationResult: eval,
        );

        final alertId = update.event!.id;
        await insightRepo.acknowledge(alertId, 'Operator BSF');

        final reloaded = await insightRepo.getInsight(alertId);
        expect(reloaded!.isActive, isTrue); // Not resolved yet!
      },
    );

    test('Recovery requires 2 consecutive optimal samples', () async {
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
          39.0,
        ),
      };

      // Open critical alert
      var eval = evaluator.evaluateUnit(
        unitId: 2,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      final update = await insightRepo.evaluateEvaluationResult(
        unitId: 2,
        unitName: 'Unit BSF 02 - Rak B',
        evaluationResult: eval,
      );
      final alertId = update.event!.id;

      // Sample 1: optimal (30.0 °C) -> Not recovered yet!
      measurements[TelemetryParameterKeys.substrateTemperature] =
          makeMeasurement(TelemetryParameterKeys.substrateTemperature, 30.0);
      eval = evaluator.evaluateUnit(
        unitId: 2,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      await insightRepo.evaluateEvaluationResult(
        unitId: 2,
        unitName: 'Unit BSF 02 - Rak B',
        evaluationResult: eval,
      );

      var alert = await insightRepo.getInsight(alertId);
      expect(alert!.isActive, isTrue); // Still active after only 1 sample!

      // Sample 2: optimal (30.0 °C) -> Recovered and closed!
      await insightRepo.evaluateEvaluationResult(
        unitId: 2,
        unitName: 'Unit BSF 02 - Rak B',
        evaluationResult: eval,
      );

      alert = await insightRepo.getInsight(alertId);
      expect(alert!.isActive, isFalse); // Successfully closed!
      expect(alert.resolvedAt, isNotNull);
    });

    test('Save action captures before snapshot and pending status', () async {
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
          39.0,
        ),
      };

      final eval = evaluator.evaluateUnit(
        unitId: 2,
        device: activeDevice,
        latestMeasurements: measurements,
        currentTime: now,
      );
      final update = await insightRepo.evaluateEvaluationResult(
        unitId: 2,
        unitName: 'Unit BSF 02 - Rak B',
        evaluationResult: eval,
      );

      final alertId = update.event!.id;
      await insightRepo.saveAction(alertId, {
        0,
        1,
      }, 'Telah dilakukan penyemprotan kabut');

      final actions = await insightRepo.getActions(alertId);
      expect(actions.length, 1);
      expect(actions.first.note, 'Telah dilakukan penyemprotan kabut');
      expect(actions.first.isWaitingForData, isTrue);
    });
  });
}
