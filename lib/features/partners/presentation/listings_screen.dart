import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

class ListingsScreen extends ConsumerStatefulWidget {
  const ListingsScreen({super.key, required this.ownedOnly, this.roleOverride});
  final bool ownedOnly;
  final DemoRole? roleOverride;

  @override
  ConsumerState<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends ConsumerState<ListingsScreen> {
  String? region;
  String? material;

  @override
  Widget build(BuildContext context) {
    final role = widget.roleOverride ?? ref.watch(demoSessionProvider).role;
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
                    final visible = all
                        .where((item) => _visible(item, role))
                        .toList();
                    final regions =
                        visible.map((e) => e.region).toSet().toList()..sort();
                    final materials =
                        visible.map((e) => e.material).toSet().toList()..sort();
                    final items = visible
                        .where(
                          (item) =>
                              (region == null || item.region == region) &&
                              (material == null || item.material == material),
                        )
                        .toList();
                    if (items.isEmpty) {
                      return Column(
                        children: [
                          _filters(regions, materials),
                          Expanded(
                            child: EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: region != null || material != null
                                  ? 'Tidak ada hasil filter'
                                  : 'Belum ada aktivitas',
                              message: widget.ownedOnly
                                  ? 'Buat penawaran atau kebutuhan pertama untuk memulai.'
                                  : 'Belum ada penawaran yang sesuai untuk peran ini.',
                              action: region != null || material != null
                                  ? OutlinedButton(
                                      onPressed: _resetFilters,
                                      child: const Text('Reset filter'),
                                    )
                                  : widget.ownedOnly
                                  ? FilledButton(
                                      onPressed: () =>
                                          context.push('/listings/new'),
                                      child: const Text('Buat sekarang'),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _filters(regions, materials),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) => _ListingCard(
                              item: items[index],
                              currentRole: role,
                            ),
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

  String _title(DemoRole role) {
    if (!widget.ownedOnly) return 'Peluang kerja sama';
    return switch (role) {
      DemoRole.supplier => 'Penawaran limbah',
      DemoRole.operator => 'Penawaran hasil BSF',
      DemoRole.buyer => 'Kebutuhan hasil BSF',
    };
  }

  bool _visible(PartnerListing item, DemoRole role) {
    if (widget.ownedOnly) return item.ownerId == role.organizationId;
    if (!item.isActive || item.ownerId == role.organizationId) return false;
    return switch (role) {
      DemoRole.operator =>
        item.kind == ListingKind.wasteOffer ||
            item.kind == ListingKind.outputNeed,
      DemoRole.buyer => item.kind == ListingKind.outputOffer,
      DemoRole.supplier => false,
    };
  }

  Widget _filters(List<String> regions, List<String> materials) {
    final count = [region, material].whereType<String>().length;
    final summary = [?region, ?material].join(' · ');
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () => _showFilters(regions, materials),
          icon: const Icon(Icons.filter_list),
          label: Text(count == 0 ? 'Filter katalog' : 'Filter ($count)'),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showFilters(
    List<String> regions,
    List<String> materials,
  ) async {
    var draftRegion = region;
    var draftMaterial = material;
    final applied =
        await showModalBottomSheet<({String? region, String? material})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheetState) => SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter katalog',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Pilih wilayah dan material. Perubahan baru berlaku setelah Terapkan.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      DropdownButtonFormField<String?>(
                        initialValue: draftRegion,
                        decoration: const InputDecoration(labelText: 'Wilayah'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Semua wilayah'),
                          ),
                          ...regions.map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => draftRegion = value),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String?>(
                        initialValue: draftMaterial,
                        decoration: const InputDecoration(
                          labelText: 'Material',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Semua material'),
                          ),
                          ...materials.map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => draftMaterial = value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          TextButton(
                            onPressed: () => setSheetState(() {
                              draftRegion = null;
                              draftMaterial = null;
                            }),
                            child: const Text('Reset filter'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, (
                              region: draftRegion,
                              material: draftMaterial,
                            )),
                            child: const Text('Terapkan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    if (applied == null || !mounted) return;
    setState(() {
      region = applied.region;
      material = applied.material;
    });
  }

  void _resetFilters() => setState(() {
    region = null;
    material = null;
  });
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
