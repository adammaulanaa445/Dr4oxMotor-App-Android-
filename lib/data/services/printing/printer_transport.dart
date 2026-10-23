/// Kontrak komunikasi dengan printer.
///
/// Ini adalah **titik integrasi** untuk printer Bluetooth. Saat ini belum
/// ada implementasi Bluetooth di aplikasi ini karena:
///
/// - belum ada perangkat printer yang bisa diuji,
/// - paket Flutter untuk Bluetooth perlu dipilih sesuai perangkat yang
///   akan dipakai (merek/model/versi Android),
/// - aplikasi tidak meminta izin perangkat yang belum diperlukan.
///
/// Cara mengaktifkannya nanti:
/// 1. Implementasikan kelas ini memakai paket Bluetooth yang sesuai
///    (misalnya `bluetooth` atau `bluetooth_low_energy`).
/// 2. Daftarkan izin yang benar di AndroidManifest
///    (BLUETOOTH_CONNECT / BLUETOOTH_SCAN untuk Android 12+).
/// 3. Passthrough `EscPosPrinterService` ke `PrinterNotAvailableService`.
abstract class PrinterTransport {
  /// True bila printer siap dipakai.
  Future<bool> isReady();

  /// Menghubungkan ke printer.
  Future<void> connect();

  /// Mengirim data ke printer.
  Future<void> write(List<int> bytes);

  /// Memutus koneksi.
  Future<void> disconnect();
}

/// Transport yang selalu belum tersedia.
///
/// Dipakai sampai ada printer Bluetooth yang benar-benar bisa diuji.
class UnavailablePrinterTransport implements PrinterTransport {
  const UnavailablePrinterTransport([this.reason = '']);

  /// Alasan kenapa printer belum bisa dipakai.
  final String reason;

  @override
  Future<bool> isReady() async => false;

  @override
  Future<void> connect() async {
    throw StateError(reason.isEmpty
        ? 'Belum ada printer Bluetooth yang terhubung.'
        : reason);
  }

  @override
  Future<void> write(List<int> bytes) async {
    throw StateError(reason.isEmpty
        ? 'Belum ada printer Bluetooth yang terhubung.'
        : reason);
  }

  @override
  Future<void> disconnect() async {}
}
