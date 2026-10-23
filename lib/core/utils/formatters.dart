import 'package:intl/intl.dart';

/// Kumpulan fungsi untuk mengubah angka/tanggal menjadi teks yang enak dibaca.
class Formatters {
  const Formatters._();

  /// Format rupiah tanpa desimal, contoh: `Rp150.000`.
  ///
  /// [value] adalah nilai dalam rupiah penuh (bukan ribuan).
  static String rupiah(num? value) {
    final number = (value ?? 0).toDouble();
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  /// Format rupiah ringkas untuk kartu ringkasan, contoh: `Rp1,5 jt`.
  ///
  /// Nilai di bawah 1.000.000 tetap ditampilkan penuh agar tidak ambigu.
  static String rupiahShort(num? value) {
    final number = (value ?? 0).toDouble();
    if (number.abs() < 1000000) {
      return rupiah(number);
    }
    final juta = number / 1000000;
    final text = juta == juta.roundToDouble()
        ? juta.toStringAsFixed(0)
        : juta.toStringAsFixed(1);
    return 'Rp$text jt';
  }

  /// Format tanggal lengkap, contoh: `21 Oktober 2026`.
  static String tanggal(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('d MMMM yyyy', 'id_ID').format(value);
  }

  /// Format tanggal singkat, contoh: `21/10/2026`.
  static String tanggalPendek(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('dd/MM/yyyy', 'id_ID').format(value);
  }

  /// Format waktu, contoh: `14.05`.
  static String waktu(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('HH.mm', 'id_ID').format(value);
  }

  /// Format tanggal + waktu lengkap, contoh: `21 Okt 2026 14.05`.
  static String tanggalWaktu(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('d MMM yyyy HH:mm', 'id_ID').format(value);
  }

  /// Format ringkas untuk daftar, contoh: `21 Okt 14.05`.
  static String tanggalWaktuPendek(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('d MMM HH:mm', 'id_ID').format(value);
  }

  /// Mengubah nilai menjadi teks dengan pemisah ribuan tanpa simbol mata uang.
  static String angka(num? value) {
    return NumberFormat.decimalPattern('id_ID').format((value ?? 0).round());
  }
}
