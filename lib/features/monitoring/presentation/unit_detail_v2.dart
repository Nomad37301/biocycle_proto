import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/formatters/indonesian_formatters.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/freshness_indicator.dart';
import '../../../shared/widgets/metric_value.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../demo_session/presentation/demo_controls.dart';
import '../domain/telemetry_models.dart';
import 'telemetry_chart.dart';

class UnitDetailScreen extends ConsumerStatefulWidget {
  const UnitDetailScreen({super.key, required this.unitId});

  final int unitId;

  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
  int rangeHours = 6;
  String parameterKey = TelemetryParameterKeys.substrateTemperature;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(unitMonitoringProvider(widget.unitId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail unit'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang telemetry',
            onPressed: () {
              ref.read(demoSessionProvider.notifier).refresh();
              ref.invalidate(unitMonitoringProvider(widget.unitId));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: snapshot.when(
          loading: () => const AppLoading(label: 'Memuat detail unit...'),
          error: (_, _) => AppError(
            message: 'Detail unit gagal dimuat. Data terakhir di perangkat tidak diubah.',
            onRetry: () =>
                ref.invalidate(unitMonitoringProvider(widget.unitId)),
          ),
          data: (value) => value == null
              ? const EmptyState(
                  icon: Icons.sensors_off,
                  title: 'Unit tidak ditemukan',
                  message: 'Kembali dan pilih unit yang tersedia.',
                )
              : _content(value),
        ),
      ),
    );
  }

  Widget _content(UnitMonitoringSnapshot snapshot) {
    final unit = snapshot.unit;
    final evaluation = snapshot.evaluation;
    final temperature = evaluation
        .parameterResults[TelemetryParameterKeys.substrateTemperature];
    final moisture =
        evaluation.parameterResults[TelemetryParameterKeys.substrateMoisture];
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(demoSessionProvider.notifier).refresh();
        await ref.read(unitMonitoringProvider(widget.unitId).future);
      },
      child: ListView(
        key: const Key('unit-detail-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    final identity = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${unit.kitCode} · Simulasi lokal',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                    if (constraints.maxWidth < 360 || scale > 1.3) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          identity,
                          const SizedBox(height: AppSpacing.sm),
                          StatusBadge(condition: evaluation.condition),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(condition: evaluation.condition),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                FreshnessIndicator(
                  state: evaluation.dataState,
                  measuredAt: temperature?.measuredAt,
                ),
                if (evaluation.isConfigurationMissing) ...[
                  const SizedBox(height: AppSpacing.md),
                  const _ImpactPanel(
                    icon: Icons.settings_outlined,
                    title: 'Konfigurasi monitoring belum tersedia',
                    message: 'Nilai dapat ditampilkan sebagai pembacaan terakhir, tetapi kondisi tidak dapat dinilai.',
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Substrat', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                AppSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scale = MediaQuery.textScalerOf(context).scale(1);
                      final twoColumns =
                          constraints.maxWidth >= 360 && scale <= 1.3;
                      final children = [
                        MetricValue(
                          label: 'Suhu substrat',
                          value: _displayValue(temperature),
                          unit: '°C',
                          isLastKnown: _isLastKnown(temperature),
                          measuredAt: temperature?.measuredAt,
                        ),
                        MetricValue(
                          label: 'Kelembapan substrat',
                          value: _displayValue(moisture),
                          unit: '%',
                          decimalDigits: 0,
                          isLastKnown: _isLastKnown(moisture),
                          measuredAt: moisture?.measuredAt,
                        ),
                      ];
                      if (!twoColumns) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            children.first,
                            const SizedBox(height: AppSpacing.md),
                            children.last,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: children.first),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(child: children.last),
                        ],
                      );
                    },
                  ),
                ),
                if (evaluation.dataState != DataState.fresh) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _DataImpactPanel(
                    state: evaluation.dataState,
                    onOpenControls: () => DemoControls.show(context),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Udara dan probe pendukung',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ParameterList(evaluation: evaluation),
                const SizedBox(height: AppSpacing.xl),
                _chartHeader(),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(height: 300, child: _chart(unit.name)),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Garis putus tidak diisi. Jeda berarti tidak ada observasi yang dapat dipercaya pada rentang itu.',
                ),
                const SizedBox(height: AppSpacing.xl),
                _kitDetails(snapshot),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/units/${unit.id}/summary'),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Buka ringkasan operasional'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartHeader() => LayoutBuilder(
    builder: (context, constraints) {
      final controls = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: parameterKey,
            decoration: const InputDecoration(labelText: 'Parameter grafik'),
            items: TelemetryParameterKeys.all
                .map(
                  (key) => DropdownMenuItem(
                    value: key,
                    child: Text(TelemetryParameterKeys.label(key)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => parameterKey = value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            initialValue: rangeHours,
            decoration: const InputDecoration(labelText: 'Rentang waktu'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 jam')),
              DropdownMenuItem(value: 6, child: Text('6 jam')),
              DropdownMenuItem(value: 24, child: Text('24 jam')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => rangeHours = value);
            },
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Riwayat telemetry',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Satu parameter per grafik agar satuan dan ambang tidak tercampur.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          controls,
        ],
      );
    },
  );

  Widget _chart(String unitName) => ref
      .watch(
        measurementHistoryProvider((widget.unitId, parameterKey, rangeHours)),
      )
      .when(
        loading: () => AppLoading(
          label: 'Memuat ${TelemetryParameterKeys.label(parameterKey)}...',
        ),
        error: (_, _) => AppError(
          message: 'Riwayat parameter gagal dimuat. Pembacaan terbaru tetap tersedia di atas.',
          onRetry: () => ref.invalidate(
            measurementHistoryProvider((
              widget.unitId,
              parameterKey,
              rangeHours,
            )),
          ),
        ),
        data: (measurements) => TelemetryChart(
          unitName: unitName,
          parameterKey: parameterKey,
          measurements: measurements,
          rangeHours: rangeHours,
          configuration: ref.watch(demoConfigurationProvider),
        ),
      );

  Widget _kitDetails(UnitMonitoringSnapshot snapshot) {
    final device = snapshot.device;
    final earliest = snapshot.substrateTemperatureHistory.isEmpty
        ? null
        : snapshot.substrateTemperatureHistory.first.measuredAt;
    return AppSurface(
      level: AppSurfaceLevel.sunken,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Kit', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _metadata('Kode perangkat', device?.code ?? snapshot.unit.kitCode),
          _metadata(
            'Firmware',
            '${device?.firmware ?? snapshot.unit.firmware} (demo)',
          ),
          _metadata(
            'Koneksi perangkat',
            device?.isConnected == true ? 'Terhubung' : 'Terputus',
          ),
          _metadata(
            'Terakhir terlihat',
            device?.lastSeenAt == null
                ? 'Belum ada'
                : IndonesianFormatters.dateTime(device!.lastSeenAt!),
          ),
          _metadata(
            'Telemetry pertama dalam cakupan',
            earliest == null
                ? 'Belum ada'
                : IndonesianFormatters.dateTime(earliest),
          ),
          _metadata('Probe', 'DHT22, DS18B20, capacitive sensor (simulasi)'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Akurasi belum divalidasi. Metadata ini bukan pairing atau sertifikasi perangkat.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _showKitGuide(snapshot.unit.kitCode),
            icon: const Icon(Icons.help_outline),
            label: const Text('Buka panduan Smart Kit'),
          ),
        ],
      ),
    );
  }

  Widget _metadata(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        );
        if (constraints.maxWidth < 360 || scale > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: AppSpacing.xxs),
              Text(value),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 132, child: labelWidget),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(value)),
          ],
        );
      },
    ),
  );

  Future<void> _showKitGuide(String kitCode) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Panduan $kitCode'),
      content: const Text(
        'Periksa daya, konektor probe, dan posisi sensor. Gunakan kontrol simulasi untuk memulihkan perangkat demo. Panduan ini tidak mengirim tiket dukungan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );

  double? _displayValue(ParameterEvaluationResult? result) => result?.value;

  bool _isLastKnown(ParameterEvaluationResult? result) =>
      result != null &&
      result.dataState != DataState.fresh &&
      result.dataState != DataState.aging &&
      result.value != null;
}

class _ParameterList extends StatelessWidget {
  const _ParameterList({required this.evaluation});

  final UnitEvaluationResult evaluation;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Column(
      children: TelemetryParameterKeys.all.map((key) {
        final result = evaluation.parameterResults[key];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                key.contains('Temperature')
                    ? Icons.thermostat_outlined
                    : Icons.water_drop_outlined,
                color: key.contains('Temperature')
                    ? AppColors.sensorTemperature
                    : AppColors.sensorHumidity,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TelemetryParameterKeys.label(key),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      result?.value == null
                          ? 'Tidak ada pembacaan'
                          : '${IndonesianFormatters.number(result!.value!)} ${TelemetryParameterKeys.unit(key)}',
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    if (result == null)
                      const Text('Belum dievaluasi')
                    else
                      FreshnessIndicator(
                        state: result.dataState,
                        measuredAt: result.measuredAt,
                        compact: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class _DataImpactPanel extends StatelessWidget {
  const _DataImpactPanel({required this.state, required this.onOpenControls});

  final DataState state;
  final VoidCallback onOpenControls;

  @override
  Widget build(BuildContext context) {
    final message = switch (state) {
      DataState.aging => 'Observasi terlambat tetapi masih dapat dinilai. Periksa timestamp sebelum bertindak.',
      DataState.stale => 'Data terlalu lama untuk menilai kondisi saat ini. Pembacaan terakhir tetap ditampilkan sebagai riwayat.',
      DataState.offline => 'Perangkat tidak mengirim observasi baru. Kondisi saat ini belum dapat dinilai.',
      DataState.sensorError => 'Satu atau lebih probe mengirim nilai invalid. Probe lain tetap ditampilkan terpisah.',
      DataState.noData => 'Belum ada observasi untuk parameter wajib. Kondisi aman belum dapat dipastikan.',
      DataState.fresh => '',
    };
    return _ImpactPanel(
      icon: state == DataState.sensorError
          ? Icons.sensors_off_outlined
          : Icons.info_outline,
      title: state.label,
      message: message,
      action: OutlinedButton(
        onPressed: onOpenControls,
        child: const Text('Buka kontrol simulasi'),
      ),
    );
  }
}

class _ImpactPanel extends StatelessWidget {
  const _ImpactPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppSurface(
    level: AppSurfaceLevel.sunken,
    borderRadius: AppRadius.control,
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(message),
        if (action != null) ...[const SizedBox(height: AppSpacing.sm), action!],
      ],
    ),
  );
}
