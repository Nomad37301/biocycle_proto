import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../domain/telemetry_models.dart';
import 'unit_card.dart';

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ContentWidth(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unit budidaya', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Semua nilai di layar ini berasal dari simulator lokal.'),
        const SizedBox(height: 16),
        Expanded(
          child: ref
              .watch(monitoringUnitsProvider)
              .when(
                loading: () => const AppLoading(),
                error: (_, _) => AppError(
                  message: 'Daftar unit gagal dimuat.',
                  onRetry: () => ref.invalidate(monitoringUnitsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.sensors_off,
                      title: 'Belum ada unit',
                      message:
                          'Unit demo akan muncul setelah data awal dimuat.',
                    );
                  }
                  final ordered = [...items]
                    ..sort((a, b) {
                      final severity = _weight(b.evaluation.condition)
                          .compareTo(_weight(a.evaluation.condition));
                      return severity != 0
                          ? severity
                          : a.unit.id.compareTo(b.unit.id);
                    });
                  return ListView.separated(
                    itemCount: ordered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => UnitCard(
                      snapshot: ordered[index],
                      configuration: ref.watch(demoConfigurationProvider),
                    ),
                  );
                },
              ),
        ),
      ],
    ),
  );

  static int _weight(ConditionState state) => switch (state) {
    ConditionState.critical => 4,
    ConditionState.attention => 3,
    ConditionState.unknown => 2,
    ConditionState.optimal => 1,
  };
}
