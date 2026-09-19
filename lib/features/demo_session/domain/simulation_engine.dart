import 'dart:math' as math;

import '../../../core/config/demo_configuration.dart';
import '../../../core/time/app_clock.dart';
import '../../monitoring/domain/telemetry_models.dart';
import '../../monitoring/domain/telemetry_repository.dart';
import 'demo_session.dart';

class UnitSimulationState {
  UnitSimulationState({
    required this.unitId,
    this.scenario = DemoScenario.normal,
    this.tickCount = 0,
    this.isConnected = true,
    this.hasSensorError = false,
  });

  final int unitId;
  DemoScenario scenario;
  int tickCount;
  bool isConnected;
  bool hasSensorError;

  UnitSimulationState copyWith({
    DemoScenario? scenario,
    int? tickCount,
    bool? isConnected,
    bool? hasSensorError,
  }) => UnitSimulationState(
    unitId: unitId,
    scenario: scenario ?? this.scenario,
    tickCount: tickCount ?? this.tickCount,
    isConnected: isConnected ?? this.isConnected,
    hasSensorError: hasSensorError ?? this.hasSensorError,
  );
}

class SimulationEngine {
  SimulationEngine({
    required this._telemetry,
    required this._clock,
    this._config = const DemoConfiguration(),
  }) {
    _initUnits();
  }

  final TelemetryRepository _telemetry;
  final AppClock _clock;
  final DemoConfiguration _config;
  final Map<int, UnitSimulationState> _unitStates = {};
  int _sampleSeq = 0;
  int _generation = 0;

  int get generation => _generation;

  void _initUnits() {
    for (final unitId in const [1, 2, 3]) {
      _unitStates[unitId] = UnitSimulationState(unitId: unitId);
    }
  }

  UnitSimulationState? getUnitState(int unitId) => _unitStates[unitId];

  Future<void> triggerScenario(int unitId, DemoScenario scenario) async {
    final gen = _generation;
    final state = _unitStates.putIfAbsent(
      unitId,
      () => UnitSimulationState(unitId: unitId),
    );
    state.scenario = scenario;
    state.tickCount = 0;

    final deviceId = 'demo-kit-00$unitId';
    if (scenario == DemoScenario.deviceOffline) {
      state.isConnected = false;
      await _telemetry.updateDeviceConnection(deviceId, false, null);
      return;
    } else {
      if (!state.isConnected) {
        state.isConnected = true;
        await _telemetry.updateDeviceConnection(deviceId, true, _clock.now);
      }
    }

    if (scenario == DemoScenario.sensorError) {
      state.hasSensorError = true;
    } else {
      state.hasSensorError = false;
    }

    if (scenario == DemoScenario.recovery) {
      state.scenario = DemoScenario.normal;
      state.hasSensorError = false;
      state.isConnected = true;
      await _telemetry.updateDeviceConnection(deviceId, true, _clock.now);
    }

    if (gen != _generation) return;
    // Immediately emit one tick for the triggered unit
    await stepUnit(unitId);
  }

  Future<void> stepAll() async {
    final gen = _generation;
    for (final unitId in _unitStates.keys) {
      if (gen != _generation) return;
      await stepUnit(unitId);
    }
  }

  Future<void> stepUnit(int unitId) async {
    final gen = _generation;
    final state = _unitStates[unitId];
    if (state == null) return;

    final deviceId = 'demo-kit-00$unitId';

    // When offline, no measurements are inserted
    if (!state.isConnected || state.scenario == DemoScenario.deviceOffline) {
      return;
    }

    state.tickCount++;
    final now = _clock.now;
    await _telemetry.updateDeviceConnection(deviceId, true, now);
    if (gen != _generation) return;

    final values = _calculateValues(state);

    for (final entry in values.entries) {
      if (gen != _generation) return;
      final isInvalid =
          state.hasSensorError &&
          entry.key == TelemetryParameterKeys.substrateTemperature;
      final seq = _sampleSeq++;
      final sampleId =
          'sim-g$gen-$unitId-${entry.key}-${state.tickCount}-s$seq';

      final measurement = TelemetryMeasurement(
        id: 0,
        unitId: unitId,
        deviceId: deviceId,
        parameterKey: entry.key,
        value: isInvalid ? null : entry.value,
        measuredAt: now,
        receivedAt: now,
        quality: isInvalid ? 'invalid' : 'valid',
        source: 'simulated',
        configVersion: _config.version,
        sampleId: sampleId,
      );

      await _telemetry.insertMeasurement(measurement);
    }
  }

  Map<String, double> _calculateValues(UnitSimulationState state) {
    final tick = state.tickCount;
    final unitId = state.unitId;

    // Deterministic noise using mathematical sin/cos with clamped bounds
    final tempNoise =
        math.sin((tick + unitId) * 0.7) *
        _config.simulator.temperatureNoiseAmplitude;
    final moistNoise =
        math.cos((tick + unitId) * 0.5) *
        _config.simulator.moistureNoiseAmplitude;

    double subTemp = 30.0 + tempNoise;
    double subMoist = 65.0 + moistNoise;
    double ambTemp = 29.0 + (tempNoise * 0.5);
    double ambHum = 65.0 + (moistNoise * 0.5);

    switch (state.scenario) {
      case DemoScenario.normal:
      case DemoScenario.recovery:
        subTemp = 30.0 + tempNoise;
        subMoist = 65.0 + moistNoise;
        break;
      case DemoScenario.thermalAttention:
        // Guaranteed in (35.0, 38.0]
        subTemp = (36.5 + tempNoise).clamp(35.5, 37.5);
        break;
      case DemoScenario.thermalCritical:
        // Guaranteed > 38.0
        subTemp = (39.0 + tempNoise.abs()).clamp(38.5, 41.0);
        break;
      case DemoScenario.substrateWet:
        // Guaranteed > 80.0
        subMoist = (85.0 + moistNoise.abs()).clamp(81.0, 95.0);
        break;
      case DemoScenario.substrateDry:
        // Guaranteed < 50.0
        subMoist = (45.0 - moistNoise.abs()).clamp(35.0, 49.0);
        break;
      case DemoScenario.sensorError:
        // Handled in stepUnit (substrateTemperature set to null and invalid)
        break;
      case DemoScenario.deviceOffline:
        break;
    }

    return {
      TelemetryParameterKeys.ambientTemperature: ambTemp,
      TelemetryParameterKeys.ambientHumidity: ambHum,
      TelemetryParameterKeys.substrateTemperature: subTemp,
      TelemetryParameterKeys.substrateMoisture: subMoist,
    };
  }

  Future<void> fastForward(Duration duration, {int? unitId}) async {
    final clock = _clock;
    if (clock is OffsetAppClock) {
      clock.advance(duration);
    } else if (clock is FakeAppClock) {
      clock.advance(duration);
    }

    if (unitId != null) {
      await stepUnit(unitId);
    } else {
      await stepAll();
    }
  }

  void reset() {
    _generation++;
    _sampleSeq = 0;
    _initUnits();
  }
}
