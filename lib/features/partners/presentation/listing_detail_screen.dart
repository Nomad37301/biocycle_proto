import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId});
  final int listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(demoSessionProvider).role;
    return Scaffold(
      appBar: AppBar(title: const Text('Rincian penawaran')),
      body: ref
          .watch(listingProvider(listingId))
          .when(
            loading: () => const AppLoading(label: 'Memuat penawaran...'),
            error: (_, _) => AppError(
              message: 'Penawaran gagal dimuat.',
              onRetry: () => ref.invalidate(listingProvider(listingId)),
            ),
            data: (item) => item == null
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Penawaran tidak ditemukan',
                    message: 'Data mungkin sudah direset.',
                    action: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Kembali'),
                    ),
                  )
                : _content(context, ref, item, role),
          ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    PartnerListing item,
    DemoRole role,
  ) => ListView(
    children: [
      ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.material,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(item.kind.label),
            Text(item.ownerName),
            const SizedBox(height: 18),
            Text(
              '${formatKg(item.availableKg)} kg tersedia dari ${formatKg(item.quantityKg)} kg',
            ),
            Text('Wilayah ${item.region}'),
            Text(
              'Tersedia ${DateFormat('dd MMMM yyyy').format(item.availableDate)}',
            ),
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(item.note),
            ],
            const SizedBox(height: 24),
            if (item.ownerId == role.organizationId)
              FilledButton.icon(
                onPressed: item.isActive
                    ? () => context.push('/listings/${item.id}/edit')
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Ubah penawaran'),
              ),
            if (_canRequest(item, role))
              FilledButton.icon(
                onPressed: item.isActive && item.availableKg > 0
                    ? () => _request(context, ref, item, role)
                    : null,
                icon: const Icon(Icons.handshake_outlined),
                label: Text(
                  role == DemoRole.supplier
                      ? 'Tawarkan ke operator'
                      : 'Ajukan kerja sama',
                ),
              ),
          ],
        ),
      ),
    ],
  );

  bool _canRequest(PartnerListing item, DemoRole role) => switch (item.kind) {
    ListingKind.wasteOffer =>
      role == DemoRole.operator ||
          (role == DemoRole.supplier && item.ownerId == role.organizationId),
    ListingKind.outputOffer => role == DemoRole.buyer,
    ListingKind.outputNeed => role == DemoRole.operator,
  };

  Future<void> _request(
    BuildContext context,
    WidgetRef ref,
    PartnerListing item,
    DemoRole role,
  ) async {
    final quantity = TextEditingController(text: formatKg(item.availableKg));
    final note = TextEditingController();
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajukan kerja sama'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantity,
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
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
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
            onPressed: () {
              final parsed = parseQuantity(quantity.text);
              if (parsed != null && parsed > 0) {
                Navigator.pop(context, (parsed, note.text));
              }
            },
            child: const Text('Kirim pengajuan'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    quantity.dispose();
    note.dispose();
    if (result == null || !context.mounted) return;
    try {
      final id = await ref
          .read(partnerRepositoryProvider)
          .createRequest(
            listingId: item.id,
            senderId: role.organizationId,
            receiverId: role == DemoRole.supplier
                ? DemoRole.operator.organizationId
                : item.ownerId,
            quantityKg: result.$1,
            note: result.$2,
          );
      ref.read(partnerRevisionProvider.notifier).state++;
      if (context.mounted) context.push('/requests/$id');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pengajuan gagal dikirim: $error')),
        );
      }
    }
  }
}
