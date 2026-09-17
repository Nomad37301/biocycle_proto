import '../../demo_session/domain/demo_session.dart';
import 'partner_models.dart';

abstract interface class PartnerRepository {
  Future<List<PartnerProfile>> getPartners();
  Future<List<PartnerListing>> getListings();
  Future<List<CooperationRequest>> getRequests(DemoRole role);
  Future<void> createListing({
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
    required DemoRole ownerRole,
    required String material,
    required double quantityKg,
    required DateTime availableDate,
    required String region,
    required String note,
  });
  Future<void> archiveListing(int id, DemoRole actor);
  Future<void> createRequest(
    PartnerListing listing,
    DemoRole sender,
    double quantityKg,
  );
  Future<void> transitionRequest(int id, RequestStatus next, DemoRole actor);
}
