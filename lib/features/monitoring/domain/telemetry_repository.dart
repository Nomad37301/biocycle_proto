import 'telemetry_models.dart';

abstract interface class TelemetryRepository {
  Future<List<BsfUnit>> getUnits();
  Future<BsfUnit?> getUnit(int id);
  Future<List<SensorReading>> getHistory(int unitId, Duration range);
  Future<BsfUnit> recordScenario(int unitId, String scenario, int tick);
}
