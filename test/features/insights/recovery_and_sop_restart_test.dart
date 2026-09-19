import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/features/insights/data/local_insight_repository.dart';
import 'package:biocycle_proto/features/insights/domain/insight_models.dart';
import 'package:biocycle_proto/features/monitoring/data/local_telemetry_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_evaluator.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('biocycle_restart_');
    dbPath = p.join(tempDir.path, 'test_restart.db');
  });

  tearDown(() async {
    final file = File(dbPath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  });

  test('Recovery counter survives repository and app restart', () async {
    const evaluator = TelemetryEvaluator();
    final now = DateTime.utc(2026, 9, 19, 12, 0, 0);

    final device = Device(
      id: 'demo-kit-001',
      unitId: 1,
      code: 'BCK-001',
      isConnected: true,
      firmware: 'demo-1.0.0',
      lastSeenAt: now,
    );

    // Session 1: Open DB, create critical alert, process optimal sample #1
    var db = await AppDatabase.open(dbPath: dbPath);
    var insightRepo = LocalInsightRepository(db);

    // Trigger critical alert
    final measurementsCrit = {
      TelemetryParameterKeys.ambientTemperature: TelemetryMeasurement(
        id: 1,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.ambientTemperature,
        value: 29.0,
        measuredAt: now,
        receivedAt: now,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-crit-1',
      ),
      TelemetryParameterKeys.ambientHumidity: TelemetryMeasurement(
        id: 2,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.ambientHumidity,
        value: 65.0,
        measuredAt: now,
        receivedAt: now,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-crit-2',
      ),
      TelemetryParameterKeys.substrateTemperature: TelemetryMeasurement(
        id: 3,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 39.0,
        measuredAt: now,
        receivedAt: now,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-crit-3',
      ),
      TelemetryParameterKeys.substrateMoisture: TelemetryMeasurement(
        id: 4,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateMoisture,
        value: 65.0,
        measuredAt: now,
        receivedAt: now,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-crit-4',
      ),
    };
    final evalCrit = evaluator.evaluateUnit(
      unitId: 1,
      device: device,
      latestMeasurements: measurementsCrit,
      currentTime: now,
    );
    final updateCrit = await insightRepo.evaluateEvaluationResult(
      unitId: 1,
      unitName: 'Unit 1',
      evaluationResult: evalCrit,
    );
    final alertId = updateCrit.event!.id;
    expect(updateCrit.event!.isActive, isTrue);

    // Sample 1: all standard parameters optimal (substrateTemp = 30.0 °C)
    final measurementsOptimal = {
      TelemetryParameterKeys.ambientTemperature: TelemetryMeasurement(
        id: 10,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.ambientTemperature,
        value: 29.0,
        measuredAt: now.add(const Duration(seconds: 10)),
        receivedAt: now.add(const Duration(seconds: 10)),
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-amb-t',
      ),
      TelemetryParameterKeys.ambientHumidity: TelemetryMeasurement(
        id: 11,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.ambientHumidity,
        value: 65.0,
        measuredAt: now.add(const Duration(seconds: 10)),
        receivedAt: now.add(const Duration(seconds: 10)),
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-amb-h',
      ),
      TelemetryParameterKeys.substrateTemperature: TelemetryMeasurement(
        id: 12,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 30.0,
        measuredAt: now.add(const Duration(seconds: 10)),
        receivedAt: now.add(const Duration(seconds: 10)),
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-opt-1',
      ),
      TelemetryParameterKeys.substrateMoisture: TelemetryMeasurement(
        id: 13,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateMoisture,
        value: 65.0,
        measuredAt: now.add(const Duration(seconds: 10)),
        receivedAt: now.add(const Duration(seconds: 10)),
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-sub-m',
      ),
    };
    final evalOpt1 = evaluator.evaluateUnit(
      unitId: 1,
      device: device,
      latestMeasurements: measurementsOptimal,
      currentTime: now.add(const Duration(seconds: 10)),
    );
    await insightRepo.evaluateEvaluationResult(
      unitId: 1,
      unitName: 'Unit 1',
      evaluationResult: evalOpt1,
    );

    var alert = await insightRepo.getInsight(alertId);
    expect(alert!.isActive, isTrue); // Still active after only 1 sample!

    // SIMULATE APP RESTART: Close database, destroy all in-memory repository instances
    await db.database.close();

    // Session 2: Fresh app open with fresh database connection and repository instance
    db = await AppDatabase.open(dbPath: dbPath);
    insightRepo = LocalInsightRepository(db);

    // Sample 2: optimal (30.0 °C) after restart
    final evalOpt2 = evaluator.evaluateUnit(
      unitId: 1,
      device: device,
      latestMeasurements: measurementsOptimal,
      currentTime: now.add(const Duration(seconds: 20)),
    );
    await insightRepo.evaluateEvaluationResult(
      unitId: 1,
      unitName: 'Unit 1',
      evaluationResult: evalOpt2,
    );

    alert = await insightRepo.getInsight(alertId);
    expect(alert!.isActive, isFalse); // Successfully recovered after restart!
    expect(alert.resolvedAt, isNotNull);
    expect(alert.recoveredAt, isNotNull);

    await db.database.close();
  });

  test('Pending SOP evaluation survives app restart and is evaluated by background lifecycle', () async {
    final now = DateTime.utc(2026, 9, 19, 12, 0, 0);

    // Session 1: Create alert, insert before telemetry, save done action
    var db = await AppDatabase.open(dbPath: dbPath);
    var insightRepo = LocalInsightRepository(db);
    var telemetryRepo = LocalTelemetryRepository(db);

    final insightId = await db.database.insert('insights', {
      'unit_id': 1,
      'unit_name': 'Unit 1',
      'kind': 'thermalCritical',
      'parameter_key': TelemetryParameterKeys.substrateTemperature,
      'severity': 'critical',
      'cause': 'Suhu 39',
      'recommendation': 'Kipas',
      'started_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await telemetryRepo.insertMeasurement(
      TelemetryMeasurement(
        id: 0,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 39.0,
        measuredAt: now,
        receivedAt: now,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-before-restart',
      ),
    );

    await insightRepo.saveAction(
      insightId,
      const {0},
      'Sebelum restart',
      responseType: ActionResponseType.done,
      idempotencyKey: 'idemp-restart-sop',
      currentTime: now,
    );

    var actions = await insightRepo.getInsightActions(insightId);
    expect(
      actions.first.evaluationStatus,
      ActionEvaluationStatus.pendingEvaluation,
    );

    // SIMULATE APP RESTART
    await db.database.close();

    // Session 2: Fresh app open
    db = await AppDatabase.open(dbPath: dbPath);
    insightRepo = LocalInsightRepository(db);
    telemetryRepo = LocalTelemetryRepository(db);

    // Telemetry after measurement inserted at due time (+16 minutes)
    final dueTime = now.add(const Duration(minutes: 16));
    await telemetryRepo.insertMeasurement(
      TelemetryMeasurement(
        id: 0,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 32.0,
        measuredAt: dueTime,
        receivedAt: dueTime,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-after-restart',
      ),
    );

    // Background lifecycle evaluation executes (without opening UI)
    await insightRepo.evaluatePendingActions(currentTime: dueTime);

    actions = await insightRepo.getInsightActions(insightId);
    expect(actions.first.evaluationStatus, ActionEvaluationStatus.evaluated);
    expect(actions.first.afterValue, equals(32.0));

    await db.database.close();
  });
}
