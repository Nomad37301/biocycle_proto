import '../../../core/database/app_database.dart';
import '../../demo_session/domain/demo_session.dart';
import '../domain/partner_models.dart';
import '../domain/partner_repository.dart';

class LocalPartnerRepository implements PartnerRepository {
  LocalPartnerRepository(this._store);
  final AppDatabase _store;

  @override
  Future<List<PartnerProfile>> getPartners() async {
    final rows = await _store.database.query('partners', orderBy: 'name');
    return rows.map(PartnerProfile.fromMap).toList();
  }

  @override
  Future<List<PartnerListing>> getListings() async {
    final rows = await _store.database.query(
      'listings',
      orderBy: 'is_active DESC, id DESC',
    );
    return rows.map(PartnerListing.fromMap).toList();
  }

  @override
  Future<List<CooperationRequest>> getRequests(DemoRole role) async {
    final rows = await _store.database.query(
      'requests',
      where: 'sender_role = ? OR receiver_role = ?',
      whereArgs: [role.name, role.name],
      orderBy: 'updated_at DESC',
    );
    return rows.map(CooperationRequest.fromMap).toList();
  }

  @override
  Future<void> createListing({
    required DemoRole ownerRole,
    required ListingKind kind,
    required String material,
    required double quantityKg,
    required DateTime availableDate,
    required String region,
    required String note,
  }) async {
    if (quantityKg <= 0) throw ArgumentError('Jumlah harus lebih dari nol.');
    if (availableDate.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      throw ArgumentError('Tanggal tidak boleh berada di masa lalu.');
    }
    await _store.database.insert('listings', {
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
  Future<void> archiveListing(int id, DemoRole actor) async {
    final count = await _store.database.update(
      'listings',
      {'is_active': 0},
      where: 'id = ? AND owner_role = ?',
      whereArgs: [id, actor.name],
    );
    if (count != 1) {
      throw StateError('Penawaran tidak dapat diarsipkan oleh peran ini.');
    }
  }

  @override
  Future<void> updateListing({
    required int id,
    required DemoRole ownerRole,
    required String material,
    required double quantityKg,
    required DateTime availableDate,
    required String region,
    required String note,
  }) async {
    if (quantityKg <= 0) {
      throw ArgumentError('Jumlah harus lebih dari nol.');
    }
    final count = await _store.database.update(
      'listings',
      {
        'material': material.trim(),
        'quantity_kg': quantityKg,
        'available_date': availableDate.toIso8601String(),
        'region': region.trim(),
        'note': note.trim(),
      },
      where: 'id = ? AND owner_role = ? AND is_active = 1',
      whereArgs: [id, ownerRole.name],
    );
    if (count != 1) {
      throw StateError('Data tidak dapat diubah oleh peran ini.');
    }
  }

  @override
  Future<void> createRequest(
    PartnerListing listing,
    DemoRole sender,
    double quantityKg,
  ) async {
    if (listing.ownerRole == sender) {
      throw StateError('Tidak dapat mengajukan kepada diri sendiri.');
    }
    if (quantityKg <= 0 || quantityKg > listing.quantityKg) {
      throw ArgumentError('Jumlah pengajuan tidak valid.');
    }
    final existing = await _store.database.query(
      'requests',
      where: 'listing_id = ?',
      whereArgs: [listing.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw StateError('Penawaran ini sudah memiliki pengajuan demo.');
    }
    final now = DateTime.now().toIso8601String();
    await _store.database.insert('requests', {
      'listing_id': listing.id,
      'sender_role': sender.name,
      'receiver_role': listing.ownerRole.name,
      'completion_role':
          (listing.kind == ListingKind.outputNeed ? listing.ownerRole : sender)
              .name,
      'sender_name': sender.organization,
      'receiver_name': listing.ownerName,
      'summary': '${listing.kind.label}: ${listing.material}',
      'quantity_kg': quantityKg,
      'status': RequestStatus.pending.name,
      'created_at': now,
      'updated_at': now,
    });
  }

  @override
  Future<void> transitionRequest(
    int id,
    RequestStatus next,
    DemoRole actor,
  ) async {
    final rows = await _store.database.query(
      'requests',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Pengajuan tidak ditemukan.');
    final request = CooperationRequest.fromMap(rows.first);
    final valid = RequestTransitionPolicy.allows(
      current: request.status,
      next: next,
      actor: actor,
      sender: request.senderRole,
      receiver: request.receiverRole,
      completer: request.completionRole,
    );
    if (!valid) {
      throw StateError('Perubahan status tidak diizinkan untuk peran ini.');
    }
    await _store.database.update(
      'requests',
      {'status': next.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
