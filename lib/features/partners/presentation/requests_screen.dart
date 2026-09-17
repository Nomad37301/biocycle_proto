import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

enum _Direction { all, incoming, outgoing }

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  _Direction direction = _Direction.all;
  RequestStatus? status;

  @override
  Widget build(BuildContext context) {
    final accountId = ref.watch(demoSessionProvider).role.organizationId;
    return ContentWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pengajuan kerja sama',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Buka pengajuan untuk memproses status dan melihat riwayat.',
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_Direction>(
              segments: const [
                ButtonSegment(value: _Direction.all, label: Text('Semua')),
                ButtonSegment(value: _Direction.incoming, label: Text('Masuk')),
                ButtonSegment(
                  value: _Direction.outgoing,
                  label: Text('Keluar'),
                ),
              ],
              selected: {direction},
              onSelectionChanged: (value) =>
                  setState(() => direction = value.first),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<RequestStatus?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua status')),
              ...RequestStatus.values.map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text(value.label)),
              ),
            ],
            onChanged: (value) => setState(() => status = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ref
                .watch(requestsProvider)
                .when(
                  loading: () => const AppLoading(label: 'Memuat pengajuan...'),
                  error: (_, _) => AppError(
                    message: 'Pengajuan gagal dimuat.',
                    onRetry: () => ref.invalidate(requestsProvider),
                  ),
                  data: (all) {
                    final items = all.where((item) {
                      final directionMatches = switch (direction) {
                        _Direction.all => true,
                        _Direction.incoming => item.receiverId == accountId,
                        _Direction.outgoing => item.senderId == accountId,
                      };
                      return directionMatches &&
                          (status == null || item.status == status);
                    }).toList();
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.handshake_outlined,
                        title: 'Tidak ada pengajuan pada filter ini',
                        message: 'Ubah filter atau pilih peluang kerja sama untuk membuat pengajuan.',
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _RequestCard(
                        item: items[index],
                        incoming: items[index].receiverId == accountId,
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, required this.incoming});
  final CooperationRequest item;
  final bool incoming;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/requests/${item.id}'),
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
                _RequestStatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              incoming
                  ? 'Dari ${item.senderName}'
                  : 'Kepada ${item.receiverName}',
            ),
            Text(
              '${formatKg(item.quantityKg)} kg · ${DateFormat('dd MMM, HH:mm').format(item.updatedAt)}',
            ),
          ],
        ),
      ),
    ),
  );
}

class _RequestStatusBadge extends StatelessWidget {
  const _RequestStatusBadge({required this.status});
  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RequestStatus.pending => Colors.orange.shade900,
      RequestStatus.accepted => Colors.blue.shade800,
      RequestStatus.completed => Colors.green.shade800,
      RequestStatus.rejected ||
      RequestStatus.cancelled => Colors.blueGrey.shade700,
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
