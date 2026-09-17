import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

class PartnersScreen extends ConsumerStatefulWidget {
  const PartnersScreen({super.key});
  @override
  ConsumerState<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends ConsumerState<PartnersScreen> {
  String query = '';
  DemoRole? filter;

  @override
  Widget build(BuildContext context) {
    final partners = ref.watch(partnersProvider);
    final listings = ref.watch(listingsProvider);
    return ContentWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jaringan mitra',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Profil dan aktivitas di bawah merupakan data mitra demo.',
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => query = value.toLowerCase()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Cari nama atau wilayah',
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<DemoRole?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Semua')),
                ButtonSegment(
                  value: DemoRole.supplier,
                  label: Text('Penyedia'),
                ),
                ButtonSegment(
                  value: DemoRole.operator,
                  label: Text('Operator'),
                ),
                ButtonSegment(value: DemoRole.buyer, label: Text('Pembeli')),
              ],
              selected: {filter},
              onSelectionChanged: (value) =>
                  setState(() => filter = value.first),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: partners.when(
              loading: () => const AppLoading(),
              error: (_, _) => AppError(
                message: 'Direktori mitra gagal dimuat.',
                onRetry: () => ref.invalidate(partnersProvider),
              ),
              data: (items) {
                final visible = items
                    .where(
                      (item) =>
                          (filter == null || item.role == filter) &&
                          (item.name.toLowerCase().contains(query) ||
                              item.region.toLowerCase().contains(query)),
                    )
                    .toList();
                if (visible.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'Mitra tidak ditemukan',
                    message: 'Ubah kata pencarian atau filter peran.',
                  );
                }
                final available =
                    listings.valueOrNull ?? const <PartnerListing>[];
                return ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final partner = visible[index];
                    final count = available
                        .where(
                          (listing) =>
                              listing.ownerName == partner.name &&
                              listing.isActive,
                        )
                        .length;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              child: Text(partner.name.characters.first),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    partner.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    '${partner.role.label} · ${partner.region}',
                                  ),
                                  Text('$count penawaran atau kebutuhan aktif'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
