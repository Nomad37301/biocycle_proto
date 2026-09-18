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
                if (insights.isLoading) {
                  return const AppLoading(label: 'Memuat ringkasan insight...');
                }
                if (insights.hasError) {
                  return AppError(
                    message: 'Ringkasan insight gagal dimuat.',
                    onRetry: () => ref.invalidate(insightsProvider),
                  );
                }
                final ordered = [...items]
                  ..sort(
                    (a, b) =>
                        _weight(b.condition).compareTo(_weight(a.condition)),
                  );
                final active = insights.requireValue
                    .where((item) => item.isActive)
                    .length;
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
                      'Alur material tercatat',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ref
                        .watch(networkFlowProvider)
                        .when(
                          loading: () => const AppLoading(
                            label: 'Menghitung transaksi selesai...',
                          ),
                          error: (_, _) => AppError(
                            message: 'Alur material gagal dihitung.',
                            onRetry: () => ref.invalidate(networkFlowProvider),
                          ),
                          data: (flow) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _FlowStep(
                                      value: '${formatKg(flow.wasteInKg)} kg',
                                      label: 'Limbah masuk',
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                  Expanded(
                                    child: _FlowStep(
                                      value: '${flow.monitoredUnits} unit',
                                      label: 'Budidaya BSF',
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                  Expanded(
                                    child: _FlowStep(
                                      value: '${formatKg(flow.outputKg)} kg',
                                      label: 'Hasil keluar',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 6),
                    const Text(
                      'Kg berasal dari transaksi selesai. Bagian budidaya hanya menunjukkan unit terpantau, bukan rasio konversi.',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Perlu ditindaklanjuti',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ref
                        .watch(dashboardAttentionProvider)
                        .when(
                          loading: () => const AppLoading(
                            label: 'Memeriksa tindak lanjut...',
                          ),
                          error: (_, _) => AppError(
                            message: 'Tindak lanjut gagal dimuat.',
                            onRetry: () =>
                                ref.invalidate(dashboardAttentionProvider),
                          ),
                          data: (attention) => Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.timeline),
                                  title: Text(
                                    '${attention.conditionEvents} kejadian sensor dalam 24 jam',
                                  ),
                                  subtitle: const Text(
                                    'Mencakup kondisi perlu perhatian dan kritis.',
                                  ),
                                  onTap:
                                      ordered.isEmpty ||
                                          attention.conditionEvents == 0
                                      ? null
                                      : () => context.push(
                                          '/units/${ordered.first.id}',
                                        ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.checklist),
                                  title: Text(
                                    '${attention.incompleteSop} SOP aktif belum lengkap',
                                  ),
                                  onTap: attention.firstInsightId == null
                                      ? null
                                      : () => context.push(
                                          '/insights/${attention.firstInsightId}',
                                        ),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.assignment_outlined,
                                  ),
                                  title: Text(
                                    '${attention.pendingRequests} pengajuan menunggu respons',
                                  ),
                                  onTap: attention.firstRequestId == null
                                      ? null
                                      : () => context.push(
                                          '/requests/${attention.firstRequestId}',
                                        ),
                                ),
                              ],
                            ),
                          ),
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
    final accountId = role.organizationId;
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
                            '${items.where((e) => e.status == RequestStatus.pending && e.receiverId == accountId).length}',
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
                error: (_, _) => AppError(
                  message: 'Ringkasan pengajuan gagal dimuat.',
                  onRetry: () => ref.invalidate(requestsProvider),
                ),
              ),
              const SizedBox(height: 24),
              requests.when(
                data: (items) {
                  final incoming = items.where(
                    (item) =>
                        item.status == RequestStatus.pending &&
                        item.receiverId == accountId,
                  );
                  if (incoming.isEmpty) return const SizedBox.shrink();
                  final item = incoming.first;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: FilledButton.icon(
                      onPressed: () => context.push('/requests/${item.id}'),
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Tinjau pengajuan masuk'),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
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
                error: (_, _) => AppError(
                  message: 'Aktivitas mitra gagal dimuat.',
                  onRetry: () => ref.invalidate(listingsProvider),
                ),
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

class _FlowStep extends StatelessWidget {
  const _FlowStep({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(label, textAlign: TextAlign.center),
    ],
  );
}
