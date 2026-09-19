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
      UnitCondition.unknown => AppColors.dataUnavailable,
    };
    final icon = switch (condition) {
      UnitCondition.optimal => Icons.check,
      UnitCondition.attention => Icons.warning_amber_rounded,
      UnitCondition.critical => Icons.close,
      UnitCondition.unknown => Icons.question_mark,
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
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                condition.label,
                softWrap: true,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
