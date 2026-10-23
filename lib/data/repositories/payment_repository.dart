
import '../../core/utils/app_exception.dart';
import '../../core/utils/date_times.dart';
import '../local/database_schema.dart';
import '../models/enums.dart';
import '../models/service_transaction.dart';
import 'base_repository.dart';

/// Repository pencatatan pembayaran.
class PaymentRepository extends BaseRepository {
  PaymentRepository(super.appDatabase);

  /// Mencatat pembayaran (bisa sebagian) untuk sebuah transaksi.
  ///
  /// Mengembalikan transaksi terbaru. Status pembayaran menjadi `lunas`
  /// hanya bila total pembayaran sudah menutup tagihan. Pembayaran sebagian
  /// tetap berstatus "Belum Dibayar" agar laporan tetap akurat.
  Future<ServiceTransaction> addPayment({
    required int transactionId,
    required int amount,
    required PaymentMethod method,
    String note = '',
  }) async {
    if (amount <= 0) {
      throw const AppException('Nominal pembayaran harus lebih dari 0');
    }

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
      final transaction = ServiceTransaction.fromMap(rows.first);

      if (transaction.isCancelled) {
        throw const AppException(
          'Transaksi sudah dibatalkan, pembayaran tidak dapat dicatat',
        );
      }
      if (transaction.remainingAmount <= 0) {
        throw const AppException('Transaksi ini sudah lunas');
      }
      if (amount > transaction.remainingAmount) {
        throw AppException(
          'Nominal melebihi sisa tagihan (${transaction.remainingAmount})',
        );
      }

      final now = DateTime.now();
      await txn.insert(DatabaseSchema.tablePayments, {
        'transaction_id': transactionId,
        'amount': amount,
        'method': method.dbValue,
        'note': note.trim(),
        'paid_at': DateTimes.toIso(now),
        'created_at': DateTimes.toIso(now),
      });

      final newPaid = transaction.paidAmount + amount;
      final newStatus = newPaid >= transaction.grandTotal
          ? PaymentStatus.lunas
          : PaymentStatus.belumDibayar;

      await txn.update(
        DatabaseSchema.tableTransactions,
        {
          'paid_amount': newPaid,
          'payment_status': newStatus.dbValue,
          'updated_at': DateTimes.toIso(now),
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });

    final updated = await _findById(transactionId);
    if (updated == null) {
      throw const AppException('Transaksi tidak ditemukan');
    }
    return updated;
  }

  /// Riwayat pembayaran sebuah transaksi.
  Future<List<Payment>> listByTransaction(int transactionId) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tablePayments,
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  /// Semua pembayaran pada rentang tanggal tertentu.
  Future<List<Payment>> listByPeriod(DateTime from, DateTime to) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tablePayments,
      where: 'paid_at BETWEEN ? AND ?',
      whereArgs: [
        DateTimes.toIso(DateTimes.startOfDay(from)),
        DateTimes.toIso(DateTimes.endOfDay(to)),
      ],
      orderBy: 'id DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  Future<ServiceTransaction?> _findById(int id) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ServiceTransaction.fromMap(rows.first);
  }
}
