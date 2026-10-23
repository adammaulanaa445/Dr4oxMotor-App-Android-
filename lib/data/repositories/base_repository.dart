import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';

/// Kelas dasar untuk semua repository.
///
/// Menyediakan akses ke koneksi database dengan satu cara yang seragam.
abstract class BaseRepository {
  BaseRepository(this.appDatabase);

  final AppDatabase appDatabase;

  /// Koneksi database (dibuka otomatis bila belum terbuka).
  Future<Database> get db async => appDatabase.database;
}
