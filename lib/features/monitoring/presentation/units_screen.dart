import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
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
              .watch(unitsProvider)
              .when(
                loading: () => const AppLoading(),
                error: (_, _) => AppError(
                  message: 'Daftar unit gagal dimuat.',
                  onRetry: () => ref.invalidate(unitsProvider),
                ),
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.sensors_off,
                        title: 'Belum ada unit',
                        message:
                            'Unit demo akan muncul setelah data awal dimuat.',
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => UnitCard(unit: items[index]),
                      ),
              ),
        ),
      ],
    ),
  );
}
