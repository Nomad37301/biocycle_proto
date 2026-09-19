import 'package:flutter/material.dart';

import '../../core/formatters/indonesian_formatters.dart';

class MetricValue extends StatelessWidget {
  const MetricValue({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.decimalDigits = 1,
    this.isLastKnown = false,
    this.measuredAt,
  });

  final String label;
  final double? value;
  final String unit;
  final int decimalDigits;
  final bool isLastKnown;
  final DateTime? measuredAt;

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? 'Tidak tersedia'
        : IndonesianFormatters.number(value!, decimalDigits: decimalDigits);
    final semantic = [
      label,
      value == null ? 'tidak tersedia' : '$formatted $unit',
      if (isLastKnown) 'pembacaan terakhir, bukan kondisi saat ini',
      if (measuredAt != null)
        'diukur ${IndonesianFormatters.dateTime(measuredAt!)}',
    ].join(', ');
    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          if (value == null)
            Text(formatted, style: Theme.of(context).textTheme.titleMedium)
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 4,
              runSpacing: 0,
              children: [
                Text(
                  formatted,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          if (isLastKnown) ...[
            const SizedBox(height: 4),
            Text(
              'Pembacaan terakhir',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
