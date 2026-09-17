import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../../monitoring/domain/telemetry_models.dart';
import '../../monitoring/presentation/unit_card.dart';
import '../../partners/domain/partner_models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(demoSessionProvider).role;
    return role == DemoRole.operator
        ? const _OperatorDashboard()
        : _PartnerDashboard(role: role);
  }
}

class _OperatorDashboard extends ConsumerWidget {
  const _OperatorDashboard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final insights = ref.watch(insightsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(demoSessionProvider.notifier).refresh();
        await ref.read(unitsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _Hero(
            title: 'Pantau yang perlu tindakan',
            subtitle: 'Data simulasi · pembaruan setiap 5 detik',
            icon: Icons.sensors,
          ),
          ContentWidth(
            child: units.when(
              loading: () => const AppLoading(),
              error: (_, _) => AppError(
                message: 'Data unit belum dapat dibuka.',
                onRetry: () => ref.invalidate(unitsProvider),
              ),
              data: (items) {
                final ordered = [...items]
                  ..sort(
                    (a, b) =>
                        _weight(b.condition).compareTo(_weight(a.condition)),
                  );
                final active =
                    insights.valueOrNull
                        ?.where((item) => item.isActive)
                        .length ??
                    0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Summary(
                            value: '${items.length}',
                            label: 'Unit demo',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Summary(
                            value: '$active',
                            label: 'Insight aktif',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Prioritas unit',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Unit dengan kondisi terpenting ditampilkan lebih dulu.',
                    ),
                    const SizedBox(height: 12),
                    ...ordered.map(
                      (unit) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: UnitCard(unit: unit),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static int _weight(UnitCondition condition) => switch (condition) {
    UnitCondition.critical => 4,
    UnitCondition.offline => 3,
    UnitCondition.attention => 2,
    UnitCondition.optimal => 1,
  };
}

class _PartnerDashboard extends ConsumerWidget {
  const _PartnerDashboard({required this.role});
  final DemoRole role;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestsProvider);
    final listings = ref.watch(listingsProvider);
    return ListView(
      children: [
        _Hero(
          title: role == DemoRole.supplier
              ? 'Kelola pasokan organik'
              : 'Temukan hasil BSF',
          subtitle: 'Workspace simulasi ${role.label.toLowerCase()}',
          icon: role == DemoRole.supplier
              ? Icons.compost_outlined
              : Icons.agriculture_outlined,
        ),
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              requests.when(
                data: (items) => Row(
                  children: [
                    Expanded(
                      child: _Summary(
                        value:
                            '${items.where((e) => e.status == RequestStatus.pending).length}',
                        label: 'Perlu ditinjau',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Summary(
                        value:
                            '${items.where((e) => e.status == RequestStatus.accepted).length}',
                        label: 'Sedang berjalan',
                      ),
                    ),
                  ],
                ),
                loading: () => const AppLoading(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              Text(
                'Langkah berikutnya',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role == DemoRole.supplier
                            ? 'Tawarkan limbah yang sudah tersortir'
                            : 'Catat kebutuhan atau ajukan pada penawaran',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Jumlah, tanggal, dan wilayah membantu mitra menilai kecocokan kerja sama.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.push('/listings/new'),
                        icon: const Icon(Icons.add),
                        label: Text(
                          role == DemoRole.supplier
                              ? 'Buat penawaran'
                              : 'Buat kebutuhan',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Aktivitas demo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              listings.when(
                data: (items) => Text(
                  '${items.where((e) => e.isActive).length} penawaran dan kebutuhan aktif di jaringan.',
                ),
                loading: () => const Text('Memuat aktivitas...'),
                error: (_, _) => const Text('Aktivitas belum dapat dimuat.'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.forest,
    child: ContentWidth(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFFDCEBDD)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: AppColors.leaf, size: 44),
        ],
      ),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label),
      ],
    ),
  );
}
