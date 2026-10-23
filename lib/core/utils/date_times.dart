/// Utilitas waktu untuk penyimpanan di database.
///
/// Semua timestamp disimpan sebagai teks dengan panjang tetap
/// (`YYYY-MM-DDTHH:MM:SS.ffffff`) supaya bisa dibandingkan langsung
/// dengan operator `>` / `<` di SQL maupun di Dart.
class DateTimes {
  const DateTimes._();

  /// Format timestamp dengan panjang tetap.
  static String toIso(DateTime value) {
    final local = value.toLocal();
    return '${_date(local)}T${_time(local)}';
  }

  /// Format tanggal saja (`YYYY-MM-DD`).
  static String toDateOnly(DateTime value) {
    return _date(value.toLocal());
  }

  /// Awal hari (00:00:00) dari tanggal yang diberikan.
  static DateTime startOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Akhir hari (23:59:59.999999) dari tanggal yang diberikan.
  static DateTime endOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day, 23, 59, 59, 999, 999);
  }

  /// Rentang tanggal dalam bentuk teks untuk query SQL.
  static (String, String) rangeOf(DateTime from, DateTime to) {
    return (toIso(startOfDay(from)), toIso(endOfDay(to)));
  }

  static String _date(DateTime d) {
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  static String _time(DateTime d) {
    return '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}.'
        '${d.microsecond.toString().padLeft(6, '0')}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
