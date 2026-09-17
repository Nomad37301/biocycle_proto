import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final int requestId;

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  bool updating = false;

  @override
  Widget build(BuildContext context) {
    final accountId = ref.watch(demoSessionProvider).role.organizationId;
    return Scaffold(
      appBar: AppBar(title: const Text('Rincian pengajuan')),
      body: ref
          .watch(requestProvider(widget.requestId))
          .when(
            loading: () => const AppLoading(label: 'Memuat pengajuan...'),
            error: (_, _) => AppError(
              message: 'Pengajuan gagal dimuat.',
              onRetry: () => ref.invalidate(requestProvider(widget.requestId)),
            ),
            data: (item) {
              if (item == null ||
                  (item.senderId != accountId &&
                      item.receiverId != accountId)) {
                return EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Pengajuan tidak dapat dibuka',
                  message: 'Data mungkin sudah direset atau tidak terkait dengan akun aktif.',
                  action: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Kembali'),
                  ),
                );
              }
              return _content(item, accountId);
            },
          ),
    );
  }

  Widget _content(CooperationRequest item, int accountId) => ListView(
    children: [
      ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.summary,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('${formatKg(item.quantityKg)} kg'),
            Text('Dari ${item.senderName}'),
            Text('Kepada ${item.receiverName}'),
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Catatan awal: ${item.note}'),
            ],
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/listings/${item.listingId}'),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Buka penawaran terkait'),
            ),
            const SizedBox(height: 20),
            _actions(item, accountId),
            const SizedBox(height: 28),
            Text(
              'Riwayat status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _history(),
          ],
        ),
      ),
    ],
  );

  Widget _actions(CooperationRequest item, int accountId) {
    final actions = <Widget>[];
    if (item.status == RequestStatus.pending && item.receiverId == accountId) {
      actions.addAll([
        FilledButton(
          onPressed: updating
              ? null
              : () => _confirmTransition(item, RequestStatus.accepted),
          child: const Text('Terima pengajuan'),
        ),
        OutlinedButton(
          onPressed: updating ? null : () => _reject(item),
          child: const Text('Tolak'),
        ),
      ]);
    } else if (item.status == RequestStatus.pending &&
        item.senderId == accountId) {
      actions.add(
        OutlinedButton(
          onPressed: updating
              ? null
              : () => _confirmTransition(item, RequestStatus.cancelled),
          child: const Text('Batalkan pengajuan'),
        ),
      );
    } else if (item.status == RequestStatus.accepted &&
        item.completionId == accountId) {
      actions.add(
        FilledButton(
          onPressed: updating
              ? null
              : () => _confirmTransition(item, RequestStatus.completed),
          child: const Text('Konfirmasi barang diterima'),
        ),
      );
    }
    if (actions.isEmpty) {
      return Text(
        'Status saat ini: ${item.status.label}. Tidak ada tindakan yang perlu dilakukan akun ini.',
      );
    }
    return Wrap(spacing: 10, runSpacing: 10, children: actions);
  }

  Widget _history() => ref
      .watch(requestHistoryProvider(widget.requestId))
      .when(
        loading: () => const AppLoading(label: 'Memuat riwayat...'),
        error: (_, _) => AppError(
          message: 'Riwayat status gagal dimuat.',
          onRetry: () =>
              ref.invalidate(requestHistoryProvider(widget.requestId)),
        ),
        data: (items) => Column(
          children: items
              .map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text('${entry.status.label} oleh ${entry.actorName}'),
                  subtitle: Text(
                    [
                      DateFormat('dd MMM yyyy, HH:mm').format(entry.createdAt),
                      if (entry.note.isNotEmpty) entry.note,
                    ].join('\n'),
                  ),
                ),
              )
              .toList(),
        ),
      );

  Future<void> _confirmTransition(
    CooperationRequest item,
    RequestStatus next,
  ) async {
    final label = switch (next) {
      RequestStatus.accepted => 'menerima pengajuan',
      RequestStatus.cancelled => 'membatalkan pengajuan',
      RequestStatus.completed => 'mengonfirmasi barang sudah diterima',
      _ => 'mengubah status',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi tindakan'),
        content: Text('Anda akan $label.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _transition(next);
  }

  Future<void> _reject(CooperationRequest item) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak pengajuan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alasan penolakan',
            hintText: 'Jelaskan alasan agar mitra dapat memperbaiki pengajuan.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Tolak pengajuan'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    controller.dispose();
    if (!mounted) return;
    if (reason != null) await _transition(RequestStatus.rejected, note: reason);
  }

  Future<void> _transition(RequestStatus next, {String note = ''}) async {
    setState(() => updating = true);
    try {
      await ref
          .read(partnerRepositoryProvider)
          .transitionRequest(
            id: widget.requestId,
            next: next,
            actorId: ref.read(demoSessionProvider).role.organizationId,
            note: note,
          );
      ref.read(partnerRevisionProvider.notifier).state++;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status gagal diperbarui: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }
}
