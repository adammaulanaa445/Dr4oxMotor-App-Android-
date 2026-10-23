import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dr4ox_motor/core/app_dependencies.dart';
import 'package:dr4ox_motor/data/local/app_database.dart';
import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';
import 'package:dr4ox_motor/data/repositories/receipt_repository.dart';
import 'package:dr4ox_motor/data/repositories/transaction_repository.dart';
import 'package:dr4ox_motor/data/services/service_announcer.dart';
import 'package:dr4ox_motor/data/services/speech_service.dart';

/// TTS palsu untuk menguji pengumuman tanpa perangkat.
class FakeSpeech implements SpeechService {
  final List<String> spoken = [];
  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<bool> announceServiceCompleted(String plateNumber) =>
      speak('Servis kendaraan dengan nomor polisi $plateNumber telah selesai.');

  @override
  Future<void> stop() async {}
}

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late AppDependencies deps;

  setUp(() async {
    await initializeDateFormatting('id_ID', null);
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

  test('PERJALANAN: pelanggan -> kendaraan -> transaksi -> status -> bayar '
      '-> struk -> laporan', () async {
    // ---------- 1. Pelanggan & kendaraan ----------
    final customer = await deps.customers.create(
      name: 'Andi Pratama',
      phone: '081234567890',
      address: 'Jl. Merdeka No. 12',
    );
    final vehicle = await deps.vehicles.create(
      customerId: customer.id!,
      plateNumber: 'b 1234 abc',
      brand: 'Honda',
      model: 'Beat',
    );
    expect(vehicle.plateNumber, 'B 1234 ABC', reason: 'nomor polisi dinormalkan');

    // ---------- 2. Katalog layanan & sparepart ----------
    final gantiOli = await deps.services.create(
      name: 'Ganti Oli',
      description: 'Ganti oli + filter',
      price: 60000,
    );
    final parts = await deps.parts.create(
      name: 'Oli Mesin 1 Liter',
      code: 'OLI-001',
      sellPrice: 55000,
      purchasePrice: 45000,
      stock: 10,
      minStock: 3,
      unit: 'botol',
    );
    final kampas = await deps.parts.create(
      name: 'Kampas Rem',
      sellPrice: 45000,
      stock: 2,
      minStock: 2,
      unit: 'set',
    );

    // ---------- 3. Transaksi ----------
    final transaction = await deps.transactions.createTransaction(
      TransactionDraft(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
        complaint: 'Oli encok, rem blong',
        mechanicNotes: 'Ganti oli & kampas',
        services: [ServiceSelection(serviceId: gantiOli.id!, qty: 1)],
        parts: [
          PartSelection(partId: parts.id!, qty: 2),
          PartSelection(partId: kampas.id!, qty: 1),
        ],
      ),
    );

    // Perhitungan total (dihitung repository, bukan UI).
    expect(transaction.serviceTotal, 60000);
    expect(transaction.partsTotal, 2 * 55000 + 45000);
    expect(transaction.grandTotal, 60000 + 155000);
    expect(transaction.paymentStatus, PaymentStatus.belumDibayar);
    expect(transaction.workStatus, WorkStatus.menunggu);

    // Stok berkurang sesuai pemakaian.
    expect((await deps.parts.findById(parts.id!))!.stock, 8);
    expect((await deps.parts.findById(kampas.id!))!.stock, 1);

    // ---------- 4. Status pengerjaan + pengumuman TTS ----------
    final speech = FakeSpeech();
    final announcer = ServiceAnnouncer(
      transactions: deps.transactions,
      settings: deps.settings,
      speech: speech,
    );

    var updated = await deps.transactions
        .updateWorkStatus(transaction.id!, WorkStatus.dikerjakan);
    await announcer.announceIfNeeded(
      previousStatus: WorkStatus.menunggu,
      updated: updated,
    );
    expect(speech.spoken, isEmpty, reason: 'belum selesai -> tidak diumumkan');

    updated = await deps.transactions
        .updateWorkStatus(transaction.id!, WorkStatus.selesai);
    await announcer.announceIfNeeded(
      previousStatus: WorkStatus.dikerjakan,
      updated: updated,
    );
    expect(speech.spoken.length, 1);
    expect(speech.spoken.first, contains('B 1234 ABC'));

    // Selesai TIDAK otomatis menjadi lunas.
    expect(updated.workStatus, WorkStatus.selesai);
    expect(updated.paymentStatus, PaymentStatus.belumDibayar);

    // ---------- 5. Pembayaran sebagian lalu pelunasan ----------
    final partial = await deps.payments.addPayment(
      transactionId: transaction.id!,
      amount: 100000,
      method: PaymentMethod.transfer,
    );
    expect(partial.paymentStatus, PaymentStatus.belumDibayar);
    expect(partial.remainingAmount, transaction.grandTotal - 100000);

    var report = await deps.transactions.reportSummary(
      from: DateTime.now().subtract(const Duration(days: 1)),
      to: DateTime.now().add(const Duration(days: 1)),
    );
    expect(report.revenue, 0, reason: 'sebagian bukan pendapatan');
    expect(report.unpaidAmount, transaction.grandTotal - 100000);

    final lunas = await deps.payments.addPayment(
      transactionId: transaction.id!,
      amount: transaction.grandTotal - 100000,
      method: PaymentMethod.tunai,
    );
    expect(lunas.paymentStatus, PaymentStatus.lunas);
    expect(lunas.remainingAmount, 0);

    report = await deps.transactions.reportSummary(
      from: DateTime.now().subtract(const Duration(days: 1)),
      to: DateTime.now().add(const Duration(days: 1)),
    );
    expect(report.revenue, transaction.grandTotal);
    expect(report.unpaidAmount, 0);

    // ---------- 6. Struk memakai data historis ----------
    // Harga katalog berubah setelah transaksi -> struk tidak berubah.
    await deps.services.update(gantiOli.copyWith(price: 999000));
    final receipt = await ReceiptRepository(database).build(transaction.id!);
    expect(receipt!.serviceLines.first.unitPrice, 60000);
    expect(receipt.partLines.length, 2);
    expect(receipt.grandTotal, transaction.grandTotal);
    expect(receipt.paymentStatusLabel, 'Lunas');
    expect(receipt.paymentMethodLabel, 'Tunai');
    expect(receipt.totalItems, 4); // 1 layanan + 2 oli + 1 kampas

    // ---------- 7. Dashboard mencerminkan semua ----------
    final dashboard = await deps.transactions.dashboardSummary(
      periodStart: DateTime.now().subtract(const Duration(days: 1)),
      periodEnd: DateTime.now().add(const Duration(days: 1)),
    );
    expect(dashboard.todayTransactionCount, 1);
    expect(dashboard.unpaidCount, 0);
    expect(dashboard.todayRevenue, transaction.grandTotal);
    expect(dashboard.inProgressCount, 0);
    expect(dashboard.waitingCount, 0);

    // Stok menipis terdeteksi (kampas tersisa 1, minimum 2).
    final lowStock = await deps.parts.lowStock();
    expect(lowStock.any((p) => p.id == kampas.id), isTrue);
  });

  test('PERJALANAN: pembatalan transaksi mengembalikan stok & tidak '
      'dihitung pendapatan', () async {
    final customer = await deps.customers.create(name: 'Siti');
    final vehicle = await deps.vehicles.create(
      customerId: customer.id!,
      plateNumber: 'D 5678 EYZ',
    );
    final part = await deps.parts.create(
      name: 'Busi',
      sellPrice: 25000,
      stock: 5,
      minStock: 2,
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
    expect((await deps.parts.findById(part.id!))!.stock, 2);

    await deps.transactions
        .cancelTransaction(transaction.id!, 'Pelanggan membatalkan');
    expect((await deps.parts.findById(part.id!))!.stock, 5);

    // Pembatalan kedua tidak mengembalikan stok lagi.
    await expectLater(
      deps.transactions.cancelTransaction(transaction.id!, 'lagi'),
      throwsA(isA<Exception>()),
    );
    expect((await deps.parts.findById(part.id!))!.stock, 5);

    final report = await deps.transactions.reportSummary(
      from: DateTime.now().subtract(const Duration(days: 1)),
      to: DateTime.now().add(const Duration(days: 1)),
    );
    expect(report.revenue, 0);
    expect(report.cancelledCount, 1);
  });

  test('PERJALANAN: pelanggan dengan riwayat transaksi tidak bisa dihapus',
      () async {
    final customer = await deps.customers.create(name: 'Budi');
    final vehicle = await deps.vehicles.create(
      customerId: customer.id!,
      plateNumber: 'B 9012 XYZ',
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

    // Arsipkan tetap menyimpan riwayat.
    await deps.customers.archive(customer.id!);
    final history = await deps.transactions.historyForCustomer(customer.id!);
    expect(history.length, 1);
  });

  test('PERJALANAN: transaksi tidak tersimpan bila input tidak valid',
      () async {
    final customer = await deps.customers.create(name: 'Eko');
    final vehicle = await deps.vehicles.create(
      customerId: customer.id!,
      plateNumber: 'B 1111 ZZZ',
    );
    final services = await deps.services.list();

    // Tanpa item.
    await expectLater(
      deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
        ),
      ),
      throwsA(isA<Exception>()),
    );

    // Kendaraan milik pelanggan lain.
    final other = await deps.customers.create(name: 'Lain');
    final otherVehicle = await deps.vehicles.create(
      customerId: other.id!,
      plateNumber: 'B 2222 YYY',
    );
    await expectLater(
      deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: otherVehicle.id!,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      ),
      throwsA(isA<Exception>()),
    );

    // Diskon melebihi total.
    await expectLater(
      deps.transactions.createTransaction(
        TransactionDraft(
          customerId: customer.id!,
          vehicleId: vehicle.id!,
          discount: 999999999,
          services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        ),
      ),
      throwsA(isA<Exception>()),
    );

    // Tidak ada transaksi yang tersimpan.
    final all = await deps.transactions.list(const TransactionFilter());
    expect(all, isEmpty);
  });
}
