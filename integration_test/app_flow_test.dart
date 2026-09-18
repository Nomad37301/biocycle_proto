import 'package:biocycle_proto/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pengalih peran dan skenario utama dapat digunakan', (
    tester,
  ) async {
    await app.main();
    await tester.pump(const Duration(seconds: 2));

    if (find.text('Lewati').evaluate().isNotEmpty) {
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Pantau yang perlu tindakan'), findsOneWidget);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await tester.pump();
    expect(find.text('Pantau yang perlu tindakan'), findsOneWidget);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pump();

    await tester.tap(find.byTooltip('Kontrol skenario sensor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suhu meningkat'));
    await tester.pumpAndSettle();

    expect(find.text('Perlu perhatian'), findsWidgets);

    await tester.tap(find.text('Unit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit Demo Utama').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Kode perangkat: BCK-001'), findsOneWidget);
    expect(find.textContaining('Firmware:'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ubah batas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan batas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Buka ringkasan operasional'),
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Buka ringkasan operasional'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan operasional'), findsOneWidget);
    expect(find.text('24 jam'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Akun demo dan pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengaturan demo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Aktifkan demo 30 hari'),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Aktifkan demo 30 hari'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Status: aktif'), findsOneWidget);
    await tester.tap(find.text('Reset demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset demo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.text('Data awal BioCycle telah dimuat kembali.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mitra').last);
    await tester.pumpAndSettle();
    final wasteCard = find.ancestor(
      of: find.text('Sisa sayur'),
      matching: find.byType(Card),
    );
    final requestButton = find.descendant(
      of: wasteCard,
      matching: find.widgetWithText(FilledButton, 'Ajukan kerja sama'),
    );
    await tester.ensureVisible(requestButton);
    await tester.pumpAndSettle();
    await tester.tap(requestButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim pengajuan'));
    await tester.pumpAndSettle();
    expect(find.text('Rincian pengajuan'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Akun demo dan pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penyedia Limbah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengajuan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penawaran limbah: Sisa sayur'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Terima sebagian'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Konfirmasi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Diterima oleh'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Akun demo dan pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operator BSF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mitra').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengajuan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penawaran limbah: Sisa sayur'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Konfirmasi barang diterima'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Konfirmasi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selesai oleh'), findsOneWidget);
  });
}
