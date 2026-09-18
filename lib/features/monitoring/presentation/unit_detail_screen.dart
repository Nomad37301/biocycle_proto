import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/status_badge.dart';
import '../domain/telemetry_models.dart';

class UnitDetailScreen extends ConsumerStatefulWidget {
  const UnitDetailScreen({super.key, required this.unitId});
  final int unitId;
  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
  int rangeHours = 6;

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(unitProvider(widget.unitId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail unit')),
      body: unit.when(
        loading: () => const AppLoading(),
        error: (_, _) => AppError(
          message: 'Detail unit gagal dimuat.',
          onRetry: () => ref.invalidate(unitProvider(widget.unitId)),
        ),
        data: (value) => value == null
            ? const EmptyState(
                icon: Icons.sensors_off,
                title: 'Unit tidak ditemukan',
                message: 'Kembali dan pilih unit yang tersedia.',
              )
            : _content(value),
      ),
    );
  }

  Widget _content(BsfUnit unit) => ListView(
    children: [
      ContentWidth(
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
                        unit.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('${unit.kitCode} · Data simulasi'),
                    ],
                  ),
                ),
                StatusBadge(condition: unit.condition),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Kit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Kode perangkat: ${unit.kitCode}'),
                    Text(
                      'Konektivitas: ${unit.isConnected ? 'Terhubung' : 'Offline'}',
                    ),
                    Text(
                      unit.lastSyncedAt == null
                          ? 'Sinkronisasi terakhir: belum ada'
                          : 'Sinkronisasi terakhir: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(unit.lastSyncedAt!)}',
                    ),
                    Text('Firmware: ${unit.firmware} (simulasi)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Reading(
                  label: 'Suhu',
                  value: unit.isConnected
                      ? '${unit.temperature.toStringAsFixed(1)} °C'
                      : 'Tidak tersedia',
                  icon: Icons.thermostat,
                ),
                _Reading(
                  label: 'Kelembapan',
                  value: unit.isConnected
                      ? '${unit.humidity.toStringAsFixed(0)}%'
                      : 'Tidak tersedia',
                  icon: Icons.water_drop_outlined,
                ),
                _Reading(
                  label: 'Kondisi media',
                  value: unit.isConnected ? unit.medium : 'Tidak tersedia',
                  icon: Icons.compost_outlined,
                ),
                _Reading(
                  label: 'Koneksi',
                  value: unit.isConnected ? 'Terhubung' : 'Offline',
                  icon: Icons.wifi,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Batas kondisi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _editThresholds(unit),
                  child: const Text('Ubah batas'),
                ),
              ],
            ),
            Text(
              'Suhu ${unit.thresholds.temperatureAttention.toStringAsFixed(1)} / ${unit.thresholds.temperatureCritical.toStringAsFixed(1)} °C, kelembapan ${unit.thresholds.humidityAttention.toStringAsFixed(0)} / ${unit.thresholds.humidityCritical.toStringAsFixed(0)}%.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/units/${unit.id}/summary'),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Buka ringkasan operasional'),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  'Perubahan sensor',
                  style: Theme.of(context).textTheme.titleLarge,
                );
                final selector = SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1j')),
                    ButtonSegment(value: 6, label: Text('6j')),
                    ButtonSegment(value: 24, label: Text('24j')),
                  ],
                  selected: {rangeHours},
                  onSelectionChanged: (value) =>
                      setState(() => rangeHours = value.first),
                );
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), selector],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    selector,
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Text('Suhu dan kelembapan dalam $rangeHours jam terakhir.'),
            const SizedBox(height: 20),
            SizedBox(height: 250, child: _chart(unit.thresholds)),
            const SizedBox(height: 16),
            const _Legend(),
            const SizedBox(height: 18),
            Text(
              'Pembaruan terakhir ${DateFormat('dd MMM, HH:mm').format(unit.updatedAt)}',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _chart(UnitThresholds thresholds) => ref
      .watch(historyProvider((widget.unitId, rangeHours)))
      .when(
        loading: () => const AppLoading(label: 'Memuat riwayat...'),
        error: (_, _) => AppError(
          message: 'Riwayat sensor gagal dimuat.',
          onRetry: () =>
              ref.invalidate(historyProvider((widget.unitId, rangeHours))),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.show_chart,
              title: 'Belum ada riwayat',
              message: 'Jalankan simulator untuk membuat pembacaan baru.',
            );
          }
          final temperatures = <FlSpot>[];
          final humidities = <FlSpot>[];
          for (var index = 0; index < items.length; index++) {
            temperatures.add(
              FlSpot(index.toDouble(), items[index].temperature),
            );
            humidities.add(FlSpot(index.toDouble(), items[index].humidity));
          }
          return Semantics(
            label: 'Grafik riwayat suhu dan kelembapan',
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 34),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: temperatures,
                    color: AppColors.danger,
                    dotData: const FlDotData(show: false),
                    barWidth: 3,
                  ),
                  LineChartBarData(
                    spots: humidities,
                    color: Colors.blue.shade700,
                    dotData: const FlDotData(show: false),
                    barWidth: 3,
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: thresholds.temperatureAttention,
                      color: AppColors.warning.withValues(alpha: 0.55),
                      dashArray: [6, 4],
                    ),
                    HorizontalLine(
                      y: thresholds.temperatureCritical,
                      color: AppColors.danger.withValues(alpha: 0.55),
                      dashArray: [6, 4],
                    ),
                    HorizontalLine(
                      y: thresholds.humidityAttention,
                      color: AppColors.warning.withValues(alpha: 0.35),
                      dashArray: [3, 5],
                    ),
                    HorizontalLine(
                      y: thresholds.humidityCritical,
                      color: AppColors.danger.withValues(alpha: 0.35),
                      dashArray: [3, 5],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Future<void> _editThresholds(BsfUnit unit) async {
    final values = [
      unit.thresholds.temperatureAttention,
      unit.thresholds.temperatureCritical,
      unit.thresholds.humidityAttention,
      unit.thresholds.humidityCritical,
    ];
    final controllers = values
        .map((value) => TextEditingController(text: value.toStringAsFixed(1)))
        .toList();
    String? error;
    final result = await showDialog<UnitThresholds>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Batas ${unit.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < controllers.length; index++) ...[
                  TextField(
                    controller: controllers[index],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: const [
                        'Suhu perlu perhatian (°C)',
                        'Suhu kritis (°C)',
                        'Kelembapan perlu perhatian (%)',
                        'Kelembapan kritis (%)',
                      ][index],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = controllers
                    .map(
                      (controller) =>
                          double.tryParse(controller.text.replaceAll(',', '.')),
                    )
                    .toList();
                if (parsed.any((value) => value == null || !value.isFinite)) {
                  setDialogState(
                    () => error = 'Semua batas harus berupa angka finite.',
                  );
                  return;
                }
                final thresholds = UnitThresholds(
                  temperatureAttention: parsed[0]!,
                  temperatureCritical: parsed[1]!,
                  humidityAttention: parsed[2]!,
                  humidityCritical: parsed[3]!,
                );
                if (!thresholds.isValid) {
                  setDialogState(
                    () => error = 'Batas perhatian harus di bawah kritis. Kelembapan harus 0 sampai 100%.',
                  );
                  return;
                }
                Navigator.pop(context, thresholds);
              },
              child: const Text('Simpan batas'),
            ),
          ],
        ),
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (result == null || !mounted) return;
    await ref
        .read(demoSessionProvider.notifier)
        .updateThresholds(unit.id, result);
    ref.invalidate(unitProvider(unit.id));
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 155,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 18,
    children: [
      _LegendItem(color: AppColors.danger, label: 'Suhu °C'),
      _LegendItem(color: Colors.blue, label: 'Kelembapan %'),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 18, height: 4, color: color),
      const SizedBox(width: 7),
      Text(label),
    ],
  );
}
