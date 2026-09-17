import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../features/monitoring/domain/telemetry_models.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.condition});
  final UnitCondition condition;

  @override
  Widget build(BuildContext context) {
    final color = switch (condition) {
      UnitCondition.optimal => AppColors.forest,
      UnitCondition.attention => AppColors.warning,
      UnitCondition.critical => AppColors.danger,
      UnitCondition.offline => Colors.blueGrey,
    };
    return Semantics(
      label: 'Status ${condition.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 9, color: color),
            const SizedBox(width: 6),
            Text(
              condition.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
