# BioCycle Prototype

Working prototype aplikasi Android untuk pemantauan budidaya Black Soldier Fly (BSF), sistem insight dan rekomendasi berbasis aturan, SOP digital, serta jaringan kemitraan pengolahan limbah organik.

Aplikasi dirancang untuk kebutuhan demonstrasi dan kompetisi inovasi bisnis (IDBIS), berjalan sepenuhnya secara lokal (offline) menggunakan simulasi telemetri dan penyimpanan SQLite tanpa ketergantungan koneksi server eksternal.

---

## Fitur Utama

### 1. Monitoring Unit Budidaya BSF
- **Pemantauan Kondisi Lingkungan**: Memantau suhu (°C), kelembapan relatif (%), status kelembapan media (Kering, Ideal, Terlalu Basah), dan status konektivitas perangkat secara berkala.
- **Grafik Tren Telemetri**: Menampilkan visualisasi riwayat fluktuasi suhu dan kelembapan per unit budidaya menggunakan pustaka `fl_chart`.
- **Indikator Ambang Batas**: Menandai status unit (Optimal, Perhatian, Kritis, Offline) sesuai parameter ideal biokonversi larva BSF.

### 2. Sistem Insight & SOP Digital
- **Deteksi Kondisi Otomatis**: Menghasilkan catatan analisis ketika parameter lingkungan berada di luar ambang batas ideal (misalnya suhu berlebih atau kelembapan tinggi).
- **Rekomendasi Tindakan Cepat**: Memberikan panduan aksi perbaikan langsung (misalnya aktivasi ventilasi/exhaust, pengadukan media, atau penyesuaian pakan).
- **Checklist SOP Terstruktur**: Checklist langkah kerja operasional yang dapat dicentang langsung oleh operator saat melakukan penanganan di lapangan.
- **Pencatatan Riwayat Tindakan**: Menyimpan log tindakan penanganan yang telah diselesaikan ke dalam basis data lokal.

### 3. Simulasi Sensor & Skenario Demo
- **Skenario Langsung dari Header**: Penguji dapat mengubah kondisi telemetri secara instan untuk mengamati respons aplikasi:
  - **Normal**: Kondisi suhu dan kelembapan stabil pada rentang optimal (29 - 31°C, 65 - 75%).
  - **Suhu Meningkat**: Simulasi panas berlebih yang memicu status perhatian/kritis dan rekomendasi pendinginan.
  - **Kelembapan Meningkat**: Simulasi kelembapan tinggi pada kandang dan media biokonversi.
  - **Perangkat Offline**: Simulasi kegagalan koneksi modul telemetri.
- **Notifikasi Lokal**: Mengirim pemberitahuan lokal pada perangkat Android ketika terjadi perubahan status kritis atau rekomendasi baru.
- **Reset Data Demo**: Memungkinkan pengembalian seluruh data transaksi dan pembacaan sensor ke kondisi awal kapan saja melalui menu pengaturan.

### 4. Jaringan Kemitraan (Partner Hub)
Menyediakan simulasi alur kerja sama antara tiga pihak dalam satu basis data:
- **Penyedia Limbah**: Restoran, pasar, atau industri pengolahan makanan yang menawarkan bahan baku limbah organik.
- **Operator BSF**: Fasilitas biokonversi yang membutuhkan pasokan limbah dan memproduksi larva kering/segar serta pupuk kasgot.
- **Pembeli Hasil**: Peternak, perikanan, atau distributor pupuk yang membutuhkan produk turunan BSF.
- **Siklus Pengajuan Terpadu**: Pembuatan listing penawaran/kebutuhan, pengajuan kemitraan, konfirmasi penerimaan, hingga penyelesaian transaksi.

### 5. Multi-Peran Workspace
Pengalih akun cepat pada app bar memungkinkan demonstrator beralih tampilan dan hak akses secara langsung antara Operator BSF, Penyedia Limbah, dan Pembeli Hasil tanpa perlu proses login ulang.

---

## Arsitektur & Teknologi

Proyek ini dibangun menggunakan pendekatan arsitektur per fitur (feature-first) dengan pemisahan tanggung jawab yang jelas:

- **Framework**: Flutter 3 (Dart)
- **State Management**: `flutter_riverpod` (v2.6.1)
- **Routing**: `go_router` (v18.0.1) dengan konfigurasi `StatefulShellRoute` untuk navigasi tab yang persisten
- **Basis Data Lokal**: `sqflite` (v2.4.4) dan `path`
- **Visualisasi Data**: `fl_chart` (v1.2.0)
- **Notifikasi**: `flutter_local_notifications` (v22.3.1)
- **Format Tanggal & Waktu**: `intl` (v0.20.2)

### Struktur Direktori

```text
lib/
├── app/                  # Konfigurasi global aplikasi
│   ├── bootstrap/        # Inisialisasi service dan database sebelum runApp
│   ├── routing/          # Definisi rute, shell navigasi, dan navigasi bawah
│   ├── theme/            # Tema Material 3, palet warna hijau alami, dan tipografi
│   ├── app.dart          # Root widget aplikasi
│   └── app_providers.dart # Provider level global
├── core/                 # Infrastruktur bersama
│   ├── database/         # Helper SQLite, skema tabel, dan seeder data awal
│   └── notifications/    # Service notifikasi lokal Android
├── features/             # Modul fungsional per fitur
│   ├── dashboard/        # Ringkasan operasional dan metrik utama
│   ├── demo_session/     # Kontrol skenario simulasi sensor dan pengalih peran
│   ├── insights/         # Model, repository, dan layar detail insight/SOP
│   ├── monitoring/       # Telemetri unit, pembacaan sensor, dan grafik tren
│   ├── partners/         # Direktori mitra, listing pasar, dan alur pengajuan
│   └── settings/         # Pengaturan tema, profil simulasi, dan reset data
└── shared/               # Komponen UI umum (badge status, wrapper async)
```

---

## Panduan Menjalankan Aplikasi

### Prasyarat
- Flutter SDK versi 3.13.3 atau yang lebih baru
- Android Studio atau VS Code dengan ekstensi Flutter/Dart
- Perangkat Android fisik dengan USB debugging aktif atau Emulator Android (API Level 21+)

### Langkah Instalasi

1. Ambil seluruh dependensi proyek:
   ```bash
   flutter pub get
   ```

2. Jalankan aplikasi pada perangkat/emulator:
   ```bash
   flutter run
   ```

3. Untuk menghasilkan berkas APK release:
   ```bash
   flutter build apk --release
   ```
   Berkas keluaran akan tersedia pada direktori:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## Panduan Demonstrasi Alur Kerja (Demo Walkthrough)

1. **Memeriksa Dashboard & Unit Telemetri**:
   - Buka tab **Monitoring** untuk melihat daftar rak/unit budidaya.
   - Pilih salah satu unit untuk melihat riwayat grafik suhu, kelembapan, serta status media.

2. **Menguji Skenario Simulasi Sensor**:
   - Ketuk ikon sensor pada app bar bagian atas.
   - Ubah skenario dari **Normal** menjadi **Suhu meningkat** atau **Kelembapan meningkat**.
   - Perhatikan perubahan status unit pada layar serta masuknya notifikasi peringatan.
   - Masuk ke tab **Insight** untuk melihat analisis anomali, pelajari rekomendasi tindakan, dan centang SOP perbaikan.

3. **Menguji Siklus Kemitraan**:
   - Beralih ke peran **Penyedia Limbah** melalui menu profil di app bar.
   - Buat penawaran limbah organik baru pada tab **Partner Hub**.
   - Ganti peran menjadi **Operator BSF**, temukan listing limbah tersebut, lalu ajukan permohonan kemitraan.
   - Kembali ke peran **Penyedia Limbah** untuk menyetujui pengajuan, lalu selesaikan transaksi saat limbah telah diterima.

---

## Pengujian & Kualitas Kode

Proyek dilengkapi dengan pengujian unit, logika alur, dan pengujian integrasi:

```bash
# Analisis statis kode
flutter analyze

# Menjalankan seluruh pengujian unit dan kebijakan alur
flutter test

# Menjalankan pengujian integrasi alur aplikasi
flutter test integration_test/app_flow_test.dart
```

Cakupan pengujian mencakup:
- Evaluasi ambang batas parameter sensor (`test/features/monitoring/demo_thresholds_test.dart`)
- Aturan transisi status permintaan kemitraan (`test/features/partners/request_transition_policy_test.dart`)
- Alur navigasi antarlayar utama (`integration_test/app_flow_test.dart`)

---

## Catatan Batasan Prototype

- Data sensor, daftar mitra, dan transaksi yang ditampilkan merupakan data simulasi lokal untuk keperluan demonstrasi fungsional dan validasi konsep bisnis.
- Aplikasi tidak terhubung ke perangkat keras IoT fisik, gateway pembayaran, ataupun sistem perpesanan eksternal. Seluruh logika berjalan mandiri pada penyimpanan perangkat.
