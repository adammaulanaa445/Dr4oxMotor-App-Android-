import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'speech_service.dart';

/// Layanan Text-to-Speech aplikasi berbasis mesin TTS Android.
///
/// TTS dipakai untuk mengumumkan ketika status pengerjaan sebuah transaksi
/// berubah menjadi "Selesai".
///
/// Catatan:
/// - Bahasa diatur ke Indonesia agar pengumuman jelas.
/// - Kegagalan TTS (misal TTS engine tidak terpasang) tidak boleh mengganggu
///   proses penyimpanan transaksi, karena semua error ditangkap di sini.
class TtsService implements SpeechService {
  TtsService._();

  /// Instance tunggal (TTS menggunakan satu channel ke sistem Android).
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _available = true;

  /// True bila layanan TTS berhasil disiapkan.
  bool get isAvailable => _available;

  /// Menyiapkan TTS (bahasa Indonesia, volume & kecepatan wajar).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (error) {
      // Jangan menggagalkan aplikasi hanya karena TTS bermasalah.
      _available = false;
      debugPrint('TTS tidak dapat disiapkan: $error');
    }
  }

  /// Mengucapkan teks. Mengembalikan true bila berhasil.
  @override
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    try {
      await initialize();
      if (!_available) return false;
      await _tts.speak(text);
      return true;
    } catch (error) {
      debugPrint('TTS gagal berbicara: $error');
      return false;
    }
  }

  /// Pengumuman standar saat servis sebuah kendaraan selesai.
  @override
  Future<bool> announceServiceCompleted(String plateNumber) {
    return speak(
      'Servis kendaraan dengan nomor polisi $plateNumber telah selesai.',
    );
  }

  /// Menghentikan pengumuman yang sedang berjalan.
  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (error) {
      debugPrint('TTS gagal dihentikan: $error');
    }
  }
}
