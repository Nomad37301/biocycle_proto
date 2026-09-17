import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/insight_models.dart';

class InsightDetailScreen extends ConsumerStatefulWidget {
  const InsightDetailScreen({super.key, required this.insightId});
  final int insightId;
  @override
  ConsumerState<InsightDetailScreen> createState() =>
      _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  final noteController = TextEditingController();
  final completed = <int>{};
  bool seeded = false;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(demoSessionProvider).role;
    final async = ref.watch(insightProvider(widget.insightId));
    return Scaffold(
      appBar: AppBar(title: const Text('Rincian insight')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (_, _) => AppError(
          message: 'Insight gagal dimuat.',
          onRetry: () => ref.invalidate(insightProvider(widget.insightId)),
        ),
        data: (item) {
          if (item == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Insight tidak ditemukan',
              message: 'Kejadian ini mungkin sudah direset.',
            );
          }
          if (!seeded) {
            seeded = true;
            completed.addAll(item.completedSteps);
            noteController.text = item.note;
          }
          if (role != DemoRole.operator) {
            return _RoleGuard(
              onSwitch: () {
                ref
                    .read(demoSessionProvider.notifier)
                    .setRole(DemoRole.operator);
              },
            );
          }
          return _content(item);
        },
      ),
    );
  }

  Widget _content(InsightEvent item) {
    final steps = sopSteps[item.kind] ?? const <String>[];
    final color = item.severity == 'critical'
        ? AppColors.danger
        : AppColors.warning;
    return ListView(
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isActive ? 'Perlu ditangani' : 'Kondisi telah pulih',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: color),
                    ),
                    const SizedBox(height: 8),
                    Text(item.cause),
                    const SizedBox(height: 8),
                    Text(
                      'Terakhir diperbarui ${DateFormat('dd MMM yyyy, HH:mm').format(item.updatedAt)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Rekomendasi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(item.recommendation),
              const SizedBox(height: 24),
              Text(
                'SOP tindakan demo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Panduan ini perlu divalidasi ahli sebelum dipakai dalam operasional nyata.',
              ),
              const SizedBox(height: 10),
              ...List.generate(
                steps.length,
                (index) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: completed.contains(index),
                  title: Text(steps[index]),
                  onChanged: (checked) => setState(
                    () => checked == true
                        ? completed.add(index)
                        : completed.remove(index),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Catatan tindakan',
                  hintText:
                      'Tuliskan hasil pemeriksaan atau tindakan di lokasi.',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan catatan tindakan'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    await ref
        .read(insightRepositoryProvider)
        .saveAction(widget.insightId, completed, noteController.text);
    ref.read(demoSessionProvider.notifier).refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tindakan tersimpan pada riwayat demo.')),
      );
    }
  }
}

class _RoleGuard extends StatelessWidget {
  const _RoleGuard({required this.onSwitch});
  final VoidCallback onSwitch;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.manage_accounts_outlined,
    title: 'Insight dikelola operator',
    message: 'Beralih ke workspace Operator BSF untuk membuka SOP dan catatan tindakan.',
    action: FilledButton(
      onPressed: onSwitch,
      child: const Text('Beralih ke Operator BSF'),
    ),
  );
}
