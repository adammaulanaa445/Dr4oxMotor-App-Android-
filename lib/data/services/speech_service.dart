/// Kontrak untuk layanan pengumuman suara.
///
/// Dipisah dari implementasi TTS supaya mudah diuji (tanpa perangkat).
abstract class SpeechService {
  /// Mengucapkan teks. Mengembalikan true bila berhasil.
  Future<bool> speak(String text);

  /// Pengumuman standar saat servis sebuah kendaraan selesai.
  Future<bool> announceServiceCompleted(String plateNumber);

  /// Menghentikan pengumuman yang sedang berjalan.
  Future<void> stop();
}
