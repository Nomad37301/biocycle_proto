import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/features/insights/data/local_insight_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_evaluator.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;
  late AppDatabase database;
  late LocalInsightRepository insightRepo;
  late TelemetryEvaluator evaluator;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'biocycle_escalation_',
    );
    dbPath = p.join(tempDir.path, 'test_escalation.db');
    database = await AppDatabase.open(dbPath: dbPath);
    insightRepo = LocalInsightRepository(database);
    evaluator = const TelemetryEvaluator();
  });

  tearDown(() async {
    await database.database.close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('Attention to Critical escalation maintains single episode and same alert ID', () async {
    final now = DateTime.now().toUtc();
    final activeDevice = Device(
      id: 'demo-kit-001',
      unitId: 1,
      code: 'BCK-001',
      isConnected: true,
      firmware: 'demo-1.0.0',
      lastSeenAt: now,
    );

    // 1. Step 1: Substrate temp = 36.5 °C (triggers attention)
    final measurementsAttention = {
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
        sampleId: 'sample-1',
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
        sampleId: 'sample-2',
      ),
      TelemetryParameterKeys.substrateTemperature: TelemetryMeasurement(
        id: 3,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 36.5,
        measuredAt: now,
        receivedAt: now,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-3',
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
        sampleId: 'sample-4',
      ),
    };

    final evalAttention = evaluator.evaluateUnit(
      unitId: 1,
      device: activeDevice,
      latestMeasurements: measurementsAttention,
      currentTime: now,
    );
    expect(evalAttention.condition, ConditionState.attention);

    final updateAttention = await insightRepo.evaluateEvaluationResult(
      unitId: 1,
      unitName: 'Unit BSF 01 - Rak A',
      evaluationResult: evalAttention,
    );

    expect(updateAttention.shouldNotify, isTrue);
    expect(updateAttention.event, isNotNull);
    final attentionAlertId = updateAttention.event!.id;
    final attentionEpisodeId = updateAttention.event!.episodeId;
    expect(updateAttention.event!.severity, 'attention');

    // Verify active alert count is 1
    var activeAlerts = await insightRepo.getActiveInsights();
    expect(activeAlerts.length, 1);
    expect(activeAlerts.first.id, attentionAlertId);

    // 2. Step 2: Substrate temp rises to 39.5 °C (escalation to critical)
    final later = now.add(const Duration(seconds: 30));
    final measurementsCritical = Map<String, TelemetryMeasurement>.from(
      measurementsAttention,
    );
    measurementsCritical[TelemetryParameterKeys.substrateTemperature] =
        TelemetryMeasurement(
          id: 5,
          unitId: 1,
          deviceId: 'demo-kit-001',
          parameterKey: TelemetryParameterKeys.substrateTemperature,
          value: 39.5,
          measuredAt: later,
          receivedAt: later,
          quality: 'valid',
          source: 'simulated',
          configVersion: 'demo-v1',
          sampleId: 'sample-5',
        );

    final evalCritical = evaluator.evaluateUnit(
      unitId: 1,
      device: activeDevice,
      latestMeasurements: measurementsCritical,
      currentTime: later,
    );
    expect(evalCritical.condition, ConditionState.critical);

    final updateCritical = await insightRepo.evaluateEvaluationResult(
      unitId: 1,
      unitName: 'Unit BSF 01 - Rak A',
      evaluationResult: evalCritical,
    );

    // CONTRACT EXPECTATIONS:
    // 1. Must notify on escalation
    expect(updateCritical.shouldNotify, isTrue);
    expect(updateCritical.event, isNotNull);

    // 2. Alert ID and Episode ID must remain identical!
    expect(updateCritical.event!.id, equals(attentionAlertId));
    expect(updateCritical.event!.episodeId, equals(attentionEpisodeId));

    // 3. Severity must be escalated to critical
    expect(updateCritical.event!.severity, equals('critical'));

    // 4. Exactly one active alert exists in total (no duplicates!)
    activeAlerts = await insightRepo.getActiveInsights();
    expect(activeAlerts.length, equals(1));
    expect(activeAlerts.first.id, equals(attentionAlertId));
    expect(activeAlerts.first.severity, equals('critical'));
  });
}
