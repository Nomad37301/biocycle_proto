import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

class PartnerDetailScreen extends ConsumerWidget {
  const PartnerDetailScreen({super.key, required this.partnerId});
  final int partnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProvider(partnerId));
    return Scaffold(
      appBar: AppBar(title: const Text('Profil mitra')),
      body: partner.when(
        loading: () => const AppLoading(label: 'Memuat profil mitra...'),
        error: (_, _) => AppError(
          message: 'Profil mitra gagal dimuat.',
          onRetry: () => ref.invalidate(partnerProvider(partnerId)),
        ),
        data: (value) => value == null
            ? EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Mitra tidak ditemukan',
                message: 'Data mungkin sudah direset.',
                action: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Kembali'),
                ),
              )
            : _content(context, ref, value),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, PartnerProfile partner) {
    final activeRole = ref.watch(demoSessionProvider).role;
    final activeId = activeRole.organizationId;
    return ListView(
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(partner.name.characters.first),
              ),
              const SizedBox(height: 12),
              Text(
                partner.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('${partner.role.label} · ${partner.region}'),
              const SizedBox(height: 18),
              ref
                  .watch(partnerActivityProvider(partner.id))
                  .when(
                    loading: () =>
                        const AppLoading(label: 'Memuat aktivitas...'),
                    error: (_, _) => AppError(
                      message: 'Ringkasan aktivitas gagal dimuat.',
                      onRetry: () =>
                          ref.invalidate(partnerActivityProvider(partner.id)),
                    ),
                    data: (summary) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${summary.completedTransactions} transaksi selesai',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${formatKg(summary.totalKg)} kg dipertukarkan',
                            ),
                            Text(
                              summary.lastActivityAt == null
                                  ? 'Belum ada aktivitas tercatat'
                                  : 'Aktivitas terakhir ${DateFormat('dd MMM yyyy, HH:mm').format(summary.lastActivityAt!)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 26),
              Text(
                activeRole == DemoRole.supplier &&
                        partner.role == DemoRole.operator
                    ? 'Penawaran limbah saya untuk operator ini'
                    : 'Penawaran dan kebutuhan aktif',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ref
                  .watch(listingsProvider)
                  .when(
                    loading: () =>
                        const AppLoading(label: 'Memuat penawaran...'),
                    error: (_, _) => AppError(
                      message: 'Penawaran gagal dimuat.',
                      onRetry: () => ref.invalidate(listingsProvider),
                    ),
                    data: (all) {
                      final useOwnWaste =
                          activeRole == DemoRole.supplier &&
                          partner.role == DemoRole.operator;
                      final items = all
                          .where(
                            (item) =>
                                item.isActive &&
                                (useOwnWaste
                                    ? item.ownerId == activeId &&
                                          item.kind == ListingKind.wasteOffer
                                    : item.ownerId == partner.id),
                          )
                          .toList();
                      if (items.isEmpty) {
                        return EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Belum ada penawaran aktif',
                          message: useOwnWaste
                              ? 'Buat penawaran limbah dahulu, lalu kembali ke profil operator.'
                              : 'Mitra ini belum memiliki penawaran atau kebutuhan aktif.',
                          action: useOwnWaste
                              ? FilledButton(
                                  onPressed: () =>
                                      context.push('/listings/new'),
                                  child: const Text('Buat penawaran limbah'),
                                )
                              : null,
                        );
                      }
                      return Column(
                        children: items
                            .map(
                              (item) => Card(
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  minVerticalPadding: 14,
                                  title: Text(item.material),
                                  subtitle: Text(
                                    '${formatKg(item.availableKg)} kg tersedia',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      context.push('/listings/${item.id}'),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
              const SizedBox(height: 26),
              Text(
                'Riwayat kerja sama',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ref
                  .watch(requestsProvider)
                  .when(
                    loading: () => const AppLoading(label: 'Memuat riwayat...'),
                    error: (_, _) => AppError(
                      message: 'Riwayat kerja sama gagal dimuat.',
                      onRetry: () => ref.invalidate(requestsProvider),
                    ),
                    data: (all) {
                      final items = all
                          .where(
                            (item) =>
                                (item.senderId == activeId &&
                                    item.receiverId == partner.id) ||
                                (item.receiverId == activeId &&
                                    item.senderId == partner.id),
                          )
                          .toList();
                      if (items.isEmpty) {
                        return const Text(
                          'Belum ada riwayat kerja sama dengan mitra ini.',
                        );
                      }
                      return Column(
                        children: items
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.summary),
                                subtitle: Text(
                                  '${item.status.label} · ${formatKg(item.committedQuantityKg)} kg',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    context.push('/requests/${item.id}'),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
