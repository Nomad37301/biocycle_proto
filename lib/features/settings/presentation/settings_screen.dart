import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';

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
                child: ListTile(
                  minVerticalPadding: 14,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Aktifkan notifikasi'),
                  subtitle: const Text(
                    'Android akan meminta izin untuk menampilkan peringatan kondisi.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _permission(context, ref),
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
                          'asset/ChatGPT Image Aug 30, 2026, 10_03_50 PM.png',
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

  Future<void> _permission(BuildContext context, WidgetRef ref) async {
    final granted = await ref.read(notificationProvider).requestPermission();
    await ref
        .read(databaseProvider)
        .setSetting('notifications_enabled', granted.toString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
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
    await ref.read(demoSessionProvider.notifier).reset();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data awal BioCycle telah dimuat kembali.'),
        ),
      );
    }
  }
}
