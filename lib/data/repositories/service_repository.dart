import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_times.dart';
import '../local/database_schema.dart';
import '../models/service_item.dart';
import 'base_repository.dart';

/// Repository katalog layanan servis.
class ServiceRepository extends BaseRepository {
  ServiceRepository(super.appDatabase);

  /// Daftar layanan. [activeOnly] hanya mengambil layanan yang aktif.
  Future<List<ServiceItem>> list({bool activeOnly = false}) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableServices,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'is_active DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(ServiceItem.fromMap).toList();
  }

  /// Mencari layanan berdasarkan nama.
  Future<List<ServiceItem>> search(String keyword) async {
    final db = await this.db;
    final text = keyword.trim();
    if (text.isEmpty) return list();
    final rows = await db.query(
      DatabaseSchema.tableServices,
      where: 'name LIKE ?',
      whereArgs: ['%$text%'],
      orderBy: 'is_active DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(ServiceItem.fromMap).toList();
  }

  Future<ServiceItem?> findById(int id) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableServices,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ServiceItem.fromMap(rows.first);
  }

  /// Menambah layanan baru.
  Future<ServiceItem> create({
    required String name,
    String description = '',
    required int price,
    bool isActive = true,
  }) async {
    final now = DateTime.now();
    final db = await this.db;
    final id = await db.insert(DatabaseSchema.tableServices, {
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'is_active': isActive ? 1 : 0,
      'created_at': DateTimes.toIso(now),
      'updated_at': DateTimes.toIso(now),
    });
    return ServiceItem(
      id: id,
      name: name.trim(),
      description: description.trim(),
      price: price,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Mengubah layanan.
  Future<void> update(ServiceItem service) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableServices,
      {
        'name': service.name.trim(),
        'description': service.description.trim(),
        'price': service.price,
        'is_active': service.isActive ? 1 : 0,
        'updated_at': DateTimes.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [service.id],
    );
  }

  /// Mengaktifkan / menonaktifkan layanan.
  Future<void> setActive(int id, bool isActive) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableServices,
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTimes.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Menghapus layanan yang belum pernah dipakai transaksi.
  Future<bool> delete(int id) async {
    final db = await this.db;
    final used = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.tableTransactionServices} WHERE service_id = ?',
          [id],
        )) ??
        0;
    if (used > 0) return false;
    await db.delete(
      DatabaseSchema.tableServices,
      where: 'id = ?',
      whereArgs: [id],
    );
    return true;
  }
}
