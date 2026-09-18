# Laporan Audit: BioCycle Prototype vs Proposal Bisnis

**Tanggal:** 18 September 2026
**Auditor:** Code Auditor (Claude)
**Scope:** Alur dan fitur, bukan kualitas kode

---

## Ringkasan

Proposal bisnis mendeskripsikan BioCycle sebagai platform **IoT-as-a-Service** dengan tiga pilar utama:

1. **BioCycle Smart Kit** (perangkat IoT untuk mengumpulkan data sensor)
2. **BioCycle Dashboard** (visualisasi kondisi dan riwayat data budidaya)
3. **BioCycle Insight** (peringatan dan panduan tindakan berbasis kondisi)

Ditambah rencana pengembangan lanjutan berupa **BioCycle Partner Network** yang menghubungkan penyedia limbah, operator BSF, dan pembeli hasil.

Prototype sudah mengimplementasikan **semua pilar inti** dan bahkan melampaui scope MVP dengan mengimplementasikan Partner Network. Namun, ada beberapa aspek dari proposal yang belum sepenuhnya tercermin di prototype dan beberapa peluang peningkatan dari segi alur.

---

## A. Temuan: Fitur yang Sudah Terimplementasi dengan Baik

| Komponen Proposal                                | Status           | Keterangan                                                                                                          |
| ------------------------------------------------ | ---------------- | ------------------------------------------------------------------------------------------------------------------- |
| IoT Monitoring (suhu, kelembapan, kondisi media) | ✅ Lengkap       | Simulator lokal menggantikan perangkat IoT. Tiga unit demo dengan skenario normal, panas, lembap, offline.          |
| Dashboard kondisi real-time                      | ✅ Lengkap       | Dashboard operator menampilkan prioritas unit berdasarkan kondisi. Dashboard mitra menampilkan ringkasan pengajuan. |
| Riwayat data sensor                              | ✅ Lengkap       | Grafik riwayat suhu dan kelembapan dengan rentang 1j/6j/24j.                                                        |
| Peringatan dan insight                           | ✅ Lengkap       | Insight otomatis berdasarkan threshold, dengan severity (attention/critical), auto-resolve saat kondisi pulih.      |
| Digital SOP & Decision Support                   | ✅ Lengkap       | SOP tindakan per jenis masalah dengan checklist, catatan, dan riwayat tindakan.                                     |
| Notifikasi                                       | ✅ Lengkap       | Notifikasi Android untuk kondisi baru atau eskalasi severity. Toggle di pengaturan.                                 |
| Partner Network (perencanaan)                    | ✅ Melampaui MVP | Sudah diimplementasikan: direktori mitra, penawaran/kebutuhan, pengajuan kerja sama, transisi status, riwayat.      |
| Multi-role (operator, penyedia, pembeli)         | ✅ Lengkap       | Tiga peran dengan workspace berbeda dan navigasi yang disesuaikan.                                                  |

---

## B. Temuan: Gap antara Proposal dan Implementasi

### B-1. Belum ada alur onboarding atau demo guided tour

**Proposal menyebutkan:** Alur layanan dimulai dengan "instalasi dan konfigurasi Smart Kit" serta "pilot project" untuk membangun kepercayaan.

**Kondisi saat ini:** Pengguna langsung masuk ke dashboard tanpa penjelasan. Tidak ada walkthrough yang menunjukkan bagaimana alur monitoring bekerja atau apa yang bisa dilakukan di setiap tab.

**Dampak:** Untuk keperluan demo ke calon pelanggan (B2B), seorang penilai atau investor yang membuka app pertama kali tidak tahu harus mulai dari mana. Konteks "ini simulasi" hanya muncul sebagai teks kecil di subtitle.

**Saran:** Tambahkan layar onboarding singkat (2-3 langkah) yang menjelaskan tiga pilar BioCycle, atau berikan guided highlights saat pertama kali membuka setiap tab.

---

### B-2. Hanya satu unit yang aktif disimulasikan

**Proposal menyebutkan:** "Perangkat mengumpulkan data kondisi budidaya" (jamak, implisit multi-unit).

**Kondisi saat ini:** Meskipun ada 3 unit demo di database, simulator hanya mengupdate Unit 1 (`recordScenario(1, ...)`). Unit 2 dan Unit 3 tetap statis dengan data seed awal.

**Dampak:** Presentasi demo kurang realistis karena hanya satu unit yang berubah. Penilai mungkin bertanya mengapa unit lain tidak bergerak.

**Saran:** Simulasikan perubahan data di semua unit, meskipun dengan variasi kecil atau skenario berbeda per unit.

---

### B-3. Belum ada representasi "BioCycle Smart Kit" sebagai entitas

**Proposal menyebutkan:** Smart Kit sebagai **perangkat fisik** yang dikirim dan dikonfigurasi. Proposal juga menyebut "maintenance" dan "dukungan teknis" sebagai bagian layanan.

**Kondisi saat ini:** Smart Kit hanya muncul sebagai `kit_code` di model unit (contoh: BCK-001). Tidak ada layar atau alur yang merepresentasikan:

- Status perangkat (firmware version, uptime, last sync)
- Konfigurasi sensor (threshold custom)
- Riwayat maintenance atau laporan gangguan perangkat

**Dampak:** Aspek "as-a-Service" kurang terlihat. Proposal menekankan bahwa BioCycle bukan sekadar penyedia perangkat tapi "mitra teknologi", namun belum ada alur yang menunjukkan lifecycle management perangkat.

**Saran:** Tambahkan section sederhana di detail unit yang menampilkan info perangkat (kode kit, versi firmware placeholder, waktu sinkronisasi terakhir).

---

### B-4. Threshold bersifat statis dan tidak bisa dikonfigurasi

**Proposal menyebutkan:** "Rekomendasi tindakan berdasarkan kondisi yang terdeteksi" dan "decision support."

**Kondisi saat ini:** Threshold untuk suhu (34 C attention, 38 C critical) dan kelembapan (80% attention, 90% critical) di-hardcode di `DemoThresholds`. Tidak ada cara bagi operator untuk menyesuaikan batas ini sesuai fase budidaya (misalnya larva vs prepupa punya kebutuhan suhu berbeda).

**Dampak:** Decision support terlihat kaku dan tidak adaptif terhadap variasi operasional nyata.

**Saran:** Tambahkan pengaturan threshold per unit (meskipun sebagai simulasi), agar terlihat bahwa sistem bisa dikustomisasi sesuai kondisi operasional.

---

### B-5. Belum ada alur "subscription" atau "implementasi awal"

**Proposal menyebutkan:** Model bisnis IoT-as-a-Service dengan biaya implementasi awal dan langganan bulanan (Rp299.000/bulan). Ini adalah inti monetisasi.

**Kondisi saat ini:** Tidak ada representasi apapun tentang status langganan, masa aktif layanan, atau siklus billing. App langsung berjalan tanpa konteks bahwa ini adalah layanan berbayar.

**Dampak:** Untuk demo ke investor, tidak ada yang menunjukkan bahwa ini adalah produk berbayar dengan model SaaS/subscription.

**Saran:** Tambahkan sebuah card sederhana di pengaturan atau dashboard yang menampilkan "Status layanan: Aktif (demo)" dengan informasi paket layanan, tanggal mulai, dan masa aktif.

---

### B-6. Alur "waste-to-process-to-value" belum divisualisasikan secara end-to-end

**Proposal menyebutkan:** Pendekatan "waste-to-process-to-value" yang menghubungkan ketersediaan limbah dengan kebutuhan unit budidaya dan pemanfaatan hasil.

**Kondisi saat ini:** Partner Network sudah mengimplementasikan mekanisme penawaran dan pengajuan, tapi tidak ada visualisasi alur material dari hulu ke hilir. Setiap transaksi berdiri sendiri tanpa konteks rantai nilai yang lebih besar.

**Dampak:** Value proposition utama BioCycle yaitu menjadi "penghubung ekosistem" belum terlihat jelas.

**Saran:** Tambahkan diagram atau ringkasan visual sederhana di dashboard yang menunjukkan alur: Limbah Masuk -> Proses BSF -> Hasil Keluar, dengan jumlah agregat dari transaksi yang sudah selesai.

---

### B-7. Tidak ada fitur pelaporan atau ekspor data

**Proposal menyebutkan:** "Data operasional sulit digunakan untuk evaluasi" sebagai masalah, dan BioCycle hadir untuk membuat data "lebih terukur."

**Kondisi saat ini:** Data sensor dan riwayat insight hanya bisa dilihat di layar, tidak bisa diekspor atau dibuat ringkasan periodik.

**Dampak:** Salah satu value proposition utama adalah "pengelolaan data" tapi tidak ada fitur yang menunjukkan bahwa data bisa digunakan untuk evaluasi jangka panjang.

**Saran:** Tambahkan minimal ringkasan statistik (rata-rata suhu/kelembapan per periode, jumlah insight per minggu) di dashboard atau halaman terpisah.

---

### B-8. Profil mitra sangat minim

**Proposal menyebutkan:** Partner Network yang menghubungkan penyedia limbah, unit BSF, dan pengguna produk.

**Kondisi saat ini:** Profil mitra hanya berisi nama, peran, dan wilayah. Tidak ada informasi kapasitas, jenis limbah yang biasa ditangani, rating, atau track record transaksi.

**Dampak:** Untuk menilai kecocokan mitra, operator hanya bisa melihat daftar penawaran aktif tanpa konteks reputasi atau kapasitas.

**Saran:** Tambahkan informasi ringkasan pada profil mitra: jumlah transaksi selesai, total kg yang sudah berhasil diproses, dan kapan terakhir aktif.

---

## C. Peluang Peningkatan Alur

### C-1. Dashboard operator bisa lebih informatif

**Saat ini:** Dashboard menampilkan jumlah unit dan insight aktif, lalu daftar unit berdasarkan prioritas.

**Saran:** Tambahkan:

- Tren kondisi 24 jam terakhir (berapa kali masuk zona attention/critical)
- Ringkasan tindakan SOP yang belum diselesaikan
- Notifikasi partner yang menunggu respons

Ini menjadikan dashboard sebagai "pusat kendali" yang sesuai dengan positioning proposal.

---

### C-2. Insight belum memiliki mekanisme eskalasi

**Saat ini:** Insight berubah severity dari attention ke critical berdasarkan threshold, tapi tidak ada mekanisme eskalasi jika SOP tidak ditindaklanjuti dalam waktu tertentu.

**Saran:** Tambahkan indikator durasi insight aktif (berapa lama kondisi belum ditangani). Jika sudah melewati batas waktu tertentu, tampilkan peringatan tambahan. Ini memperkuat narasi "decision support."

---

### C-3. Tidak ada mekanisme feedback dari tindakan SOP ke kondisi sensor

**Saat ini:** Operator bisa checklist langkah SOP dan menulis catatan, tapi tidak ada koneksi antara tindakan yang diambil dengan perubahan kondisi sensor.

**Saran:** Saat operator menyimpan tindakan SOP, tampilkan perbandingan kondisi sensor sebelum dan sesudah tindakan (dari riwayat data yang sudah ada). Ini menunjukkan apakah tindakan efektif.

---

### C-4. Alur pengajuan kerja sama bisa ditambahkan tahap negosiasi

**Saat ini:** Pengajuan bersifat binary: kirim, lalu terima/tolak. Penerima tidak bisa melakukan counter-offer (misalnya menyetujui sebagian jumlah).

**Saran:** Tambahkan opsi "Terima sebagian" di mana penerima bisa menyesuaikan jumlah kg sebelum menerima. Ini lebih realistis untuk transaksi B2B.

---

### C-5. Belum ada notifikasi untuk aktivitas Partner Network

**Saat ini:** Notifikasi hanya untuk perubahan kondisi sensor. Pengajuan kerja sama masuk tidak memunculkan notifikasi.

**Saran:** Tambahkan notifikasi saat ada pengajuan masuk, pengajuan diterima/ditolak, atau transaksi diselesaikan. Ini penting untuk alur B2B.

---

### C-6. Pencarian dan filter di beberapa layar bisa diperkuat

**Saat ini:**

- Direktori mitra memiliki search dan filter peran
- Pengajuan memiliki filter arah dan status
- Penawaran tidak memiliki filter (kecuali filter visibility berdasarkan peran)

**Saran:** Tambahkan filter wilayah dan jenis material pada layar penawaran/kebutuhan agar pengguna lebih cepat menemukan peluang yang relevan.

---

### C-7. Tidak ada representasi "pilot project" di alur app

**Proposal menyebutkan:** Strategi pemasaran melalui "pilot program, uji coba terbatas" sebelum berlangganan.

**Saran:** Prototype bisa menambahkan konsep "masa trial" di representasi akun, menunjukkan bahwa model bisnis mendukung uji coba sebelum komitmen berlangganan penuh.

---

## D. Ringkasan Prioritas

| #   | Temuan                                     | Prioritas  | Alasan                                      |
| --- | ------------------------------------------ | ---------- | ------------------------------------------- |
| B-1 | Tidak ada onboarding/guided tour           | **Tinggi** | Krusial untuk demo ke investor/penilai      |
| B-2 | Hanya satu unit yang disimulasikan         | **Tinggi** | Langsung terlihat saat demo                 |
| B-6 | Alur waste-to-value belum divisualisasikan | **Tinggi** | Core value proposition dari proposal        |
| C-1 | Dashboard operator kurang informatif       | **Sedang** | Memperkuat narasi "decision support"        |
| B-4 | Threshold statis                           | **Sedang** | Menunjukkan fleksibilitas sistem            |
| C-5 | Tidak ada notifikasi partner               | **Sedang** | Penting untuk alur B2B                      |
| B-3 | Tidak ada representasi Smart Kit           | **Sedang** | Memperkuat aspek "as-a-Service"             |
| B-5 | Tidak ada representasi subscription        | **Sedang** | Menunjukkan model bisnis                    |
| B-7 | Tidak ada pelaporan/ekspor                 | **Rendah** | Bagus untuk demo tapi bukan blocker         |
| B-8 | Profil mitra minim                         | **Rendah** | Iterasi berikutnya                          |
| C-2 | Belum ada eskalasi waktu pada insight      | **Rendah** | Memperkaya alur tapi bukan kekurangan fatal |
| C-3 | Tidak ada feedback SOP ke sensor           | **Rendah** | Fitur lanjutan                              |
| C-4 | Tidak ada negosiasi pengajuan              | **Rendah** | Fitur lanjutan                              |
| C-6 | Filter penawaran minim                     | **Rendah** | Quality of life                             |
| C-7 | Tidak ada representasi pilot project       | **Rendah** | Konteks tambahan                            |

---

## E. Hal yang Sudah Baik dan Layak Dipertahankan

1. **Tiga peran berbeda** dengan navigasi yang disesuaikan per peran menunjukkan pemahaman terhadap ekosistem yang dijelaskan di proposal.
2. **Alur pengajuan kerja sama yang lengkap** (pending -> accepted -> completed, dengan rejected dan cancelled) menunjukkan transisi status yang realistis.
3. **Policy validation di repository** (cek pasangan peran, duplikasi, sisa kuantitas) menunjukkan bahwa business rules sudah dipertimbangkan.
4. **Empty state, loading state, dan error state** sudah diterapkan secara konsisten di semua layar.
5. **Persistensi data lokal** dengan SQLite memungkinkan demo berjalan tanpa server, sesuai kebutuhan prototype.
6. **Mekanisme reset** memudahkan demonstrasi berulang tanpa install ulang.
7. **Insight dengan auto-resolve** menunjukkan bahwa sistem responsif terhadap perubahan kondisi.
8. **Bahasa Indonesia** di seluruh antarmuka sesuai dengan target pasar lokal.

---

## F. Kesimpulan

Prototype sudah merepresentasikan **inti proposal** dengan baik, bahkan melampaui scope MVP yang disebutkan di proposal (Partner Network sudah diimplementasikan meski direncanakan sebagai tahap lanjutan). Kekurangan utama bersifat **presentasional dan kontekstual**: beberapa value proposition penting dari proposal (waste-to-value chain, IoT-as-a-Service lifecycle, decision support yang adaptif) belum diterjemahkan menjadi elemen yang terlihat di antarmuka. Perbaikan prioritas tinggi (B-1, B-2, B-6) bisa dilakukan dengan effort yang relatif kecil dan akan memberikan dampak besar pada kualitas demo ke calon pelanggan atau penilai kompetisi.
