import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../monitoring/domain/telemetry_models.dart';
import '../domain/insight_models.dart';
import '../domain/insight_repository.dart';

class LocalInsightRepository implements InsightRepository {
  LocalInsightRepository(this._store);
  final AppDatabase _store;

  @override
  Future<List<InsightEvent>> getInsights() async {
    final rows = await _store.database.rawQuery('''
      SELECT i.*, EXISTS(
        SELECT 1 FROM insight_actions a WHERE a.insight_id = i.id
      ) AS has_saved_action
      FROM insights i ORDER BY i.updated_at DESC''');
    return rows.map(InsightEvent.fromMap).toList();
  }

  @override
  Future<List<InsightEvent>> getActiveInsights() async {
    final list = await getInsights();
    return list.where((i) => i.isActive).toList();
  }

  @override
  Future<InsightEvent?> getInsight(int id) async {
    final rows = await _store.database.rawQuery(
      '''
      SELECT i.*, EXISTS(
        SELECT 1 FROM insight_actions a WHERE a.insight_id = i.id
      ) AS has_saved_action
      FROM insights i WHERE i.id = ?''',
      [id],
    );
    return rows.isEmpty ? null : InsightEvent.fromMap(rows.first);
  }

  @override
  Future<List<InsightAction>> getInsightActions(int insightId) async {
    final rows = await _store.database.query(
      'insight_actions',
      where: 'insight_id = ?',
      whereArgs: [insightId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(InsightAction.fromMap).toList();
  }

  @override
  Future<void> evaluatePendingActions({DateTime? currentTime}) async {
    final now = currentTime ?? DateTime.now().toUtc();
    final actions = await _store.database.query(
      'insight_actions',
      where: "evaluation_status = 'pendingEvaluation'",
    );

    for (final actionRow in actions) {
      final actionId = actionRow['id'] as int;
      final insightId = actionRow['insight_id'] as int;
      final dueAtStr = actionRow['evaluation_due_at'] as String?;
      if (dueAtStr == null) continue;

      final dueAt = DateTime.parse(dueAtStr);
      final graceEnd = dueAt.add(const Duration(minutes: 5));

      if (now.isBefore(dueAt)) {
        continue;
      }

      final insight = await getInsight(insightId);
      if (insight == null) continue;
      final paramKey =
          insight.parameterKey ?? TelemetryParameterKeys.substrateTemperature;

      final measurements = await _store.database.query(
        'telemetry_measurements',
        where: 'unit_id = ? AND parameter_key = ? AND measured_at >= ? AND measured_at <= ? AND quality = ?',
        whereArgs: [
          insight.unitId,
          paramKey,
          dueAt.toIso8601String(),
          graceEnd.toIso8601String(),
          'valid',
        ],
        orderBy: 'measured_at ASC, id ASC',
        limit: 1,
      );

      if (measurements.isNotEmpty) {
        final m = measurements.first;
        final afterVal = (m['value'] as num?)?.toDouble();
        final afterAt = m['measured_at'] as String;

        await _store.database.update(
          'insight_actions',
          {
            'after_temperature': afterVal,
            'after_value': afterVal,
            'after_measurement_id': m['id'],
            'after_recorded_at': afterAt,
            'evaluation_status': ActionEvaluationStatus.evaluated.name,
          },
          where: 'id = ?',
          whereArgs: [actionId],
        );
      } else if (now.isAfter(graceEnd)) {
        await _store.database.update(
          'insight_actions',
          {'evaluation_status': ActionEvaluationStatus.insufficientData.name},
          where: 'id = ?',
          whereArgs: [actionId],
        );
      }
    }
  }

  @override
  Future<List<InsightAction>> getActions(int insightId) async {
    await evaluatePendingActions();
    final rows = await _store.database.query(
      'insight_actions',
      where: 'insight_id = ?',
      whereArgs: [insightId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(InsightAction.fromMap).toList();
  }

  @override
  Future<void> acknowledge(int id, String actor) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _store.database.update(
      'insights',
      {'acknowledged_at': now, 'acknowledged_by': actor},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<InsightUpdate> evaluate(BsfUnit unit) async {
    final condition = unit.condition;
    if (condition == ConditionState.optimal) {
      await _checkAndApplyRecovery(unit.id);
      return const InsightUpdate();
    }

    if (!unit.isConnected) {
      return _evaluateKind(
        unitId: unit.id,
        unitName: unit.name,
        parameterKey: 'connectivity',
        ruleId: 'deviceConnectivityRule',
        kind: 'deviceOffline',
        severity: 'attention',
        value: null,
        copy: (
          'BioCycle Smart Kit terputus atau tidak mengirim data.',
          'Periksa daya adaptor 5V dan koneksi fisik kit di lokasi.',
        ),
      );
    }

    final isSubTempViolation =
        unit.temperature > unit.thresholds.temperatureAttention;
    final kind = isSubTempViolation ? 'thermalAttention' : 'substrateWet';
    final paramKey = isSubTempViolation
        ? TelemetryParameterKeys.substrateTemperature
        : TelemetryParameterKeys.substrateMoisture;
    final ruleId = isSubTempViolation
        ? 'substrateTemperatureRule'
        : 'substrateMoistureRule';
    final severity = condition == ConditionState.critical
        ? 'critical'
        : 'attention';

    return _evaluateKind(
      unitId: unit.id,
      unitName: unit.name,
      parameterKey: paramKey,
      ruleId: ruleId,
      kind: kind,
      severity: severity,
      value: unit.temperature,
      copy: _copyFor(unit, isSubTempViolation ? 'temperature' : 'humidity'),
    );
  }

  @override
  Future<InsightUpdate> evaluateEvaluationResult({
    required int unitId,
    required String unitName,
    required UnitEvaluationResult evaluationResult,
  }) async {
    final condition = evaluationResult.condition;

    if (condition == ConditionState.optimal) {
      await _checkAndApplyRecovery(unitId, evaluationResult);
      return const InsightUpdate();
    }

    // Explicit device disconnect check
    if (evaluationResult.isDeviceExplicitlyDisconnected) {
      return _evaluateKind(
        unitId: unitId,
        unitName: unitName,
        parameterKey: 'connectivity',
        ruleId: 'deviceConnectivityRule',
        kind: 'deviceOffline',
        severity: 'attention',
        value: null,
        copy: (
          'BioCycle Smart Kit terputus atau tidak mengirim data.',
          'Periksa daya adaptor 5V dan koneksi fisik kit di lokasi.',
        ),
      );
    }

    // Do NOT generate technical or biological recommendations if condition is unknown
    // due to noData, stale, sensorError, or partial coverage.
    if (condition == ConditionState.unknown) {
      return const InsightUpdate();
    }

    String kind = 'thermalAttention';
    String parameterKey = TelemetryParameterKeys.substrateTemperature;
    String ruleId = 'substrateTemperatureRule';
    String severity = 'attention';
    double? val;
    String cause = '';
    String recommendation = '';

    final subTempResult = evaluationResult
        .parameterResults[TelemetryParameterKeys.substrateTemperature];
    final subMoistResult = evaluationResult
        .parameterResults[TelemetryParameterKeys.substrateMoisture];

    if (subTempResult?.condition == ConditionState.critical) {
      kind = 'thermalCritical';
      parameterKey = TelemetryParameterKeys.substrateTemperature;
      ruleId = 'substrateTemperatureRule';
      severity = 'critical';
      val = subTempResult?.value;
      cause = subTempResult?.reason ?? 'Suhu substrat kritis melewati 38 °C.';
      recommendation = 'Periksa aerasi media, kurangi ketebalan substrat, dan tingkatkan ventilasi.';
    } else if (subTempResult?.condition == ConditionState.attention) {
      kind = 'thermalAttention';
      parameterKey = TelemetryParameterKeys.substrateTemperature;
      ruleId = 'substrateTemperatureRule';
      severity = 'attention';
      val = subTempResult?.value;
      cause = subTempResult?.reason ?? 'Suhu substrat meningkat di atas 35 °C.';
      recommendation =
          'Tingkatkan sirkulasi udara di sekitar rak pembesaran dan cek ulang.';
    } else if (subMoistResult?.condition == ConditionState.attention) {
      final isWet = (subMoistResult?.value ?? 0) > 80;
      kind = isWet ? 'substrateWet' : 'substrateDry';
      parameterKey = TelemetryParameterKeys.substrateMoisture;
      ruleId = 'substrateMoistureRule';
      severity = 'attention';
      val = subMoistResult?.value;
      cause =
          subMoistResult?.reason ??
          'Kelembapan substrat di luar rentang optimal.';
      recommendation = isWet
          ? 'Tambahkan materi kering seperti dedak dan ratakan media.'
          : 'Semprot air secukupnya atau berikan pakan berkadar air lebih tinggi.';
    } else {
      return const InsightUpdate();
    }

    return _evaluateKind(
      unitId: unitId,
      unitName: unitName,
      parameterKey: parameterKey,
      ruleId: ruleId,
      kind: kind,
      severity: severity,
      value: val,
      copy: (cause, recommendation),
    );
  }

  Future<void> _checkAndApplyRecovery(
    int unitId, [
    UnitEvaluationResult? evaluationResult,
  ]) async {
    final activeAlerts = await _store.database.query(
      'insights',
      where: 'unit_id = ? AND resolved_at IS NULL',
      whereArgs: [unitId],
    );
    if (activeAlerts.isEmpty) return;

    for (final alert in activeAlerts) {
      final alertId = alert['id'] as int;
      final paramKey =
          alert['parameter_key'] as String? ??
          TelemetryParameterKeys.substrateTemperature;
      final paramResult = evaluationResult?.parameterResults[paramKey];
      final isOptimal =
          evaluationResult == null ||
          (paramResult != null &&
              paramResult.condition == ConditionState.optimal);
      final isViolation =
          paramResult != null &&
          (paramResult.condition == ConditionState.attention ||
              paramResult.condition == ConditionState.critical);

      if (isOptimal) {
        final currentCountStr =
            await _store.getSetting('recovery_count_$alertId') ?? '0';
        final currentCount = int.tryParse(currentCountStr) ?? 0;
        final newCount = currentCount + 1;

        if (newCount >= 2) {
          final now = DateTime.now().toUtc().toIso8601String();
          await _store.database.update(
            'insights',
            {'recovered_at': now, 'resolved_at': now},
            where: 'id = ?',
            whereArgs: [alertId],
          );
          await _store.setSetting('recovery_count_$alertId', '0');
        } else {
          await _store.setSetting('recovery_count_$alertId', '$newCount');
        }
      } else if (isViolation) {
        await _store.setSetting('recovery_count_$alertId', '0');
      }
    }
  }

  Future<InsightUpdate> _evaluateKind({
    required int unitId,
    required String unitName,
    required String parameterKey,
    required String ruleId,
    required String kind,
    required String severity,
    required double? value,
    required (String, String) copy,
  }) async {
    // Unique active episode identified by unit_id + parameter_key
    final active = await _store.database.query(
      'insights',
      where: 'unit_id = ? AND parameter_key = ? AND resolved_at IS NULL',
      whereArgs: [unitId, parameterKey],
      limit: 1,
    );

    final now = DateTime.now().toUtc().toIso8601String();
    var shouldNotify = active.isEmpty;
    int id;

    if (active.isEmpty) {
      final episodeId =
          'ep-$unitId-$parameterKey-${DateTime.now().millisecondsSinceEpoch}';
      id = await _store.database.insert('insights', {
        'unit_id': unitId,
        'unit_name': unitName,
        'kind': kind,
        'parameter_key': parameterKey,
        'rule_id': ruleId,
        'severity': severity,
        'cause': copy.$1,
        'recommendation': copy.$2,
        'started_at': now,
        'updated_at': now,
        'episode_id': episodeId,
        'trigger_value': value,
        'trigger_measured_at': now,
        'config_version': 'demo-v1',
        'sop_version': 'demo-sop-v1',
      });
    } else {
      id = active.first['id']! as int;
      final prevSeverity = active.first['severity'] as String?;
      // Escalate notification if jumping from attention to critical
      shouldNotify = prevSeverity == 'attention' && severity == 'critical';

      await _store.database.update(
        'insights',
        {
          'severity': severity,
          'kind': kind,
          'cause': copy.$1,
          'recommendation': copy.$2,
          'updated_at': now,
          'trigger_value': value,
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
  Future<void> saveAction(
    int id,
    Set<int> steps,
    String note, {
    ActionResponseType responseType = ActionResponseType.done,
    String? idempotencyKey,
    int? actorId,
    String? actorName,
    List<String>? checklist,
    DateTime? currentTime,
  }) async {
    final sorted = steps.toList()..sort();
    final now = currentTime ?? DateTime.now().toUtc();
    final nowStr = now.toIso8601String();
    final dueAtStr = now.add(const Duration(minutes: 15)).toIso8601String();
    final key = idempotencyKey ?? 'action-$id-${now.millisecondsSinceEpoch}';

    await _store.database.transaction((txn) async {
      final insightRows = await txn.query(
        'insights',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (insightRows.isEmpty) throw StateError('Insight tidak ditemukan.');
      final insightRow = insightRows.first;
      final unitId = insightRow['unit_id'] as int;
      final paramKey =
          (insightRow['parameter_key'] as String?) ??
          TelemetryParameterKeys.substrateTemperature;

      // Query latest valid measurement for before snapshot
      final measurementRows = await txn.query(
        'telemetry_measurements',
        where: 'unit_id = ? AND parameter_key = ? AND quality = ? AND measured_at <= ?',
        whereArgs: [unitId, paramKey, 'valid', nowStr],
        orderBy: 'measured_at DESC, id DESC',
        limit: 1,
      );
      final measurement = measurementRows.firstOrNull;

      final count = await txn.update(
        'insights',
        {
          'completed_steps': sorted.join(','),
          'note': note.trim(),
          'updated_at': nowStr,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count != 1) throw StateError('Insight tidak ditemukan.');

      String initialStatus;
      if (responseType != ActionResponseType.done) {
        initialStatus = ActionEvaluationStatus.notApplicable.name;
      } else if (measurement == null) {
        initialStatus = ActionEvaluationStatus.insufficientData.name;
      } else {
        initialStatus = ActionEvaluationStatus.pendingEvaluation.name;
      }

      await txn.insert('insight_actions', {
        'insight_id': id,
        'completed_steps': sorted.join(','),
        'note': note.trim(),
        'created_at': nowStr,
        'before_temperature': measurement?['value'],
        'before_value': measurement?['value'],
        'before_recorded_at': measurement?['measured_at'],
        'before_measurement_id': measurement?['id'],
        'evaluation_due_at': dueAtStr,
        'evaluation_status': initialStatus,
        'response_type': responseType.name,
        'idempotency_key': key,
        'actor_id': actorId,
        'actor_name': actorName,
        'checklist': checklist?.join(';'),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }
}
