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
  });

  final int id;
  final String name;
  final String kitCode;
  final double temperature;
  final double humidity;
  final String medium;
  final bool isConnected;
  final DateTime updatedAt;

  UnitCondition get condition => DemoThresholds.evaluate(
    temperature: temperature,
    humidity: humidity,
    connected: isConnected,
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
  );
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
  }) {
    if (!connected) return UnitCondition.offline;
    if (temperature >= criticalTemperature || humidity >= criticalHumidity) {
      return UnitCondition.critical;
    }
    if (temperature >= attentionTemperature || humidity >= attentionHumidity) {
      return UnitCondition.attention;
    }
    return UnitCondition.optimal;
  }
}
