import 'package:biocycle_proto/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pengalih peran dan skenario utama dapat digunakan', (
    tester,
  ) async {
    await app.main();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byTooltip('Akun demo dan pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operator BSF'));
    await tester.pumpAndSettle();

    expect(find.text('Pantau yang perlu tindakan'), findsOneWidget);

    await tester.tap(find.byTooltip('Kontrol skenario sensor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suhu meningkat'));
    await tester.pumpAndSettle();

    expect(find.text('Perlu perhatian'), findsWidgets);
  });
}
