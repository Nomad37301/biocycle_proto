import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/core/notifications/notification_service.dart';
import 'package:biocycle_proto/core/time/app_clock.dart';
import 'package:biocycle_proto/features/demo_session/application/demo_session_controller.dart';
import 'package:biocycle_proto/features/demo_session/domain/simulation_engine.dart';
import 'package:biocycle_proto/features/insights/data/local_insight_repository.dart';
import 'package:biocycle_proto/features/monitoring/data/local_telemetry_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_evaluator.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:biocycle_proto/features/partners/data/local_partner_repository.dart';

class FakeNotificationService extends NotificationService {
  @override
  Future<void> showInsight({
    required int id,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> showPartner({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;
  late AppDatabase database;
  late LocalTelemetryRepository telemetryRepo;
  late LocalInsightRepository insightRepo;
  late LocalPartnerRepository partnerRepo;
  late TelemetryEvaluator evaluator;
  late FakeAppClock fakeClock;
  late SimulationEngine simulationEngine;
  late DemoSessionController controller;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'biocycle_freshness_',
    );
    dbPath = p.join(tempDir.path, 'test_freshness.db');
    database = await AppDatabase.open(dbPath: dbPath);
    telemetryRepo = LocalTelemetryRepository(database);
    insightRepo = LocalInsightRepository(database);
    partnerRepo = LocalPartnerRepository(database);
    evaluator = const TelemetryEvaluator();
    fakeClock = FakeAppClock(DateTime.utc(2026, 9, 19, 12, 0, 0));
    simulationEngine = SimulationEngine(
      telemetry: telemetryRepo,
      clock: fakeClock,
    );
    controller = DemoSessionController(
      database,
      telemetryRepo,
      insightRepo,
      FakeNotificationService(),
      partnerRepo,
      simulationEngine,
      evaluator,
      fakeClock,
    );
  });

  tearDown(() async {
    controller.dispose();
    await database.database.close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('Freshness degrades (fresh -> aging -> stale -> offline) when simulator is paused and time advances', () async {
    final t0 = fakeClock.now;

    // 1. Insert fresh telemetry at t0
    final device = Device(
      id: 'demo-kit-001',
      unitId: 1,
      code: 'BCK-001',
      isConnected: true,
      firmware: 'demo-1.0.0',
      lastSeenAt: t0,
    );
    await telemetryRepo.updateDeviceConnection(device.id, true, t0);

    for (final key in TelemetryParameterKeys.all) {
      await telemetryRepo.insertMeasurement(
        TelemetryMeasurement(
          id: 0,
          unitId: 1,
          deviceId: device.id,
          parameterKey: key,
          value: 30.0,
          measuredAt: t0,
          receivedAt: t0,
          quality: 'valid',
          source: 'simulated',
          configVersion: 'demo-v1',
          sampleId: 'fresh-$key-0',
        ),
      );
    }

    // Evaluate at t0 (0s diff): DataState is fresh
    var latest = await telemetryRepo.getLatestMeasurements(1);
    var eval = evaluator.evaluateUnit(
      unitId: 1,
      device: device,
      latestMeasurements: latest,
      currentTime: fakeClock.now,
    );
    expect(eval.dataState, DataState.fresh);

    // 2. Pause simulator
    await controller.toggleManualPause();
    expect(controller.state.manuallyPaused, isTrue);

    // Count measurements before time advancement
    final countBefore = (await telemetryRepo.getLatestMeasurements(1)).length;

    // 3. Advance clock by 40 seconds -> aging (> 30s)
    fakeClock.advance(const Duration(seconds: 40));
    await controller
        .tick(); // Tick runs evaluation without simulation engine write!

    latest = await telemetryRepo.getLatestMeasurements(1);
    eval = evaluator.evaluateUnit(
      unitId: 1,
      device: device,
      latestMeasurements: latest,
      currentTime: fakeClock.now,
    );
    expect(eval.dataState, DataState.aging);

    // 4. Advance clock by 280 seconds (total 320s > 300s) -> stale
    fakeClock.advance(const Duration(seconds: 280));
    await controller.tick();

    latest = await telemetryRepo.getLatestMeasurements(1);
    eval = evaluator.evaluateUnit(
      unitId: 1,
      device: device,
      latestMeasurements: latest,
      currentTime: fakeClock.now,
    );
    expect(eval.dataState, DataState.stale);

    // 5. Advance clock by 350 seconds (total 670s > 600s) -> offline
    fakeClock.advance(const Duration(seconds: 350));
    await controller.tick();

    latest = await telemetryRepo.getLatestMeasurements(1);
    eval = evaluator.evaluateUnit(
      unitId: 1,
      device: device,
      latestMeasurements: latest,
      currentTime: fakeClock.now,
    );
    expect(eval.dataState, DataState.offline);

    // Verify no new telemetry was inserted while paused
    final countAfter = (await telemetryRepo.getLatestMeasurements(1)).length;
    expect(countAfter, equals(countBefore));
  });
}
