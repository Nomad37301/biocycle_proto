import 'package:sqflite/sqflite.dart';

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
    final since = DateTime.now().toUtc().subtract(range).toIso8601String();
    final rows = await _store.database.query(
      'readings',
      where: 'unit_id = ? AND recorded_at >= ?',
      whereArgs: [unitId, since],
      orderBy: 'recorded_at',
    );
    return rows.map(SensorReading.fromMap).toList();
  }

  @override
  Future<List<BsfDevice>> getDevices(int unitId) async {
    final rows = await _store.database.query(
      'devices',
      where: 'unit_id = ?',
      whereArgs: [unitId],
      orderBy: 'id',
    );
    return rows.map(BsfDevice.fromMap).toList();
  }

  @override
  Future<List<SensorParameter>> getSensorParameters(String deviceId) async {
    final rows = await _store.database.query(
      'sensor_parameters',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'id',
    );
    return rows.map(SensorParameter.fromMap).toList();
  }

  @override
  Future<Map<String, TelemetryMeasurement>> getLatestMeasurements(
    int unitId,
  ) async {
    final result = <String, TelemetryMeasurement>{};
    final rows = await _store.database.rawQuery(
      '''
      SELECT t1.* FROM telemetry_measurements t1
      INNER JOIN (
        SELECT parameter_key, MAX(measured_at) as max_measured_at
        FROM telemetry_measurements
        WHERE unit_id = ?
        GROUP BY parameter_key
      ) t2 ON t1.parameter_key = t2.parameter_key AND t1.measured_at = t2.max_measured_at
      WHERE t1.unit_id = ?
      ORDER BY t1.id DESC
      ''',
      [unitId, unitId],
    );

    for (final row in rows) {
      final measurement = TelemetryMeasurement.fromMap(row);
      if (!result.containsKey(measurement.parameterKey)) {
        result[measurement.parameterKey] = measurement;
      }
    }
    return result;
  }

  @override
  Future<List<TelemetryMeasurement>> getMeasurementHistory(
    int unitId,
    String parameterKey,
    Duration range,
  ) async {
    final since = DateTime.now().toUtc().subtract(range).toIso8601String();
    final rows = await _store.database.query(
      'telemetry_measurements',
      where: 'unit_id = ? AND parameter_key = ? AND measured_at >= ?',
      whereArgs: [unitId, parameterKey, since],
      orderBy: 'measured_at ASC',
    );
    return rows.map(TelemetryMeasurement.fromMap).toList();
  }

  @override
  Future<void> insertMeasurement(TelemetryMeasurement measurement) async {
    final insertedId = await _store.database.insert(
      'telemetry_measurements',
      measurement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (insertedId <= 0) {
      return;
    }

    // Sync legacy unit table values only if incoming measurement is newer than or equal to current unit.updated_at
    if (measurement.isValid) {
      final unit = await getUnit(measurement.unitId);
      final isNewerOrEqual =
          unit == null ||
          measurement.measuredAt.isAfter(unit.updatedAt) ||
          measurement.measuredAt.isAtSameMomentAs(unit.updatedAt);

      if (isNewerOrEqual) {
        if (measurement.parameterKey ==
            TelemetryParameterKeys.substrateTemperature) {
          await _store.database.update(
            'units',
            {
              'temperature': measurement.value,
              'updated_at': measurement.measuredAt.toIso8601String(),
              'last_synced_at': measurement.receivedAt.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [measurement.unitId],
          );
        } else if (measurement.parameterKey ==
            TelemetryParameterKeys.substrateMoisture) {
          await _store.database.update(
            'units',
            {
              'humidity': measurement.value,
              'updated_at': measurement.measuredAt.toIso8601String(),
              'last_synced_at': measurement.receivedAt.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [measurement.unitId],
          );
        }
      }
    }
  }

  @override
  Future<void> updateDeviceConnection(
    String deviceId,
    bool isConnected,
    DateTime? lastSeenAt,
  ) async {
    await _store.database.update(
      'devices',
      {
        'is_connected': isConnected ? 1 : 0,
        if (lastSeenAt != null)
          'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [deviceId],
    );

    final deviceRows = await _store.database.query(
      'devices',
      columns: ['unit_id'],
      where: 'id = ?',
      whereArgs: [deviceId],
    );
    if (deviceRows.isNotEmpty) {
      final unitId = deviceRows.first['unit_id'] as int;
      await _store.database.update(
        'units',
        {'is_connected': isConnected ? 1 : 0},
        where: 'id = ?',
        whereArgs: [unitId],
      );
    }
  }

  @override
  Future<BsfUnit> recordScenario(int unitId, String scenario, int tick) async {
    final unit = await getUnit(unitId);
    if (unit == null) throw StateError('Unit demo tidak ditemukan.');
    final now = DateTime.now().toUtc();
    final variation = (((tick + unitId * 2) % 7) - 3) * 0.18;
    final values = switch (scenario) {
      'hot' || 'thermalAttention' => (36.0, 65.0, 'Suhu meningkat', true),
      'thermalCritical' => (39.0, 65.0, 'Suhu kritis', true),
      'humid' || 'substrateWet' => (30.0, 85.0, 'Terlalu lembap', true),
      'substrateDry' => (30.0, 45.0, 'Media kering', true),
      'offline' ||
      'deviceOffline' => (unit.temperature, unit.humidity, unit.medium, false),
      _ => (30.0 + variation, 65.0 + (tick % 3), 'Stabil', true),
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
    final since = DateTime.now().toUtc().subtract(range).toIso8601String();
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
