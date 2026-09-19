import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/features/insights/data/local_insight_repository.dart';
import 'package:biocycle_proto/features/insights/domain/insight_models.dart';
import 'package:biocycle_proto/features/monitoring/data/local_telemetry_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;
  late AppDatabase database;
  late LocalInsightRepository insightRepo;
  late LocalTelemetryRepository telemetryRepo;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('biocycle_sop_');
    dbPath = p.join(tempDir.path, 'test_sop.db');
    database = await AppDatabase.open(dbPath: dbPath);
    insightRepo = LocalInsightRepository(database);
    telemetryRepo = LocalTelemetryRepository(database);
  });

  tearDown(() async {
    await database.database.close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  Future<int> createTestInsight() async {
    final now = DateTime.now().toUtc().toIso8601String();
    return await database.database.insert('insights', {
      'unit_id': 1,
      'unit_name': 'Unit BSF 01',
      'kind': 'thermalCritical',
      'parameter_key': TelemetryParameterKeys.substrateTemperature,
      'rule_id': 'substrateTemperatureRule',
      'severity': 'critical',
      'cause': 'Suhu substrat 39 °C',
      'recommendation': 'Buka ventilasi',
      'started_at': now,
      'updated_at': now,
      'episode_id': 'ep-1-test',
    });
  }

  test('unable and notRelevant result directly in notApplicable status without comparison', () async {
    final insightId = await createTestInsight();

    // 1. Unable
    await insightRepo.saveAction(
      insightId,
      const {0},
      'Kipas rusak, tidak dapat melakukan tindakan',
      responseType: ActionResponseType.unable,
      idempotencyKey: 'idemp-unable-1',
    );

    var actions = await insightRepo.getInsightActions(insightId);
    expect(actions.length, 1);
    expect(actions.first.responseType, ActionResponseType.unable);
    expect(
      actions.first.evaluationStatus,
      ActionEvaluationStatus.notApplicable,
    );

    // 2. Not relevant
    await insightRepo.saveAction(
      insightId,
      const {1},
      'Sensor terlepas sementara, alarm tidak relevan',
      responseType: ActionResponseType.notRelevant,
      idempotencyKey: 'idemp-not-rel-1',
    );

    actions = await insightRepo.getInsightActions(insightId);
    expect(actions.length, 2);
    final notRelAction = actions.firstWhere(
      (a) => a.idempotencyKey == 'idemp-not-rel-1',
    );
    expect(notRelAction.responseType, ActionResponseType.notRelevant);
    expect(notRelAction.evaluationStatus, ActionEvaluationStatus.notApplicable);
  });

  test(
    'Missing before measurement results in immediate insufficientData',
    () async {
      // Buat unit baru tanpa telemetry history
      await database.database.insert('units', {
        'id': 99,
        'name': 'Unit 99 Kosong',
        'kit_code': 'BCK-099',
        'temperature': 30.0,
        'humidity': 60.0,
        'medium': 'Biomassa',
        'is_connected': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final emptyInsightId = await database.database.insert('insights', {
        'unit_id': 99,
        'unit_name': 'Unit 99 Kosong',
        'kind': 'thermalAttention',
        'parameter_key': 'non_existent_parameter',
        'severity': 'attention',
        'cause': 'Unknown',
        'recommendation': 'Check',
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await insightRepo.saveAction(
        emptyInsightId,
        const {0},
        'Tindakan selesai tapi tidak ada data before',
        responseType: ActionResponseType.done,
        idempotencyKey: 'idemp-no-before',
      );

      final actions = await insightRepo.getInsightActions(emptyInsightId);
      expect(actions.length, 1);
      expect(
        actions.first.evaluationStatus,
        ActionEvaluationStatus.insufficientData,
      );
    },
  );

  test('Done action transitions to pendingEvaluation, then evaluated when valid after measurement exists', () async {
    final now = DateTime.now().toUtc();
    final insightId = await createTestInsight();

    // Pastikan ada before measurement yang valid
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
        sampleId: 'sample-before-1',
      ),
    );

    await insightRepo.saveAction(
      insightId,
      const {0},
      'Selesai menyalakan exhaust',
      responseType: ActionResponseType.done,
      idempotencyKey: 'idemp-done-eval-1',
      currentTime: now.add(const Duration(seconds: 1)),
    );

    var actions = await insightRepo.getInsightActions(insightId);
    expect(actions.length, 1);
    expect(actions.first.responseType, ActionResponseType.done);
    expect(
      actions.first.evaluationStatus,
      ActionEvaluationStatus.pendingEvaluation,
    );
    expect(actions.first.beforeValue, 39.0);

    // Simulasi waktu mencapai due time (+15 menit)
    final dueTime = now.add(const Duration(minutes: 16));

    // Masukkan after measurement valid
    await telemetryRepo.insertMeasurement(
      TelemetryMeasurement(
        id: 0,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 33.5,
        measuredAt: dueTime,
        receivedAt: dueTime,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-after-1',
      ),
    );

    // Panggil evaluation lifecycle
    await insightRepo.evaluatePendingActions(currentTime: dueTime);

    actions = await insightRepo.getInsightActions(insightId);
    expect(actions.first.evaluationStatus, ActionEvaluationStatus.evaluated);
    expect(actions.first.afterValue, 33.5);
  });

  test('Done action transitions to insufficientData when grace period expires without valid after measurement', () async {
    final now = DateTime.now().toUtc();
    final insightId = await createTestInsight();

    // Before valid
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
        sampleId: 'sample-before-expire',
      ),
    );

    await insightRepo.saveAction(
      insightId,
      const {0},
      'Menunggu pending evaluation',
      responseType: ActionResponseType.done,
      idempotencyKey: 'idemp-expire-1',
      currentTime: now,
    );

    // Waktu maju melewati due time (+15m) dan grace period (+5m) = +25m tanpa after measurement baru
    final afterGraceTime = now.add(const Duration(minutes: 25));

    await insightRepo.evaluatePendingActions(currentTime: afterGraceTime);

    final actions = await insightRepo.getInsightActions(insightId);
    expect(
      actions.first.evaluationStatus,
      ActionEvaluationStatus.insufficientData,
    );
  });
}
