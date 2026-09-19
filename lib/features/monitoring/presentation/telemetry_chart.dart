import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/config/demo_configuration.dart';
import '../../../core/formatters/indonesian_formatters.dart';
import '../../../shared/widgets/async_content.dart';
import '../domain/telemetry_models.dart';

class TelemetryChartModel {
  const TelemetryChartModel({
    required this.samples,
    required this.segments,
    required this.gapCount,
    required this.minY,
    required this.maxY,
    required this.start,
    required this.end,
  });

  final List<TelemetryMeasurement> samples;
  final List<List<TelemetryMeasurement>> segments;
  final int gapCount;
  final double minY;
  final double maxY;
  final DateTime start;
  final DateTime end;

  factory TelemetryChartModel.build({
    required List<TelemetryMeasurement> measurements,
    required String parameterKey,
    required DemoConfiguration configuration,
  }) {
    final ordered = [...measurements]
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final valid = ordered.where((sample) => sample.isValid).toList();
    final now = DateTime.now().toUtc();
    if (valid.isEmpty) {
      return TelemetryChartModel(
        samples: const [],
        segments: const [],
        gapCount: 0,
        minY: 0,
        maxY: 1,
        start: now,
        end: now,
      );
    }

    final intervals = <int>[];
    for (var index = 1; index < valid.length; index++) {
      final seconds = valid[index].measuredAt
          .difference(valid[index - 1].measuredAt)
          .inSeconds;
      if (seconds > 0) intervals.add(seconds);
    }
    intervals.sort();
    final expectedSeconds = intervals.isEmpty
        ? configuration.simulator.historyInterval.inSeconds
        : intervals[intervals.length ~/ 2];
    final gapSeconds = expectedSeconds * configuration.chart.gapMultiplier;
    final segments = <List<TelemetryMeasurement>>[];
    var current = <TelemetryMeasurement>[];
    var gaps = 0;
    TelemetryMeasurement? previousValid;
    for (final sample in ordered) {
      if (!sample.isValid) {
        if (current.isNotEmpty) segments.add(current);
        current = [];
        previousValid = null;
        gaps++;
        continue;
      }
      if (previousValid != null &&
          sample.measuredAt.difference(previousValid.measuredAt).inSeconds >
              gapSeconds) {
        if (current.isNotEmpty) segments.add(current);
        current = [];
        gaps++;
      }
      current.add(sample);
      previousValid = sample;
    }
    if (current.isNotEmpty) segments.add(current);

    final values = valid.map((sample) => sample.value!).toList();
    final thresholds = _thresholds(parameterKey, configuration);
    final scaleValues = [...values, ...thresholds];
    var lower = scaleValues.reduce(math.min);
    var upper = scaleValues.reduce(math.max);
    final minimumSpan = parameterKey.contains('Temperature')
        ? configuration.chart.minTemperatureSpan
        : configuration.chart.minMoistureSpan;
    if (upper - lower < minimumSpan) {
      final midpoint = (upper + lower) / 2;
      lower = midpoint - minimumSpan / 2;
      upper = midpoint + minimumSpan / 2;
    }
    final padding = math.max(
      (upper - lower) * configuration.chart.paddingRatio,
      minimumSpan * configuration.chart.paddingRatio,
    );
    return TelemetryChartModel(
      samples: valid,
      segments: segments,
      gapCount: gaps,
      minY: lower - padding,
      maxY: upper + padding,
      start: valid.first.measuredAt,
      end: valid.last.measuredAt,
    );
  }
}

class TelemetryChart extends StatelessWidget {
  const TelemetryChart({
    super.key,
    required this.unitName,
    required this.parameterKey,
    required this.measurements,
    required this.rangeHours,
    required this.configuration,
  });

  final String unitName;
  final String parameterKey;
  final List<TelemetryMeasurement> measurements;
  final int rangeHours;
  final DemoConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    final model = TelemetryChartModel.build(
      measurements: measurements,
      parameterKey: parameterKey,
      configuration: configuration,
    );
    if (model.samples.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'Belum ada observasi',
        message: 'Simulator belum merekam nilai valid untuk parameter dan periode ini.',
      );
    }
    final values = model.samples.map((sample) => sample.value!).toList();
    final latest = model.samples.last;
    final semantic = [
      'Grafik ${TelemetryParameterKeys.label(parameterKey)} untuk $unitName',
      'periode $rangeHours jam',
      '${model.samples.length} sampel valid',
      'minimum ${IndonesianFormatters.number(values.reduce(math.min))} ${TelemetryParameterKeys.unit(parameterKey)}',
      'maksimum ${IndonesianFormatters.number(values.reduce(math.max))} ${TelemetryParameterKeys.unit(parameterKey)}',
      '${model.gapCount} jeda data',
      'observasi terakhir ${IndonesianFormatters.number(latest.value!)} ${TelemetryParameterKeys.unit(parameterKey)} pada ${IndonesianFormatters.dateTime(latest.measuredAt)}',
    ].join(', ');
    final duration = model.end.difference(model.start);
    double xOf(TelemetryMeasurement sample) =>
        sample.measuredAt.difference(model.start).inMilliseconds /
        Duration.millisecondsPerMinute;
    final maxX = math.max(1.0, duration.inMilliseconds / 60000);
    final bars = <LineChartBarData>[];
    for (final segment in model.segments) {
      if (segment.length == 1) {
        bars.add(_barFor(context, segment, xOf, latest, configuration));
        continue;
      }
      for (var index = 1; index < segment.length; index++) {
        bars.add(
          _barFor(
            context,
            [segment[index - 1], segment[index]],
            xOf,
            latest,
            configuration,
          ),
        );
      }
    }
    return Semantics(
      label: semantic,
      container: true,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: model.minY,
                maxY: model.maxY,
                clipData: const FlClipData.all(),
                lineBarsData: bars,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.bioCycleTheme.outline.withValues(
                      alpha: 0.45,
                    ),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: context.bioCycleTheme.outline),
                ),
                rangeAnnotations: _rangeAnnotations(
                  parameterKey,
                  configuration,
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxX,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          value < maxX / 2
                              ? IndonesianFormatters.time(model.start)
                              : IndonesianFormatters.time(model.end),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => Text(
                        IndonesianFormatters.number(value),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            '${IndonesianFormatters.number(spot.y)} ${TelemetryParameterKeys.unit(parameterKey)}',
                            Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.bioCycleTheme.surface,
                  border: Border.all(color: context.bioCycleTheme.outline),
                  borderRadius: BorderRadius.circular(AppRadius.status),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    'Terakhir ${IndonesianFormatters.number(latest.value!)} ${TelemetryParameterKeys.unit(parameterKey)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

LineChartBarData _barFor(
  BuildContext context,
  List<TelemetryMeasurement> samples,
  double Function(TelemetryMeasurement) xOf,
  TelemetryMeasurement latest,
  DemoConfiguration configuration,
) {
  final condition = _conditionFor(
    samples.last.parameterKey,
    samples.last.value!,
    configuration,
  );
  final color = switch (condition) {
    ConditionState.optimal => AppColors.forest,
    ConditionState.attention => AppColors.conditionAttention,
    ConditionState.critical => AppColors.conditionCritical,
    ConditionState.unknown =>
      samples.last.parameterKey.contains('Temperature')
          ? AppColors.sensorTemperature
          : AppColors.sensorHumidity,
  };
  return LineChartBarData(
    spots: samples.map((sample) => FlSpot(xOf(sample), sample.value!)).toList(),
    isCurved: false,
    color: color,
    barWidth: 2.5,
    dotData: FlDotData(
      show: true,
      checkToShowDot: (spot, barData) =>
          samples.last.id == latest.id && spot.x == xOf(latest),
    ),
    belowBarData: BarAreaData(show: false),
  );
}

RangeAnnotations _rangeAnnotations(
  String parameterKey,
  DemoConfiguration configuration,
) {
  final ranges = <HorizontalRangeAnnotation>[];
  if (parameterKey == TelemetryParameterKeys.substrateTemperature) {
    ranges.add(
      HorizontalRangeAnnotation(
        y1: configuration.substrateTemperature.optimalMin,
        y2: configuration.substrateTemperature.optimalMax,
        color: AppColors.forest.withValues(alpha: 0.06),
      ),
    );
  } else if (parameterKey == TelemetryParameterKeys.substrateMoisture) {
    ranges.add(
      HorizontalRangeAnnotation(
        y1: configuration.substrateMoisture.optimalMin,
        y2: configuration.substrateMoisture.optimalMax,
        color: AppColors.forest.withValues(alpha: 0.06),
      ),
    );
  }
  return RangeAnnotations(horizontalRangeAnnotations: ranges);
}

List<double> _thresholds(
  String parameterKey,
  DemoConfiguration configuration,
) => switch (parameterKey) {
  TelemetryParameterKeys.substrateTemperature => [
    configuration.substrateTemperature.optimalMin,
    configuration.substrateTemperature.optimalMax,
    configuration.substrateTemperature.attentionMax,
  ],
  TelemetryParameterKeys.substrateMoisture => [
    configuration.substrateMoisture.optimalMin,
    configuration.substrateMoisture.optimalMax,
  ],
  _ => const [],
};

ConditionState _conditionFor(
  String parameterKey,
  double value,
  DemoConfiguration configuration,
) => switch (parameterKey) {
  TelemetryParameterKeys.substrateTemperature =>
    value > configuration.substrateTemperature.criticalMax
        ? ConditionState.critical
        : value > configuration.substrateTemperature.optimalMax ||
              value < configuration.substrateTemperature.optimalMin
        ? ConditionState.attention
        : ConditionState.optimal,
  TelemetryParameterKeys.substrateMoisture =>
    value < configuration.substrateMoisture.optimalMin ||
            value > configuration.substrateMoisture.optimalMax
        ? ConditionState.attention
        : ConditionState.optimal,
  _ => ConditionState.unknown,
};

class TelemetrySparkline extends StatelessWidget {
  const TelemetrySparkline({
    super.key,
    required this.measurements,
    required this.configuration,
  });

  final List<TelemetryMeasurement> measurements;
  final DemoConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    final model = TelemetryChartModel.build(
      measurements: measurements,
      parameterKey: TelemetryParameterKeys.substrateTemperature,
      configuration: configuration,
    );
    if (model.samples.isEmpty) {
      return Center(
        child: Text(
          'Belum ada riwayat 24 jam',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final duration = model.end.difference(model.start);
    double xOf(TelemetryMeasurement sample) =>
        sample.measuredAt.difference(model.start).inMilliseconds /
        Duration.millisecondsPerMinute;
    final latest = model.samples.last;
    final bars = model.segments
        .map((segment) => _barFor(context, segment, xOf, latest, configuration))
        .toList();
    return Semantics(
      label:
          'Sparkline suhu substrat 24 jam, ${model.samples.length} sampel, ${model.gapCount} jeda',
      child: ExcludeSemantics(
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: math.max(1, duration.inMinutes.toDouble()),
            minY: model.minY,
            maxY: model.maxY,
            lineBarsData: bars,
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
          ),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
        ),
      ),
    );
  }
}
