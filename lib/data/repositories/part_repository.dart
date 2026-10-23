import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_times.dart';
import '../local/database_schema.dart';
import '../models/enums.dart';
import '../models/part.dart';
import '../models/service_transaction.dart';
import 'base_repository.dart';

/// Repository sparepart dan pergerakan stok.
class PartRepository extends BaseRepository {
  PartRepository(super.appDatabase);

  /// Daftar sparepart dengan pencarian & filter.
  Future<List<Part>> list({
    String query = '',
    bool activeOnly = false,
    bool lowStockOnly = false,
  }) async {
    final db = await this.db;
    final where = <String>[];
    final args = <Object?>[];

    if (activeOnly) {
      where.add('is_active = 1');
    }
    if (lowStockOnly) {
      where.add('stock <= min_stock');
    }
    final text = query.trim();
    if (text.isNotEmpty) {
      where.add('(name LIKE ? OR code LIKE ? OR category LIKE ?)');
      final pattern = '%$text%';
      args.add(pattern);
      args.add(pattern);
      args.add(pattern);
    }

    final rows = await db.query(
      DatabaseSchema.tableParts,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Part.fromMap).toList();
  }

  Future<Part?> findById(int id) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableParts,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Part.fromMap(rows.first);
  }

  /// Sparepart yang stoknya sudah menyentuh batas minimum.
  Future<List<Part>> lowStock() async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableParts,
      where: 'is_active = 1 AND stock <= min_stock',
      orderBy: 'stock ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Part.fromMap).toList();
  }

  /// Menambah sparepart baru.
  Future<Part> create({
    required String name,
    String code = '',
    String category = '',
    int purchasePrice = 0,
    required int sellPrice,
    int stock = 0,
    int minStock = 0,
    String unit = 'pcs',
    bool isActive = true,
  }) async {
    final now = DateTime.now();
    final db = await this.db;
    final id = await db.insert(DatabaseSchema.tableParts, {
      'name': name.trim(),
      'code': code.trim(),
      'category': category.trim(),
      'purchase_price': purchasePrice,
      'sell_price': sellPrice,
      'stock': stock,
      'min_stock': minStock,
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
      'is_active': isActive ? 1 : 0,
      'created_at': DateTimes.toIso(now),
      'updated_at': DateTimes.toIso(now),
    });

    // Catat pergerakan stok awal bila ada stok.
    if (stock > 0) {
      await _insertMovement(
        db,
        partId: id,
        type: StockMovementType.masuk,
        qtyChange: stock,
        stockAfter: stock,
        note: 'Stok awal',
      );
    }

    return Part(
      id: id,
      name: name.trim(),
      code: code.trim(),
      category: category.trim(),
      purchasePrice: purchasePrice,
      sellPrice: sellPrice,
      stock: stock,
      minStock: minStock,
      unit: unit.trim().isEmpty ? 'pcs' : unit.trim(),
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Mengubah data sparepart.
  ///
  /// Stok tidak boleh diubah lewat method ini; gunakan [addStock] atau
  /// [adjustStock] supaya riwayat pergerakan stok selalu tercatat.
  Future<void> update(Part part) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableParts,
      {
        'name': part.name.trim(),
        'code': part.code.trim(),
        'category': part.category.trim(),
        'purchase_price': part.purchasePrice,
        'sell_price': part.sellPrice,
        'min_stock': part.minStock,
        'unit': part.unit.trim().isEmpty ? 'pcs' : part.unit.trim(),
        'is_active': part.isActive ? 1 : 0,
        'updated_at': DateTimes.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [part.id],
    );
  }

  /// Menambah stok (misal restok dari supplier) dan mencatat pergerakannya.
  Future<int> addStock(int partId, int qty, {String note = ''}) async {
    if (qty <= 0) {
      throw ArgumentError('Jumlah stok tambahan harus lebih dari 0');
    }
    final db = await this.db;
    return db.transaction<int>((txn) async {
      final part = await _lockPart(txn, partId);
      final newStock = part.stock + qty;
      await txn.update(
        DatabaseSchema.tableParts,
        {
          'stock': newStock,
          'updated_at': DateTimes.toIso(DateTime.now()),
        },
        where: 'id = ?',
        whereArgs: [partId],
      );
      await _insertMovement(
        txn,
        partId: partId,
        type: StockMovementType.masuk,
        qtyChange: qty,
        stockAfter: newStock,
        note: note.isEmpty ? 'Penambahan stok' : note,
      );
      return newStock;
    });
  }

  /// Menyesuaikan stok secara manual (selisih opname / barang rusak).
  ///
  /// [newStock] adalah stok akhir yang dihitung manual. Selisihnya dicatat
  /// sebagai pergerakan stok bertipe penyesuaian.
  Future<int> adjustStock(int partId, int newStock, {String note = ''}) async {
    if (newStock < 0) {
      throw ArgumentError('Stok tidak boleh negatif');
    }
    final db = await this.db;
    return db.transaction<int>((txn) async {
      final part = await _lockPart(txn, partId);
      final diff = newStock - part.stock;
      if (diff == 0) return part.stock;
      await txn.update(
        DatabaseSchema.tableParts,
        {
          'stock': newStock,
          'updated_at': DateTimes.toIso(DateTime.now()),
        },
        where: 'id = ?',
        whereArgs: [partId],
      );
      await _insertMovement(
        txn,
        partId: partId,
        type: StockMovementType.penyesuaian,
        qtyChange: diff,
        stockAfter: newStock,
        note: note.isEmpty ? 'Penyesuaian stok manual' : note,
      );
      return newStock;
    });
  }

  /// Riwayat pergerakan stok sebuah sparepart.
  Future<List<StockMovement>> history(int partId, {int limit = 100}) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableStockMovements,
      where: 'part_id = ?',
      whereArgs: [partId],
      // Diurutkan berdasarkan id (urutan simpan pasti) karena jam perangkat
      // sesekali bisa mundur sedikit sehingga timestamp tidak selalu naik.
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  /// Riwayat pergerakan stok seluruh sparepart.
  Future<List<StockMovement>> recentMovements({int limit = 100}) async {
    final db = await this.db;
    final rows = await db.rawQuery('''
      SELECT m.*, p.name AS part_name
      FROM ${DatabaseSchema.tableStockMovements} m
      JOIN ${DatabaseSchema.tableParts} p ON p.id = m.part_id
      ORDER BY m.id DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(StockMovement.fromMap).toList();
  }

  /// Menghapus sparepart. Hanya boleh bila belum pernah dipakai transaksi.
  Future<bool> delete(int partId) async {
    final db = await this.db;
    final used = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.tableTransactionParts} WHERE part_id = ?',
          [partId],
        )) ??
        0;
    if (used > 0) return false;

    final movementCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.tableStockMovements} WHERE part_id = ?',
          [partId],
        )) ??
        0;
    if (movementCount > 0) {
      // Ada riwayat stok: soft delete supaya riwayat tetap utuh.
      await db.update(
        DatabaseSchema.tableParts,
        {
          'is_active': 0,
          'updated_at': DateTimes.toIso(DateTime.now()),
        },
        where: 'id = ?',
        whereArgs: [partId],
      );
      return true;
    }

    await db.delete(
      DatabaseSchema.tableParts,
      where: 'id = ?',
      whereArgs: [partId],
    );
    return true;
  }

  /// Membaca satu sparepart di dalam transaksi database (dengan kunci baris).
  Future<Part> _lockPart(DatabaseExecutor txn, int partId) async {
    final rows = await txn.query(
      DatabaseSchema.tableParts,
      where: 'id = ?',
      whereArgs: [partId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Sparepart tidak ditemukan');
    }
    return Part.fromMap(rows.first);
  }

  /// Menyisipkan baris riwayat pergerakan stok.
  static Future<void> _insertMovement(
    DatabaseExecutor txn, {
    required int partId,
    required StockMovementType type,
    required int qtyChange,
    required int stockAfter,
    String note = '',
    int? transactionId,
  }) async {
    await txn.insert(DatabaseSchema.tableStockMovements, {
      'part_id': partId,
      'transaction_id': transactionId,
      'type': type.dbValue,
      'qty_change': qtyChange,
      'stock_after': stockAfter,
      'note': note,
      'created_at': DateTimes.toIso(DateTime.now()),
    });
  }
}
