import '../../../core/config/demo_configuration.dart';
import 'telemetry_models.dart';

class TelemetryEvaluator {
  const TelemetryEvaluator({this.config = const DemoConfiguration()});

  final DemoConfiguration config;

  UnitEvaluationResult evaluateUnit({
    required int unitId,
    required BsfDevice? device,
    required Map<String, TelemetryMeasurement> latestMeasurements,
    required DateTime currentTime,
    int? activeAlertId,
  }) {
    bool isConfigMissing = false;
    try {
      config.validate();
    } catch (_) {
      isConfigMissing = true;
    }

    final parameterResults = <String, ParameterEvaluationResult>{};
    final reasons = <String>[];

    final isDeviceOnline = device != null && device.isConnected;
    final isDeviceExplicitlyDisconnected =
        device != null && !device.isConnected;

    if (isConfigMissing) {
      return UnitEvaluationResult(
        unitId: unitId,
        condition: ConditionState.unknown,
        parameterResults: const {},
        coverageComplete: false,
        reasons: const [
          'Konfigurasi demo tidak valid atau hilang (configurationMissing).',
        ],
        configVersion: config.version,
        evaluatedAt: currentTime,
        activeAlertId: activeAlertId,
        isDeviceExplicitlyDisconnected: isDeviceExplicitlyDisconnected,
        isConfigurationMissing: true,
      );
    }

    for (final key in TelemetryParameterKeys.all) {
      final measurement = latestMeasurements[key];
      final paramResult = _evaluateParameter(
        key: key,
        measurement: measurement,
        isDeviceOnline: isDeviceOnline,
        currentTime: currentTime,
      );
      parameterResults[key] = paramResult;
      if (paramResult.reason.isNotEmpty) {
        reasons.add(paramResult.reason);
      }
    }

    // Determine overall unit condition
    ConditionState overallCondition = ConditionState.optimal;
    bool hasCritical = false;
    bool hasAttention = false;
    bool hasUnknown = false;

    for (final result in parameterResults.values) {
      switch (result.condition) {
        case ConditionState.critical:
          hasCritical = true;
          break;
        case ConditionState.attention:
          hasAttention = true;
          break;
        case ConditionState.unknown:
          hasUnknown = true;
          break;
        case ConditionState.optimal:
          break;
      }
    }

    final coverageComplete =
        !hasUnknown &&
        parameterResults.length == TelemetryParameterKeys.all.length;

    if (hasCritical) {
      overallCondition = ConditionState.critical;
    } else if (hasAttention) {
      overallCondition = ConditionState.attention;
    } else if (hasUnknown) {
      // Invariant: Partial or incomplete data is UNKNOWN, not optimal!
      overallCondition = ConditionState.unknown;
    } else {
      overallCondition = ConditionState.optimal;
    }

    return UnitEvaluationResult(
      unitId: unitId,
      condition: overallCondition,
      parameterResults: parameterResults,
      coverageComplete: coverageComplete,
      reasons: reasons,
      configVersion: config.version,
      evaluatedAt: currentTime,
      activeAlertId: activeAlertId,
      isDeviceExplicitlyDisconnected: isDeviceExplicitlyDisconnected,
      isConfigurationMissing: false,
    );
  }

  ParameterEvaluationResult _evaluateParameter({
    required String key,
    required TelemetryMeasurement? measurement,
    required bool isDeviceOnline,
    required DateTime currentTime,
  }) {
    if (!TelemetryParameterKeys.all.contains(key)) {
      return ParameterEvaluationResult(
        parameterKey: key,
        condition: ConditionState.unknown,
        dataState: DataState.sensorError,
        value: measurement?.value,
        measuredAt: measurement?.measuredAt,
        reason: 'Parameter $key tidak dikenal oleh konfigurasi monitoring.',
      );
    }

    // 1. Connection check
    if (!isDeviceOnline) {
      return ParameterEvaluationResult(
        parameterKey: key,
        condition: ConditionState.unknown,
        dataState: DataState.offline,
        value: measurement?.value,
        measuredAt: measurement?.measuredAt,
        reason: 'Perangkat sedang terputus (offline).',
      );
    }

    // 2. Data presence check
    if (measurement == null) {
      return ParameterEvaluationResult(
        parameterKey: key,
        condition: ConditionState.unknown,
        dataState: DataState.noData,
        value: null,
        measuredAt: null,
        reason:
            'Belum ada data observasi untuk ${TelemetryParameterKeys.label(key)}.',
      );
    }

    // 3. Sensor validity check
    if (!measurement.isValid) {
      return ParameterEvaluationResult(
        parameterKey: key,
        condition: ConditionState.unknown,
        dataState: DataState.sensorError,
        value: measurement.value,
        measuredAt: measurement.measuredAt,
        reason:
            'Sensor ${TelemetryParameterKeys.label(key)} bermasalah atau nilai di luar batas.',
      );
    }

    final val = measurement.value!;

    // 4. Timestamp check: future timestamp is invalid
    if (measurement.measuredAt.isAfter(currentTime)) {
      return ParameterEvaluationResult(
        parameterKey: key,
        condition: ConditionState.unknown,
        dataState: DataState.sensorError,
        value: val,
        measuredAt: measurement.measuredAt,
        reason: 'Waktu pengukuran berada di masa depan.',
      );
    }

    // 5. Validation range check
    if (!config.validation.isValueValid(key, val)) {
      return ParameterEvaluationResult(
        parameterKey: key,
        condition: ConditionState.unknown,
        dataState: DataState.sensorError,
        value: val,
        measuredAt: measurement.measuredAt,
        reason:
            'Nilai $val ${TelemetryParameterKeys.unit(key)} tidak valid menurut guardrail.',
      );
    }

    // 6. Freshness check
    final age = currentTime.difference(measurement.measuredAt);
    DataState dataState;
    if (age < config.freshness.freshThreshold) {
      dataState = DataState.fresh;
    } else if (age <= config.freshness.agingThreshold) {
      dataState = DataState.aging;
    } else if (age <= config.freshness.offlineThreshold) {
      dataState = DataState.stale;
    } else {
      dataState = DataState.offline;
    }

    // If data is stale or offline, condition is unknown
    if (dataState == DataState.stale || dataState == DataState.offline) {
      return ParameterEvaluationResult(
        parameterKey: key,
        condition: ConditionState.unknown,
        dataState: dataState,
        value: val,
        measuredAt: measurement.measuredAt,
        reason: dataState == DataState.stale
            ? 'Data ${TelemetryParameterKeys.label(key)} sudah lama (> 5 menit).'
            : 'Perangkat tidak mengirim data lebih dari 10 menit.',
      );
    }

    // 6. Biological rule evaluation
    ConditionState condition = ConditionState.optimal;
    String reason = '';

    if (key == TelemetryParameterKeys.substrateTemperature) {
      if (val > config.substrateTemperature.criticalMax) {
        condition = ConditionState.critical;
        reason =
            'Suhu substrat $val °C melebihi batas kritis (> ${config.substrateTemperature.criticalMax} °C).';
      } else if (val > config.substrateTemperature.optimalMax) {
        condition = ConditionState.attention;
        reason =
            'Suhu substrat $val °C melebihi batas optimal (> ${config.substrateTemperature.optimalMax} °C).';
      } else if (val < config.substrateTemperature.optimalMin) {
        condition = ConditionState.attention;
        reason =
            'Suhu substrat $val °C di bawah batas optimal (< ${config.substrateTemperature.optimalMin} °C).';
      } else {
        condition = ConditionState.optimal;
      }
    } else if (key == TelemetryParameterKeys.substrateMoisture) {
      if (val > config.substrateMoisture.optimalMax) {
        condition = ConditionState.attention;
        reason =
            'Kelembapan substrat $val % terlalu basah (> ${config.substrateMoisture.optimalMax} %).';
      } else if (val < config.substrateMoisture.optimalMin) {
        condition = ConditionState.attention;
        reason =
            'Kelembapan substrat $val % terlalu kering (< ${config.substrateMoisture.optimalMin} %).';
      } else {
        condition = ConditionState.optimal;
      }
    } else {
      // Ambient temperature and humidity: valid observations, no biological alert in demo-v1
      condition = ConditionState.optimal;
    }

    return ParameterEvaluationResult(
      parameterKey: key,
      condition: condition,
      dataState: dataState,
      value: val,
      measuredAt: measurement.measuredAt,
      reason: reason,
    );
  }
}
