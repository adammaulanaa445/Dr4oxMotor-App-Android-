import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dr4ox_motor/core/app_dependencies.dart';
import 'package:dr4ox_motor/core/utils/app_exception.dart';
import 'package:dr4ox_motor/data/local/app_database.dart';
import 'package:dr4ox_motor/data/local/database_schema.dart';
import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';
import 'package:dr4ox_motor/data/repositories/transaction_repository.dart';

/// Pengujian lapisan database menggunakan SQLite in-memory (sqflite FFI).
///
/// Database in-memory behaving seperti database sungguhan: foreign key,
/// transaksi, dan rollback semuanya diuji.
void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late AppDependencies deps;

  setUp(() async {
    database = AppDatabase.forTesting(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    deps = AppDependencies(database: database);
    await database.database;
  });

  tearDown(() async {
    await database.close();
  });

  group('Inisialisasi database', () {
    test('semua tabel wajib tersedia', () async {
      final db = await database.database;
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = rows.map((r) => r['name'] as String).toList();

      expect(names, contains(DatabaseSchema.tableCustomers));
      expect(names, contains(DatabaseSchema.tableVehicles));
      expect(names, contains(DatabaseSchema.tableServices));
      expect(names, contains(DatabaseSchema.tableParts));
      expect(names, contains(DatabaseSchema.tableTransactions));
      expect(names, contains(DatabaseSchema.tableTransactionServices));
      expect(names, contains(DatabaseSchema.tableTransactionParts));
      expect(names, contains(DatabaseSchema.tablePayments));
      expect(names, contains(DatabaseSchema.tableStockMovements));
      expect(names, contains(DatabaseSchema.tableSettings));
    });

    test('foreign key SQLite aktif', () async {
      final db = await database.database;
      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect((result.first.values.first as int), 1);
    });

    test('data awal: katalog layanan & pengaturan bengkel', () async {
      final services = await deps.services.list();
      expect(services.length, greaterThanOrEqualTo(5));
      expect(services.any((s) => s.name == 'Ganti Oli'), isTrue);

      final settings = await deps.settings.load();
      expect(settings.workshopName, 'Dr4ox Motor');
      expect(settings.ttsEnabled, isTrue);
    });
  });

  group('Pelanggan & kendaraan', () {
    test('simpan, cari, dan perbarui pelanggan', () async {
      final customer = await deps.customers.create(
        name: 'Andi',
        phone: '08123456789',
        address: 'Bandung',
      );
      expect(customer.id, isNotNull);

      final byName = await deps.customers.list(query: 'and');
      expect(byName.length, 1);
      expect(byName.first.name, 'Andi');

      final byPhone = await deps.customers.list(query: '0812');
      expect(byPhone.length, 1);

      await deps.customers.update(
        customer.copyWith(name: 'Andi Pratama'),
      );
      final updated = await deps.customers.findById(customer.id!);
      expect(updated!.name, 'Andi Pratama');
    });

    test('kendaraan tertaut ke pelanggan dan nomor polisi unik', () async {
      final customer = await deps.customers.create(name: 'Siti');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'b 1234 abc',
        brand: 'Honda',
        model: 'Beat',
      );
      expect(vehicle.plateNumber, 'B 1234 ABC');
      expect(await deps.vehicles.plateExists('B 1234 ABC'), isTrue);

      expect(
        () => deps.vehicles.create(
          customerId: customer.id!,
          plateNumber: 'B 1234 ABC',
        ),
        throwsA(isA<DatabaseException>()),
      );

      final list = await deps.vehicles.listByCustomer(customer.id!);
      expect(list.length, 1);
    });

    test('pelanggan dengan transaksi tidak dapat dihapus', () async {
      final customer = await deps.customers.create(name: 'Budi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 1111 AAA',
      );
      final services = await deps.services.list();
      await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );

      expect(await deps.customers.hasTransactions(customer.id!), isTrue);
      expect(await deps.customers.delete(customer.id!), isFalse);
    });
  });

  group('Transaksi & stok', () {
    test('transaksi menyimpan item dan mengurangi stok sparepart', () async {
      final customer = await deps.customers.create(name: 'Andi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 1234 ABC',
      );
      final part = await deps.parts.create(
        name: 'Oli 1L',
        sellPrice: 55000,
        stock: 10,
        minStock: 2,
        unit: 'botol',
      );
      final services = await deps.services.list();
      final gantiOli = services.firstWhere((s) => s.name == 'Ganti Oli');

      final transaction = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          complaint: 'Oli encok',
          services: [ServiceSelection(serviceId: gantiOli.id!, qty: 1)],
          parts: [PartSelection(partId: part.id!, qty: 2)],
        ),
      );

      // Perhitungan total dilakukan oleh logika repository.
      expect(transaction.serviceTotal, gantiOli.price);
      expect(transaction.partsTotal, 110000);
      expect(transaction.grandTotal, gantiOli.price + 110000);
      expect(transaction.transactionNumber.startsWith('TRX-'), isTrue);
      expect(transaction.workStatus, WorkStatus.menunggu);
      expect(transaction.paymentStatus, PaymentStatus.belumDibayar);

      // Stok berkurang sesuai jumlah pemakaian.
      final updatedPart = await deps.parts.findById(part.id!);
      expect(updatedPart!.stock, 8);

      // Riwayat pergerakan stok tercatat (stok awal + pemakaian).
      final movements = await deps.parts.history(part.id!);
      expect(movements.length, 2);
      expect(movements.first.type, StockMovementType.keluar);
      expect(movements.first.qtyChange, -2);
      expect(movements.first.stockAfter, 8);

      // Item transaksi memakai harga historis.
      final partItems = await deps.transactions.partItems(transaction.id!);
      expect(partItems.length, 1);
      expect(partItems.first.price, 55000);
      expect(partItems.first.qty, 2);
    });

    test('harga katalog berubah tidak mengubah transaksi lama', () async {
      final customer = await deps.customers.create(name: 'Siti');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'D 2222 EYZ',
      );
      final part = await deps.parts.create(
        name: 'Kampas',
        sellPrice: 40000,
        stock: 5,
        minStock: 1,
      );
      final services = await deps.services.list();

      final transaction = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
          parts: [PartSelection(partId: part.id!, qty: 1)],
        ),
      );

      // Ubah harga katalog setelah transaksi dibuat.
      await deps.parts.update((await deps.parts.findById(part.id!))!.copyWith(
        sellPrice: 99000,
      ));

      final items = await deps.transactions.partItems(transaction.id!);
      expect(items.first.price, 40000);
      expect(transaction.grandTotal, services.first.price + 40000);
    });

    test('stok tidak cukup: transaksi gagal & stok tidak berubah', () async {
      final customer = await deps.customers.create(name: 'Rudi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 3333 CDE',
      );
      final part = await deps.parts.create(
        name: 'Busi',
        sellPrice: 25000,
        stock: 1,
        minStock: 1,
      );
      final services = await deps.services.list();

      await expectLater(
        deps.transactions.createTransaction(
          TransactionDraft(
            customerId: customer.id!,
            vehicleId: vehicle.id!,
            services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
            parts: [PartSelection(partId: part.id!, qty: 5)],
          ),
        ),
        throwsA(isA<AppException>()),
      );

      // Tidak ada transaksi tersimpan & stok tetap.
      final all = await deps.transactions.list(const TransactionFilter());
      expect(all, isEmpty);
      final unchanged = await deps.parts.findById(part.id!);
      expect(unchanged!.stock, 1);
      final movements = await deps.parts.history(part.id!);
      // Hanya ada catatan stok awal, tidak ada stok keluar.
      expect(
        movements.where((m) => m.type == StockMovementType.keluar),
        isEmpty,
      );
    });

    test('transaksi tanpa item ditolak', () async {
      final customer = await deps.customers.create(name: 'Tono');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 4444 FGH',
      );
      await expectLater(
        deps.transactions.createTransaction(
          TransactionDraft(
            customerId: customer.id!,
            vehicleId: vehicle.id!,
          ),
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('nomor transaksi unik untuk tiap transaksi', () async {
      final customer = await deps.customers.create(name: 'Wawan');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 5555 IJK',
      );
      final services = await deps.services.list();

      final first = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );
      final second = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );

      expect(first.transactionNumber, isNot(second.transactionNumber));
    });
  });

  group('Pembayaran', () {
    test('pembayaran sebagian belum menandai lunas', () async {
      final customer = await deps.customers.create(name: 'Dedi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 6666 LMN',
      );
      final services = await deps.services.list();
      final transaction = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );

      final partial = await deps.payments.addPayment(
        transactionId: transaction.id!,
        amount: 10000,
        method: PaymentMethod.tunai,
      );
      expect(partial.paymentStatus, PaymentStatus.belumDibayar);
      expect(partial.paidAmount, 10000);
      expect(partial.remainingAmount, transaction.grandTotal - 10000);

      final full = await deps.payments.addPayment(
        transactionId: transaction.id!,
        amount: transaction.grandTotal - 10000,
        method: PaymentMethod.transfer,
      );
      expect(full.paymentStatus, PaymentStatus.lunas);
      expect(full.paidAmount, transaction.grandTotal);
      expect(full.remainingAmount, 0);

      // Pembayaran kedua pada transaksi yang sudah lunas ditolak.
      await expectLater(
        deps.payments.addPayment(
          transactionId: transaction.id!,
          amount: 1000,
          method: PaymentMethod.tunai,
        ),
        throwsA(isA<AppException>()),
      );

      final payments = await deps.payments.listByTransaction(transaction.id!);
      expect(payments.length, 2);
    });

    test('pembayaran melebihi sisa tagihan ditolak', () async {
      final customer = await deps.customers.create(name: 'Eko');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 7777 OPQ',
      );
      final services = await deps.services.list();
      final transaction = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );

      await expectLater(
        deps.payments.addPayment(
          transactionId: transaction.id!,
          amount: transaction.grandTotal + 1000,
          method: PaymentMethod.qris,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Pembatalan & laporan', () {
    test('pembatalan mengembalikan stok dan tidak dihitung sebagai pendapatan',
        () async {
      final customer = await deps.customers.create(name: 'Galih');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 8888 RST',
      );
      final part = await deps.parts.create(
        name: 'Filter',
        sellPrice: 18000,
        stock: 10,
        minStock: 3,
      );
      final services = await deps.services.list();

      final transaction = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
          parts: [PartSelection(partId: part.id!, qty: 3)],
        ),
      );
      expect((await deps.parts.findById(part.id!))!.stock, 7);

      await deps.transactions.cancelTransaction(transaction.id!, 'Salah input');
      expect((await deps.parts.findById(part.id!))!.stock, 10);

      final updated = await deps.transactions.findById(transaction.id!);
      expect(updated!.isCancelled, isTrue);
      expect(updated.cancelReason, 'Salah input');

      // Pembatalan kedua tidak mengembalikan stok dua kali.
      await expectLater(
        deps.transactions.cancelTransaction(transaction.id!, 'Ulang'),
        throwsA(isA<AppException>()),
      );
      expect((await deps.parts.findById(part.id!))!.stock, 10);

      // Transaksi batal tidak masuk pendapatan.
      final summary = await deps.transactions.reportSummary(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      expect(summary.revenue, 0);
      expect(summary.cancelledCount, 1);
    });

    test('pendapatan hanya menghitung transaksi lunas', () async {
      final customer = await deps.customers.create(name: 'Hana');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 9999 UVW',
      );
      final services = await deps.services.list();

      final belumLunas = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );
      final lunas = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );
      await deps.payments.addPayment(
        transactionId: lunas.id!,
        amount: lunas.grandTotal,
        method: PaymentMethod.tunai,
      );

      final summary = await deps.transactions.reportSummary(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      expect(summary.transactionCount, 2);
      expect(summary.revenue, lunas.grandTotal);
      expect(summary.unpaidAmount, belumLunas.grandTotal);

      final dashboard = await deps.transactions.dashboardSummary(
        periodStart: DateTime.now().subtract(const Duration(days: 1)),
        periodEnd: DateTime.now().add(const Duration(days: 1)),
      );
      expect(dashboard.todayRevenue, lunas.grandTotal);
      expect(dashboard.unpaidCount, 1);
    });

    test('status pengerjaan tidak mengubah status pembayaran', () async {
      final customer = await deps.customers.create(name: 'Ita');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 1111 XYZ',
      );
      final services = await deps.services.list();
      final transaction = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );

      final selesai = await deps.transactions
          .updateWorkStatus(transaction.id!, WorkStatus.selesai);
      expect(selesai.workStatus, WorkStatus.selesai);
      expect(selesai.paymentStatus, PaymentStatus.belumDibayar);
    });
  });

  group('Manajemen stok', () {
    test('tambah stok tercatat di riwayat pergerakan', () async {
      final part = await deps.parts.create(
        name: 'Kampas',
        sellPrice: 45000,
        stock: 2,
        minStock: 5,
      );
      expect(part.isLowStock, isTrue);

      final newStock = await deps.parts.addStock(part.id!, 5, note: 'Restok');
      expect(newStock, 7);

      final movements = await deps.parts.history(part.id!);
      expect(movements.length, 2);
      expect(movements.first.type, StockMovementType.masuk);
      expect(movements.first.qtyChange, 5);
      expect(movements.first.stockAfter, 7);
    });

    test('penyesuaian stok manual tercatat sebagai penyesuaian', () async {
      final part = await deps.parts.create(
        name: 'Busi',
        sellPrice: 25000,
        stock: 10,
        minStock: 3,
      );
      await deps.parts.adjustStock(part.id!, 8, note: 'Opname gudang');
      final movements = await deps.parts.history(part.id!);
      expect(movements.first.type, StockMovementType.penyesuaian);
      expect(movements.first.qtyChange, -2);
    });
  });
}
