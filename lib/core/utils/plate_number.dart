/// Utilitas untuk merapikan nomor polisi (mis. `b 1234 abc` -> `B 1234 ABC`).
class PlateNumber {
  const PlateNumber._();

  /// Membersihkan spasi ganda dan mengubah huruf menjadi kapital.
  static String normalize(String? value) {
    final text = (value ?? '').trim().toUpperCase();
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Memeriksa format dasar nomor polisi Indonesia.
  ///
  /// Format yang diterima: satu-dua huruf, 1-4 angka, satu-dua huruf.
  /// Validasi ini hanya memandu pengguna, keunikan tetap dijamin database.
  static bool isValidFormat(String? value) {
    final text = normalize(value);
    if (text.isEmpty) return false;
    final pattern = RegExp(r'^[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,2}$');
    return pattern.hasMatch(text);
  }
}
