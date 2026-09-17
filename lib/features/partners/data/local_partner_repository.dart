import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';
import '../domain/partner_repository.dart';

class LocalPartnerRepository implements PartnerRepository {
  LocalPartnerRepository(this._store);
  final AppDatabase _store;

  static const _listingSelect = '''
    SELECT l.*,
      MAX(0, l.quantity_kg - COALESCE((
        SELECT SUM(r.quantity_kg) FROM requests r
        WHERE r.listing_id = l.id AND r.status IN ('accepted', 'completed')
      ), 0)) AS available_kg
    FROM listings l''';

  @override
  Future<List<PartnerProfile>> getPartners() async {
    final rows = await _store.database.query('partners', orderBy: 'name');
    return rows.map(PartnerProfile.fromMap).toList();
  }

  @override
  Future<PartnerProfile?> getPartner(int id) async {
    final rows = await _store.database.query(
      'partners',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PartnerProfile.fromMap(rows.first);
  }

  @override
  Future<List<PartnerListing>> getListings() async {
    final rows = await _store.database.rawQuery(
      '$_listingSelect ORDER BY l.is_active DESC, l.id DESC',
    );
    return rows.map(PartnerListing.fromMap).toList();
  }

  @override
  Future<PartnerListing?> getListing(int id) async {
    final rows = await _store.database.rawQuery(
      '$_listingSelect WHERE l.id = ?',
      [id],
    );
    return rows.isEmpty ? null : PartnerListing.fromMap(rows.first);
  }

  @override
  Future<List<CooperationRequest>> getRequests(int organizationId) async {
    final rows = await _store.database.query(
      'requests',
      where: 'sender_id = ? OR receiver_id = ?',
      whereArgs: [organizationId, organizationId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(CooperationRequest.fromMap).toList();
  }

  @override
  Future<CooperationRequest?> getRequest(int id) async {
    final rows = await _store.database.query(
      'requests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CooperationRequest.fromMap(rows.first);
  }

  @override
  Future<List<RequestHistory>> getRequestHistory(int requestId) async {
    final rows = await _store.database.query(
      'request_history',
      where: 'request_id = ?',
      whereArgs: [requestId],
      orderBy: 'created_at, id',
    );
    return rows.map(RequestHistory.fromMap).toList();
  }

  @override
  Future<int> createListing({
    required DemoRole ownerRole,
    required ListingKind kind,
    required String material,
    required double quantityKg,
    required DateTime availableDate,
    required String region,
    required String note,
  }) async {
    _validateListing(material, region, quantityKg, availableDate);
    final expected = switch (ownerRole) {
      DemoRole.supplier => ListingKind.wasteOffer,
      DemoRole.operator => ListingKind.outputOffer,
      DemoRole.buyer => ListingKind.outputNeed,
    };
    if (kind != expected) {
      throw StateError('Jenis data tidak sesuai dengan akun aktif.');
    }
    return _store.database.insert('listings', {
      'owner_id': ownerRole.organizationId,
      'owner_role': ownerRole.name,
      'owner_name': ownerRole.organization,
      'kind': kind.name,
      'material': material.trim(),
      'quantity_kg': quantityKg,
      'available_date': availableDate.toIso8601String(),
      'region': region.trim(),
      'note': note.trim(),
      'is_active': 1,
    });
  }

  @override
  Future<void> updateListing({
    required int id,
    required int ownerId,
    required String material,
    required double quantityKg,
    required DateTime availableDate,
    required String region,
    required String note,
  }) async {
    _validateListing(material, region, quantityKg, availableDate);
    await _store.database.transaction((txn) async {
      final listing = await _loadListing(txn, id);
      if (listing == null || listing.ownerId != ownerId || !listing.isActive) {
        throw StateError('Data tidak dapat diubah oleh akun ini.');
      }
      await _ensureNoOpenRequest(txn, id);
      final committed = await _committedQuantity(txn, id, completedOnly: true);
      if (quantityKg < committed) {
        throw StateError(
          'Jumlah tidak boleh lebih kecil dari transaksi yang selesai.',
        );
      }
      await txn.update(
        'listings',
        {
          'material': material.trim(),
          'quantity_kg': quantityKg,
          'available_date': availableDate.toIso8601String(),
          'region': region.trim(),
          'note': note.trim(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<void> archiveListing(int id, int actorId) async {
    await _store.database.transaction((txn) async {
      final listing = await _loadListing(txn, id);
      if (listing == null || listing.ownerId != actorId || !listing.isActive) {
        throw StateError('Penawaran tidak dapat diarsipkan oleh akun ini.');
      }
      await _ensureNoOpenRequest(txn, id);
      await txn.update(
        'listings',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<int> createRequest({
    required int listingId,
    required int senderId,
    required int receiverId,
    required double quantityKg,
    required String note,
  }) async {
    if (!quantityKg.isFinite || quantityKg <= 0) {
      throw ArgumentError('Jumlah harus lebih dari nol.');
    }
    if (senderId == receiverId) {
      throw StateError('Tidak dapat mengajukan kepada diri sendiri.');
    }
    return _store.database.transaction((txn) async {
      final listing = await _loadListing(txn, listingId);
      if (listing == null || !listing.isActive) {
        throw StateError('Penawaran tidak tersedia.');
      }
      final sender = await _loadPartner(txn, senderId);
      final receiver = await _loadPartner(txn, receiverId);
      if (sender == null || receiver == null) {
        throw StateError('Mitra tidak ditemukan.');
      }
      _validatePair(listing, sender, receiver);
      final duplicate = await txn.query(
        'requests',
        columns: ['id'],
        where: '''listing_id = ? AND status IN ('pending', 'accepted') AND
          ((sender_id = ? AND receiver_id = ?) OR
           (sender_id = ? AND receiver_id = ?))''',
        whereArgs: [listingId, senderId, receiverId, receiverId, senderId],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        throw StateError('Kerja sama aktif untuk pasangan ini sudah ada.');
      }
      final available =
          listing.quantityKg - await _committedQuantity(txn, listingId);
      if (quantityKg > available) {
        throw ArgumentError('Jumlah melebihi sisa ${formatKg(available)} kg.');
      }
      final now = DateTime.now().toIso8601String();
      final completionId = listing.kind == ListingKind.wasteOffer
          ? DemoRole.operator.organizationId
          : DemoRole.buyer.organizationId;
      final id = await txn.insert('requests', {
        'listing_id': listingId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'completion_id': completionId,
        'sender_role': sender.role.name,
        'receiver_role': receiver.role.name,
        'sender_name': sender.name,
        'receiver_name': receiver.name,
        'summary': '${listing.kind.label}: ${listing.material}',
        'quantity_kg': quantityKg,
        'note': note.trim(),
        'status': RequestStatus.pending.name,
        'created_at': now,
        'updated_at': now,
      });
      await _addHistory(
        txn,
        id,
        sender,
        RequestStatus.pending,
        note.trim(),
        now,
      );
      return id;
    });
  }

  @override
  Future<void> transitionRequest({
    required int id,
    required RequestStatus next,
    required int actorId,
    String note = '',
  }) async {
    await _store.database.transaction((txn) async {
      final rows = await txn.query(
        'requests',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Pengajuan tidak ditemukan.');
      final request = CooperationRequest.fromMap(rows.first);
      if (!RequestTransitionPolicy.allows(
        current: request.status,
        next: next,
        actorId: actorId,
        senderId: request.senderId,
        receiverId: request.receiverId,
        completionId: request.completionId,
      )) {
        throw StateError('Perubahan status tidak diizinkan untuk akun ini.');
      }
      if (next == RequestStatus.rejected && note.trim().isEmpty) {
        throw ArgumentError('Alasan penolakan perlu diisi.');
      }
      if (next == RequestStatus.accepted) {
        final listing = await _loadListing(txn, request.listingId);
        if (listing == null || !listing.isActive) {
          throw StateError('Penawaran tidak tersedia.');
        }
        final available =
            listing.quantityKg -
            await _committedQuantity(txn, request.listingId);
        if (request.quantityKg > available) {
          throw StateError('Sisa penawaran tidak lagi mencukupi.');
        }
      }
      final actor = await _loadPartner(txn, actorId);
      if (actor == null) throw StateError('Akun tidak ditemukan.');
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'requests',
        {'status': next.name, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addHistory(txn, id, actor, next, note.trim(), now);
    });
  }

  void _validateListing(
    String material,
    String region,
    double quantity,
    DateTime date,
  ) {
    if (material.trim().isEmpty || region.trim().isEmpty) {
      throw ArgumentError('Jenis material dan wilayah perlu diisi.');
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError('Jumlah harus lebih dari nol.');
    }
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    if (date.isBefore(start)) {
      throw ArgumentError('Tanggal tidak boleh berada di masa lalu.');
    }
  }

  void _validatePair(
    PartnerListing listing,
    PartnerProfile sender,
    PartnerProfile receiver,
  ) {
    final valid = CooperationPolicy.allowsPair(
      kind: listing.kind,
      listingOwnerId: listing.ownerId,
      sender: sender,
      receiver: receiver,
    );
    if (!valid) {
      throw StateError('Pasangan akun tidak sesuai untuk penawaran ini.');
    }
  }

  Future<PartnerListing?> _loadListing(DatabaseExecutor db, int id) async {
    final rows = await db.rawQuery('$_listingSelect WHERE l.id = ?', [id]);
    return rows.isEmpty ? null : PartnerListing.fromMap(rows.first);
  }

  Future<PartnerProfile?> _loadPartner(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'partners',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PartnerProfile.fromMap(rows.first);
  }

  Future<double> _committedQuantity(
    DatabaseExecutor db,
    int listingId, {
    bool completedOnly = false,
  }) async {
    final statuses = completedOnly ? "'completed'" : "'accepted', 'completed'";
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(quantity_kg), 0) AS total FROM requests '
      'WHERE listing_id = ? AND status IN ($statuses)',
      [listingId],
    );
    return (rows.first['total']! as num).toDouble();
  }

  Future<void> _ensureNoOpenRequest(DatabaseExecutor db, int listingId) async {
    final rows = await db.query(
      'requests',
      columns: ['id'],
      where: "listing_id = ? AND status IN ('pending', 'accepted')",
      whereArgs: [listingId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw StateError(
        'Selesaikan pengajuan aktif sebelum mengubah penawaran.',
      );
    }
  }

  Future<void> _addHistory(
    DatabaseExecutor db,
    int requestId,
    PartnerProfile actor,
    RequestStatus status,
    String note,
    String createdAt,
  ) async {
    await db.insert('request_history', {
      'request_id': requestId,
      'actor_id': actor.id,
      'actor_name': actor.name,
      'status': status.name,
      'note': note,
      'created_at': createdAt,
    });
  }
}
