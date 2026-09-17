import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key, required this.ownedOnly});
  final bool ownedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(demoSessionProvider).role;
    return ContentWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(role),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Text(
                      'Jumlah dan jadwal menggunakan data demo lokal.',
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Buat baru',
                onPressed: () => context.push('/listings/new'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ref
                .watch(listingsProvider)
                .when(
                  loading: () => const AppLoading(),
                  error: (_, _) => AppError(
                    message: 'Daftar aktivitas mitra gagal dimuat.',
                    onRetry: () => ref.invalidate(listingsProvider),
                  ),
                  data: (all) {
                    final items = all
                        .where((item) => _visible(item, role))
                        .toList();
                    if (items.isEmpty) {
                      return EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Belum ada aktivitas',
                        message: ownedOnly
                            ? 'Buat penawaran atau kebutuhan pertama untuk memulai.'
                            : 'Belum ada penawaran yang sesuai untuk peran ini.',
                        action: ownedOnly
                            ? FilledButton(
                                onPressed: () => context.push('/listings/new'),
                                child: const Text('Buat sekarang'),
                              )
                            : null,
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) =>
                          _ListingCard(item: items[index], currentRole: role),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  String _title(DemoRole role) {
    if (!ownedOnly) return 'Peluang kerja sama';
    return role == DemoRole.supplier
        ? 'Penawaran limbah'
        : 'Kebutuhan hasil BSF';
  }

  bool _visible(PartnerListing item, DemoRole role) {
    if (ownedOnly) return item.ownerRole == role;
    if (!item.isActive || item.ownerRole == role) return false;
    return switch (role) {
      DemoRole.operator =>
        item.kind == ListingKind.wasteOffer ||
            item.kind == ListingKind.outputNeed,
      DemoRole.buyer => item.kind == ListingKind.outputOffer,
      DemoRole.supplier => false,
    };
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.item, required this.currentRole});
  final PartnerListing item;
  final DemoRole currentRole;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.material,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(item.isActive ? item.kind.label : 'Diarsipkan'),
            ],
          ),
          const SizedBox(height: 5),
          Text(item.ownerName),
          Text('${item.quantityKg.toStringAsFixed(0)} kg · ${item.region}'),
          Text(
            'Tersedia ${DateFormat('dd MMM yyyy').format(item.availableDate)}',
          ),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.note),
          ],
          const SizedBox(height: 14),
          if (item.ownerRole == currentRole && item.isActive)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/listings/${item.id}/edit', extra: item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Ubah'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _archive(context, ref),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arsipkan'),
                ),
              ],
            )
          else if (item.isActive)
            FilledButton(
              onPressed: () => _request(context, ref),
              child: const Text('Ajukan kerja sama'),
            ),
        ],
      ),
    ),
  );

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    await ref
        .read(partnerRepositoryProvider)
        .archiveListing(item.id, currentRole);
    ref.read(demoSessionProvider.notifier).refresh();
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: item.quantityKg.toStringAsFixed(0),
    );
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajukan kerja sama'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Jumlah (kg)',
            helperText: 'Maksimal ${item.quantityKg.toStringAsFixed(0)} kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Kirim pengajuan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null || !context.mounted) return;
    try {
      await ref
          .read(partnerRepositoryProvider)
          .createRequest(item, currentRole, quantity);
      ref.read(demoSessionProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pengajuan tersimpan. Pantau statusnya di tab Pengajuan.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
