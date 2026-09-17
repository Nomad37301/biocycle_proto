import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/status_badge.dart';
import '../domain/telemetry_models.dart';

class UnitCard extends StatelessWidget {
  const UnitCard({super.key, required this.unit});
  final BsfUnit unit;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/units/${unit.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(unit.kitCode),
                    ],
                  ),
                ),
                StatusBadge(condition: unit.condition),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(
                  icon: Icons.thermostat,
                  value: unit.isConnected
                      ? '${unit.temperature.toStringAsFixed(1)} °C'
                      : 'Tidak tersedia',
                  label: 'Suhu',
                ),
                const SizedBox(width: 12),
                _Metric(
                  icon: Icons.water_drop_outlined,
                  value: unit.isConnected
                      ? '${unit.humidity.toStringAsFixed(0)}%'
                      : 'Tidak tersedia',
                  label: 'Kelembapan',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              unit.isConnected
                  ? 'Diperbarui ${DateFormat('HH:mm').format(unit.updatedAt)} · Media ${unit.medium}'
                  : 'Perangkat tidak terhubung · Pembacaan terakhir disimpan',
            ),
          ],
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(label),
            ],
          ),
        ),
      ],
    ),
  );
}
