import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

/// Pengelolaan koneksi database SQLite aplikasi.
///
/// Pola yang dipakai:
/// ```dart
/// final db = await AppDatabase.instance.database;
/// ```
///
/// Database dibuka sekali lalu dipakai bersama (singleton) supaya file SQLite
/// tidak dibuka berulang kali.
class AppDatabase {
  AppDatabase._({DatabaseFactory? factory, String? pathOverride})
      : _factory = factory,
        _pathOverride = pathOverride;

  /// Instance tunggal yang dipakai aplikasi.
  static final AppDatabase instance = AppDatabase._();

  /// Nama file database di dalam folder data aplikasi.
  static const String fileName = 'dr4ox_motor.db';

  final DatabaseFactory? _factory;
  final String? _pathOverride;
  Database? _database;

  /// Mengambil koneksi database, membuka bila belum terbuka.
  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _pathOverride ?? p.join(await getDatabasesPath(), fileName);

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: _onConfigure,
        onCreate: (db, version) => DatabaseSchema.onCreate(db),
        onUpgrade: (db, oldVersion, newVersion) =>
            DatabaseSchema.migrate(db, oldVersion, newVersion),
      ),
    );
  }

  /// Mengaktifkan-support foreign key SQLite.
  ///
  /// SQLite tidak mengaktifkan foreign key secara default, sehingga
  /// `PRAGMA foreign_keys = ON` harus dipanggil setiap kali koneksi dibuka.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Menutup koneksi database (dipakai saat aplikasi ditutup / diuji).
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }

  /// Menghapus file database. Hanya dipakai pada lingkungan uji.
  Future<void> deleteDatabaseFile() async {
    await close();
    final path = _pathOverride ?? p.join(await getDatabasesPath(), fileName);
    await deleteDatabase(path);
  }

  /// Membuat instance database baru, dipakai oleh pengujian.
  @visibleForTesting
  static AppDatabase forTesting({
    required DatabaseFactory factory,
    String? path,
  }) {
    return AppDatabase._(factory: factory, pathOverride: path);
  }
}
