import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

enum AppSurfaceLevel { canvas, surface, raised, sunken }

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.level = AppSurfaceLevel.surface,
    this.padding = EdgeInsets.zero,
    this.borderRadius = AppRadius.card,
  });

  final Widget child;
  final AppSurfaceLevel level;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.bioCycleTheme;
    final color = switch (level) {
      AppSurfaceLevel.canvas => tokens.canvas,
      AppSurfaceLevel.surface => tokens.surface,
      AppSurfaceLevel.raised => tokens.raised,
      AppSurfaceLevel.sunken => tokens.sunken,
    };
    final border = switch (level) {
      AppSurfaceLevel.surface => Border.all(
        color: tokens.isModeTerik
            ? tokens.outline
            : AppColors.ink.withValues(alpha: 0.10),
      ),
      AppSurfaceLevel.sunken => Border.all(color: tokens.outline),
      _ => null,
    };
    final shadows = level == AppSurfaceLevel.raised
        ? [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ]
        : const <BoxShadow>[];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: border,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
