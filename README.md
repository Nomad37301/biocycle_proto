# BioCycle App

Working prototype Android untuk monitoring unit budidaya BSF, insight tindakan,
SOP digital, dan kerja sama mitra. Seluruh sensor, unit, serta mitra pada versi
ini merupakan data simulasi dan aplikasi dapat digunakan tanpa internet.

## Menjalankan proyek

```bash
flutter pub get
flutter run
```

Gunakan ikon sensor pada header untuk memilih skenario **Normal**, **Suhu
meningkat**, **Kelembapan meningkat**, atau **Perangkat offline**. Menu akun di
sebelahnya menyediakan pengalih workspace Operator BSF, Penyedia Limbah, dan
Pembeli Hasil.

## Pemeriksaan

```bash
flutter analyze
flutter test
flutter build apk --release
```

APK release dihasilkan pada
`build/app/outputs/flutter-apk/app-release.apk`.

Ruang lingkup, keputusan produk, arsitektur, dan kriteria selesai tersedia di
[`plan.md`](plan.md).
