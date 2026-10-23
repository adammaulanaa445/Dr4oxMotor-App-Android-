/// Fungsi validasi input yang dipakai bersama oleh seluruh form.
class Validators {
  const Validators._();

  /// Mengubah teks menjadi nominal rupiah (bulat, tanpa pemisah).
  ///
  /// Mengembalikan `null` bila teks tidak bisa dibaca sebagai angka.
  static int? parseRupiah(String? text) {
    if (text == null) return null;
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  /// Validasi nama wajib isi.
  static String? requiredText(String? value, {String field = 'Kolom ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi';
    }
    return null;
  }

  /// Validasi nomor telepon opsional: bila diisi, hanya boleh angka/spasi/+.
  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final valid = RegExp(r'^\+?[0-9\s\-]{8,20}$');
    if (!valid.hasMatch(text)) {
      return 'Nomor telepon tidak valid';
    }
    return null;
  }

  /// Validasi nominal harga yang wajib diisi dan tidak boleh negatif.
  static String? price(String? value, {String field = 'Harga'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi';
    }
    final parsed = parseRupiah(value);
    if (parsed == null) {
      return '$field harus berupa angka';
    }
    if (parsed < 0) {
      return '$field tidak boleh negatif';
    }
    return null;
  }

  /// Validasi jumlah barang (> 0).
  static String? positiveInt(String? value, {String field = 'Jumlah'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return '$field harus berupa angka bulat';
    }
    if (parsed <= 0) {
      return '$field minimal 1';
    }
    return null;
  }

  /// Validasi jumlah (>= 0).
  static String? nonNegativeInt(String? value, {String field = 'Jumlah'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return '$field harus berupa angka bulat';
    }
    if (parsed < 0) {
      return '$field tidak boleh negatif';
    }
    return null;
  }
}
