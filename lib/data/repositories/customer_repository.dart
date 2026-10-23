import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_times.dart';
import '../local/database_schema.dart';
import '../models/customer.dart';
import 'base_repository.dart';

/// Hasil pencarian pelanggan.
class CustomerSearchResult {
  const CustomerSearchResult({required this.customer, required this.vehicleCount});

  final Customer customer;
  final int vehicleCount;
}

/// Repository data pelanggan.
class CustomerRepository extends BaseRepository {
  CustomerRepository(super.appDatabase);

  /// Menambah pelanggan baru.
  Future<Customer> create({
    required String name,
    String phone = '',
    String address = '',
  }) async {
    final now = DateTime.now();
    final db = await this.db;
    final id = await db.insert(DatabaseSchema.tableCustomers, {
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'created_at': DateTimes.toIso(now),
      'updated_at': DateTimes.toIso(now),
      'is_archived': 0,
    });
    return Customer(
      id: id,
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Mengubah data pelanggan.
  Future<void> update(Customer customer) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableCustomers,
      {
        'name': customer.name.trim(),
        'phone': customer.phone.trim(),
        'address': customer.address.trim(),
        'updated_at': DateTimes.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// Mengambil satu pelanggan berdasarkan id.
  Future<Customer?> findById(int id) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableCustomers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  /// Daftar pelanggan dengan pencarian sederhana (nama / telepon).
  ///
  /// [includeArchived] menentukan apakah pelanggan yang sudah diarsipkan
  /// ikut ditampilkan.
  Future<List<Customer>> list({
    String query = '',
    bool includeArchived = false,
  }) async {
    final db = await this.db;
    final keyword = query.trim();
    final where = <String>[];
    final args = <Object?>[];

    if (!includeArchived) {
      where.add('is_archived = 0');
    }
    if (keyword.isNotEmpty) {
      where.add('(name LIKE ? OR phone LIKE ?)');
      final pattern = '%$keyword%';
      args.add(pattern);
      args.add(pattern);
    }

    final rows = await db.query(
      DatabaseSchema.tableCustomers,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  /// Daftar pelanggan lengkap dengan jumlah kendaraan yang dimiliki.
  Future<List<CustomerSearchResult>> listWithVehicleCount({
    String query = '',
    bool includeArchived = false,
  }) async {
    final db = await this.db;
    final keyword = query.trim();
    final where = <String>[];
    final args = <Object?>[];

    if (!includeArchived) {
      where.add('c.is_archived = 0');
    }
    if (keyword.isNotEmpty) {
      where.add('(c.name LIKE ? OR c.phone LIKE ?)');
      final pattern = '%$keyword%';
      args.add(pattern);
      args.add(pattern);
    }

    final rows = await db.rawQuery('''
      SELECT c.*, (
        SELECT COUNT(*) FROM ${DatabaseSchema.tableVehicles} v
        WHERE v.customer_id = c.id AND v.is_archived = 0
      ) AS vehicle_count
      FROM ${DatabaseSchema.tableCustomers} c
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY c.name COLLATE NOCASE ASC
    ''', args);

    return rows
        .map((row) => CustomerSearchResult(
              customer: Customer.fromMap(row),
              vehicleCount: (row['vehicle_count'] as int?) ?? 0,
            ))
        .toList();
  }

  /// True bila pelanggan sudah memiliki transaksi (riwayat tidak boleh hilang).
  Future<bool> hasTransactions(int customerId) async {
    final db = await this.db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.tableTransactions} WHERE customer_id = ?',
          [customerId],
        )) ??
        0;
    return count > 0;
  }

  /// Jumlah kendaraan yang dimiliki pelanggan.
  Future<int> countVehicles(int customerId) async {
    final db = await this.db;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.tableVehicles} WHERE customer_id = ?',
          [customerId],
        )) ??
        0;
  }

  /// Mengarsipkan pelanggan (disembunyikan dari daftar, riwayat tetap ada).
  Future<void> archive(int customerId) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableCustomers,
      {
        'is_archived': 1,
        'updated_at': DateTimes.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Menghapus pelanggan. Hanya boleh bila tidak ada transaksi dan kendaraan.
  ///
  /// Mengembalikan `true` bila berhasil dihapus, `false` bila ditolak
  /// karena masih memiliki ketergantungan data.
  Future<bool> delete(int customerId) async {
    if (await hasTransactions(customerId)) return false;
    if (await countVehicles(customerId) > 0) return false;

    final db = await this.db;
    await db.delete(
      DatabaseSchema.tableCustomers,
      where: 'id = ?',
      whereArgs: [customerId],
    );
    return true;
  }
}
