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

String formatKg(double value) {
  final rounded = value.roundToDouble();
  return value == rounded
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

double? parseQuantity(String value) {
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  return parsed != null && parsed.isFinite ? parsed : null;
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
    required this.ownerId,
    required this.ownerRole,
    required this.ownerName,
    required this.kind,
    required this.material,
    required this.quantityKg,
    required this.availableKg,
    required this.availableDate,
    required this.region,
    required this.note,
    required this.isActive,
  });
  final int id;
  final int ownerId;
  final DemoRole ownerRole;
  final String ownerName;
  final ListingKind kind;
  final String material;
  final double quantityKg;
  final double availableKg;
  final DateTime availableDate;
  final String region;
  final String note;
  final bool isActive;

  factory PartnerListing.fromMap(Map<String, Object?> map) => PartnerListing(
    id: map['id']! as int,
    ownerId: map['owner_id']! as int,
    ownerRole: DemoRole.values.byName(map['owner_role']! as String),
    ownerName: map['owner_name']! as String,
    kind: ListingKind.values.byName(map['kind']! as String),
    material: map['material']! as String,
    quantityKg: (map['quantity_kg']! as num).toDouble(),
    availableKg: ((map['available_kg'] ?? map['quantity_kg'])! as num)
        .toDouble(),
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
    required this.senderId,
    required this.receiverId,
    required this.completionId,
    required this.senderRole,
    required this.receiverRole,
    required this.senderName,
    required this.receiverName,
    required this.summary,
    required this.quantityKg,
    required this.initialQuantityKg,
    required this.acceptedQuantityKg,
    required this.historyLimited,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  final int id;
  final int listingId;
  final int senderId;
  final int receiverId;
  final int completionId;
  final DemoRole senderRole;
  final DemoRole receiverRole;
  final String senderName;
  final String receiverName;
  final String summary;
  final double quantityKg;
  final double initialQuantityKg;
  final double? acceptedQuantityKg;
  final bool historyLimited;
  double get committedQuantityKg => acceptedQuantityKg ?? quantityKg;
  final String note;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CooperationRequest.fromMap(Map<String, Object?> map) =>
      CooperationRequest(
        id: map['id']! as int,
        listingId: map['listing_id']! as int,
        senderId: map['sender_id']! as int,
        receiverId: map['receiver_id']! as int,
        completionId: map['completion_id']! as int,
        senderRole: DemoRole.values.byName(map['sender_role']! as String),
        receiverRole: DemoRole.values.byName(map['receiver_role']! as String),
        senderName: map['sender_name']! as String,
        receiverName: map['receiver_name']! as String,
        summary: map['summary']! as String,
        quantityKg: (map['quantity_kg']! as num).toDouble(),
        initialQuantityKg:
            ((map['initial_quantity_kg'] ?? map['quantity_kg'])! as num)
                .toDouble(),
        acceptedQuantityKg: (map['accepted_quantity_kg'] as num?)?.toDouble(),
        historyLimited: (map['history_limited'] as int?) == 1,
        note: (map['note'] as String?) ?? '',
        status: RequestStatus.values.byName(map['status']! as String),
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );
}

class PartnerActivitySummary {
  const PartnerActivitySummary({
    required this.completedTransactions,
    required this.totalKg,
    required this.lastActivityAt,
  });
  final int completedTransactions;
  final double totalKg;
  final DateTime? lastActivityAt;
}

class NetworkFlowMetrics {
  const NetworkFlowMetrics({
    required this.wasteInKg,
    required this.outputKg,
    required this.monitoredUnits,
  });
  final double wasteInKg;
  final double outputKg;
  final int monitoredUnits;
}

class AppNotificationEntry {
  const AppNotificationEntry({
    required this.id,
    required this.accountId,
    required this.title,
    required this.body,
    required this.payload,
    required this.createdAt,
  });
  final int id;
  final int accountId;
  final String title;
  final String body;
  final String payload;
  final DateTime createdAt;

  factory AppNotificationEntry.fromMap(Map<String, Object?> map) =>
      AppNotificationEntry(
        id: map['id']! as int,
        accountId: map['account_id']! as int,
        title: map['title']! as String,
        body: map['body']! as String,
        payload: map['payload']! as String,
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

class RequestHistory {
  const RequestHistory({
    required this.id,
    required this.requestId,
    required this.actorId,
    required this.actorName,
    required this.status,
    required this.note,
    required this.createdAt,
  });
  final int id;
  final int requestId;
  final int actorId;
  final String actorName;
  final RequestStatus status;
  final String note;
  final DateTime createdAt;

  factory RequestHistory.fromMap(Map<String, Object?> map) => RequestHistory(
    id: map['id']! as int,
    requestId: map['request_id']! as int,
    actorId: map['actor_id']! as int,
    actorName: map['actor_name']! as String,
    status: RequestStatus.values.byName(map['status']! as String),
    note: (map['note'] as String?) ?? '',
    createdAt: DateTime.parse(map['created_at']! as String),
  );
}

abstract final class RequestTransitionPolicy {
  static bool allows({
    required RequestStatus current,
    required RequestStatus next,
    required int actorId,
    required int senderId,
    required int receiverId,
    required int completionId,
  }) => switch ((current, next)) {
    (RequestStatus.pending, RequestStatus.accepted) ||
    (RequestStatus.pending, RequestStatus.rejected) => actorId == receiverId,
    (RequestStatus.pending, RequestStatus.cancelled) => actorId == senderId,
    (RequestStatus.accepted, RequestStatus.completed) =>
      actorId == completionId,
    _ => false,
  };
}

abstract final class CooperationPolicy {
  static bool allowsPair({
    required ListingKind kind,
    required int listingOwnerId,
    required PartnerProfile sender,
    required PartnerProfile receiver,
  }) => switch (kind) {
    ListingKind.wasteOffer =>
      (sender.role == DemoRole.operator && receiver.id == listingOwnerId) ||
          (sender.id == listingOwnerId && receiver.role == DemoRole.operator),
    ListingKind.outputOffer =>
      sender.role == DemoRole.buyer && receiver.id == listingOwnerId,
    ListingKind.outputNeed =>
      sender.role == DemoRole.operator && receiver.id == listingOwnerId,
  };

  static double remaining(double total, Iterable<double> committed) =>
      (total - committed.fold<double>(0, (sum, value) => sum + value))
          .clamp(0, double.infinity)
          .toDouble();

  static bool validAcceptedQuantity({
    required double requested,
    required double accepted,
    required double available,
  }) =>
      requested.isFinite &&
      accepted.isFinite &&
      available.isFinite &&
      accepted > 0 &&
      accepted <= requested &&
      accepted <= available;
}
