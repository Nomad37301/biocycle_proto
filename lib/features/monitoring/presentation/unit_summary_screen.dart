import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';

class UnitSummaryScreen extends ConsumerStatefulWidget {
  const UnitSummaryScreen({super.key, required this.unitId});
  final int unitId;

  @override
  ConsumerState<UnitSummaryScreen> createState() => _UnitSummaryScreenState();
}

class _UnitSummaryScreenState extends ConsumerState<UnitSummaryScreen> {
  int hours = 24;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ringkasan operasional')),
    body: ContentWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 24, label: Text('24 jam')),
              ButtonSegment(value: 168, label: Text('7 hari')),
            ],
            selected: {hours},
            onSelectionChanged: (value) => setState(() => hours = value.first),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ref
                .watch(unitSummaryProvider((widget.unitId, hours)))
                .when(
                  loading: () =>
                      const AppLoading(label: 'Menghitung ringkasan...'),
                  error: (_, _) => AppError(
                    message: 'Ringkasan belum dapat dihitung.',
                    onRetry: () => ref.invalidate(
                      unitSummaryProvider((widget.unitId, hours)),
                    ),
                  ),
                  data: (summary) {
                    if (summary == null) {
                      return const EmptyState(
                        icon: Icons.analytics_outlined,
                        title: 'Unit tidak ditemukan',
                        message: 'Data mungkin sudah direset.',
                      );
                    }
                    if (summary.sampleCount == 0) {
                      return const EmptyState(
                        icon: Icons.show_chart,
                        title: 'Belum ada pembacaan',
                        message:
                            'Jalankan simulator untuk mengisi rentang ini.',
                      );
                    }
                    String metric(double? value, String unit) => value == null
                        ? 'Tidak tersedia'
                        : '${value.toStringAsFixed(1)} $unit';
                    return ListView(
                      children: [
                        Text(
                          summary.unit.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${summary.sampleCount} pembacaan, ${DateFormat('dd MMM, HH:mm').format(summary.firstReadingAt!)} sampai ${DateFormat('dd MMM, HH:mm').format(summary.lastReadingAt!)}.',
                        ),
                        const SizedBox(height: 20),
                        _MetricBlock(
                          title: 'Suhu',
                          average: metric(summary.temperatureAverage, '°C'),
                          minimum: metric(summary.temperatureMinimum, '°C'),
                          maximum: metric(summary.temperatureMaximum, '°C'),
                        ),
                        const SizedBox(height: 12),
                        _MetricBlock(
                          title: 'Kelembapan',
                          average: metric(summary.humidityAverage, '%'),
                          minimum: metric(summary.humidityMinimum, '%'),
                          maximum: metric(summary.humidityMaximum, '%'),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.notification_important_outlined,
                            ),
                            title: Text(
                              '${summary.insightCount} insight dimulai',
                            ),
                            subtitle: Text(
                              hours == 24
                                  ? 'Dalam 24 jam terakhir'
                                  : 'Dalam 7 hari terakhir',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Ekspor belum tersedia pada prototipe offline ini.',
                        ),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    ),
  );
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.title,
    required this.average,
    required this.minimum,
    required this.maximum,
  });
  final String title;
  final String average;
  final String minimum;
  final String maximum;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text('Rata-rata $average'),
          Text('Minimum $minimum'),
          Text('Maksimum $maximum'),
        ],
      ),
    ),
  );
}
