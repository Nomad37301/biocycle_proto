import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final controller = PageController();
  int page = 0;

  static const steps = [
    (
      Icons.sensors,
      'Smart Kit',
      'Tiga unit simulasi mengirim suhu, kelembapan, kondisi media, dan status koneksi setiap 5 detik.',
    ),
    (
      Icons.dashboard_outlined,
      'Dashboard',
      'Pantau prioritas unit dan alur transaksi. Gunakan menu akun untuk berganti peran operator, penyedia, atau pembeli.',
    ),
    (
      Icons.notification_important_outlined,
      'Insight',
      'Kondisi di luar batas membuat insight dan SOP. Semua data prototipe tersimpan lokal di perangkat.',
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _finish, child: const Text('Lewati')),
          ),
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: steps.length,
              onPageChanged: (value) => setState(() => page = value),
              itemBuilder: (context, index) {
                final step = steps[index];
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(step.$1, size: 78, color: AppColors.forest),
                      const SizedBox(height: 28),
                      Text(
                        step.$2,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(step.$3, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      const Text(
                        'Mode simulasi. Tidak ada perangkat, pembayaran, atau layanan daring yang dihubungkan.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Row(
              children: [
                Text('${page + 1} dari ${steps.length}'),
                const Spacer(),
                FilledButton(
                  onPressed: page == steps.length - 1
                      ? _finish
                      : () => controller.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                  child: Text(
                    page == steps.length - 1 ? 'Masuk ke demo' : 'Lanjut',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _finish() async {
    await ref.read(databaseProvider).setSetting('onboarding_complete', 'true');
    if (mounted) context.go('/');
  }
}
