import '../../monitoring/domain/telemetry_models.dart';
import 'insight_models.dart';

class InsightUpdate {
  const InsightUpdate({this.event, this.shouldNotify = false});
  final InsightEvent? event;
  final bool shouldNotify;
}

abstract interface class InsightRepository {
  Future<List<InsightEvent>> getInsights();
  Future<InsightEvent?> getInsight(int id);
  Future<InsightUpdate> evaluate(BsfUnit unit);
  Future<void> saveAction(int id, Set<int> steps, String note);
}
