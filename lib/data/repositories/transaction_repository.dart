
import '../../core/utils/app_exception.dart';
import '../../core/utils/date_times.dart';
import '../local/database_schema.dart';
import '../models/enums.dart';
import '../models/reports.dart';
import '../models/service_item.dart';
import '../models/service_transaction.dart';
import '../models/transaction_draft.dart';
import 'base_repository.dart';

/// Filter untuk daftar transaksi.
class TransactionFilter {
  const TransactionFilter({
    this.keyword = '',
    this.workStatus,
    this.paymentStatus,
    this.from,
    this.to,
    this.customerId,
    this.vehicleId,
    this.includeCancelled = true,
    this.limit,
  });

  final String keyword;
  final WorkStatus? workStatus;
  final PaymentStatus? paymentStatus;
  final DateTime? from;
  final DateTime? to;
  final int? customerId;
  final int? vehicleId;
  final bool includeCancelled;

  /// Batas jumlah hasil (null = tanpa batas).
  final int? limit;
}

/// Repository transaksi servis.
///
/// Semua operasi yang menyentuh beberapa tabel (transaksi + item + stok)
/// dijalankan di dalam transaksi database agar data tetap konsisten.
class TransactionRepository extends BaseRepository {
  TransactionRepository(super.appDatabase);

  // ------------------------------------------------------------------
  // Membuat transaksi
  // ------------------------------------------------------------------

  /// Membuat transaksi baru beserta item layanan, item sparepart, dan
  /// pengurangan stok sparepart.
  ///
  /// Semua langkah dijalankan dalam satu transaksi database: bila ada satu
  /// langkah yang gagal (misal stok kurang), seluruh perubahan dibatalkan
  /// sehingga stok tidak pernah berkurang dua kali atau berkurang tanpa
  /// transaksi tersimpan.
  Future<ServiceTransaction> createTransaction(TransactionDraft draft) async {
    if (draft.services.isEmpty && draft.parts.isEmpty) {
      throw const AppException(
        'Transaksi harus memiliki minimal satu layanan atau sparepart',
      );
    }
    if (draft.discount < 0) {
      throw const AppException('Diskon tidak boleh negatif');
    }

    final db = await this.db;
    return db.transaction<ServiceTransaction>((txn) async {
      // 1. Pastikan pelanggan & kendaraan valid dan saling terhubung.
      final customerRows = await txn.query(
        DatabaseSchema.tableCustomers,
        where: 'id = ?',
        whereArgs: [draft.customerId],
        limit: 1,
      );
      if (customerRows.isEmpty) {
        throw const AppException('Pelanggan tidak ditemukan');
      }
      final vehicleRows = await txn.query(
        DatabaseSchema.tableVehicles,
        where: 'id = ?',
        whereArgs: [draft.vehicleId],
        limit: 1,
      );
      if (vehicleRows.isEmpty) {
        throw const AppException('Kendaraan tidak ditemukan');
      }
      if ((vehicleRows.first['customer_id'] as int) != draft.customerId) {
        throw const AppException(
          'Kendaraan yang dipilih bukan milik pelanggan tersebut',
        );
      }

      // 2. Hitung subtotal layanan dari harga katalog saat ini.
      var serviceTotal = 0;
      final serviceLines = <Map<String, Object?>>[];
      for (final selection in draft.services) {
        final rows = await txn.query(
          DatabaseSchema.tableServices,
          where: 'id = ?',
          whereArgs: [selection.serviceId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw const AppException('Layanan yang dipilih tidak ditemukan');
        }
        final service = ServiceItem.fromMap(rows.first);
        final price = service.price;
        final qty = selection.qty < 1 ? 1 : selection.qty;
        final subtotal = price * qty;
        serviceTotal += subtotal;
        serviceLines.add({
          'service_id': service.id,
          'name': service.name,
          'price': price,
          'qty': qty,
          'subtotal': subtotal,
        });
      }

      // 3. Hitung subtotal sparepart & cek ketersediaan stok.
      var partsTotal = 0;
      final partLines = <Map<String, Object?>>[];
      for (final selection in draft.parts) {
        final rows = await txn.query(
          DatabaseSchema.tableParts,
          where: 'id = ?',
          whereArgs: [selection.partId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw const AppException('Sparepart yang dipilih tidak ditemukan');
        }
        final part = PartSnapshot.fromMap(rows.first);
        final qty = selection.qty < 1 ? 1 : selection.qty;
        if (part.stock < qty) {
          throw AppException(
            'Stok ${part.name} tidak cukup. Tersedia ${part.stock}, dibutuhkan $qty',
          );
        }
        final subtotal = part.sellPrice * qty;
        partsTotal += subtotal;
        partLines.add({
          'part_id': part.id,
          'name': part.name,
          'code': part.code,
          'price': part.sellPrice,
          'qty': qty,
          'subtotal': subtotal,
        });
      }

      // 4. Hitung total & validasi diskon.
      final grossTotal = serviceTotal + partsTotal;
      if (draft.discount > grossTotal) {
        throw const AppException(
          'Diskon tidak boleh lebih besar dari total tagihan',
        );
      }
      final grandTotal = grossTotal - draft.discount;

      // 5. Simpan header transaksi.
      final now = DateTime.now();
      final transactionId = await txn.insert(DatabaseSchema.tableTransactions, {
        'transaction_number': '',
        'customer_id': draft.customerId,
        'vehicle_id': draft.vehicleId,
        'complaint': draft.complaint.trim(),
        'mechanic_notes': draft.mechanicNotes.trim(),
        'service_total': serviceTotal,
        'parts_total': partsTotal,
        'discount': draft.discount,
        'grand_total': grandTotal,
        'paid_amount': 0,
        'work_status': WorkStatus.menunggu.dbValue,
        'payment_status': PaymentStatus.belumDibayar.dbValue,
        'is_cancelled': 0,
        'created_at': DateTimes.toIso(now),
        'updated_at': DateTimes.toIso(now),
      });

      // 6. Nomor transaksi unik: TRX-YYYYMMDD-0001 (memakai id transaksi).
      final transactionNumber = _buildTransactionNumber(now, transactionId);
      await txn.update(
        DatabaseSchema.tableTransactions,
        {'transaction_number': transactionNumber},
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      // 7. Simpan item layanan & sparepart (harga historis).
      for (final line in serviceLines) {
        await txn.insert(DatabaseSchema.tableTransactionServices, {
          'transaction_id': transactionId,
          ...line,
        });
      }
      for (final line in partLines) {
        await txn.insert(DatabaseSchema.tableTransactionParts, {
          'transaction_id': transactionId,
          ...line,
        });
      }

      // 8. Kurangi stok sparepart & catat riwayat pergerakan stok.
      for (final line in partLines) {
        final partId = line['part_id'] as int;
        final qty = line['qty'] as int;
        final partRows = await txn.query(
          DatabaseSchema.tableParts,
          where: 'id = ?',
          whereArgs: [partId],
          limit: 1,
        );
        final currentStock = (partRows.first['stock'] as int?) ?? 0;
        final newStock = currentStock - qty;
        await txn.update(
          DatabaseSchema.tableParts,
          {
            'stock': newStock,
            'updated_at': DateTimes.toIso(now),
          },
          where: 'id = ?',
          whereArgs: [partId],
        );
        await txn.insert(DatabaseSchema.tableStockMovements, {
          'part_id': partId,
          'transaction_id': transactionId,
          'type': StockMovementType.keluar.dbValue,
          'qty_change': -qty,
          'stock_after': newStock,
          'note': 'Pemakaian pada transaksi $transactionNumber',
          'created_at': DateTimes.toIso(now),
        });
      }

      return ServiceTransaction(
        id: transactionId,
        transactionNumber: transactionNumber,
        customerId: draft.customerId,
        vehicleId: draft.vehicleId,
        complaint: draft.complaint.trim(),
        mechanicNotes: draft.mechanicNotes.trim(),
        serviceTotal: serviceTotal,
        partsTotal: partsTotal,
        discount: draft.discount,
        grandTotal: grandTotal,
        paidAmount: 0,
        workStatus: WorkStatus.menunggu,
        paymentStatus: PaymentStatus.belumDibayar,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  static String _buildTransactionNumber(DateTime date, int id) {
    String two(int value) => value.toString().padLeft(2, '0');
    final datePart = '${date.year}${two(date.month)}${two(date.day)}';
    return 'TRX-$datePart-${id.toString().padLeft(4, '0')}';
  }

  // ------------------------------------------------------------------
  // Status pengerjaan & pembatalan
  // ------------------------------------------------------------------

  /// Mengubah status pengerjaan.
  ///
  /// Mengembalikan transaksi terbaru. Status pembayaran tidak ikut berubah.
  Future<ServiceTransaction> updateWorkStatus(
    int transactionId,
    WorkStatus status,
  ) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableTransactions,
      {
        'work_status': status.dbValue,
        'updated_at': DateTimes.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    final updated = await findById(transactionId);
    if (updated == null) {
      throw const AppException('Transaksi tidak ditemukan');
    }
    return updated;
  }

  /// Mencatat bahwa pengumuman TTS sudah dilakukan (agar tidak diulang).
  Future<void> markTtsAnnounced(int transactionId) async {
    final db = await this.db;
    await db.update(
      DatabaseSchema.tableTransactions,
      {'tts_announced_at': DateTimes.toIso(DateTime.now())},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Membatalkan transaksi.
  ///
  /// Transaksi tidak dihapus, melainkan ditandai batal. Stok sparepart yang
  /// sempat terpakai dikembalikan dan pergerakannya tercatat sebagai koreksi
  /// sehingga stok tidak mengembalikan dua kali.
  Future<void> cancelTransaction(int transactionId, String reason) async {
    final db = await this.db;
    await db.transaction<void>((txn) async {
      final rows = await txn.query(
        DatabaseSchema.tableTransactions,
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const AppException('Transaksi tidak ditemukan');
      }
      if (((rows.first['is_cancelled'] as int?) ?? 0) == 1) {
        throw const AppException('Transaksi ini sudah dibatalkan');
      }

      final now = DateTime.now();
      final partRows = await txn.query(
        DatabaseSchema.tableTransactionParts,
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      for (final item in partRows) {
        final partId = item['part_id'] as int?;
        final qty = (item['qty'] as int?) ?? 0;
        if (partId == null || qty <= 0) continue;

        final partData = await txn.query(
          DatabaseSchema.tableParts,
          where: 'id = ?',
          whereArgs: [partId],
          limit: 1,
        );
        if (partData.isEmpty) continue;
        final currentStock = (partData.first['stock'] as int?) ?? 0;
        final newStock = currentStock + qty;

        await txn.update(
          DatabaseSchema.tableParts,
          {
            'stock': newStock,
            'updated_at': DateTimes.toIso(now),
          },
          where: 'id = ?',
          whereArgs: [partId],
        );
        await txn.insert(DatabaseSchema.tableStockMovements, {
          'part_id': partId,
          'transaction_id': transactionId,
          'type': StockMovementType.koreksi.dbValue,
          'qty_change': qty,
          'stock_after': newStock,
          'note': 'Pengembalian stok akibat pembatalan transaksi',
          'created_at': DateTimes.toIso(now),
        });
      }

      await txn.update(
        DatabaseSchema.tableTransactions,
        {
          'is_cancelled': 1,
          'cancelled_at': DateTimes.toIso(now),
          'cancel_reason': reason.trim(),
          'work_status': WorkStatus.menunggu.dbValue,
          'updated_at': DateTimes.toIso(now),
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  // ------------------------------------------------------------------
  // Pembacaan data
  // ------------------------------------------------------------------

  /// Daftar transaksi sesuai filter.
  Future<List<ServiceTransaction>> list(TransactionFilter filter) async {
    final db = await this.db;
    final where = <String>[];
    final args = <Object?>[];

    if (!filter.includeCancelled) {
      where.add('t.is_cancelled = 0');
    }
    if (filter.workStatus != null) {
      where.add('t.work_status = ?');
      args.add(filter.workStatus!.dbValue);
    }
    if (filter.paymentStatus != null) {
      where.add('t.payment_status = ?');
      args.add(filter.paymentStatus!.dbValue);
    }
    if (filter.customerId != null) {
      where.add('t.customer_id = ?');
      args.add(filter.customerId);
    }
    if (filter.vehicleId != null) {
      where.add('t.vehicle_id = ?');
      args.add(filter.vehicleId);
    }
    if (filter.from != null) {
      where.add('t.created_at >= ?');
      args.add(DateTimes.toIso(DateTimes.startOfDay(filter.from!)));
    }
    if (filter.to != null) {
      where.add('t.created_at <= ?');
      args.add(DateTimes.toIso(DateTimes.endOfDay(filter.to!)));
    }
    final keyword = filter.keyword.trim();
    if (keyword.isNotEmpty) {
      where.add(
        '(t.transaction_number LIKE ? OR c.name LIKE ? OR v.plate_number LIKE ?)',
      );
      final pattern = '%$keyword%';
      args.add(pattern);
      args.add(pattern);
      args.add(pattern);
    }

    final rows = await db.rawQuery('''
      SELECT t.*, c.name AS customer_name, c.phone AS customer_phone,
             v.plate_number AS plate_number, v.brand AS vehicle_brand,
             v.model AS vehicle_model
      FROM ${DatabaseSchema.tableTransactions} t
      JOIN ${DatabaseSchema.tableCustomers} c ON c.id = t.customer_id
      JOIN ${DatabaseSchema.tableVehicles} v ON v.id = t.vehicle_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY t.id DESC
      ${filter.limit == null ? '' : 'LIMIT ?'}
    ''', filter.limit == null ? args : [...args, filter.limit!]);

    return rows.map(ServiceTransaction.fromMap).toList();
  }

  /// Mengambil satu transaksi lengkap dengan data pelanggan & kendaraan.
  Future<ServiceTransaction?> findById(int id) async {
    final db = await this.db;
    final rows = await db.rawQuery('''
      SELECT t.*, c.name AS customer_name, c.phone AS customer_phone,
             v.plate_number AS plate_number, v.brand AS vehicle_brand,
             v.model AS vehicle_model
      FROM ${DatabaseSchema.tableTransactions} t
      JOIN ${DatabaseSchema.tableCustomers} c ON c.id = t.customer_id
      JOIN ${DatabaseSchema.tableVehicles} v ON v.id = t.vehicle_id
      WHERE t.id = ?
      LIMIT 1
    ''', [id]);
    if (rows.isEmpty) return null;
    return ServiceTransaction.fromMap(rows.first);
  }

  /// Item layanan sebuah transaksi.
  Future<List<TransactionServiceItem>> serviceItems(int transactionId) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableTransactionServices,
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id ASC',
    );
    return rows.map(TransactionServiceItem.fromMap).toList();
  }

  /// Item sparepart sebuah transaksi.
  Future<List<TransactionPartItem>> partItems(int transactionId) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableTransactionParts,
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id ASC',
    );
    return rows.map(TransactionPartItem.fromMap).toList();
  }

  // ------------------------------------------------------------------
  // Dashboard & laporan
  // ------------------------------------------------------------------

  /// Ringkasan untuk Dashboard.
  ///
  /// Pendapatan hanya menghitung transaksi yang benar-benar lunas
  /// (`payment_status = 'lunas'`) dan tidak dibatalkan.
  Future<DashboardSummary> dashboardSummary({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final db = await this.db;
    final now = DateTime.now();
    final todayStart = DateTimes.toIso(DateTimes.startOfDay(now));
    final todayEnd = DateTimes.toIso(DateTimes.endOfDay(now));
    final monthStart = DateTimes.toIso(DateTime(now.year, now.month));
    final periodStartIso = DateTimes.toIso(DateTimes.startOfDay(periodStart));
    final periodEndIso = DateTimes.toIso(DateTimes.endOfDay(periodEnd));

    final counts = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN is_cancelled = 0 AND created_at BETWEEN ? AND ? THEN 1 ELSE 0 END) AS today_count,
        SUM(CASE WHEN is_cancelled = 0 AND work_status = 'dikerjakan' THEN 1 ELSE 0 END) AS in_progress,
        SUM(CASE WHEN is_cancelled = 0 AND work_status = 'menunggu' THEN 1 ELSE 0 END) AS waiting,
        SUM(CASE WHEN is_cancelled = 0 AND payment_status = 'belum_dibayar' THEN 1 ELSE 0 END) AS unpaid,
        SUM(CASE WHEN is_cancelled = 0 AND payment_status = 'lunas' AND created_at BETWEEN ? AND ? THEN grand_total ELSE 0 END) AS today_revenue,
        SUM(CASE WHEN is_cancelled = 0 AND payment_status = 'lunas' AND created_at >= ? THEN grand_total ELSE 0 END) AS month_revenue,
        SUM(CASE WHEN is_cancelled = 0 AND payment_status = 'lunas' AND created_at BETWEEN ? AND ? THEN grand_total ELSE 0 END) AS period_revenue,
        SUM(CASE WHEN is_cancelled = 0 AND created_at BETWEEN ? AND ? THEN 1 ELSE 0 END) AS period_count
      FROM ${DatabaseSchema.tableTransactions}
    ''', [
      todayStart,
      todayEnd,
      todayStart,
      todayEnd,
      monthStart,
      periodStartIso,
      periodEndIso,
      periodStartIso,
      periodEndIso,
    ]);

    final row = counts.isEmpty ? <String, Object?>{} : counts.first;

    final lowStockRows = await db.query(
      DatabaseSchema.tableParts,
      where: 'is_active = 1 AND stock <= min_stock',
      orderBy: 'stock ASC',
      limit: 5,
    );

    return DashboardSummary(
      todayTransactionCount: (row['today_count'] as int?) ?? 0,
      inProgressCount: (row['in_progress'] as int?) ?? 0,
      waitingCount: (row['waiting'] as int?) ?? 0,
      unpaidCount: (row['unpaid'] as int?) ?? 0,
      todayRevenue: (row['today_revenue'] as int?) ?? 0,
      monthRevenue: (row['month_revenue'] as int?) ?? 0,
      periodRevenue: (row['period_revenue'] as int?) ?? 0,
      periodTransactionCount: (row['period_count'] as int?) ?? 0,
      lowStockParts: lowStockRows
          .map((r) => LowStockInfo(
                id: (r['id'] as int?) ?? 0,
                name: (r['name'] as String?) ?? '',
                stock: (r['stock'] as int?) ?? 0,
                minStock: (r['min_stock'] as int?) ?? 0,
                unit: (r['unit'] as String?) ?? 'pcs',
              ))
          .toList(),
    );
  }

  /// Ringkasan laporan pada rentang tanggal tertentu.
  Future<ReportSummary> reportSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await this.db;
    final start = DateTimes.toIso(DateTimes.startOfDay(from));
    final end = DateTimes.toIso(DateTimes.endOfDay(to));

    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_count,
        SUM(CASE WHEN is_cancelled = 0 AND payment_status = 'lunas' THEN grand_total ELSE 0 END) AS revenue,
        SUM(CASE WHEN is_cancelled = 0 THEN paid_amount ELSE 0 END) AS paid_revenue,
        SUM(CASE WHEN is_cancelled = 0 AND payment_status = 'belum_dibayar' THEN grand_total - paid_amount ELSE 0 END) AS unpaid_amount,
        SUM(CASE WHEN is_cancelled = 1 THEN 1 ELSE 0 END) AS cancelled_count,
        SUM(CASE WHEN is_cancelled = 0 THEN service_total ELSE 0 END) AS service_total,
        SUM(CASE WHEN is_cancelled = 0 THEN parts_total ELSE 0 END) AS parts_total
      FROM ${DatabaseSchema.tableTransactions}
      WHERE created_at BETWEEN ? AND ?
    ''', [start, end]);

    final row = rows.isEmpty ? <String, Object?>{} : rows.first;
    return ReportSummary(
      transactionCount: (row['total_count'] as int?) ?? 0,
      revenue: (row['revenue'] as int?) ?? 0,
      paidRevenue: (row['paid_revenue'] as int?) ?? 0,
      unpaidAmount: (row['unpaid_amount'] as int?) ?? 0,
      cancelledCount: (row['cancelled_count'] as int?) ?? 0,
      serviceCount: (row['service_total'] as int?) ?? 0,
      partsCount: (row['parts_total'] as int?) ?? 0,
    );
  }

  /// Transaksi yang belum lunas.
  Future<List<ServiceTransaction>> unpaidTransactions() async {
    return list(const TransactionFilter(paymentStatus: PaymentStatus.belumDibayar));
  }

  /// Rekap penggunaan sparepart pada rentang tanggal tertentu.
  ///
  /// Transaksi batal tidak dihitung karena stoknya sudah dikembalikan.
  Future<List<PartUsage>> partUsage({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await this.db;
    final start = DateTimes.toIso(DateTimes.startOfDay(from));
    final end = DateTimes.toIso(DateTimes.endOfDay(to));

    final rows = await db.rawQuery('''
      SELECT tp.part_id AS part_id,
             tp.name AS name,
             SUM(tp.qty) AS qty,
             SUM(tp.subtotal) AS total
      FROM ${DatabaseSchema.tableTransactionParts} tp
      JOIN ${DatabaseSchema.tableTransactions} t ON t.id = tp.transaction_id
      WHERE t.is_cancelled = 0 AND t.created_at BETWEEN ? AND ?
      GROUP BY tp.part_id, tp.name
      ORDER BY qty DESC, total DESC
    ''', [start, end]);

    return rows
        .map((row) => PartUsage(
              partId: (row['part_id'] as int?) ?? 0,
              name: (row['name'] as String?) ?? '',
              qty: (row['qty'] as int?) ?? 0,
              total: (row['total'] as int?) ?? 0,
            ))
        .toList();
  }

  /// Riwayat transaksi seorang pelanggan.
  Future<List<ServiceTransaction>> historyForCustomer(int customerId) async {
    return list(TransactionFilter(customerId: customerId));
  }

  /// Riwayat transaksi sebuah kendaraan.
  Future<List<ServiceTransaction>> historyForVehicle(int vehicleId) async {
    return list(TransactionFilter(vehicleId: vehicleId));
  }
}

/// Snapshot ringkas sparepart yang dipakai saat membuat transaksi.
class PartSnapshot {
  const PartSnapshot({
    required this.id,
    required this.name,
    required this.code,
    required this.sellPrice,
    required this.stock,
  });

  final int id;
  final String name;
  final String code;
  final int sellPrice;
  final int stock;

  factory PartSnapshot.fromMap(Map<String, Object?> map) {
    return PartSnapshot(
      id: (map['id'] as int?) ?? 0,
      name: (map['name'] as String?) ?? '',
      code: (map['code'] as String?) ?? '',
      sellPrice: (map['sell_price'] as int?) ?? 0,
      stock: (map['stock'] as int?) ?? 0,
    );
  }
}
