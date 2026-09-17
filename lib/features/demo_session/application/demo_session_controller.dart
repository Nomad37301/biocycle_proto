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
  bool _updating = false;
  bool _settingsLoaded = false;
  bool _starting = false;

  Future<void> start() async {
    if (_timer != null || _starting) return;
    _starting = true;
    try {
      if (!_settingsLoaded) {
        _settingsLoaded = true;
        final savedRole = await _database.getSetting('active_role');
        final role = DemoRole.values.where((item) => item.name == savedRole);
        if (role.isNotEmpty) state = state.copyWith(role: role.first);
      }
      if (_timer != null) return;
      state = state.copyWith(running: true);
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _update());
    } finally {
      _starting = false;
    }
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(running: false);
  }

  Future<void> resume() => start();

  void setRole(DemoRole role) {
    state = state.copyWith(role: role);
    unawaited(_database.setSetting('active_role', role.name));
  }

  Future<void> setScenario(DemoScenario scenario) async {
    state = state.copyWith(scenario: scenario);
    _tick = 0;
    await _update();
  }

  Future<void> _update() async {
    if (_updating) return;
    _updating = true;
    try {
      _tick++;
      final unit = await _telemetry.recordScenario(
        1,
        state.scenario.name,
        _tick,
      );
      final update = await _insights.evaluate(unit);
      if (update.shouldNotify && update.event != null) {
        await _notifications.showInsight(
          id: update.event!.id,
          title:
              '${update.event!.severity == 'critical' ? 'Kritis' : 'Perlu perhatian'}: ${unit.name}',
          body: update.event!.cause,
        );
      }
      state = state.copyWith(revision: state.revision + 1);
    } finally {
      _updating = false;
    }
  }

  void refresh() => state = state.copyWith(revision: state.revision + 1);

  Future<void> reset() async {
    pause();
    await _database.reset();
    await _notifications.cancelAll();
    _tick = 0;
    _settingsLoaded = true;
    state = const DemoSessionState(revision: 1);
    await start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
