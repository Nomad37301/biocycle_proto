import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/async_content.dart';
import '../domain/insight_models.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ContentWidth(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insight dan tindakan',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Rekomendasi berbasis aturan demo, bukan diagnosis otomatis.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ref
              .watch(insightsProvider)
              .when(
                loading: () => const AppLoading(),
                error: (_, _) => AppError(
                  message: 'Riwayat insight gagal dimuat.',
                  onRetry: () => ref.invalidate(insightsProvider),
                ),
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.task_alt,
                        title: 'Semua kondisi terkendali',
                        message: 'Pilih skenario di kontrol demo untuk melihat alur peringatan.',
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) =>
                            _InsightCard(item: items[index]),
                      ),
              ),
        ),
      ],
    ),
  );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.item});
  final InsightEvent item;
  @override
  Widget build(BuildContext context) {
    final color = item.isActive
        ? (item.severity == 'critical' ? AppColors.danger : AppColors.warning)
        : Colors.blueGrey;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/insights/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.kind == 'deviceOffline'
                    ? Icons.wifi_off
                    : Icons.warning_amber_rounded,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.unitName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          item.isActive ? 'Aktif' : 'Pulih',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(item.cause),
                    const SizedBox(height: 8),
                    Text(
                      item.isActive
                          ? 'Aktif ${_age(item.startedAt)}'
                          : DateFormat('dd MMM, HH:mm').format(item.updatedAt),
                    ),
                    if (item.isActive &&
                        !item.hasSavedAction &&
                        DateTime.now().difference(item.startedAt) >=
                            const Duration(minutes: 15))
                      Text(
                        'Belum ditangani',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _age(DateTime startedAt) {
    final age = DateTime.now().difference(startedAt);
    if (age.inHours > 0) return '${age.inHours} jam';
    return '${age.inMinutes} menit';
  }
}
