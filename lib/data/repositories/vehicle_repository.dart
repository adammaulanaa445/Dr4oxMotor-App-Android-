import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_times.dart';
import '../../core/utils/plate_number.dart';
import '../local/database_schema.dart';
import '../models/vehicle.dart';
import 'base_repository.dart';

/// Repository data kendaraan.
class VehicleRepository extends BaseRepository {
  VehicleRepository(super.appDatabase);

  /// Menambah kendaraan baru untuk seorang pelanggan.
  Future<Vehicle> create({
    required int customerId,
    required String plateNumber,
    String brand = '',
    String model = '',
    String notes = '',
  }) async {
    final now = DateTime.now();
    final plate = PlateNumber.normalize(plateNumber);
    final db = await this.db;
    final id = await db.insert(DatabaseSchema.tableVehicles, {
      'customer_id': customerId,
      'plate_number': plate,
      'brand': brand.trim(),
      'model': model.trim(),
      'notes': notes.trim(),
      'created_at': DateTimes.toIso(now),
      'updated_at': DateTimes.toIso(now),
      'is_archived': 0,
    });
    return Vehicle(
      id: id,
      customerId: customerId,
      plateNumber: plate,
      brand: brand.trim(),
      model: model.trim(),
      notes: notes.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Mengubah data kendaraan.
  Future<void> update(Vehicle vehicle) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableVehicles,
      {
        'customer_id': vehicle.customerId,
        'plate_number': PlateNumber.normalize(vehicle.plateNumber),
        'brand': vehicle.brand.trim(),
        'model': vehicle.model.trim(),
        'notes': vehicle.notes.trim(),
        'updated_at': DateTimes.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  /// Mengambil satu kendaraan.
  Future<Vehicle?> findById(int id) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableVehicles,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Vehicle.fromMap(rows.first);
  }

  /// Mencari kendaraan berdasarkan nomor polisi (persis / sebagian).
  Future<List<Vehicle>> searchByPlate(String keyword) async {
    final db = await this.db;
    final text = PlateNumber.normalize(keyword);
    if (text.isEmpty) return [];
    final rows = await db.query(
      DatabaseSchema.tableVehicles,
      where: 'plate_number LIKE ?',
      whereArgs: ['%$text%'],
      orderBy: 'plate_number ASC',
    );
    return rows.map(Vehicle.fromMap).toList();
  }

  /// Kendaraan milik seorang pelanggan.
  Future<List<Vehicle>> listByCustomer(int customerId) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableVehicles,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'is_archived ASC, plate_number ASC',
    );
    return rows.map(Vehicle.fromMap).toList();
  }

  /// Semua kendaraan (dipakai untuk pencarian global).
  Future<List<Vehicle>> list({String query = ''}) async {
    final db = await this.db;
    final text = PlateNumber.normalize(query);
    final rows = await db.query(
      DatabaseSchema.tableVehicles,
      where: text.isEmpty ? null : 'plate_number LIKE ?',
      whereArgs: text.isEmpty ? null : ['%$text%'],
      orderBy: 'is_archived ASC, plate_number ASC',
    );
    return rows.map(Vehicle.fromMap).toList();
  }

  /// True bila nomor polisi sudah dipakai kendaraan lain.
  ///
  /// [ignoreVehicleId] dipakai saat proses edit agar kendaraan itu sendiri
  /// tidak dianggap sebagai duplikat.
  Future<bool> plateExists(String plateNumber, {int? ignoreVehicleId}) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableVehicles,
      where: 'plate_number = ?',
      whereArgs: [PlateNumber.normalize(plateNumber)],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final id = rows.first['id'] as int?;
    return id != ignoreVehicleId;
  }

  /// True bila kendaraan sudah memiliki transaksi.
  Future<bool> hasTransactions(int vehicleId) async {
    final db = await this.db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.tableTransactions} WHERE vehicle_id = ?',
          [vehicleId],
        )) ??
        0;
    return count > 0;
  }

  /// Mengarsipkan kendaraan.
  Future<void> archive(int vehicleId) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableVehicles,
      {
        'is_archived': 1,
        'updated_at': DateTimes.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Menghapus kendaraan. Hanya boleh bila belum pernah dipakai transaksi.
  Future<bool> delete(int vehicleId) async {
    if (await hasTransactions(vehicleId)) return false;
    final db = await this.db;
    await db.delete(
      DatabaseSchema.tableVehicles,
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
    return true;
  }
}
