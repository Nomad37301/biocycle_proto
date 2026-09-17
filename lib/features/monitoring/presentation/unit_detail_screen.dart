import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
                    'Perubahan sensor',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1j')),
                    ButtonSegment(value: 6, label: Text('6j')),
                    ButtonSegment(value: 24, label: Text('24j')),
                  ],
                  selected: {rangeHours},
                  onSelectionChanged: (value) =>
                      setState(() => rangeHours = value.first),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Suhu dan kelembapan dalam $rangeHours jam terakhir.'),
            const SizedBox(height: 20),
            SizedBox(height: 250, child: _chart()),
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

  Widget _chart() => ref
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
              ),
            ),
          );
        },
      );
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
