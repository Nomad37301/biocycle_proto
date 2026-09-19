import 'package:biocycle_proto/core/config/demo_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoConfiguration', () {
    test('default configuration is valid', () {
      const config = DemoConfiguration();
      expect(() => config.validate(), returnsNormally);
      expect(config.version, 'demo-v1');
      expect(config.freshness.freshThreshold.inSeconds, 30);
      expect(config.freshness.agingThreshold.inSeconds, 300);
      expect(config.freshness.offlineThreshold.inSeconds, 600);
      expect(config.substrateTemperature.criticalMax, 38.0);
      expect(config.substrateMoisture.optimalMin, 50.0);
      expect(config.substrateMoisture.optimalMax, 80.0);
    });

    test('serializes and deserializes correctly', () {
      const config = DemoConfiguration();
      final jsonStr = config.toJson();
      final deserialized = DemoConfiguration.fromJson(jsonStr);

      expect(deserialized.version, config.version);
      expect(
        deserialized.freshness.freshThreshold,
        config.freshness.freshThreshold,
      );
      expect(
        deserialized.substrateTemperature.criticalMax,
        config.substrateTemperature.criticalMax,
      );
      expect(deserialized.pitch.subscriptionPriceMonthly, 299000.0);
    });

    test('rejects reversed or nonfinite thresholds', () {
      const invalidTemp = SubstrateTemperatureRuleConfig(
        optimalMin: 38.0,
        optimalMax: 30.0,
      );
      expect(
        () => invalidTemp.validate(),
        throwsA(isA<ConfigurationException>()),
      );

      const invalidMoisture = SubstrateMoistureRuleConfig(
        optimalMin: 90.0,
        optimalMax: 50.0,
      );
      expect(
        () => invalidMoisture.validate(),
        throwsA(isA<ConfigurationException>()),
      );

      const invalidFreshness = FreshnessConfig(
        freshThreshold: Duration(seconds: 400),
        agingThreshold: Duration(seconds: 200),
      );
      expect(
        () => invalidFreshness.validate(),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });
}
