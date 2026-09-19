import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan demo')),
    body: ListView(
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ref
                    .watch(notificationsEnabledProvider)
                    .when(
                      loading: () => const ListTile(
                        title: Text('Memuat pengaturan notifikasi...'),
                        trailing: CircularProgressIndicator(),
                      ),
                      error: (_, _) => ListTile(
                        title: const Text('Pengaturan notifikasi gagal dimuat'),
                        trailing: IconButton(
                          tooltip: 'Coba lagi',
                          onPressed: () =>
                              ref.invalidate(notificationsEnabledProvider),
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                      data: (enabled) => SwitchListTile(
                        secondary: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: const Text('Notifikasi kondisi'),
                        subtitle: Text(
                          enabled
                              ? 'Peringatan sensor dan aktivitas kemitraan ditampilkan oleh Android.'
                              : 'Insight dan aktivitas tetap tersimpan tanpa peringatan Android.',
                        ),
                        value: enabled,
                        onChanged: (value) =>
                            _setNotifications(context, ref, value),
                      ),
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ref
                    .watch(modeTerikProvider)
                    .when(
                      loading: () => const ListTile(
                        title: Text('Memuat Mode Terik...'),
                        trailing: CircularProgressIndicator(),
                      ),
                      error: (_, _) => ListTile(
                        title: const Text('Mode Terik gagal dimuat'),
                        trailing: IconButton(
                          tooltip: 'Coba lagi',
                          onPressed: () => ref.invalidate(modeTerikProvider),
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                      data: (enabled) => SwitchListTile(
                        secondary: const Icon(Icons.wb_sunny_outlined),
                        title: const Text('Mode Terik'),
                        subtitle: const Text(
                          'Perkuat batas, bobot teks, dan permukaan untuk kondisi cahaya terang.',
                        ),
                        value: enabled,
                        onChanged: (value) => _setModeTerik(ref, value),
                      ),
                    ),
              ),
              const SizedBox(height: 12),
              if (ref.watch(demoSessionProvider).role == DemoRole.operator) ...[
                ref
                    .watch(demoServicePlanProvider)
                    .when(
                      loading: () => const Card(
                        child: AppLoading(label: 'Memuat layanan...'),
                      ),
                      error: (_, _) => AppError(
                        message: 'Status layanan gagal dimuat.',
                        onRetry: () => ref.invalidate(demoServicePlanProvider),
                      ),
                      data: (plan) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paket operator',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              const Text('Rp299.000/bulan'),
                              Text('Status: ${plan.effectiveStatus}'),
                              Text(
                                'Mulai: ${DateFormat('dd MMM yyyy').format(plan.startedAt)}',
                              ),
                              Text(
                                'Berakhir: ${DateFormat('dd MMM yyyy').format(plan.endsAt)}',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Aktivasi ini hanya simulasi 30 hari. Tidak ada pembayaran dan fitur tidak dibatasi.',
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => _activateDemo(ref),
                                child: const Text('Aktifkan demo 30 hari'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
              ],
              Card(
                child: ListTile(
                  minVerticalPadding: 14,
                  leading: const Icon(Icons.slideshow_outlined),
                  title: const Text('Ulangi pemilihan peran'),
                  subtitle: const Text(
                    'Pilih workspace Operator, Penyedia, atau Pembeli.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/onboarding'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  minVerticalPadding: 14,
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('Reset demo'),
                  subtitle: const Text(
                    'Hapus perubahan lokal dan muat kembali data awal.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _reset(context, ref),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tentang BioCycle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Image.asset(
                          'asset/images/biocycle_logo.png',
                          height: 150,
                          semanticLabel: 'Logo BioCycle',
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'BioCycle menghubungkan smart monitoring, panduan tindakan, dan jaringan mitra dalam ekosistem pengolahan limbah organik.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Working prototype · seluruh data operasional dan mitra adalah simulasi.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _setNotifications(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final notifications = ref.read(notificationProvider);
    final store = ref.read(databaseProvider);
    final session = ref.read(demoSessionProvider.notifier);
    final granted = enabled ? await notifications.requestPermission() : false;
    await store.setSetting(
      'notifications_enabled',
      (enabled && granted).toString(),
    );
    session.refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !enabled
                ? 'Notifikasi dinonaktifkan.'
                : granted
                ? 'Notifikasi diaktifkan.'
                : 'Izin tidak diberikan. Insight tetap tersedia di aplikasi.',
          ),
        ),
      );
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset semua data demo?'),
        content: const Text(
          'Penawaran, pengajuan, insight, dan catatan yang dibuat akan dihapus dari perangkat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset demo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(demoSessionProvider.notifier);
    final partnerRevision = ref.read(partnerRevisionProvider.notifier);
    await session.reset();
    partnerRevision.state++;
    if (context.mounted) {
      context.go('/onboarding');
    }
  }

  Future<void> _activateDemo(WidgetRef ref) async {
    final now = DateTime.now();
    final store = ref.read(databaseProvider);
    await store.setSetting('service_status', 'active');
    await store.setSetting('service_started_at', now.toIso8601String());
    await store.setSetting(
      'service_ends_at',
      now.add(const Duration(days: 30)).toIso8601String(),
    );
    ref.read(demoSessionProvider.notifier).refresh();
  }

  Future<void> _setModeTerik(WidgetRef ref, bool enabled) async {
    await ref
        .read(databaseProvider)
        .setSetting('mode_terik', enabled.toString());
    ref.read(demoSessionProvider.notifier).refresh();
  }
}
