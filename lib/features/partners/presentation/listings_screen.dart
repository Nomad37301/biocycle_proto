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
    return switch (role) {
      DemoRole.supplier => 'Penawaran limbah',
      DemoRole.operator => 'Penawaran hasil BSF',
      DemoRole.buyer => 'Kebutuhan hasil BSF',
    };
  }

  bool _visible(PartnerListing item, DemoRole role) {
    if (ownedOnly) return item.ownerId == role.organizationId;
    if (!item.isActive || item.ownerId == role.organizationId) return false;
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
          Text('${formatKg(item.quantityKg)} kg · ${item.region}'),
          Text('Sisa ${formatKg(item.availableKg)} kg'),
          Text(
            'Tersedia ${DateFormat('dd MMM yyyy').format(item.availableDate)}',
          ),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.note),
          ],
          const SizedBox(height: 14),
          if (item.ownerId == currentRole.organizationId && item.isActive)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/listings/${item.id}/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Ubah'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _archive(context, ref),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arsipkan'),
                ),
                if (currentRole == DemoRole.supplier)
                  FilledButton.icon(
                    onPressed: item.availableKg > 0
                        ? () => _request(context, ref)
                        : null,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Tawarkan ke operator'),
                  ),
              ],
            )
          else if (item.isActive)
            FilledButton(
              onPressed: item.availableKg > 0
                  ? () => _request(context, ref)
                  : null,
              child: const Text('Ajukan kerja sama'),
            ),
        ],
      ),
    ),
  );

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    await ref
        .read(partnerRepositoryProvider)
        .archiveListing(item.id, currentRole.organizationId);
    ref.read(partnerRevisionProvider.notifier).state++;
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: formatKg(item.availableKg));
    final noteController = TextEditingController();
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajukan kerja sama'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Jumlah (kg)',
                helperText: 'Maksimal ${formatKg(item.availableKg)} kg',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan untuk mitra (opsional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, parseQuantity(controller.text)),
            child: const Text('Kirim pengajuan'),
          ),
        ],
      ),
    );
    final note = noteController.text;
    await Future<void>.delayed(kThemeAnimationDuration);
    controller.dispose();
    noteController.dispose();
    if (quantity == null || !context.mounted) return;
    try {
      final requestId = await ref
          .read(partnerRepositoryProvider)
          .createRequest(
            listingId: item.id,
            senderId: currentRole.organizationId,
            receiverId:
                currentRole == DemoRole.supplier &&
                    item.ownerId == currentRole.organizationId
                ? DemoRole.operator.organizationId
                : item.ownerId,
            quantityKg: quantity,
            note: note,
          );
      ref.read(partnerRevisionProvider.notifier).state++;
      if (context.mounted) {
        context.push('/requests/$requestId');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
