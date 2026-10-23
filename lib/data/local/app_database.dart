
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database_schema.dart';

/// Pengelolaan koneksi database SQLite aplikasi.
class AppDatabase {
  AppDatabase._({DatabaseFactory? factory, String? pathOverride})
      : _factory = factory,
        _pathOverride = pathOverride;

  static final AppDatabase instance = AppDatabase._();

  static const String fileName = 'dr4ox_motor.db';

  final DatabaseFactory? _factory;
  final String? _pathOverride;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    // Jika factory diberikan, gunakan factory tersebut (misalnya saat tes).
    // Jika tidak, pilih factory sesuai platform.
    final DatabaseFactory factory;

    if (_factory != null) {
      factory = _factory!;
    } else if (kIsWeb) {
      factory = databaseFactoryFfiWeb;
    } else {
      factory = databaseFactory;
    }

    // Browser tidak menggunakan getDatabasesPath().
    // Nama database Web cukup berupa nama file.
    final String path;

    if (_pathOverride != null) {
      path = _pathOverride!;
    } else if (kIsWeb) {
      path = 'dr4ox_motor_web.db';
    } else {
      path = p.join(await getDatabasesPath(), fileName);
    }

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

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> close() async {
    final db = _database;

    if (db != null && db.isOpen) {
      await db.close();
    }

    _database = null;
  }

  Future<void> deleteDatabaseFile() async {
    await close();

    final DatabaseFactory factory;
    final String path;

    if (_factory != null) {
      factory = _factory!;
    } else if (kIsWeb) {
      factory = databaseFactoryFfiWeb;
    } else {
      factory = databaseFactory;
    }

    if (_pathOverride != null) {
      path = _pathOverride!;
    } else if (kIsWeb) {
      path = 'dr4ox_motor_web.db';
    } else {
      path = p.join(await getDatabasesPath(), fileName);
    }

    await factory.deleteDatabase(path);
  }

  @visibleForTesting
  static AppDatabase forTesting({
    required DatabaseFactory factory,
    String? path,
  }) {
    return AppDatabase._(factory: factory, pathOverride: path);
  }
}
