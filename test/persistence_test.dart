import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dr4ox_motor/core/app_dependencies.dart';
import 'package:dr4ox_motor/data/local/app_database.dart';
import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';
import 'package:dr4ox_motor/data/repositories/transaction_repository.dart';

/// Menguji bahwa data tetap tersimpan setelah aplikasi ditutup
/// (database ditutup) lalu dibuka kembali.
void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  AppDatabase? openDatabase;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('dr4ox_persistence');
    dbPath = p.join(tempDir.path, 'dr4ox_motor.db');
  });

  tearDown(() async {
    await openDatabase?.close();
    openDatabase = null;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  AppDatabase open() {
    final database = AppDatabase.forTesting(
      factory: databaseFactoryFfiNoIsolate,
      path: dbPath,
    );
    openDatabase = database;
    return database;
  }

  test('data tetap tersimpan setelah database ditutup & dibuka kembali',
      () async {
    // --- Sesi 1: aplikasi dibuka, data disimpan, lalu ditutup ---
    var database = open();
    var deps = AppDependencies(database: database);
    await database.database;

    final customer = await deps.customers.create(
      name: 'Andi Pratama',
      phone: '081234567890',
    );
    final vehicle = await deps.vehicles.create(
      customerId: customer.id!,
      plateNumber: 'B 1234 ABC',
      brand: 'Honda',
      model: 'Beat',
    );
    final part = await deps.parts.create(
      name: 'Oli 1 Liter',
      sellPrice: 55000,
      stock: 10,
      minStock: 3,
    );
    final services = await deps.services.list();
    final transaction = await deps.transactions.createTransaction(
      TransactionDraft(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
        services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        parts: [PartSelection(partId: part.id!, qty: 2)],
      ),
    );
    await deps.payments.addPayment(
      transactionId: transaction.id!,
      amount: 50000,
      method: PaymentMethod.qris,
    );
    await deps.settings.save(
      (await deps.settings.load()).copyWith(workshopName: 'Dr4ox Motor Utama'),
    );

    final grandTotal = transaction.grandTotal;
    final stockAfter = (await deps.parts.findById(part.id!))!.stock;

    // Aplikasi ditutup: koneksi database dilepas.
    await database.close();

    // Berkas database benar-benar ada di disk.
    expect(File(dbPath).existsSync(), isTrue);

    // --- Sesi 2: aplikasi dibuka kembali ---
    database = open();
    deps = AppDependencies(database: database);
    await database.database;

    // Pelanggan, kendaraan, sparepart, transaksi, dan pembayaran utuh.
    final customers = await deps.customers.list();
    expect(customers.length, 1);
    expect(customers.first.name, 'Andi Pratama');
    expect(customers.first.phone, '081234567890');

    final vehicles = await deps.vehicles.list();
    expect(vehicles.length, 1);
    expect(vehicles.first.plateNumber, 'B 1234 ABC');

    final parts = await deps.parts.list();
    expect(parts.first.stock, stockAfter);
    expect(parts.first.stock, 8, reason: 'stok tidak kembali ke awal');

    final transactions = await deps.transactions.list(const TransactionFilter());
    expect(transactions.length, 1);
    expect(transactions.first.transactionNumber, transaction.transactionNumber);
    expect(transactions.first.grandTotal, grandTotal);
    expect(transactions.first.paidAmount, 50000);
    expect(transactions.first.paymentStatus, PaymentStatus.belumDibayar);

    final payments = await deps.payments.listByTransaction(transaction.id!);
    expect(payments.length, 1);
    expect(payments.first.method, PaymentMethod.qris);
    expect(payments.first.amount, 50000);

    // Pengaturan bengkel ikut tersimpan.
    final settings = await deps.settings.load();
    expect(settings.workshopName, 'Dr4ox Motor Utama');

    // Riwayat pergerakan stok tetap ada.
    final movements = await deps.parts.history(part.id!);
    expect(movements.length, 2, reason: 'stok awal + pemakaian');

    // Data bisa dibuka berulang kali tanpa hilang.
    await database.close();
    database = open();
    deps = AppDependencies(database: database);
    await database.database;
    expect((await deps.customers.list()).length, 1);
    expect((await deps.transactions.list(const TransactionFilter())).length, 1);
  });

  test('nomor transaksi tidak bentrok setelah aplikasi dibuka kembali',
      () async {
    var database = open();
    var deps = AppDependencies(database: database);
    await database.database;

    final customer = await deps.customers.create(name: 'Andi');
    final vehicle = await deps.vehicles.create(
      customerId: customer.id!,
      plateNumber: 'B 1234 ABC',
    );
    final services = await deps.services.list();

    Future<String> buatTransaksi() async {
      final transaction = await deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      );
      return transaction.transactionNumber;
    }

    final first = await buatTransaksi();
    await database.close();

    // Dibuka kembali -> nomor berikutnya harus berbeda.
    database = open();
    deps = AppDependencies(database: database);
    await database.database;
    final second = await buatTransaksi();

    expect(second, isNot(first));
  });
}
