import '../../demo_session/domain/demo_session.dart';
import 'partner_models.dart';

abstract interface class PartnerRepository {
  Future<List<PartnerProfile>> getPartners();
  Future<PartnerProfile?> getPartner(int id);
  Future<List<PartnerListing>> getListings();
  Future<PartnerListing?> getListing(int id);
  Future<List<CooperationRequest>> getRequests(int organizationId);
  Future<CooperationRequest?> getRequest(int id);
  Future<List<RequestHistory>> getRequestHistory(int requestId);
  Future<PartnerActivitySummary> getPartnerActivity(int partnerId);
  Future<NetworkFlowMetrics> getNetworkFlow();
  Future<List<AppNotificationEntry>> takePendingNotifications(int accountId);
  Future<int> createListing({
    required DemoRole ownerRole,
    required ListingKind kind,
    required String material,
    required double quantityKg,
    required DateTime availableDate,
    required String region,
    required String note,
  });
  Future<void> updateListing({
    required int id,
    required int ownerId,
    required String material,
    required double quantityKg,
    required DateTime availableDate,
    required String region,
    required String note,
  });
  Future<void> archiveListing(int id, int actorId);
  Future<int> createRequest({
    required int listingId,
    required int senderId,
    required int receiverId,
    required double quantityKg,
    required String note,
  });
  Future<void> transitionRequest({
    required int id,
    required RequestStatus next,
    required int actorId,
    String note = '',
    double? acceptedQuantityKg,
  });
}
