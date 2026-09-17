import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../domain/demo_session.dart';

class DemoControls extends ConsumerWidget {
  const DemoControls({super.key});
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const DemoControls(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoSessionProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kontrol skenario',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Skenario mengubah Unit Demo Utama dan berjalan setiap 5 detik saat aplikasi aktif.',
            ),
            const SizedBox(height: 18),
            ...DemoScenario.values.map(
              (scenario) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  selected: state.scenario == scenario,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    state.scenario == scenario
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  title: Text(scenario.label),
                  subtitle: Text(_description(scenario)),
                  onTap: () async {
                    await ref
                        .read(demoSessionProvider.notifier)
                        .setScenario(scenario);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(demoSessionProvider.notifier)
                      .setScenario(DemoScenario.normal);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.restore),
                label: const Text('Pulihkan kondisi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _description(DemoScenario scenario) => switch (scenario) {
    DemoScenario.normal => 'Pembacaan kembali ke rentang demo optimal.',
    DemoScenario.hot => 'Suhu naik bertahap hingga status kritis.',
    DemoScenario.humid => 'Kelembapan naik bertahap hingga status kritis.',
    DemoScenario.offline => 'Perangkat berhenti mengirim pembacaan baru.',
  };
}
