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
  );
}

class InsightAction {
  const InsightAction({
    required this.id,
    required this.insightId,
    required this.completedSteps,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final int insightId;
  final Set<int> completedSteps;
  final String note;
  final DateTime createdAt;

  factory InsightAction.fromMap(Map<String, Object?> map) => InsightAction(
    id: map['id']! as int,
    insightId: map['insight_id']! as int,
    completedSteps: (map['completed_steps']! as String)
        .split(',')
        .where((value) => value.isNotEmpty)
        .map(int.parse)
        .toSet(),
    note: map['note']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
  );
}

const sopSteps = <String, List<String>>{
  'temperature': [
    'Periksa sirkulasi udara pada area budidaya.',
    'Kurangi paparan panas langsung pada media.',
    'Catat perubahan suhu setelah tindakan.',
  ],
  'humidity': [
    'Periksa ventilasi dan permukaan media.',
    'Kurangi sumber kelembapan berlebih.',
    'Catat kondisi media setelah tindakan.',
  ],
  'offline': [
    'Periksa daya BioCycle Smart Kit.',
    'Periksa koneksi perangkat di lokasi.',
    'Hubungi dukungan jika perangkat tetap offline.',
  ],
};
