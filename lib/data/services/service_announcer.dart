import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/service_transaction.dart';
import '../repositories/settings_repository.dart';
import '../repositories/transaction_repository.dart';
import 'speech_service.dart';
import 'tts_service.dart';

/// Mengatur pengumuman TTS saat status pengerjaan berubah menjadi Selesai.
///
/// Aturan:
/// - Pengumuman hanya terjadi **saat status benar-benar berubah** menjadi
///   `Selesai` (bukan saat halaman dibuka atau di-refresh).
/// - Satu transaksi hanya diumumkan **satu kali** (ditandai di database
///   dengan `tts_announced_at`), sehingga tidak ada pengumuman berulang.
/// - Pengumuman dapat dimatikan lewat pengaturan bengkel.
class ServiceAnnouncer {
  ServiceAnnouncer({
    required this.transactions,
    required this.settings,
    SpeechService? speech,
  }) : _speech = speech ?? TtsService.instance;

  final TransactionRepository transactions;
  final SettingsRepository settings;
  final SpeechService _speech;

  /// Transaksi yang sedang diumumkan (mencegah pengumuman ganda ketika
  /// tombol ditekan berulang kali dengan cepat).
  static final Set<int> _inProgress = {};

  /// Mengumumkan bila perlu.
  ///
  /// [previousStatus] adalah status pengerjaan sebelum perubahan,
  /// [updated] adalah transaksi setelah perubahan status disimpan.
  Future<bool> announceIfNeeded({
    required WorkStatus? previousStatus,
    required ServiceTransaction updated,
  }) async {
    // Hanya saat berubah dari status lain menjadi Selesai.
    if (updated.workStatus != WorkStatus.selesai) return false;
    if (previousStatus == WorkStatus.selesai) return false;

    // Sudah pernah diumumkan untuk transaksi ini.
    if (updated.ttsAnnouncedAt != null) return false;

    // Pengumuman dimatikan oleh pengguna.
    final workshopSettings = await settings.load();
    if (!workshopSettings.ttsEnabled) return false;

    final id = updated.id;
    if (id == null) return false;
    if (_inProgress.contains(id)) return false;
    _inProgress.add(id);

    try {
      final spoken = await _speech.announceServiceCompleted(updated.plateNumber);
      if (spoken) {
        // Tandai agar tidak diulang pada perubahan status berikutnya.
        await transactions.markTtsAnnounced(id);
        debugPrint('Pengumuman TTS: servis ${updated.plateNumber} selesai');
      }
      return spoken;
    } catch (error) {
      debugPrint('Pengumuman TTS gagal: $error');
      return false;
    } finally {
      _inProgress.remove(id);
    }
  }
}
