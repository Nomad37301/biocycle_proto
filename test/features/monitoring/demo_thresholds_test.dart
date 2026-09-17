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
        DemoThresholds.evaluate(temperature: 34, humidity: 70, connected: true),
        UnitCondition.attention,
      );
      expect(
        DemoThresholds.evaluate(temperature: 38, humidity: 70, connected: true),
        UnitCondition.critical,
      );
      expect(
        DemoThresholds.evaluate(temperature: 30, humidity: 90, connected: true),
        UnitCondition.critical,
      );
    });

    test('status offline mengalahkan nilai sensor terakhir', () {
      expect(
        DemoThresholds.evaluate(
          temperature: 31,
          humidity: 65,
          connected: false,
        ),
        UnitCondition.offline,
      );
    });
  });
}
