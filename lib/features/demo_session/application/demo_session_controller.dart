import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../insights/domain/insight_repository.dart';
import '../../monitoring/domain/telemetry_repository.dart';
import '../domain/demo_session.dart';

class DemoSessionController extends StateNotifier<DemoSessionState> {
  DemoSessionController(
    this._database,
    this._telemetry,
    this._insights,
    this._notifications,
  ) : super(const DemoSessionState());

  final AppDatabase _database;
  final TelemetryRepository _telemetry;
  final InsightRepository _insights;
  final NotificationService _notifications;
  Timer? _timer;
  int _tick = 0;
  bool _settingsLoaded = false;
  bool _starting = false;
  Future<void> _serial = Future.value();

  Future<void> start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _loadSettings();
      if (!state.manuallyPaused) _startTimer();
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
    final roles = DemoRole.values.where((item) => item.name == savedRole);
    final scenarios = DemoScenario.values.where(
      (item) => item.name == savedScenario,
    );
    state = state.copyWith(
      role: roles.isEmpty ? DemoRole.operator : roles.first,
      scenario: scenarios.isEmpty ? DemoScenario.normal : scenarios.first,
      manuallyPaused: paused,
    );
  }

  void _startTimer() {
    if (_timer != null || state.manuallyPaused) return;
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
    if (!state.manuallyPaused) _startTimer();
  }

  Future<void> toggleManualPause() async {
    final paused = !state.manuallyPaused;
    await _database.setSetting('simulator_paused', paused.toString());
    state = state.copyWith(manuallyPaused: paused);
    if (paused) {
      pauseForLifecycle();
      state = state.copyWith(manuallyPaused: true);
    } else {
      _startTimer();
    }
  }

  void setRole(DemoRole role) {
    state = state.copyWith(role: role);
    unawaited(_database.setSetting('active_role', role.name));
  }

  Future<void> setScenario(DemoScenario scenario) async {
    state = state.copyWith(scenario: scenario);
    _tick = 0;
    await _database.setSetting('demo_scenario', scenario.name);
    await _enqueueUpdate();
  }

  Future<void> _enqueueUpdate() {
    final operation = _serial.then((_) => _update());
    _serial = operation.catchError((_) {});
    return operation;
  }

  Future<void> _update() async {
    _tick++;
    final unit = await _telemetry.recordScenario(1, state.scenario.name, _tick);
    final update = await _insights.evaluate(unit);
    final enabled =
        await _database.getSetting('notifications_enabled') == 'true';
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
    state = state.copyWith(revision: state.revision + 1);
  }

  void refresh() => state = state.copyWith(revision: state.revision + 1);

  Future<void> reset() async {
    pauseForLifecycle();
    final operation = _serial.then((_) async {
      await _database.reset();
      await _notifications.cancelAll();
      _tick = 0;
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
