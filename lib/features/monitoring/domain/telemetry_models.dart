enum UnitCondition { optimal, attention, critical, offline }

extension UnitConditionLabel on UnitCondition {
  String get label => switch (this) {
    UnitCondition.optimal => 'Optimal',
    UnitCondition.attention => 'Perlu perhatian',
    UnitCondition.critical => 'Kritis',
    UnitCondition.offline => 'Offline',
  };
}

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

  UnitCondition get condition => DemoThresholds.evaluate(
    temperature: temperature,
    humidity: humidity,
    connected: isConnected,
    thresholds: thresholds,
  );

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
    firmware: (map['firmware'] as String?) ?? 'Simulasi 1.0.0',
    thresholds: UnitThresholds.fromMap(map),
  );
}

class UnitThresholds {
  const UnitThresholds({
    this.temperatureAttention = 34,
    this.temperatureCritical = 38,
    this.humidityAttention = 80,
    this.humidityCritical = 90,
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
        (map['temperature_attention'] as num?)?.toDouble() ?? 34,
    temperatureCritical:
        (map['temperature_critical'] as num?)?.toDouble() ?? 38,
    humidityAttention: (map['humidity_attention'] as num?)?.toDouble() ?? 80,
    humidityCritical: (map['humidity_critical'] as num?)?.toDouble() ?? 90,
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
  static const attentionTemperature = 34.0;
  static const criticalTemperature = 38.0;
  static const attentionHumidity = 80.0;
  static const criticalHumidity = 90.0;

  static UnitCondition evaluate({
    required double temperature,
    required double humidity,
    required bool connected,
    UnitThresholds thresholds = const UnitThresholds(),
  }) {
    if (!connected) return UnitCondition.offline;
    if (temperature >= thresholds.temperatureCritical ||
        humidity >= thresholds.humidityCritical) {
      return UnitCondition.critical;
    }
    if (temperature >= thresholds.temperatureAttention ||
        humidity >= thresholds.humidityAttention) {
      return UnitCondition.attention;
    }
    return UnitCondition.optimal;
  }
}
