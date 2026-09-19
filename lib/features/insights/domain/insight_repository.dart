import '../../monitoring/domain/telemetry_models.dart';
import 'insight_models.dart';

class InsightUpdate {
  const InsightUpdate({this.event, this.shouldNotify = false});
  final InsightEvent? event;
  final bool shouldNotify;
}

abstract interface class InsightRepository {
  Future<List<InsightEvent>> getInsights();
  Future<List<InsightEvent>> getActiveInsights();
  Future<InsightEvent?> getInsight(int id);
  Future<List<InsightAction>> getActions(int insightId);
  Future<InsightUpdate> evaluate(BsfUnit unit);
  Future<InsightUpdate> evaluateEvaluationResult({
    required int unitId,
    required String unitName,
    required UnitEvaluationResult evaluationResult,
  });
  Future<void> evaluatePendingActions({DateTime? currentTime});
  Future<List<InsightAction>> getInsightActions(int insightId);
  Future<void> acknowledge(int id, String actor);
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
  });
}
