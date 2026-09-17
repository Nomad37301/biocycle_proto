import 'package:biocycle_proto/features/demo_session/domain/demo_session.dart';
import 'package:biocycle_proto/features/partners/domain/partner_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const supplier = PartnerProfile(
    id: 1,
    name: 'Penyedia',
    role: DemoRole.supplier,
    region: 'Badung',
  );
  const operator = PartnerProfile(
    id: 3,
    name: 'Operator',
    role: DemoRole.operator,
    region: 'Badung',
  );
  const buyer = PartnerProfile(
    id: 4,
    name: 'Pembeli',
    role: DemoRole.buyer,
    region: 'Tabanan',
  );

  test('penawaran limbah dapat dimulai operator maupun penyedia', () {
    expect(
      CooperationPolicy.allowsPair(
        kind: ListingKind.wasteOffer,
        listingOwnerId: supplier.id,
        sender: operator,
        receiver: supplier,
      ),
      isTrue,
    );
    expect(
      CooperationPolicy.allowsPair(
        kind: ListingKind.wasteOffer,
        listingOwnerId: supplier.id,
        sender: supplier,
        receiver: operator,
      ),
      isTrue,
    );
  });

  test('aliran hasil BSF hanya menerima pasangan peran yang benar', () {
    expect(
      CooperationPolicy.allowsPair(
        kind: ListingKind.outputOffer,
        listingOwnerId: operator.id,
        sender: buyer,
        receiver: operator,
      ),
      isTrue,
    );
    expect(
      CooperationPolicy.allowsPair(
        kind: ListingKind.outputNeed,
        listingOwnerId: buyer.id,
        sender: operator,
        receiver: buyer,
      ),
      isTrue,
    );
    expect(
      CooperationPolicy.allowsPair(
        kind: ListingKind.outputOffer,
        listingOwnerId: operator.id,
        sender: supplier,
        receiver: operator,
      ),
      isFalse,
    );
  });

  test('jumlah tersisa tidak pernah negatif', () {
    expect(CooperationPolicy.remaining(100, [25, 30]), 45);
    expect(CooperationPolicy.remaining(10, [12]), 0);
  });

  test('jumlah menerima koma, titik, dan menolak nilai tidak finite', () {
    expect(parseQuantity('12,5'), 12.5);
    expect(parseQuantity('12.5'), 12.5);
    expect(parseQuantity('NaN'), isNull);
    expect(parseQuantity('Infinity'), isNull);
  });
}
