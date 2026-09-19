import 'telemetry_models.dart';

abstract interface class TelemetryRepository {
  Future<List<BsfUnit>> getUnits();
  Future<BsfUnit?> getUnit(int id);
  Future<List<SensorReading>> getHistory(int unitId, Duration range);
  Future<BsfUnit> recordScenario(int unitId, String scenario, int tick);
  Future<void> updateThresholds(int unitId, UnitThresholds thresholds);
  Future<UnitSummary?> getSummary(int unitId, Duration range);

  // v6 methods
  Future<List<BsfDevice>> getDevices(int unitId);
  Future<List<SensorParameter>> getSensorParameters(String deviceId);
  Future<Map<String, TelemetryMeasurement>> getLatestMeasurements(int unitId);
  Future<List<TelemetryMeasurement>> getMeasurementHistory(
    int unitId,
    String parameterKey,
    Duration range,
  );
  Future<void> insertMeasurement(TelemetryMeasurement measurement);
  Future<void> updateDeviceConnection(
    String deviceId,
    bool isConnected,
    DateTime? lastSeenAt,
  );
}
