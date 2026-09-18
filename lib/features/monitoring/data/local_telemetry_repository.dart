import '../../../core/database/app_database.dart';
import '../domain/telemetry_models.dart';
import '../domain/telemetry_repository.dart';

class LocalTelemetryRepository implements TelemetryRepository {
  LocalTelemetryRepository(this._store);
  final AppDatabase _store;

  @override
  Future<List<BsfUnit>> getUnits() async {
    final rows = await _store.database.query('units', orderBy: 'id');
    return rows.map(BsfUnit.fromMap).toList();
  }

  @override
  Future<BsfUnit?> getUnit(int id) async {
    final rows = await _store.database.query(
      'units',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : BsfUnit.fromMap(rows.first);
  }

  @override
  Future<List<SensorReading>> getHistory(int unitId, Duration range) async {
    final since = DateTime.now().subtract(range).toIso8601String();
    final rows = await _store.database.query(
      'readings',
      where: 'unit_id = ? AND recorded_at >= ?',
      whereArgs: [unitId, since],
      orderBy: 'recorded_at',
    );
    return rows.map(SensorReading.fromMap).toList();
  }

  @override
  Future<BsfUnit> recordScenario(int unitId, String scenario, int tick) async {
    final unit = await getUnit(unitId);
    if (unit == null) throw StateError('Unit demo tidak ditemukan.');
    final now = DateTime.now();
    final variation = (((tick + unitId * 2) % 7) - 3) * 0.18;
    final values = switch (scenario) {
      'hot' => (36.0 + tick.clamp(0, 10) * 0.35, 69.0, 'Mulai mengering', true),
      'humid' => (
        33.0 + variation,
        84.0 + tick.clamp(0, 8) * 0.9,
        'Terlalu lembap',
        true,
      ),
      'offline' => (unit.temperature, unit.humidity, unit.medium, false),
      _ => (32.2 + variation, 65.0 + (tick % 3), 'Stabil', true),
    };
    await _store.database.update(
      'units',
      {
        'temperature': values.$1,
        'humidity': values.$2,
        'medium': values.$3,
        'is_connected': values.$4 ? 1 : 0,
        'updated_at': values.$4
            ? now.toIso8601String()
            : unit.updatedAt.toIso8601String(),
        'last_synced_at': values.$4
            ? now.toIso8601String()
            : unit.lastSyncedAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [unitId],
    );
    if (values.$4) {
      await _store.database.insert('readings', {
        'unit_id': unitId,
        'temperature': values.$1,
        'humidity': values.$2,
        'medium': values.$3,
        'recorded_at': now.toIso8601String(),
      });
    }
    final updated = (await getUnit(unitId))!;
    if (updated.condition != unit.condition &&
        (updated.condition == UnitCondition.attention ||
            updated.condition == UnitCondition.critical)) {
      await _store.database.insert('condition_events', {
        'unit_id': unitId,
        'condition': updated.condition.name,
        'occurred_at': now.toIso8601String(),
      });
    }
    return updated;
  }

  @override
  Future<void> updateThresholds(int unitId, UnitThresholds thresholds) async {
    if (!thresholds.isValid) {
      throw ArgumentError(
        'Batas perlu perhatian harus di bawah batas kritis. Kelembapan harus 0 sampai 100%.',
      );
    }
    final count = await _store.database.update(
      'units',
      {
        'temperature_attention': thresholds.temperatureAttention,
        'temperature_critical': thresholds.temperatureCritical,
        'humidity_attention': thresholds.humidityAttention,
        'humidity_critical': thresholds.humidityCritical,
      },
      where: 'id = ?',
      whereArgs: [unitId],
    );
    if (count != 1) throw StateError('Unit tidak ditemukan.');
  }

  @override
  Future<UnitSummary?> getSummary(int unitId, Duration range) async {
    final unit = await getUnit(unitId);
    if (unit == null) return null;
    final since = DateTime.now().subtract(range).toIso8601String();
    final rows = await _store.database.rawQuery(
      '''
      SELECT COUNT(*) AS sample_count,
        AVG(temperature) AS temperature_average,
        MIN(temperature) AS temperature_minimum,
        MAX(temperature) AS temperature_maximum,
        AVG(humidity) AS humidity_average,
        MIN(humidity) AS humidity_minimum,
        MAX(humidity) AS humidity_maximum,
        MIN(recorded_at) AS first_reading_at,
        MAX(recorded_at) AS last_reading_at
      FROM readings WHERE unit_id = ? AND recorded_at >= ?''',
      [unitId, since],
    );
    final insightRows = await _store.database.rawQuery(
      'SELECT COUNT(*) AS total FROM insights WHERE unit_id = ? AND started_at >= ?',
      [unitId, since],
    );
    final item = rows.first;
    double? number(String key) => (item[key] as num?)?.toDouble();
    return UnitSummary(
      unit: unit,
      range: range,
      sampleCount: (item['sample_count'] as num).toInt(),
      temperatureAverage: number('temperature_average'),
      temperatureMinimum: number('temperature_minimum'),
      temperatureMaximum: number('temperature_maximum'),
      humidityAverage: number('humidity_average'),
      humidityMinimum: number('humidity_minimum'),
      humidityMaximum: number('humidity_maximum'),
      insightCount: (insightRows.first['total'] as num).toInt(),
      firstReadingAt: item['first_reading_at'] == null
          ? null
          : DateTime.parse(item['first_reading_at']! as String),
      lastReadingAt: item['last_reading_at'] == null
          ? null
          : DateTime.parse(item['last_reading_at']! as String),
    );
  }
}
