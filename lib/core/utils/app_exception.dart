/// Kesalahan bisnis yang bisa ditampilkan langsung ke pengguna.
///
/// Dipakai agar pesan error dari logika data tetap ramah dibaca, bukan
/// error teknis SQLite.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
