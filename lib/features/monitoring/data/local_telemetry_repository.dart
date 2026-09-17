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
    final variation = ((tick % 5) - 2) * 0.25;
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
    return (await getUnit(unitId))!;
  }
}
