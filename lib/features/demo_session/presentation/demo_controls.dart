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
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kontrol simulasi & skenario',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih satu unit untuk skenario deterministik. Unit lain tetap diperbarui otomatis setiap 5 detik.',
              ),
              const SizedBox(height: 18),
              ref
                  .watch(unitsProvider)
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Daftar unit gagal dimuat.'),
                    data: (units) => DropdownButtonFormField<int>(
                      initialValue: state.selectedUnitId,
                      decoration: const InputDecoration(
                        labelText: 'Unit target skenario',
                      ),
                      items: units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(demoSessionProvider.notifier)
                              .setSelectedUnit(value);
                        }
                      },
                    ),
                  ),
              const SizedBox(height: 14),
              ...DemoScenario.values.map(
                (scenario) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    await ref
                        .read(demoSessionProvider.notifier)
                        .fastForward15Minutes();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Waktu simulasi dipercepat 15 menit untuk evaluasi SOP.',
                          ),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.fast_forward),
                  label: const Text('Percepat waktu (+15 menit SOP)'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(demoSessionProvider.notifier)
                        .setScenario(DemoScenario.recovery);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Pulihkan kondisi (Recovery)'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(demoSessionProvider.notifier)
                      .toggleManualPause(),
                  icon: Icon(
                    state.manuallyPaused ? Icons.play_arrow : Icons.pause,
                  ),
                  label: Text(
                    state.manuallyPaused
                        ? 'Lanjutkan simulator'
                        : 'Jeda simulator',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _description(DemoScenario scenario) => switch (scenario) {
    DemoScenario.normal =>
      'Suhu substrat 30 °C, kelembapan 65%, kondisi optimal.',
    DemoScenario.thermalAttention =>
      'Suhu substrat meningkat ke 36 °C (perlu perhatian).',
    DemoScenario.thermalCritical =>
      'Suhu substrat kritis naik ke 39 °C (melewati 38 °C).',
    DemoScenario.substrateWet =>
      'Kelembapan substrat 85% (terlalu basah, perlu dedak).',
    DemoScenario.substrateDry =>
      'Kelembapan substrat 45% (terlalu kering, perlu cairan).',
    DemoScenario.deviceOffline =>
      'Perangkat terputus; berhenti menulis observasi baru.',
    DemoScenario.sensorError =>
      'Sensor substrat invalid/error; sensor lain tetap normal.',
    DemoScenario.recovery =>
      'Perangkat terhubung kembali dan membaca kondisi normal.',
  };
}
