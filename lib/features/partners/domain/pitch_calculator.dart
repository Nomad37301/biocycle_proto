import '../../../core/config/demo_configuration.dart';

class PitchEstimate {
  const PitchEstimate({
    required this.wasteInputKg,
    required this.monitoredUnits,
    required this.projectedLarvaKg,
    required this.projectedFrassKg,
    required this.projectedRevenue,
    required this.monthlyPackageCost,
    required this.revenuePackageDifference,
    required this.projectedEmissionKgCo2e,
    required this.configVersion,
  });

  final double wasteInputKg;
  final int monitoredUnits;
  final double projectedLarvaKg;
  final double projectedFrassKg;
  final double projectedRevenue;
  final double monthlyPackageCost;
  final double revenuePackageDifference;
  final double projectedEmissionKgCo2e;
  final String configVersion;
}

class PitchCalculator {
  const PitchCalculator._();

  static PitchEstimate calculate({
    required double wasteInputKg,
    required int monitoredUnits,
    required DemoConfiguration configuration,
  }) {
    if (!wasteInputKg.isFinite || wasteInputKg < 0) {
      throw ArgumentError.value(
        wasteInputKg,
        'wasteInputKg',
        'Input harus finite dan tidak negatif.',
      );
    }
    if (monitoredUnits < 0) {
      throw ArgumentError.value(
        monitoredUnits,
        'monitoredUnits',
        'Jumlah unit tidak boleh negatif.',
      );
    }
    configuration.pitch.validate();
    final pitch = configuration.pitch;
    final larvae = wasteInputKg * pitch.larvaYieldFactor;
    final frass = wasteInputKg * pitch.frassYieldFactor;
    final revenue =
        larvae * pitch.larvaPricePerKg + frass * pitch.frassPricePerKg;
    final packageCost = monitoredUnits * pitch.subscriptionPriceMonthly;
    return PitchEstimate(
      wasteInputKg: wasteInputKg,
      monitoredUnits: monitoredUnits,
      projectedLarvaKg: larvae,
      projectedFrassKg: frass,
      projectedRevenue: revenue,
      monthlyPackageCost: packageCost,
      revenuePackageDifference: revenue - packageCost,
      projectedEmissionKgCo2e: wasteInputKg * pitch.emissionReductionFactor,
      configVersion: configuration.version,
    );
  }
}
