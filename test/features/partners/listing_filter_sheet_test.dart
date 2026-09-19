import 'package:biocycle_proto/app/app_providers.dart';
import 'package:biocycle_proto/app/theme/app_theme.dart';
import 'package:biocycle_proto/features/demo_session/domain/demo_session.dart';
import 'package:biocycle_proto/features/partners/domain/partner_models.dart';
import 'package:biocycle_proto/features/partners/presentation/listings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filter sheet memisahkan draft, Batal, Terapkan, dan Reset', (
    tester,
  ) async {
    final listing = PartnerListing(
      id: 1,
      ownerId: DemoRole.supplier.organizationId,
      ownerRole: DemoRole.supplier,
      ownerName: 'Mitra Demo',
      kind: ListingKind.wasteOffer,
      material: 'Sisa sayur',
      quantityKg: 500,
      availableKg: 500,
      availableDate: DateTime(2026, 9, 20),
      region: 'Badung',
      note: '',
      isActive: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listingsProvider.overrideWith((ref) async => [listing]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: ListingsScreen(
              ownedOnly: false,
              roleOverride: DemoRole.operator,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter katalog'));
    await tester.pumpAndSettle();
    expect(find.text('Reset filter'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Filter katalog'), findsOneWidget);

    await tester.tap(find.text('Filter katalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua wilayah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Badung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(find.text('Filter (1)'), findsOneWidget);

    await tester.tap(find.text('Filter (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset filter'));
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(find.text('Filter katalog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
