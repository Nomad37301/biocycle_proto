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

class ThrowingNotificationService extends NotificationService {
  @override
  Future<void> showInsight({
    required int id,
    required String title,
    required String body,
  }) async {
    throw Exception(
      'OS Notification Service Failure: Permission denied or IPC timeout',
    );
  }

  @override
  Future<void> showPartner({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    throw Exception('Partner Notification Failure');
  }
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
      'biocycle_notif_fail_',
    );
    dbPath = p.join(tempDir.path, 'test_notif.db');
    database = await AppDatabase.open(dbPath: dbPath);
    await database.setSetting('notifications_enabled', 'true');

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
      ThrowingNotificationService(), // Always throws!
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

  test('Notification failure does not prevent alert persistence and domain state transitions', () async {
    final now = fakeClock.now;
    // Pause simulator so stepAll doesn't overwrite with normal values
    await controller.toggleManualPause();

    // 1. Insert measurement that triggers thermal critical violation (> 38 °C)
    await telemetryRepo.insertMeasurement(
      TelemetryMeasurement(
        id: 0,
        unitId: 1,
        deviceId: 'demo-kit-001',
        parameterKey: TelemetryParameterKeys.substrateTemperature,
        value: 39.5,
        measuredAt: now,
        receivedAt: now,
        quality: 'valid',
        source: 'simulated',
        configVersion: 'demo-v1',
        sampleId: 'sample-crit-notif-fail',
      ),
    );

    // Update device lastSeenAt so it is fresh
    await telemetryRepo.updateDeviceConnection('demo-kit-001', true, now);

    // 2. Run tick / evaluateAll (NotificationService.showInsight will throw Exception)
    // Must NOT throw unhandled exception or crash!
    await expectLater(controller.tick(), completes);

    // 3. CONTRACT VERIFICATION:
    // The alert MUST be persisted and active in the database despite the notification crash!
    final activeAlerts = await insightRepo.getActiveInsights();
    expect(activeAlerts, isNotEmpty);
    final alert = activeAlerts.firstWhere((a) => a.unitId == 1);
    expect(alert.severity, equals('critical'));
    expect(alert.isActive, isTrue);
    expect(alert.cause, contains('batas kritis'));
  });
}
