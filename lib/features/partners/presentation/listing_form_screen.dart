import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, this.initial});
  final PartnerListing? initial;
  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class ListingEditScreen extends ConsumerWidget {
  const ListingEditScreen({super.key, required this.listingId});
  final int listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(listingProvider(listingId))
      .when(
        loading: () => const Scaffold(body: AppLoading()),
        error: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Ubah penawaran')),
          body: AppError(
            message: 'Penawaran gagal dimuat.',
            onRetry: () => ref.invalidate(listingProvider(listingId)),
          ),
        ),
        data: (item) {
          if (item == null ||
              item.ownerId !=
                  ref.watch(demoSessionProvider).role.organizationId) {
            return Scaffold(
              appBar: AppBar(title: const Text('Ubah penawaran')),
              body: const EmptyState(
                icon: Icons.lock_outline,
                title: 'Penawaran tidak dapat diubah',
                message: 'Data mungkin sudah direset atau dimiliki akun lain.',
              ),
            );
          }
          return ListingFormScreen(initial: item);
        },
      );
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final formKey = GlobalKey<FormState>();
  final material = TextEditingController();
  final quantity = TextEditingController();
  final region = TextEditingController(text: 'Badung');
  final note = TextEditingController();
  DateTime date = DateTime.now().add(const Duration(days: 1));
  String outputType = 'Larva BSF';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      material.text = initial.material;
      quantity.text = formatKg(initial.quantityKg);
      region.text = initial.region;
      note.text = initial.note;
      date = initial.availableDate;
      outputType = initial.material;
    }
  }

  @override
  void dispose() {
    material.dispose();
    quantity.dispose();
    region.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(demoSessionProvider).role;
    final kind = role == DemoRole.supplier
        ? ListingKind.wasteOffer
        : role == DemoRole.operator
        ? ListingKind.outputOffer
        : ListingKind.outputNeed;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? kind.label
              : 'Ubah ${kind.label.toLowerCase()}',
        ),
      ),
      body: ContentWidth(
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              const Text('Data simulasi akan disimpan di perangkat ini.'),
              const SizedBox(height: 18),
              if (role == DemoRole.supplier)
                TextFormField(
                  controller: material,
                  decoration: const InputDecoration(
                    labelText: 'Jenis limbah',
                    hintText: 'Contoh: sisa sayur tersortir',
                  ),
                  validator: _required,
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: outputType,
                  decoration: const InputDecoration(
                    labelText: 'Jenis hasil BSF',
                  ),
                  items: ['Larva BSF', 'Prepupa', 'Frass']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => outputType = value!,
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Jumlah (kg)'),
                validator: (value) {
                  final parsed = parseQuantity(value ?? '');
                  return parsed == null || parsed <= 0
                      ? 'Masukkan jumlah lebih dari nol.'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: region,
                decoration: const InputDecoration(labelText: 'Wilayah'),
                validator: _required,
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: const Text('Tanggal tersedia'),
                subtitle: Text('${date.day}/${date.month}/${date.year}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Kondisi material atau kebutuhan khusus.',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : () => _save(kind, role),
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Simpan data demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini perlu diisi.' : null;

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (result != null) setState(() => date = result);
  }

  Future<void> _save(ListingKind kind, DemoRole role) async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final selectedMaterial = role == DemoRole.supplier
          ? material.text
          : outputType;
      if (widget.initial == null) {
        await ref
            .read(partnerRepositoryProvider)
            .createListing(
              ownerRole: role,
              kind: kind,
              material: selectedMaterial,
              quantityKg: parseQuantity(quantity.text)!,
              availableDate: date,
              region: region.text,
              note: note.text,
            );
      } else {
        await ref
            .read(partnerRepositoryProvider)
            .updateListing(
              id: widget.initial!.id,
              ownerId: role.organizationId,
              material: selectedMaterial,
              quantityKg: parseQuantity(quantity.text)!,
              availableDate: date,
              region: region.text,
              note: note.text,
            );
      }
      ref.read(partnerRevisionProvider.notifier).state++;
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
