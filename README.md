# Dr4ox Motor

Aplikasi manajemen operasional bengkel motor (Android, 100% offline).

Semua data disimpan di perangkat menggunakan SQLite (`sqflite`). Tidak ada
server, backend, atau layanan cloud.

## Tahap pengerjaan

| Tahap | Isi | Status |
|-------|-----|--------|
| 1 | Pemeriksaan lingkungan & fondasi proyek | Selesai |
| 2 | Database SQLite, model, repository, pengujian otomatis | Selesai |
| 3 | UI utama (navigasi 5 menu) + Dashboard + pelanggan/kendaraan | Selesai |
| 4 | Katalog layanan + alur pembuatan transaksi | Selesai |
| 5 | Inventaris sparepart, pergerakan stok, TTS pengumuman selesai | Selesai |
| 6 | Laporan periode, riwayat pembayaran, pengaturan bengkel | Selesai |
| 7 | Struk di layar, struk PDF, berbagi lewat Share Sheet | Selesai |
| 8 | Persiapan printer (paket ESC/POS & titik integrasi) | Selesai |
| 9 | Titik integrasi printer Bluetooth (transport + profil printer) | Selesai |
| 10 | Pengujian akhir: alur, perhitungan, stok, layar, offline, persistensi | Selesai |

## Alur yang sudah bisa dipakai

1. **Dashboard** - ringkasan operasional (transaksi hari ini, sedang
   dikerjakan, menunggu, belum lunas, pendapatan), transaksi terbaru,
   peringatan stok menipis, tombol transaksi baru, dan menu pengaturan.
2. **Pelanggan** - cari (nama/telepon), tambah, ubah, arsipkan, hapus,
   kelola kendaraan, lihat riwayat transaksi, dan buat transaksi langsung.
3. **Transaksi** - buat transaksi (pelanggan, kendaraan, layanan, sparepart),
   filter per status pengerjaan & pembayaran, buka detail, ubah status,
   catat pembayaran (bisa sebagian), batalkan transaksi, lihat riwayat
   pembayaran, dan **buka struk**.
4. **Sparepart** - daftar & cari, filter stok menipis, tambah/ubah data,
   tambah stok, sesuaikan stok (opname), riwayat pergerakan stok, aktif &
   nonaktifkan.
5. **Laporan** - ringkasan periode (total transaksi, pendapatan, sisa
   tagihan, transaksi batal, total layanan, total sparepart), daftar
   transaksi belum lunas, dan rekap penggunaan sparepart.

## Struk, PDF & berbagi

- Tombol 🧾 pada detail transaksi membuka **struk di layar** dengan gaya
  kertas thermal (putih, mudah dibaca).
- Tombol **Bagikan PDF** membuat berkas PDF struk (ukuran 80mm) lalu membuka
  **Android Share Sheet**. Pilih WhatsApp/Gmail/Bluetooth/penyimpanan
  sendiri. Aplikasi **tidak** mengirim pesan otomatis - pengguna tetap
  memilih penerima dan mengonfirmasi.
- Nama berkas aman: `struk_TRX-20261021-0007.pdf`.

## Fitur khusus

- **Pengumuman suara (TTS)** - saat status pengerjaan berubah menjadi
  "Selesai", aplikasi mengumumkan "Servis kendaraan dengan nomor polisi
  B 1234 ABC telah selesai." Pengumuman hanya terjadi satu kali per
  transaksi, bisa dimatikan di menu **Pengaturan** (ikon roda gigi di
  Dashboard), dan kegagalan TTS tidak pernah mengganggu penyimpanan
  transaksi.
- **Katalog Layanan** - dibuka dari menu Transaksi (ikon label di kanan atas).

## Persiapan printer (Tahap 8 & 9)

Struk disusun sebagai data murni (`ReceiptData`) yang terpisah dari mekanisme
keluaran, sehingga PDF, tampilan layar, dan printer memakai sumber data
yang sama.

```
ReceiptData  (data murni, tanpa import apa pun)
   ├── ReceiptPdfService      -> file PDF (paket pdf)
   └── EscPosPayloadBuilder   -> paket byte ESC/POS
          └── EscPosPrinterService -> memakai PrinterTransport
                 └── UnavailablePrinterTransport (belum ada printer)
```

- `lib/data/services/printing/printer_transport.dart` berisi kontrak
  `PrinterTransport` - **titik integrasi** untuk printer Bluetooth.
  Cara mengaktifkannya nanti: ganti dengan implementasi Bluetooth
  (misalnya paket `bluetooth`), daftarkan izin `BLUETOOTH_CONNECT` /
  `BLUETOOTH_SCAN` di AndroidManifest (Android 12+), lalu teruskan ke
  `EscPosPrinterService`.
- `PrinterProfile` (nama, model, lebar kertas 58/80mm, protokol) disimpan di
  **Pengaturan > Printer thermal**. Lebar kertas menentukan jumlah kolom
  payload ESC/POS (32 kolom untuk 58mm, 42 kolom untuk 80mm).
- **Paket ESC/POS belum diuji pada printer fisik** karena perangkatnya
  belum ada. Tombol "Cetak" selalu menampilkan penjelasan yang jujur, tidak
  pernah mengklaim berhasil. Aplikasi juga **tidak meminta izin Bluetooth**
  yang belum diperlukan.

## Struktur kode

```
lib/
  main.dart                    # Entry point: buka database, siapkan TTS
  app.dart                     # MaterialApp + tema
  core/
    app_dependencies.dart      # Kumpulan repository + status menu aktif
    app_scope.dart             # InheritedWidget untuk akses repository
    tab_refresh_mixin.dart     # Muat ulang data saat menu aktif
    theme/                     # Palet warna & tema gelap
    utils/                     # Format rupiah/tanggal, validasi, helper
  data/
    local/                     # Inisialisasi DB, skema, migrasi, data awal
    models/                    # Struktur data (POCO)
    repositories/              # Semua query & logika bisnis
    services/                  # TTS, pengumuman, PDF, berbagi, cetak, uji data
  features/
    customers/                 # Pelanggan & kendaraan
    services/                  # Katalog layanan servis
    transactions/              # Daftar, form, detail transaksi + picker
    parts/                     # Sparepart, stok, riwayat pergerakan
    reports/                   # Laporan periode
    receipt/                   # Tampilan struk
    settings/                  # Pengaturan bengkel + profil printer
    dashboard/                 # Ringkasan operasional
    devtools/                  # Alat bantu uji data
    home/                      # Kerangka + navigasi 5 menu
  widgets/                     # Komponen UI yang dipakai berulang
```

## Menjalankan aplikasi

```powershell
flutter pub get
flutter run
```

## Menjalankan pengujian otomatis

Pengujian memakai SQLite lokal (`sqflite_common_ffi` in-memory untuk
sebagian besar test, berkas database sungguhan untuk uji persistensi),
sehingga tidak perlu perangkat Android maupun koneksi internet.

```powershell
flutter test
```

Isi pengujian:

| Berkas | Yang diperiksa |
|--------|-----------------|
| `database_test.dart` | Skema, foreign key, relasi, rollback, harga historis |
| `feature_flow_test.dart` | Alur UI: pelanggan, transaksi, katalog layanan |
| `inventory_payment_test.dart` | Stok, pergerakan stok, TTS, pembayaran, laporan |
| `sparepart_reports_test.dart` | Menu sparepart, laporan, pengaturan |
| `receipt_test.dart` | Data struk, PDF valid, paket ESC/POS |
| `receipt_screen_test.dart` | Halaman struk dari detail transaksi |
| `printer_test.dart` | Pemisahan layer & titik integrasi printer |
| `journey_test.dart` | Perjalanan lengkap pelanggan -> struk -> laporan |
| `persistence_test.dart` | Data tetap ada setelah aplikasi ditutup/dibuka |
| `responsive_test.dart` | Tampilan pada 4 ukuran layar HP/tablet |
| `offline_audit_test.dart` | Tidak ada dependensi/izin jaringan |
| `app_logo_test.dart` | Berkas logo & ikon launcher |
| `double_tap_test.dart` | Pengaman klik ganda (pembayaran & transaksi) |

Total 83 pengujian otomatis.

## Pemeriksaan berkala

Untuk memastikan proyek tetap sehat, jalankan:

```powershell
flutter analyze                 # pemeriksaan statis
flutter test                    # 83 pengujian otomatis
dart run tool/check_unused_files.dart   # cek file yang tidak terpakai
```

Membangun versi **release** (23,7 MB) juga berguna untuk menangkap masalah
yang tidak muncul di build debug (AOT, tree-shaking, R8):

```powershell
$env:GRADLE_USER_HOME="D:\GradleHome"
flutter build apk --release
```

## Build APK

Karena drive C: pada komputer ini hampir penuh, cache Gradle diarahkan ke
drive D: lebih dulu:

```powershell
$env:GRADLE_USER_HOME="D:\GradleHome"
$env:TEMP="D:\Temp"; $env:TMP="D:\Temp"
flutter build apk --debug
```

Hasilnya ada di `build\app\outputs\flutter-apk\app-debug.apk`.

## Logo aplikasi

Logo Dr4ox Motor (burung elang) berada di `assets/images/dr4ox_logo.png`.
Ikon launcher Android dan logo di dalam aplikasi **dihasilkan otomatis**
dari berkas tersebut memakai skrip:

```powershell
dart run tool/generate_app_icons.dart
```

Kalau Anda mengganti gambar logo, salin ke
`assets/images/dr4ox_logo.png` lalu jalankan skrip di atas.

## Catatan penting

- **Pendapatan dihitung dari transaksi LUNAS saja.** Transaksi belum dibayar
  dan transaksi batal tidak dihitung sebagai pendapatan.
- **Stok tidak pernah berkurang dua kali.** Transaksi, item, dan perubahan
  stok disimpan dalam satu transaksi database. Bila gagal, semua perubahan
  dibatalkan.
- **Setiap perubahan stok tercatat.** Tambah stok, penyesuaian opname,
  pemakaian transaksi, dan pengembalian karena pembatalan semuanya masuk
  ke riwayat pergerakan stok.
- **Harga historis tersimpan.** Harga layanan/sparepart pada transaksi
  disimpan sebagai snapshot, jadi perubahan harga katalog tidak mengubah
  transaksi lama, termasuk pada struk.
- **Transaksi tidak dihapus permanen.** Transaksi yang batal ditandai
  (`is_cancelled`) dan stok dikembalikan lewat koreksi yang tercatat.
- **Pembayaran sebagian tetap berstatus Belum Dibayar** sampai total
  pembayaran menutup tagihan.
- **Aplikasi tidak butuh internet.** Tidak ada dependensi jaringan maupun
  izin `INTERNET`; semua data ada di perangkat.
