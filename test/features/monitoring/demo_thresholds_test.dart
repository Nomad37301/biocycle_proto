import 'package:biocycle_proto/features/monitoring/domain/telemetry_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoThresholds', () {
    test('memisahkan kondisi optimal, perhatian, dan kritis', () {
      expect(
        DemoThresholds.evaluate(
          temperature: 33.9,
          humidity: 79.9,
          connected: true,
        ),
        UnitCondition.optimal,
      );
      expect(
        DemoThresholds.evaluate(temperature: 36, humidity: 70, connected: true),
        UnitCondition.attention,
      );
      expect(
        DemoThresholds.evaluate(temperature: 39, humidity: 70, connected: true),
        UnitCondition.critical,
      );
      expect(
        DemoThresholds.evaluate(temperature: 30, humidity: 90, connected: true),
        UnitCondition.attention,
      );
    });

    test('status offline mengalahkan nilai sensor terakhir', () {
      expect(
        DemoThresholds.evaluate(
          temperature: 31,
          humidity: 65,
          connected: false,
        ),
        UnitCondition.unknown,
      );
    });

    test('batas per unit mengubah evaluasi dan menolak konfigurasi rusak', () {
      const thresholds = UnitThresholds(
        temperatureAttention: 30,
        temperatureCritical: 32,
        humidityAttention: 70,
        humidityCritical: 75,
      );
      expect(thresholds.isValid, isTrue);
      expect(
        DemoThresholds.evaluate(
          temperature: 31,
          humidity: 60,
          connected: true,
          thresholds: thresholds,
        ),
        UnitCondition.attention,
      );
      expect(
        const UnitThresholds(
          temperatureAttention: 38,
          temperatureCritical: 34,
        ).isValid,
        isFalse,
      );
      expect(
        const UnitThresholds(
          humidityAttention: 80,
          humidityCritical: 101,
        ).isValid,
        isFalse,
      );
    });
  });
}
