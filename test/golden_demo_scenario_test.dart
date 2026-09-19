import 'package:biocycle_proto/core/config/demo_configuration.dart';
import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/core/time/app_clock.dart';
import 'package:biocycle_proto/features/demo_session/domain/demo_session.dart';
import 'package:biocycle_proto/features/demo_session/domain/simulation_engine.dart';
import 'package:biocycle_proto/features/insights/data/local_insight_repository.dart';
import 'package:biocycle_proto/features/insights/domain/insight_models.dart';
import 'package:biocycle_proto/features/monitoring/data/local_telemetry_repository.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_evaluator.dart';
import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:biocycle_proto/features/partners/data/local_partner_repository.dart';
import 'package:biocycle_proto/features/partners/domain/partner_models.dart';
import 'package:biocycle_proto/features/partners/domain/pitch_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Golden Demo Scenario konsisten dua putaran setelah reset', () async {
    final database = await AppDatabase.open(dbPath: inMemoryDatabasePath);
    const configuration = DemoConfiguration();

    for (var pass = 1; pass <= 2; pass++) {
      await database.reset();
      final telemetry = LocalTelemetryRepository(database);
      final insights = LocalInsightRepository(database);
      final partners = LocalPartnerRepository(database);
      final clock = FakeAppClock(DateTime.now().toUtc());
      final engine = SimulationEngine(
        telemetry: telemetry,
        clock: clock,
        config: configuration,
      );
      const evaluator = TelemetryEvaluator();

      expect(await database.getSetting('onboarding_complete'), 'false');
      expect(await _count(database, 'insights'), 0);
      expect(await _count(database, 'insight_actions'), 0);
      expect(await _count(database, 'app_notifications'), 0);

      final units = await telemetry.getUnits();
      expect(units.map((unit) => unit.id), [1, 2, 3]);
      for (final unit in units) {
        final latest = await telemetry.getLatestMeasurements(unit.id);
        expect(latest.keys.toSet(), TelemetryParameterKeys.all.toSet());
        final history = await telemetry.getMeasurementHistory(
          unit.id,
          TelemetryParameterKeys.substrateTemperature,
          const Duration(hours: 24),
        );
        expect(history, isNotEmpty);
      }
      final unit1Before = await telemetry.getLatestMeasurements(1);
      expect(
        unit1Before[TelemetryParameterKeys.substrateTemperature]!.value,
        30,
      );

      await engine.triggerScenario(2, DemoScenario.thermalCritical);
      final critical = await _evaluate(
        telemetry,
        insights,
        evaluator,
        clock,
        2,
      );
      expect(critical.condition, UnitCondition.critical);
      expect(
        critical
            .parameterResults[TelemetryParameterKeys.substrateTemperature]!
            .value,
        closeTo(39, configuration.simulator.temperatureNoiseAmplitude),
      );
      final unit1After = await _evaluate(
        telemetry,
        insights,
        evaluator,
        clock,
        1,
      );
      expect(unit1After.condition, UnitCondition.optimal);

      final alert = (await insights.getActiveInsights()).single;
      expect(alert.unitId, 2);
      expect(alert.parameterKey, TelemetryParameterKeys.substrateTemperature);
      expect(alert.configVersion, configuration.version);
      expect(alert.sopVersion, isNotEmpty);
      expect(alert.triggerMeasuredAt, isNotNull);
      expect(sopSteps[alert.kind], isNotEmpty);

      await insights.acknowledge(alert.id, 'Operator BSF');
      await insights.saveAction(
        alert.id,
        const {0, 1, 2},
        'Tindakan Golden Demo putaran $pass',
        responseType: ActionResponseType.done,
        idempotencyKey: 'golden-$pass',
        currentTime: clock.now,
      );
      var savedAlert = await insights.getInsight(alert.id);
      var actions = await insights.getActions(alert.id);
      expect(savedAlert!.isActive, isTrue);
      expect(savedAlert.acknowledgedBy, 'Operator BSF');
      expect(
        actions.single.evaluationStatus,
        ActionEvaluationStatus.pendingEvaluation,
      );
      expect(
        actions.single.beforeValue,
        closeTo(39, configuration.simulator.temperatureNoiseAmplitude),
      );

      await engine.triggerScenario(2, DemoScenario.recovery);
      await _evaluate(telemetry, insights, evaluator, clock, 2);
      savedAlert = await insights.getInsight(alert.id);
      expect(savedAlert!.isActive, isTrue);
      await engine.stepUnit(2);
      await _evaluate(telemetry, insights, evaluator, clock, 2);
      savedAlert = await insights.getInsight(alert.id);
      expect(savedAlert!.isActive, isFalse);

      clock.advance(const Duration(minutes: 15));
      await engine.stepUnit(2);
      await insights.evaluatePendingActions(currentTime: clock.now);
      actions = await insights.getActions(alert.id);
      expect(actions.single.evaluationStatus, ActionEvaluationStatus.evaluated);
      expect(actions.single.afterValue, isNotNull);

      await engine.triggerScenario(3, DemoScenario.substrateWet);
      final wet = await _evaluate(telemetry, insights, evaluator, clock, 3);
      expect(wet.condition, UnitCondition.attention);
      expect(
        wet.parameterResults[TelemetryParameterKeys.substrateMoisture]!.value,
        closeTo(85, configuration.simulator.moistureNoiseAmplitude),
      );

      final writesBeforeOffline = await _count(
        database,
        'telemetry_measurements',
      );
      await engine.triggerScenario(3, DemoScenario.deviceOffline);
      await engine.stepUnit(3);
      final offline = await _evaluate(telemetry, insights, evaluator, clock, 3);
      expect(offline.dataState, DataState.offline);
      expect(offline.condition, UnitCondition.unknown);
      expect(
        await _count(database, 'telemetry_measurements'),
        writesBeforeOffline,
      );

      await database.setSetting('mode_terik', 'true');
      expect(await database.getSetting('mode_terik'), 'true');

      await partners.transitionRequest(
        id: 1001,
        next: RequestStatus.accepted,
        actorId: 1,
        acceptedQuantityKg: 250,
      );
      final request = (await partners.getRequest(1001))!;
      final listing = (await partners.getListing(101))!;
      expect(request.initialQuantityKg, 500);
      expect(request.acceptedQuantityKg, 250);
      expect(listing.availableKg, 250);
      expect((await partners.getRequestHistory(1001)).length, 2);

      final flow = await partners.getNetworkFlow();
      expect(flow.wasteInKg, 120);
      expect(flow.outputKg, 60);
      final estimate = PitchCalculator.calculate(
        wasteInputKg: flow.wasteInKg,
        monitoredUnits: flow.monitoredUnits,
        configuration: configuration,
      );
      expect(estimate.configVersion, configuration.version);
      expect(estimate.projectedRevenue, greaterThan(0));
    }

    await database.database.close();
  });
}

Future<UnitEvaluationResult> _evaluate(
  LocalTelemetryRepository telemetry,
  LocalInsightRepository insights,
  TelemetryEvaluator evaluator,
  FakeAppClock clock,
  int unitId,
) async {
  final unit = (await telemetry.getUnits()).firstWhere(
    (item) => item.id == unitId,
  );
  final device = (await telemetry.getDevices(unitId)).single;
  final latest = await telemetry.getLatestMeasurements(unitId);
  final evaluation = evaluator.evaluateUnit(
    unitId: unitId,
    device: device,
    latestMeasurements: latest,
    currentTime: clock.now,
  );
  await insights.evaluateEvaluationResult(
    unitId: unitId,
    unitName: unit.name,
    evaluationResult: evaluation,
  );
  return evaluation;
}

Future<int> _count(AppDatabase database, String table) async {
  final rows = await database.database.rawQuery(
    'SELECT COUNT(*) AS count FROM $table',
  );
  return rows.single['count']! as int;
}
