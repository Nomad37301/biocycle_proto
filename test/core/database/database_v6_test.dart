import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/features/monitoring/data/local_telemetry_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database v6 and TelemetryRepository', () {
    late AppDatabase appDb;
    late LocalTelemetryRepository repository;

    setUp(() async {
      appDb = await AppDatabase.open(dbPath: inMemoryDatabasePath);
      repository = LocalTelemetryRepository(appDb);
    });

    tearDown(() async {
      await appDb.database.close();
    });

    test('Fresh install creates v6 schema with stable seed', () async {
      final units = await repository.getUnits();
      expect(units.length, 3);
      expect(units[0].id, 1);
      expect(units[0].kitCode, 'BCK-001');

      final devices = await repository.getDevices(1);
      expect(devices.length, 1);
      expect(devices.first.id, 'demo-kit-001');
      expect(devices.first.code, 'BCK-001');

      final params = await repository.getSensorParameters('demo-kit-001');
      expect(params.length, 4);

      final latest = await repository.getLatestMeasurements(1);
      expect(
        latest.containsKey(TelemetryParameterKeys.substrateTemperature),
        isTrue,
      );
      expect(
        latest.containsKey(TelemetryParameterKeys.substrateMoisture),
        isTrue,
      );
      expect(
        latest.containsKey(TelemetryParameterKeys.ambientTemperature),
        isTrue,
      );
      expect(
        latest.containsKey(TelemetryParameterKeys.ambientHumidity),
        isTrue,
      );

      final history = await repository.getMeasurementHistory(
        1,
        TelemetryParameterKeys.substrateTemperature,
        const Duration(hours: 25),
      );
      expect(history.length, 25);
    });

    test(
      'Inserting new measurement preserves ordering and updates latest',
      () async {
        final now = DateTime.now().toUtc();
        final newMeasurement = TelemetryMeasurement(
          id: 0,
          unitId: 1,
          deviceId: 'demo-kit-001',
          parameterKey: TelemetryParameterKeys.substrateTemperature,
          value: 36.5,
          measuredAt: now.add(const Duration(minutes: 5)),
          receivedAt: now.add(const Duration(minutes: 5)),
          quality: 'valid',
          source: 'simulated',
          configVersion: 'demo-v1',
          sampleId: 'test-sample-1',
        );

        await repository.insertMeasurement(newMeasurement);

        final latest = await repository.getLatestMeasurements(1);
        expect(
          latest[TelemetryParameterKeys.substrateTemperature]?.value,
          36.5,
        );
      },
    );

    test('Reset clears data and reseeds stable configuration', () async {
      await appDb.reset();

      final units = await repository.getUnits();
      expect(units.length, 3);

      final setting = await appDb.getSetting('seed_version');
      expect(setting, '6');
    });
  });
}
