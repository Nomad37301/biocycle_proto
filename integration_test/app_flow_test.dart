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

    if (find.text('Pilih peran demo').evaluate().isNotEmpty) {
      await tester.tap(find.text('Operator BSF'));
      await tester.pump();
      await tester.tap(find.text('Masuk dengan peran ini'));
      await tester.pumpAndSettle();
    } else if (find.text('Pantau yang perlu tindakan').evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Akun demo dan pengaturan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operator BSF'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Pantau yang perlu tindakan'), findsOneWidget);
    await tester.tap(find.byTooltip('Akun demo dan pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengaturan demo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reset demo'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Reset demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset demo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operator BSF'));
    await tester.pump();
    await tester.tap(find.text('Masuk dengan peran ini'));
    await tester.pumpAndSettle();

    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await tester.pump();
    expect(find.text('Pantau yang perlu tindakan'), findsOneWidget);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pump();

    await tester.tap(find.byTooltip('Kontrol skenario sensor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suhu substrat meningkat (Perhatian)'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Perlu perhatian'), findsWidgets);

    await tester.tap(find.text('Unit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit BSF 01 - Rak A').first);
    await tester.pumpAndSettle();
    expect(find.text('Kode perangkat'), findsOneWidget);
    expect(find.text('BCK-001'), findsOneWidget);
    expect(find.text('Firmware'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Akun demo dan pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengaturan demo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Aktifkan demo 30 hari'),
      400,
      scrollable: find.byType(Scrollable).last,
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
    expect(find.text('Pilih peran demo'), findsOneWidget);
    await tester.tap(find.text('Operator BSF'));
    await tester.pump();
    await tester.tap(find.text('Masuk dengan peran ini'));
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

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estimasi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Estimasi berbasis simulasi'), findsOneWidget);
    expect(find.textContaining('bukan laba'), findsOneWidget);
    expect(
      find.textContaining('Bukan pengurangan emisi aktual'),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('pitch-estimate-list')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Salin laporan estimasi'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Laporan estimasi disalin.'), findsOneWidget);
  });
}
