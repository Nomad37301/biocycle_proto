import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/features/monitoring/data/local_telemetry_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;
  late AppDatabase database;
  late LocalTelemetryRepository telemetryRepo;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'biocycle_late_telemetry_',
    );
    dbPath = p.join(tempDir.path, 'test_late.db');
    database = await AppDatabase.open(dbPath: dbPath);
    telemetryRepo = LocalTelemetryRepository(database);
  });

  tearDown(() async {
    await database.database.close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('Late-arriving telemetry does not overwrite latest cache or latest query result', () async {
    final t1005 = DateTime.utc(2026, 9, 19, 10, 5, 0);
    final t1010 = DateTime.utc(2026, 9, 19, 10, 10, 0);
    final t1007 = DateTime.utc(2026, 9, 19, 10, 7, 0);

    // 1. Insert Measurement A (10:05, temp = 31.0)
    await telemetryRepo.insertMeasurement(
      TelemetryMeasurement(
        id: 0,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 31.0,
        measuredAt: t1005,
        receivedAt: t1005,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-A-1005',
      ),
    );

    // 2. Insert Measurement B (10:10, temp = 33.0)
    await telemetryRepo.insertMeasurement(
      TelemetryMeasurement(
        id: 0,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 33.0,
        measuredAt: t1010,
        receivedAt: t1010,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-B-1010',
      ),
    );

    var latest = await telemetryRepo.getLatestMeasurements(1);
    expect(latest[TelemetryParameterKeys.substrateTemperature]?.value, 33.0);
    expect(
      latest[TelemetryParameterKeys.substrateTemperature]?.measuredAt,
      t1010,
    );

    var unit = await telemetryRepo.getUnit(1);
    expect(unit?.temperature, 33.0);
    expect(unit?.updatedAt, t1010);

    // 3. Late arriving Measurement C (10:07, temp = 32.0, arrives AFTER 10:10)
    await telemetryRepo.insertMeasurement(
      TelemetryMeasurement(
        id: 0,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 32.0,
        measuredAt: t1007,
        receivedAt: DateTime.utc(2026, 9, 19, 10, 11, 0), // Received late
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-C-1007',
      ),
    );

    // CONTRACT VERIFICATION:
    // A, B, and C must all exist in history
    final history = await telemetryRepo.getMeasurementHistory(
      1,
      TelemetryParameterKeys.substrateTemperature,
      const Duration(hours: 24),
    );
    final historySampleIds = history.map((m) => m.sampleId).toList();
    expect(
      historySampleIds,
      containsAll(['sample-A-1005', 'sample-B-1010', 'sample-C-1007']),
    );

    // Latest must STILL be B (10:10, 33.0), NOT degraded to C!
    latest = await telemetryRepo.getLatestMeasurements(1);
    expect(latest[TelemetryParameterKeys.substrateTemperature]?.value, 33.0);
    expect(
      latest[TelemetryParameterKeys.substrateTemperature]?.sampleId,
      'sample-B-1010',
    );

    // Units table scalar cache must NOT be degraded to C!
    unit = await telemetryRepo.getUnit(1);
    expect(unit?.temperature, 33.0);
    expect(unit?.updatedAt, t1010);

    // 4. Duplicate sampleId is ignored and does not throw or corrupt data
    await telemetryRepo.insertMeasurement(
      TelemetryMeasurement(
        id: 0,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 99.0, // Attempt to corrupt
        measuredAt: t1010,
        receivedAt: t1010,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-B-1010', // duplicate
      ),
    );

    latest = await telemetryRepo.getLatestMeasurements(1);
    expect(latest[TelemetryParameterKeys.substrateTemperature]?.value, 33.0);
  });
}
