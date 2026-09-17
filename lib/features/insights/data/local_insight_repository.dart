import '../../../core/database/app_database.dart';
import '../../monitoring/domain/telemetry_models.dart';
import '../domain/insight_models.dart';
import '../domain/insight_repository.dart';

class LocalInsightRepository implements InsightRepository {
  LocalInsightRepository(this._store);
  final AppDatabase _store;

  @override
  Future<List<InsightEvent>> getInsights() async {
    final rows = await _store.database.query(
      'insights',
      orderBy: 'updated_at DESC',
    );
    return rows.map(InsightEvent.fromMap).toList();
  }

  @override
  Future<InsightEvent?> getInsight(int id) async {
    final rows = await _store.database.query(
      'insights',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : InsightEvent.fromMap(rows.first);
  }

  @override
  Future<List<InsightAction>> getActions(int insightId) async {
    final rows = await _store.database.query(
      'insight_actions',
      where: 'insight_id = ?',
      whereArgs: [insightId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(InsightAction.fromMap).toList();
  }

  @override
  Future<InsightUpdate> evaluate(BsfUnit unit) async {
    final condition = unit.condition;
    if (condition == UnitCondition.optimal) {
      await _store.database.update(
        'insights',
        {'resolved_at': DateTime.now().toIso8601String()},
        where: 'unit_id = ? AND resolved_at IS NULL',
        whereArgs: [unit.id],
      );
      return const InsightUpdate();
    }
    final kind = switch (condition) {
      UnitCondition.offline => 'offline',
      _ when unit.temperature >= DemoThresholds.attentionTemperature =>
        'temperature',
      _ => 'humidity',
    };
    await _store.database.update(
      'insights',
      {'resolved_at': DateTime.now().toIso8601String()},
      where: 'unit_id = ? AND kind != ? AND resolved_at IS NULL',
      whereArgs: [unit.id, kind],
    );
    final severity = condition == UnitCondition.critical
        ? 'critical'
        : 'attention';
    final active = await _store.database.query(
      'insights',
      where: 'unit_id = ? AND kind = ? AND resolved_at IS NULL',
      whereArgs: [unit.id, kind],
      limit: 1,
    );
    final now = DateTime.now().toIso8601String();
    final copy = _copyFor(unit, kind);
    var shouldNotify = active.isEmpty;
    int id;
    if (active.isEmpty) {
      id = await _store.database.insert('insights', {
        'unit_id': unit.id,
        'unit_name': unit.name,
        'kind': kind,
        'severity': severity,
        'cause': copy.$1,
        'recommendation': copy.$2,
        'started_at': now,
        'updated_at': now,
      });
    } else {
      id = active.first['id']! as int;
      shouldNotify =
          active.first['severity'] == 'attention' && severity == 'critical';
      await _store.database.update(
        'insights',
        {
          'severity': severity,
          'cause': copy.$1,
          'recommendation': copy.$2,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return InsightUpdate(
      event: await getInsight(id),
      shouldNotify: shouldNotify,
    );
  }

  (String, String) _copyFor(BsfUnit unit, String kind) => switch (kind) {
    'temperature' => (
      'Suhu ${unit.temperature.toStringAsFixed(1)} °C melewati batas demo.',
      'Periksa sirkulasi udara dan paparan panas pada media.',
    ),
    'humidity' => (
      'Kelembapan ${unit.humidity.toStringAsFixed(0)}% melewati batas demo.',
      'Periksa ventilasi dan kurangi kelembapan berlebih pada media.',
    ),
    _ => (
      'Smart Kit belum mengirim pembacaan terbaru.',
      'Periksa daya dan koneksi perangkat di lokasi.',
    ),
  };

  @override
  Future<void> saveAction(int id, Set<int> steps, String note) async {
    final sorted = steps.toList()..sort();
    final now = DateTime.now().toIso8601String();
    await _store.database.transaction((txn) async {
      final count = await txn.update(
        'insights',
        {
          'completed_steps': sorted.join(','),
          'note': note.trim(),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count != 1) throw StateError('Insight tidak ditemukan.');
      await txn.insert('insight_actions', {
        'insight_id': id,
        'completed_steps': sorted.join(','),
        'note': note.trim(),
        'created_at': now,
      });
    });
  }
}
