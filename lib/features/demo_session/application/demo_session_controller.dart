import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/time/app_clock.dart';
import '../../insights/domain/insight_repository.dart';
import '../../monitoring/domain/telemetry_evaluator.dart';
import '../../monitoring/domain/telemetry_models.dart';
import '../../monitoring/domain/telemetry_repository.dart';
import '../../partners/domain/partner_repository.dart';
import '../domain/demo_session.dart';
import '../domain/simulation_engine.dart';

class DemoSessionController extends StateNotifier<DemoSessionState> {
  DemoSessionController(
    this._database,
    this._telemetry,
    this._insights,
    this._notifications,
    this._partners,
    this._simulationEngine,
    this._evaluator,
    this._clock,
  ) : super(const DemoSessionState());

  final AppDatabase _database;
  final TelemetryRepository _telemetry;
  final InsightRepository _insights;
  final NotificationService _notifications;
  final PartnerRepository _partners;
  final SimulationEngine _simulationEngine;
  final TelemetryEvaluator _evaluator;
  final AppClock _clock;

  Timer? _timer;
  bool _settingsLoaded = false;
  bool _starting = false;
  Future<void> _serial = Future.value();

  Future<void> start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _loadSettings();
      await _deliverPartnerNotifications(state.role.organizationId);
      await _evaluateAll();
      _startTimer();
    } finally {
      _starting = false;
    }
  }

  Future<void> _loadSettings() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    final savedRole = await _database.getSetting('active_role');
    final savedScenario = await _database.getSetting('demo_scenario');
    final paused = await _database.getSetting('simulator_paused') == 'true';
    final selectedUnitId =
        int.tryParse(await _database.getSetting('selected_unit_id') ?? '') ?? 1;
    final roles = DemoRole.values.where((item) => item.name == savedRole);
    final scenarios = DemoScenario.values.where(
      (item) => item.name == savedScenario,
    );
    state = state.copyWith(
      role: roles.isEmpty ? DemoRole.operator : roles.first,
      scenario: scenarios.isEmpty ? DemoScenario.normal : scenarios.first,
      manuallyPaused: paused,
      selectedUnitId: selectedUnitId,
    );
  }

  void _startTimer() {
    if (_timer != null) return;
    state = state.copyWith(running: true);
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_enqueueUpdate()),
    );
  }

  void pauseForLifecycle() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(running: false);
  }

  Future<void> resumeForLifecycle() async {
    await _loadSettings();
    _startTimer();
  }

  Future<void> toggleManualPause() async {
    final paused = !state.manuallyPaused;
    await _database.setSetting('simulator_paused', paused.toString());
    state = state.copyWith(manuallyPaused: paused);
  }

  Future<void> setRole(DemoRole role) async {
    state = state.copyWith(role: role);
    await _database.setSetting('active_role', role.name);
    await _deliverPartnerNotifications(role.organizationId);
  }

  Future<void> _deliverPartnerNotifications(int accountId) async {
    final enabled =
        await _database.getSetting('notifications_enabled') == 'true';
    if (!enabled) return;
    final items = await _partners.takePendingNotifications(accountId);
    for (final item in items) {
      try {
        await _notifications.showPartner(
          id: item.id,
          title: item.title,
          body: item.body,
          payload: item.payload,
        );
      } catch (_) {}
    }
  }

  Future<void> setScenario(DemoScenario scenario) async {
    state = state.copyWith(scenario: scenario);
    await _database.setSetting('demo_scenario', scenario.name);
    final operation = _serial.then((_) async {
      await _simulationEngine.triggerScenario(state.selectedUnitId, scenario);
      await _evaluateAll();
    });
    _serial = operation.catchError((_) {});
    await operation;
  }

  Future<void> setSelectedUnit(int unitId) async {
    state = state.copyWith(selectedUnitId: unitId);
    await _database.setSetting('selected_unit_id', '$unitId');
    refresh();
  }

  Future<void> fastForward15Minutes() async {
    state = state.copyWith(
      isFastForwarding: true,
      fastForwardLabel: 'Waktu simulasi dipercepat +15 menit',
    );
    final operation = _serial.then((_) async {
      await _simulationEngine.fastForward(
        const Duration(minutes: 15),
        unitId: state.selectedUnitId,
      );
      await _evaluateAll();
    });
    _serial = operation.catchError((_) {});
    await operation;
    state = state.copyWith(isFastForwarding: false);
  }

  Future<void> _enqueueUpdate() {
    final operation = _serial.then((_) => _update());
    _serial = operation.catchError((_) {});
    return operation;
  }

  Future<void> tick() async {
    final operation = _serial.then((_) => _update());
    _serial = operation.catchError((_) {});
    await operation;
  }

  Future<void> _update() async {
    if (!state.manuallyPaused) {
      await _simulationEngine.stepAll();
    }
    await _evaluateAll();
  }

  Future<void> _evaluateAll() async {
    await _insights.evaluatePendingActions(currentTime: _clock.now);
    final units = await _telemetry.getUnits();
    final enabled =
        await _database.getSetting('notifications_enabled') == 'true';

    for (final unit in units) {
      final devices = await _telemetry.getDevices(unit.id);
      final device = devices.firstOrNull;
      final latest = await _telemetry.getLatestMeasurements(unit.id);

      final evalResult = _evaluator.evaluateUnit(
        unitId: unit.id,
        device: device,
        latestMeasurements: latest,
        currentTime: _clock.now,
      );

      final update = await _insights.evaluateEvaluationResult(
        unitId: unit.id,
        unitName: unit.name,
        evaluationResult: evalResult,
      );

      if (enabled && update.shouldNotify && update.event != null) {
        try {
          await _notifications.showInsight(
            id: update.event!.id,
            title:
                '${update.event!.severity == 'critical' ? 'Kritis' : 'Perlu perhatian'}: ${unit.name}',
            body: update.event!.cause,
          );
        } catch (_) {}
      }
    }
    state = state.copyWith(revision: state.revision + 1);
  }

  void refresh() => state = state.copyWith(revision: state.revision + 1);

  Future<void> updateThresholds(int unitId, UnitThresholds thresholds) async {
    await _telemetry.updateThresholds(unitId, thresholds);
    refresh();
  }

  Future<void> reset() async {
    pauseForLifecycle();
    final operation = _serial.then((_) async {
      _simulationEngine.reset();
      await _database.reset();
      await _notifications.cancelAll();
      _notifications.sessionGeneration =
          int.tryParse(
            await _database.getSetting('session_generation') ?? '',
          ) ??
          1;
      _settingsLoaded = true;
      state = const DemoSessionState(revision: 1);
      _startTimer();
    });
    _serial = operation.catchError((_) {});
    await operation;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
