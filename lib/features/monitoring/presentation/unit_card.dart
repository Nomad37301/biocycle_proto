import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/config/demo_configuration.dart';
import '../../../shared/widgets/freshness_indicator.dart';
import '../../../shared/widgets/metric_value.dart';
import '../../../shared/widgets/status_badge.dart';
import '../domain/telemetry_models.dart';
import 'telemetry_chart.dart';

class UnitCard extends StatelessWidget {
  const UnitCard({
    super.key,
    required this.snapshot,
    this.configuration = const DemoConfiguration(),
  });
  final UnitMonitoringSnapshot snapshot;
  final DemoConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    final unit = snapshot.unit;
    final evaluation = snapshot.evaluation;
    final temperature = _reading(
      evaluation.parameterResults[TelemetryParameterKeys.substrateTemperature],
      snapshot.substrateTemperatureHistory,
    );
    final moisture = _reading(
      evaluation.parameterResults[TelemetryParameterKeys.substrateMoisture],
      snapshot.substrateMoistureHistory,
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => context.push('/units/${unit.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
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
                        style: Theme.of(context).textTheme.titleMedium,
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
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final useColumns =
                      constraints.maxWidth >= 360 && scale <= 1.3;
                  final metrics = [
                    MetricValue(
                      label: 'Suhu substrat',
                      value: temperature.value,
                      unit: '°C',
                      isLastKnown: temperature.isLastKnown,
                      measuredAt: temperature.measuredAt,
                    ),
                    MetricValue(
                      label: 'Kelembapan substrat',
                      value: moisture.value,
                      unit: '%',
                      decimalDigits: 0,
                      isLastKnown: moisture.isLastKnown,
                      measuredAt: moisture.measuredAt,
                    ),
                  ];
                  if (!useColumns) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        metrics.first,
                        const SizedBox(height: AppSpacing.md),
                        metrics.last,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: metrics.first),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: metrics.last),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 64,
                child: TelemetrySparkline(
                  measurements: snapshot.substrateTemperatureHistory,
                  configuration: configuration,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Suhu substrat · 24 jam',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: FreshnessIndicator(
                      state: evaluation.dataState,
                      measuredAt: temperature.measuredAt,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right, size: 22),
                ],
              ),
              if (!evaluation.coverageComplete) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  evaluation.isConfigurationMissing
                      ? 'Konfigurasi monitoring belum tersedia.'
                      : 'Data sebagian. Kondisi aman belum dapat dipastikan.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ({double? value, DateTime? measuredAt, bool isLastKnown}) _reading(
    ParameterEvaluationResult? result,
    List<TelemetryMeasurement> history,
  ) {
    if (result == null) {
      return (value: null, measuredAt: null, isLastKnown: false);
    }
    final current =
        result.dataState == DataState.fresh ||
        result.dataState == DataState.aging;
    if (current) {
      return (
        value: result.value,
        measuredAt: result.measuredAt,
        isLastKnown: false,
      );
    }
    final valid = history.where((sample) => sample.isValid).toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    if (valid.isEmpty) {
      return (value: null, measuredAt: result.measuredAt, isLastKnown: false);
    }
    return (
      value: valid.last.value,
      measuredAt: valid.last.measuredAt,
      isLastKnown: true,
    );
  }
}
