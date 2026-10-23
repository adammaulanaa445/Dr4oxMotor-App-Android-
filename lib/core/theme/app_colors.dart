import 'package:flutter/material.dart';

/// Palet warna resmi aplikasi Dr4ox Motor.
///
/// Semua warna dibuat sebagai `const` supaya aman dipakai di
/// `const` widget maupun di theme Material.
class AppColors {
  const AppColors._();

  /// Latar belakang utama aplikasi.
  static const Color background = Color(0xFF0D0C11);

  /// Permukaan kartu / panel.
  static const Color surface = Color(0xFF1A1922);

  /// Permukaan elevated (dialog, sheet, input yang terangkat).
  static const Color surfaceElevated = Color(0xFF23212C);

  /// Warna aksen merah (tombol utama, penanda penting).
  static const Color accent = Color(0xFFB71C1C);

  /// Aksen merah terang untuk state hover / pressed.
  static const Color accentLight = Color(0xFFE53935);

  /// Teks utama.
  static const Color textPrimary = Color(0xFFF5F5F7);

  /// Teks sekunder (keterangan, label).
  static const Color textSecondary = Color(0xFFA0A0AC);

  /// Garis pemisah.
  static const Color divider = Color(0xFF2E2C38);

  /// Warna status berhasil / lunas.
  static const Color success = Color(0xFF2E7D32);

  /// Warna status menunggu / perlu perhatian.
  static const Color warning = Color(0xFFF9A825);

  /// Warna status informatif / sedang dikerjakan.
  static const Color info = Color(0xFF1565C0);

  /// Warna status dibatalkan.
  static const Color danger = Color(0xFF6D1B1B);
}
