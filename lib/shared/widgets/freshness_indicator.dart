import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/formatters/indonesian_formatters.dart';
import '../../features/monitoring/domain/telemetry_models.dart';

class FreshnessIndicator extends StatelessWidget {
  const FreshnessIndicator({
    super.key,
    required this.state,
    this.measuredAt,
    this.now,
    this.compact = false,
  });

  final DataState state;
  final DateTime? measuredAt;
  final DateTime? now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(state);
    final timestamp = measuredAt == null
        ? null
        : IndonesianFormatters.relativeAge(measuredAt!, now ?? DateTime.now());
    final label = timestamp == null
        ? presentation.label
        : '${presentation.label}, $timestamp';
    return Semantics(
      label: 'Kualitas data: $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(presentation.icon, size: 18, color: presentation.color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              compact || timestamp == null
                  ? presentation.label
                  : '${presentation.label} · $timestamp',
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

({String label, IconData icon, Color color}) _presentation(DataState state) =>
    switch (state) {
      DataState.fresh => (
        label: 'Terkini',
        icon: Icons.schedule_outlined,
        color: AppColors.forest,
      ),
      DataState.aging => (
        label: 'Terlambat',
        icon: Icons.history_toggle_off,
        color: AppColors.conditionAttention,
      ),
      DataState.stale => (
        label: 'Data lama',
        icon: Icons.history_outlined,
        color: AppColors.dataUnavailable,
      ),
      DataState.offline => (
        label: 'Perangkat terputus',
        icon: Icons.link_off,
        color: AppColors.dataUnavailable,
      ),
      DataState.sensorError => (
        label: 'Sensor bermasalah',
        icon: Icons.sensors_off_outlined,
        color: AppColors.conditionCritical,
      ),
      DataState.noData => (
        label: 'Belum ada data',
        icon: Icons.hourglass_empty,
        color: AppColors.dataUnavailable,
      ),
    };
