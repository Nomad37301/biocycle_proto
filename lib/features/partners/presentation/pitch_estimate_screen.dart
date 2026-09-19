import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/config/demo_configuration.dart';
import '../../../core/formatters/indonesian_formatters.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/async_content.dart';
import '../domain/pitch_calculator.dart';

class PitchEstimateScreen extends ConsumerWidget {
  const PitchEstimateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ContentWidth(
    child: ref
        .watch(networkFlowProvider)
        .when(
          loading: () =>
              const AppLoading(label: 'Menghitung transaksi demo selesai...'),
          error: (_, _) => AppError(
            message: 'Estimasi tidak dapat dihitung. Monitoring unit tetap berjalan.',
            onRetry: () => ref.invalidate(networkFlowProvider),
          ),
          data: (flow) {
            final configuration = ref.watch(demoConfigurationProvider);
            final estimate = PitchCalculator.calculate(
              wasteInputKg: flow.wasteInKg,
              monitoredUnits: flow.monitoredUnits,
              configuration: configuration,
            );
            return ListView(
              key: const Key('pitch-estimate-list'),
              children: [
                Text(
                  'Estimasi sirkular',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Estimasi berbasis simulasi · ${estimate.configVersion}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Periode: seluruh transaksi completed pada fixture demo tersimpan. Pending, accepted, rejected, dan cancelled tidak dihitung.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(
                        context,
                        'Limbah masuk selesai',
                        '${IndonesianFormatters.number(flow.wasteInKg)} kg',
                      ),
                      _row(
                        context,
                        'Hasil keluar selesai',
                        '${IndonesianFormatters.number(flow.outputKg)} kg',
                      ),
                      _row(
                        context,
                        'Unit terpantau',
                        '${flow.monitoredUnits} unit',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Proyeksi dari input limbah',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSurface(
                  level: AppSurfaceLevel.sunken,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(
                        context,
                        'Larva, asumsi konversi demo ${IndonesianFormatters.number(configuration.pitch.larvaYieldFactor * 100)}%',
                        '${IndonesianFormatters.number(estimate.projectedLarvaKg)} kg',
                      ),
                      _row(
                        context,
                        'Kasgot, asumsi konversi demo ${IndonesianFormatters.number(configuration.pitch.frassYieldFactor * 100)}%',
                        '${IndonesianFormatters.number(estimate.projectedFrassKg)} kg',
                      ),
                      _row(
                        context,
                        'Proyeksi pendapatan',
                        IndonesianFormatters.currency(
                          estimate.projectedRevenue,
                        ),
                      ),
                      _row(
                        context,
                        'Biaya paket satu bulan',
                        IndonesianFormatters.currency(
                          estimate.monthlyPackageCost,
                        ),
                      ),
                      _row(
                        context,
                        'Selisih pendapatan dan paket',
                        IndonesianFormatters.currency(
                          estimate.revenuePackageDifference,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Selisih ini bukan laba. Biaya operasi, mortalitas, dan hubungan transaksi ke batch belum dimodelkan.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row(
                        context,
                        'Proyeksi emisi',
                        '${IndonesianFormatters.number(estimate.projectedEmissionKgCo2e)} kg CO2e',
                      ),
                      Text(
                        'Bukan pengurangan emisi aktual. Faktor ${IndonesianFormatters.number(configuration.pitch.emissionReductionFactor)} kg CO2e per kg input adalah asumsi demo yang belum tervalidasi.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => _copyReport(
                    context,
                    estimate,
                    flow.outputKg,
                    configuration,
                  ),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Salin laporan estimasi'),
                ),
              ],
            );
          },
        ),
  );

  static Widget _row(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      );

  static Future<void> _copyReport(
    BuildContext context,
    PitchEstimate estimate,
    double completedOutputKg,
    DemoConfiguration configuration,
  ) async {
    final report =
        '''BioCycle, estimasi berbasis simulasi
Config: ${estimate.configVersion}
Periode: seluruh transaksi completed pada fixture demo tersimpan
Input limbah completed: ${IndonesianFormatters.number(estimate.wasteInputKg)} kg
Output completed tercatat: ${IndonesianFormatters.number(completedOutputKg)} kg
Proyeksi larva: W x ${IndonesianFormatters.number(configuration.pitch.larvaYieldFactor, decimalDigits: 3)} = ${IndonesianFormatters.number(estimate.projectedLarvaKg)} kg
Proyeksi kasgot: W x ${IndonesianFormatters.number(configuration.pitch.frassYieldFactor, decimalDigits: 3)} = ${IndonesianFormatters.number(estimate.projectedFrassKg)} kg
Proyeksi pendapatan: ${IndonesianFormatters.currency(estimate.projectedRevenue)}
Biaya paket 1 bulan: ${IndonesianFormatters.currency(estimate.monthlyPackageCost)}
Selisih: ${IndonesianFormatters.currency(estimate.revenuePackageDifference)} (bukan laba)
Proyeksi emisi: ${IndonesianFormatters.number(estimate.projectedEmissionKgCo2e)} kg CO2e (bukan pengurangan aktual)
Semua harga, faktor konversi, dan faktor emisi adalah asumsi demo.''';
    await Clipboard.setData(ClipboardData(text: report));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan estimasi disalin.')),
      );
    }
  }
}
