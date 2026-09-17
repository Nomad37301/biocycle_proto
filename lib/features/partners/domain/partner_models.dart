import '../../demo_session/domain/demo_session.dart';

enum ListingKind { wasteOffer, outputOffer, outputNeed }

extension ListingKindLabel on ListingKind {
  String get label => switch (this) {
    ListingKind.wasteOffer => 'Penawaran limbah',
    ListingKind.outputOffer => 'Penawaran hasil BSF',
    ListingKind.outputNeed => 'Kebutuhan hasil BSF',
  };
}

enum RequestStatus { pending, accepted, completed, rejected, cancelled }

extension RequestStatusLabel on RequestStatus {
  String get label => switch (this) {
    RequestStatus.pending => 'Menunggu',
    RequestStatus.accepted => 'Diterima',
    RequestStatus.completed => 'Selesai',
    RequestStatus.rejected => 'Ditolak',
    RequestStatus.cancelled => 'Dibatalkan',
  };
}

class PartnerProfile {
  const PartnerProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.region,
  });
  final int id;
  final String name;
  final DemoRole role;
  final String region;

  factory PartnerProfile.fromMap(Map<String, Object?> map) => PartnerProfile(
    id: map['id']! as int,
    name: map['name']! as String,
    role: DemoRole.values.byName(map['role']! as String),
    region: map['region']! as String,
  );
}

class PartnerListing {
  const PartnerListing({
    required this.id,
    required this.ownerRole,
    required this.ownerName,
    required this.kind,
    required this.material,
    required this.quantityKg,
    required this.availableDate,
    required this.region,
    required this.note,
    required this.isActive,
  });
  final int id;
  final DemoRole ownerRole;
  final String ownerName;
  final ListingKind kind;
  final String material;
  final double quantityKg;
  final DateTime availableDate;
  final String region;
  final String note;
  final bool isActive;

  factory PartnerListing.fromMap(Map<String, Object?> map) => PartnerListing(
    id: map['id']! as int,
    ownerRole: DemoRole.values.byName(map['owner_role']! as String),
    ownerName: map['owner_name']! as String,
    kind: ListingKind.values.byName(map['kind']! as String),
    material: map['material']! as String,
    quantityKg: (map['quantity_kg']! as num).toDouble(),
    availableDate: DateTime.parse(map['available_date']! as String),
    region: map['region']! as String,
    note: map['note']! as String,
    isActive: (map['is_active']! as int) == 1,
  );
}

class CooperationRequest {
  const CooperationRequest({
    required this.id,
    required this.listingId,
    required this.senderRole,
    required this.receiverRole,
    required this.completionRole,
    required this.senderName,
    required this.receiverName,
    required this.summary,
    required this.quantityKg,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  final int id;
  final int listingId;
  final DemoRole senderRole;
  final DemoRole receiverRole;
  final DemoRole completionRole;
  final String senderName;
  final String receiverName;
  final String summary;
  final double quantityKg;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CooperationRequest.fromMap(Map<String, Object?> map) =>
      CooperationRequest(
        id: map['id']! as int,
        listingId: map['listing_id']! as int,
        senderRole: DemoRole.values.byName(map['sender_role']! as String),
        receiverRole: DemoRole.values.byName(map['receiver_role']! as String),
        completionRole: DemoRole.values.byName(
          map['completion_role']! as String,
        ),
        senderName: map['sender_name']! as String,
        receiverName: map['receiver_name']! as String,
        summary: map['summary']! as String,
        quantityKg: (map['quantity_kg']! as num).toDouble(),
        status: RequestStatus.values.byName(map['status']! as String),
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );
}

abstract final class RequestTransitionPolicy {
  static bool allows({
    required RequestStatus current,
    required RequestStatus next,
    required DemoRole actor,
    required DemoRole sender,
    required DemoRole receiver,
    required DemoRole completer,
  }) => switch ((current, next)) {
    (RequestStatus.pending, RequestStatus.accepted) ||
    (RequestStatus.pending, RequestStatus.rejected) => actor == receiver,
    (RequestStatus.pending, RequestStatus.cancelled) => actor == sender,
    (RequestStatus.accepted, RequestStatus.completed) => actor == completer,
    _ => false,
  };
}
