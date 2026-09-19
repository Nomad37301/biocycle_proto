abstract final class TelemetryParameterKeys {
  static const ambientTemperature = 'ambientTemperature';
  static const ambientHumidity = 'ambientHumidity';
  static const substrateTemperature = 'substrateTemperature';
  static const substrateMoisture = 'substrateMoisture';

  static const all = [
    ambientTemperature,
    ambientHumidity,
    substrateTemperature,
    substrateMoisture,
  ];

  static String label(String key) => switch (key) {
    ambientTemperature => 'Suhu udara',
    ambientHumidity => 'Kelembapan udara',
    substrateTemperature => 'Suhu substrat',
    substrateMoisture => 'Kelembapan substrat (indeks demo)',
    _ => key,
  };

  static String unit(String key) => switch (key) {
    ambientTemperature => '°C',
    ambientHumidity => '% RH',
    substrateTemperature => '°C',
    substrateMoisture => '%',
    _ => '',
  };
}

enum ConditionState { unknown, optimal, attention, critical }

extension ConditionStateLabel on ConditionState {
  String get label => switch (this) {
    ConditionState.optimal => 'Optimal',
    ConditionState.attention => 'Perlu perhatian',
    ConditionState.critical => 'Kritis',
    ConditionState.unknown => 'Belum dapat dinilai',
  };
}

// Backward compatibility alias for existing widgets
typedef UnitCondition = ConditionState;

enum DataState { fresh, aging, stale, offline, sensorError, noData }

extension DataStateLabel on DataState {
  String get label => switch (this) {
    DataState.fresh => 'Terkini',
    DataState.aging => 'Terlambat',
    DataState.stale => 'Data lama',
    DataState.offline => 'Perangkat terputus',
    DataState.sensorError => 'Sensor bermasalah',
    DataState.noData => 'Belum ada data',
  };
}

class TelemetryMeasurement {
  const TelemetryMeasurement({
    required this.id,
    required this.unitId,
    required this.deviceId,
    required this.parameterKey,
    required this.value,
    required this.measuredAt,
    required this.receivedAt,
    required this.quality,
    required this.source,
    required this.configVersion,
    required this.sampleId,
  });

  final int id;
  final int unitId;
  final String deviceId;
  final String parameterKey;
  final double? value;
  final DateTime measuredAt;
  final DateTime receivedAt;
  final String quality; // 'valid' | 'invalid'
  final String source; // 'simulated' | 'legacyDemo' | 'production'
  final String configVersion;
  final String sampleId;

  bool get isValid => quality == 'valid' && value != null && value!.isFinite;

  factory TelemetryMeasurement.fromMap(Map<String, Object?> map) =>
      TelemetryMeasurement(
        id: map['id']! as int,
        unitId: map['unit_id']! as int,
        deviceId: map['device_id']! as String,
        parameterKey: map['parameter_key']! as String,
        value: (map['value'] as num?)?.toDouble(),
        measuredAt: DateTime.parse(map['measured_at']! as String).toUtc(),
        receivedAt: DateTime.parse(map['received_at']! as String).toUtc(),
        quality: (map['quality'] as String?) ?? 'valid',
        source: (map['source'] as String?) ?? 'simulated',
        configVersion: (map['config_version'] as String?) ?? 'demo-v1',
        sampleId: (map['sample_id'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
    if (id > 0) 'id': id,
    'unit_id': unitId,
    'device_id': deviceId,
    'parameter_key': parameterKey,
    'value': value,
    'measured_at': measuredAt.toUtc().toIso8601String(),
    'received_at': receivedAt.toUtc().toIso8601String(),
    'quality': quality,
    'source': source,
    'config_version': configVersion,
    'sample_id': sampleId,
  };
}

typedef Device = BsfDevice;

class BsfDevice {
  const BsfDevice({
    required this.id,
    required this.unitId,
    required this.code,
    required this.firmware,
    required this.isConnected,
    required this.lastSeenAt,
  });

  final String id;
  final int unitId;
  final String code;
  final String firmware;
  final bool isConnected;
  final DateTime? lastSeenAt;

  factory BsfDevice.fromMap(Map<String, Object?> map) => BsfDevice(
    id: map['id']! as String,
    unitId: map['unit_id']! as int,
    code: map['code']! as String,
    firmware: (map['firmware'] as String?) ?? 'demo-1.0.0',
    isConnected: (map['is_connected']! as int) == 1,
    lastSeenAt: map['last_seen_at'] == null
        ? null
        : DateTime.parse(map['last_seen_at']! as String).toUtc(),
  );
}

class SensorParameter {
  const SensorParameter({
    required this.id,
    required this.deviceId,
    required this.parameterKey,
    required this.label,
    required this.unit,
    required this.profile,
    required this.configVersion,
  });

  final int id;
  final String deviceId;
  final String parameterKey;
  final String label;
  final String unit;
  final String profile;
  final String configVersion;

  factory SensorParameter.fromMap(Map<String, Object?> map) => SensorParameter(
    id: map['id']! as int,
    deviceId: map['device_id']! as String,
    parameterKey: map['parameter_key']! as String,
    label: map['label']! as String,
    unit: map['unit']! as String,
    profile: map['profile']! as String,
    configVersion: map['config_version']! as String,
  );
}

class ParameterEvaluationResult {
  const ParameterEvaluationResult({
    required this.parameterKey,
    required this.condition,
    required this.dataState,
    required this.value,
    required this.measuredAt,
    required this.reason,
  });

  final String parameterKey;
  final ConditionState condition;
  final DataState dataState;
  final double? value;
  final DateTime? measuredAt;
  final String reason;
}

class UnitEvaluationResult {
  const UnitEvaluationResult({
    required this.unitId,
    required this.condition,
    required this.parameterResults,
    required this.coverageComplete,
    required this.reasons,
    required this.configVersion,
    required this.evaluatedAt,
    this.activeAlertId,
    this.isDeviceExplicitlyDisconnected = false,
    this.isConfigurationMissing = false,
  });

  final int unitId;
  final ConditionState condition;
  final Map<String, ParameterEvaluationResult> parameterResults;
  final bool coverageComplete;
  final List<String> reasons;
  final String configVersion;
  final DateTime evaluatedAt;
  final int? activeAlertId;
  final bool isDeviceExplicitlyDisconnected;
  final bool isConfigurationMissing;

  bool get isCoverageComplete => coverageComplete;

  DataState get dataState {
    if (isDeviceExplicitlyDisconnected) return DataState.offline;
    if (parameterResults.isEmpty) return DataState.noData;
    if (parameterResults.values.any(
      (p) => p.dataState == DataState.sensorError,
    )) {
      return DataState.sensorError;
    }
    if (parameterResults.values.any((p) => p.dataState == DataState.stale)) {
      return DataState.stale;
    }
    if (parameterResults.values.any((p) => p.dataState == DataState.aging)) {
      return DataState.aging;
    }
    return parameterResults.values.first.dataState;
  }
}

// Backward compatible BsfUnit & supporting structures for existing code
class BsfUnit {
  const BsfUnit({
    required this.id,
    required this.name,
    required this.kitCode,
    required this.temperature,
    required this.humidity,
    required this.medium,
    required this.isConnected,
    required this.updatedAt,
    required this.lastSyncedAt,
    required this.firmware,
    required this.thresholds,
    this.evaluationResult,
  });

  final int id;
  final String name;
  final String kitCode;
  final double temperature;
  final double humidity;
  final String medium;
  final bool isConnected;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final String firmware;
  final UnitThresholds thresholds;
  final UnitEvaluationResult? evaluationResult;

  ConditionState get condition {
    if (evaluationResult != null) {
      return evaluationResult!.condition;
    }
    return DemoThresholds.evaluate(
      temperature: temperature,
      humidity: humidity,
      connected: isConnected,
      thresholds: thresholds,
    );
  }

  factory BsfUnit.fromMap(Map<String, Object?> map) => BsfUnit(
    id: map['id']! as int,
    name: map['name']! as String,
    kitCode: map['kit_code']! as String,
    temperature: (map['temperature']! as num).toDouble(),
    humidity: (map['humidity']! as num).toDouble(),
    medium: map['medium']! as String,
    isConnected: (map['is_connected']! as int) == 1,
    updatedAt: DateTime.parse(map['updated_at']! as String),
    lastSyncedAt: map['last_synced_at'] == null
        ? null
        : DateTime.parse(map['last_synced_at']! as String),
    firmware: (map['firmware'] as String?) ?? 'demo-1.0.0',
    thresholds: UnitThresholds.fromMap(map),
  );

  BsfUnit copyWith({
    int? id,
    String? name,
    String? kitCode,
    double? temperature,
    double? humidity,
    String? medium,
    bool? isConnected,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    String? firmware,
    UnitThresholds? thresholds,
    UnitEvaluationResult? evaluationResult,
  }) => BsfUnit(
    id: id ?? this.id,
    name: name ?? this.name,
    kitCode: kitCode ?? this.kitCode,
    temperature: temperature ?? this.temperature,
    humidity: humidity ?? this.humidity,
    medium: medium ?? this.medium,
    isConnected: isConnected ?? this.isConnected,
    updatedAt: updatedAt ?? this.updatedAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    firmware: firmware ?? this.firmware,
    thresholds: thresholds ?? this.thresholds,
    evaluationResult: evaluationResult ?? this.evaluationResult,
  );
}

class UnitThresholds {
  const UnitThresholds({
    this.temperatureAttention = 35.0,
    this.temperatureCritical = 38.0,
    this.humidityAttention = 80.0,
    this.humidityCritical = 90.0,
  });

  final double temperatureAttention;
  final double temperatureCritical;
  final double humidityAttention;
  final double humidityCritical;

  bool get isValid =>
      temperatureAttention.isFinite &&
      temperatureCritical.isFinite &&
      humidityAttention.isFinite &&
      humidityCritical.isFinite &&
      temperatureAttention < temperatureCritical &&
      humidityAttention < humidityCritical &&
      humidityAttention >= 0 &&
      humidityCritical <= 100;

  factory UnitThresholds.fromMap(Map<String, Object?> map) => UnitThresholds(
    temperatureAttention:
        (map['temperature_attention'] as num?)?.toDouble() ?? 35.0,
    temperatureCritical:
        (map['temperature_critical'] as num?)?.toDouble() ?? 38.0,
    humidityAttention: (map['humidity_attention'] as num?)?.toDouble() ?? 80.0,
    humidityCritical: (map['humidity_critical'] as num?)?.toDouble() ?? 90.0,
  );
}

class UnitSummary {
  const UnitSummary({
    required this.unit,
    required this.range,
    required this.sampleCount,
    required this.temperatureAverage,
    required this.temperatureMinimum,
    required this.temperatureMaximum,
    required this.humidityAverage,
    required this.humidityMinimum,
    required this.humidityMaximum,
    required this.insightCount,
    required this.firstReadingAt,
    required this.lastReadingAt,
  });

  final BsfUnit unit;
  final Duration range;
  final int sampleCount;
  final double? temperatureAverage;
  final double? temperatureMinimum;
  final double? temperatureMaximum;
  final double? humidityAverage;
  final double? humidityMinimum;
  final double? humidityMaximum;
  final int insightCount;
  final DateTime? firstReadingAt;
  final DateTime? lastReadingAt;
}

class SensorReading {
  const SensorReading({
    required this.unitId,
    required this.temperature,
    required this.humidity,
    required this.medium,
    required this.recordedAt,
  });

  final int unitId;
  final double temperature;
  final double humidity;
  final String medium;
  final DateTime recordedAt;

  factory SensorReading.fromMap(Map<String, Object?> map) => SensorReading(
    unitId: map['unit_id']! as int,
    temperature: (map['temperature']! as num).toDouble(),
    humidity: (map['humidity']! as num).toDouble(),
    medium: map['medium']! as String,
    recordedAt: DateTime.parse(map['recorded_at']! as String),
  );
}

abstract final class DemoThresholds {
  static const attentionTemperature = 35.0;
  static const criticalTemperature = 38.0;
  static const attentionHumidity = 80.0;
  static const criticalHumidity = 90.0;

  static ConditionState evaluate({
    required double temperature,
    required double humidity,
    required bool connected,
    UnitThresholds thresholds = const UnitThresholds(),
  }) {
    if (!connected) return ConditionState.unknown;
    if (temperature > thresholds.temperatureCritical) {
      return ConditionState.critical;
    }
    if (temperature > thresholds.temperatureAttention ||
        humidity > thresholds.humidityAttention) {
      return ConditionState.attention;
    }
    return ConditionState.optimal;
  }
}
