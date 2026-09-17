import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(demoSessionProvider).role;
    return ContentWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pengajuan kerja sama',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('Status dan riwayat diperbarui pada perangkat ini.'),
          const SizedBox(height: 16),
          Expanded(
            child: ref
                .watch(requestsProvider)
                .when(
                  loading: () => const AppLoading(),
                  error: (_, _) => AppError(
                    message: 'Pengajuan gagal dimuat.',
                    onRetry: () => ref.invalidate(requestsProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? const EmptyState(
                          icon: Icons.handshake_outlined,
                          title: 'Belum ada pengajuan',
                          message: 'Pilih penawaran di jaringan mitra untuk memulai kerja sama.',
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _RequestCard(item: items[index], role: role),
                        ),
                ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.item, required this.role});
  final CooperationRequest item;
  final DemoRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = item.receiverRole == role;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.summary,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _Status(status: item.status),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              incoming
                  ? 'Dari ${item.senderName}'
                  : 'Kepada ${item.receiverName}',
            ),
            Text(
              '${item.quantityKg.toStringAsFixed(0)} kg · ${DateFormat('dd MMM, HH:mm').format(item.updatedAt)}',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _actions(context, ref, incoming),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, bool incoming) {
    if (item.status == RequestStatus.pending && incoming) {
      return [
        FilledButton(
          onPressed: () => _transition(context, ref, RequestStatus.accepted),
          child: const Text('Terima'),
        ),
        OutlinedButton(
          onPressed: () => _transition(context, ref, RequestStatus.rejected),
          child: const Text('Tolak'),
        ),
      ];
    }
    if (item.status == RequestStatus.pending && !incoming) {
      return [
        OutlinedButton(
          onPressed: () => _transition(context, ref, RequestStatus.cancelled),
          child: const Text('Batalkan'),
        ),
      ];
    }
    if (item.status == RequestStatus.accepted && role == item.completionRole) {
      return [
        FilledButton(
          onPressed: () => _transition(context, ref, RequestStatus.completed),
          child: const Text('Tandai barang diterima'),
        ),
      ];
    }
    return const [];
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    RequestStatus next,
  ) async {
    try {
      await ref
          .read(partnerRepositoryProvider)
          .transitionRequest(item.id, next, role);
      ref.read(demoSessionProvider.notifier).refresh();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.status});
  final RequestStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RequestStatus.pending => Colors.orange.shade800,
      RequestStatus.accepted => Colors.blue.shade800,
      RequestStatus.completed => Colors.green.shade800,
      RequestStatus.rejected || RequestStatus.cancelled => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
