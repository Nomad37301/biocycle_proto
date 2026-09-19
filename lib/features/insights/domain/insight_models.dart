enum ActionResponseType { done, unable, notRelevant }

enum ActionEvaluationStatus {
  pendingEvaluation,
  evaluated,
  insufficientData,
  notApplicable,
}

class InsightEvent {
  const InsightEvent({
    required this.id,
    required this.unitId,
    required this.unitName,
    required this.kind,
    required this.severity,
    required this.cause,
    required this.recommendation,
    required this.startedAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.note,
    required this.completedSteps,
    required this.hasSavedAction,
    this.episodeId,
    this.parameterKey,
    this.ruleId,
    this.configVersion,
    this.triggerValue,
    this.triggerMeasuredAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.recoveredAt,
    this.sopVersion,
  });

  final int id;
  final int unitId;
  final String unitName;
  final String kind;
  final String severity;
  final String cause;
  final String recommendation;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final String note;
  final Set<int> completedSteps;
  final bool hasSavedAction;
  final String? episodeId;
  final String? parameterKey;
  final String? ruleId;
  final String? configVersion;
  final double? triggerValue;
  final DateTime? triggerMeasuredAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final DateTime? recoveredAt;
  final String? sopVersion;

  bool get isActive => resolvedAt == null;

  factory InsightEvent.fromMap(Map<String, Object?> map) => InsightEvent(
    id: map['id']! as int,
    unitId: map['unit_id']! as int,
    unitName: map['unit_name']! as String,
    kind: map['kind']! as String,
    severity: map['severity']! as String,
    cause: map['cause']! as String,
    recommendation: map['recommendation']! as String,
    startedAt: DateTime.parse(map['started_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
    resolvedAt: map['resolved_at'] == null
        ? null
        : DateTime.parse(map['resolved_at']! as String),
    note: (map['note'] as String?) ?? '',
    completedSteps: ((map['completed_steps'] as String?) ?? '')
        .split(',')
        .where((value) => value.isNotEmpty)
        .map(int.parse)
        .toSet(),
    hasSavedAction: (map['has_saved_action'] as int?) == 1,
    episodeId: map['episode_id'] as String?,
    parameterKey: map['parameter_key'] as String?,
    ruleId: map['rule_id'] as String?,
    configVersion: map['config_version'] as String?,
    triggerValue: (map['trigger_value'] as num?)?.toDouble(),
    triggerMeasuredAt: map['trigger_measured_at'] == null
        ? null
        : DateTime.parse(map['trigger_measured_at']! as String),
    acknowledgedAt: map['acknowledged_at'] == null
        ? null
        : DateTime.parse(map['acknowledged_at']! as String),
    acknowledgedBy: map['acknowledged_by'] as String?,
    recoveredAt: map['recovered_at'] == null
        ? null
        : DateTime.parse(map['recovered_at']! as String),
    sopVersion: map['sop_version'] as String?,
  );
}

class InsightAction {
  const InsightAction({
    required this.id,
    required this.insightId,
    required this.completedSteps,
    required this.note,
    required this.createdAt,
    required this.beforeTemperature,
    required this.beforeHumidity,
    required this.beforeRecordedAt,
    required this.afterTemperature,
    required this.afterHumidity,
    required this.afterRecordedAt,
    this.responseType = ActionResponseType.done,
    this.evaluationStatus = ActionEvaluationStatus.pendingEvaluation,
    this.evaluationDueAt,
    this.idempotencyKey,
    this.beforeValue,
    this.afterValue,
    this.beforeMeasurementId,
    this.afterMeasurementId,
  });

  final int id;
  final int insightId;
  final Set<int> completedSteps;
  final String note;
  final DateTime createdAt;
  final double? beforeTemperature;
  final double? beforeHumidity;
  final DateTime? beforeRecordedAt;
  final double? afterTemperature;
  final double? afterHumidity;
  final DateTime? afterRecordedAt;
  final ActionResponseType responseType;
  final ActionEvaluationStatus evaluationStatus;
  final DateTime? evaluationDueAt;
  final String? idempotencyKey;
  final double? beforeValue;
  final double? afterValue;
  final int? beforeMeasurementId;
  final int? afterMeasurementId;

  bool get isWaitingForData =>
      evaluationStatus == ActionEvaluationStatus.pendingEvaluation;

  factory InsightAction.fromMap(Map<String, Object?> map) {
    final statusStr = map['evaluation_status'] as String?;
    final evalStatus = switch (statusStr) {
      'evaluated' => ActionEvaluationStatus.evaluated,
      'insufficientData' => ActionEvaluationStatus.insufficientData,
      'notApplicable' => ActionEvaluationStatus.notApplicable,
      _ => ActionEvaluationStatus.pendingEvaluation,
    };

    final respStr = map['response_type'] as String?;
    final respType = switch (respStr) {
      'unable' => ActionResponseType.unable,
      'notRelevant' => ActionResponseType.notRelevant,
      _ => ActionResponseType.done,
    };

    return InsightAction(
      id: map['id']! as int,
      insightId: map['insight_id']! as int,
      completedSteps: (map['completed_steps']! as String)
          .split(',')
          .where((value) => value.isNotEmpty)
          .map(int.parse)
          .toSet(),
      note: map['note']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      beforeTemperature: (map['before_temperature'] as num?)?.toDouble(),
      beforeHumidity: (map['before_humidity'] as num?)?.toDouble(),
      beforeRecordedAt: map['before_recorded_at'] == null
          ? null
          : DateTime.parse(map['before_recorded_at']! as String),
      afterTemperature: (map['after_temperature'] as num?)?.toDouble(),
      afterHumidity: (map['after_humidity'] as num?)?.toDouble(),
      afterRecordedAt: map['after_recorded_at'] == null
          ? null
          : DateTime.parse(map['after_recorded_at']! as String),
      responseType: respType,
      evaluationStatus: evalStatus,
      evaluationDueAt: map['evaluation_due_at'] == null
          ? null
          : DateTime.parse(map['evaluation_due_at']! as String),
      idempotencyKey: map['idempotency_key'] as String?,
      beforeValue:
          (map['before_value'] as num?)?.toDouble() ??
          (map['before_temperature'] as num?)?.toDouble(),
      afterValue:
          (map['after_value'] as num?)?.toDouble() ??
          (map['after_temperature'] as num?)?.toDouble(),
      beforeMeasurementId: map['before_measurement_id'] as int?,
      afterMeasurementId: map['after_measurement_id'] as int?,
    );
  }
}

const sopSteps = <String, List<String>>{
  'thermalAttention': [
    'Periksa sirkulasi udara pada area budidaya.',
    'Kurangi paparan panas langsung pada media.',
    'Catat perubahan suhu setelah tindakan.',
  ],
  'thermalCritical': [
    'Periksa sirkulasi udara pada area budidaya.',
    'Pindahkan atau lindungi media dari sumber panas langsung.',
    'Catat suhu ulang setelah tindakan.',
  ],
  'substrateWet': [
    'Periksa ventilasi dan permukaan media.',
    'Kurangi sumber kelembapan berlebih.',
    'Catat kondisi media setelah tindakan.',
  ],
  'substrateDry': [
    'Periksa kelembapan pada beberapa titik media.',
    'Tambahkan cairan secara bertahap sesuai prosedur lokasi.',
    'Catat kondisi media setelah tindakan.',
  ],
  'deviceOffline': [
    'Periksa daya BioCycle Smart Kit.',
    'Periksa koneksi perangkat di lokasi.',
    'Hubungi dukungan jika perangkat tetap offline.',
  ],
  'sensorError': [
    'Periksa posisi dan kabel probe substrat.',
    'Jangan gunakan pembacaan invalid untuk keputusan media.',
    'Catat hasil pemeriksaan probe.',
  ],
};
