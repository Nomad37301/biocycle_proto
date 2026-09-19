import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../demo_session/domain/demo_session.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  DemoRole? selectedRole;
  bool saving = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Pilih peran demo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Pilihan ini menentukan pekerjaan dan navigasi yang tampil. Anda dapat menggantinya lagi dari menu akun.',
          ),
          const SizedBox(height: AppSpacing.lg),
          ...DemoRole.values.map(
            (role) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RoleOption(
                role: role,
                selected: selectedRole == role,
                onTap: () => setState(() => selectedRole = role),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSurface(
            level: AppSurfaceLevel.sunken,
            borderRadius: AppRadius.control,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: const Text(
              'Simulasi lokal. Tidak ada perangkat, pembayaran, autentikasi production, atau layanan daring yang dihubungkan.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: selectedRole == null || saving
                ? null
                : () => _finish(selectedRole!),
            child: Text(saving ? 'Menyimpan...' : 'Masuk dengan peran ini'),
          ),
        ],
      ),
    ),
  );

  Future<void> _finish(DemoRole role) async {
    setState(() => saving = true);
    await ref.read(demoSessionProvider.notifier).setRole(role);
    await ref.read(databaseProvider).setSetting('onboarding_complete', 'true');
    if (mounted) context.go('/');
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final DemoRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = switch (role) {
      DemoRole.operator =>
        'Pantau unit BSF, tangani insight, dan catat tindakan SOP.',
      DemoRole.supplier =>
        'Kelola penawaran limbah organik dan respons pengajuan.',
      DemoRole.buyer => 'Catat kebutuhan hasil BSF dan pantau kerja sama.',
    };
    final icon = switch (role) {
      DemoRole.operator => Icons.sensors_outlined,
      DemoRole.supplier => Icons.compost_outlined,
      DemoRole.buyer => Icons.agriculture_outlined,
    };
    return Semantics(
      selected: selected,
      button: true,
      label: '${role.label}. $description',
      child: AppSurface(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon, size: 30, color: AppColors.forest),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(description),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? AppColors.forest : AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
