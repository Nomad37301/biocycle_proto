import 'package:biocycle_proto/core/config/demo_configuration.dart';
import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/core/time/app_clock.dart';
import 'package:biocycle_proto/features/demo_session/domain/demo_session.dart';
import 'package:biocycle_proto/features/demo_session/domain/simulation_engine.dart';
import 'package:biocycle_proto/features/monitoring/data/local_telemetry_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SimulationEngine Scenarios', () {
    late AppDatabase appDb;
    late LocalTelemetryRepository repository;
    late FakeAppClock clock;
    late SimulationEngine engine;

    setUp(() async {
      appDb = await AppDatabase.open(dbPath: inMemoryDatabasePath);
      repository = LocalTelemetryRepository(appDb);
      clock = FakeAppClock(DateTime.utc(2026, 9, 19, 12, 0, 0));
      engine = SimulationEngine(
        telemetry: repository,
        clock: clock,
        config: const DemoConfiguration(),
      );
    });

    tearDown(() async {
      await appDb.database.close();
    });

    test(
      'thermalCritical scenario targets substrateTemperature > 38.0',
      () async {
        await engine.triggerScenario(2, DemoScenario.thermalCritical);

        final latest = await repository.getLatestMeasurements(2);
        final subTemp = latest[TelemetryParameterKeys.substrateTemperature]!;
        expect(subTemp.value, greaterThan(38.0));
        expect(subTemp.quality, 'valid');

        // Other units stay normal
        final unit1Latest = await repository.getLatestMeasurements(1);
        final u1Temp =
            unit1Latest[TelemetryParameterKeys.substrateTemperature]!;
        expect(u1Temp.value, inInclusiveRange(26.0, 35.0));
      },
    );

    test(
      'thermalAttention scenario targets substrateTemperature in (35.0, 38.0]',
      () async {
        await engine.triggerScenario(2, DemoScenario.thermalAttention);

        final latest = await repository.getLatestMeasurements(2);
        final subTemp = latest[TelemetryParameterKeys.substrateTemperature]!;
        expect(subTemp.value, greaterThan(35.0));
        expect(subTemp.value, lessThanOrEqualTo(38.0));
      },
    );

    test('substrateWet scenario targets substrateMoisture > 80.0', () async {
      await engine.triggerScenario(3, DemoScenario.substrateWet);

      final latest = await repository.getLatestMeasurements(3);
      final subMoist = latest[TelemetryParameterKeys.substrateMoisture]!;
      expect(subMoist.value, greaterThan(80.0));
    });

    test('substrateDry scenario targets substrateMoisture < 50.0', () async {
      await engine.triggerScenario(3, DemoScenario.substrateDry);

      final latest = await repository.getLatestMeasurements(3);
      final subMoist = latest[TelemetryParameterKeys.substrateMoisture]!;
      expect(subMoist.value, lessThan(50.0));
    });

    test(
      'deviceOffline marks device disconnected and does not insert writes',
      () async {
        final preCount = (await repository.getMeasurementHistory(
          3,
          TelemetryParameterKeys.substrateTemperature,
          const Duration(hours: 48),
        )).length;

        await engine.triggerScenario(3, DemoScenario.deviceOffline);

        final devices = await repository.getDevices(3);
        expect(devices.first.isConnected, isFalse);

        await engine.stepUnit(3);

        final postCount = (await repository.getMeasurementHistory(
          3,
          TelemetryParameterKeys.substrateTemperature,
          const Duration(hours: 48),
        )).length;

        expect(postCount, preCount);
      },
    );

    test(
      'sensorError sets substrateTemperature invalid while other probes work',
      () async {
        await engine.triggerScenario(1, DemoScenario.sensorError);

        final latest = await repository.getLatestMeasurements(1);
        final subTemp = latest[TelemetryParameterKeys.substrateTemperature]!;
        expect(subTemp.quality, 'invalid');
        expect(subTemp.value, isNull);

        final subMoist = latest[TelemetryParameterKeys.substrateMoisture]!;
        expect(subMoist.quality, 'valid');
        expect(subMoist.value, isNotNull);
      },
    );

    test('recovery reconnects and restores optimal values', () async {
      await engine.triggerScenario(2, DemoScenario.thermalCritical);
      await engine.triggerScenario(2, DemoScenario.recovery);

      final latest = await repository.getLatestMeasurements(2);
      final subTemp = latest[TelemetryParameterKeys.substrateTemperature]!;
      expect(subTemp.value, inInclusiveRange(26.0, 35.0));
      expect(subTemp.quality, 'valid');
    });

    test('fastForward advances clock and steps unit', () async {
      final t0 = clock.now;
      await engine.fastForward(const Duration(minutes: 15), unitId: 1);

      expect(clock.now, t0.add(const Duration(minutes: 15)));
      final latest = await repository.getLatestMeasurements(1);
      expect(
        latest[TelemetryParameterKeys.substrateTemperature]?.measuredAt,
        clock.now,
      );
    });
  });
}
