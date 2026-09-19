import 'package:biocycle_proto/core/config/demo_configuration.dart';
import 'package:biocycle_proto/features/partners/domain/pitch_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formula pitch memakai centralized config', () {
    final estimate = PitchCalculator.calculate(
      wasteInputKg: 120,
      monitoredUnits: 3,
      configuration: const DemoConfiguration(),
    );

    expect(estimate.projectedLarvaKg, closeTo(19.2, 0.0001));
    expect(estimate.projectedFrassKg, closeTo(51, 0.0001));
    expect(estimate.projectedRevenue, closeTo(255600, 0.0001));
    expect(estimate.monthlyPackageCost, 897000);
    expect(estimate.revenuePackageDifference, -641400);
    expect(estimate.projectedEmissionKgCo2e, closeTo(228, 0.0001));
    expect(estimate.configVersion, 'demo-v1');
  });

  test('zero valid dan input negatif atau nonfinite ditolak', () {
    final zero = PitchCalculator.calculate(
      wasteInputKg: 0,
      monitoredUnits: 0,
      configuration: const DemoConfiguration(),
    );
    expect(zero.projectedRevenue, 0);
    expect(
      () => PitchCalculator.calculate(
        wasteInputKg: -1,
        monitoredUnits: 1,
        configuration: const DemoConfiguration(),
      ),
      throwsArgumentError,
    );
    expect(
      () => PitchCalculator.calculate(
        wasteInputKg: double.nan,
        monitoredUnits: 1,
        configuration: const DemoConfiguration(),
      ),
      throwsArgumentError,
    );
  });
}
