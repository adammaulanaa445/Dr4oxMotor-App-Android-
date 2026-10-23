import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dr4ox_motor/core/app_dependencies.dart';
import 'package:dr4ox_motor/core/utils/app_exception.dart';
import 'package:dr4ox_motor/data/local/app_database.dart';
import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';
import 'package:dr4ox_motor/data/repositories/settings_repository.dart';
import 'package:dr4ox_motor/data/services/service_announcer.dart';
import 'package:dr4ox_motor/data/services/speech_service.dart';

/// TTS palsu yang mencatat semua pengumuman (untuk pengujian).
class FakeSpeechService implements SpeechService {
  final List<String> spoken = [];
  bool shouldFail = false;

  @override
  Future<bool> speak(String text) async {
    if (shouldFail) return false;
    spoken.add(text);
    return true;
  }

  @override
  Future<bool> announceServiceCompleted(String plateNumber) {
    return speak(
      'Servis kendaraan dengan nomor polisi $plateNumber telah selesai.',
    );
  }

  @override
  Future<void> stop() async {}
}

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late AppDependencies deps;
  late FakeSpeechService speech;

  setUp(() async {
    database = AppDatabase.forTesting(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    deps = AppDependencies(database: database);
    await database.database;
    speech = FakeSpeechService();
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> buatTransaksi({
    required int customerId,
    required int vehicleId,
    int partQty = 1,
  }) async {
    final services = await deps.services.list();
    final part = await deps.parts.create(
      name: 'Kampas Rem',
      sellPrice: 45000,
      stock: 10,
      minStock: 2,
      unit: 'set',
    );
    final transaction = await deps.transactions.createTransaction(
      TransactionDraft(
        customerId: customerId,
        vehicleId: vehicleId,
        services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
        parts: [PartSelection(partId: part.id!, qty: partQty)],
      ),
    );
    return transaction.id!;
  }

  group('Tahap 5 - TTS pengumuman selesai', () {
    test('mengumumkan saat status berubah menjadi Selesai', () async {
      final customer = await deps.customers.create(name: 'Andi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 1234 ABC',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );

      final announcer = ServiceAnnouncer(
        transactions: deps.transactions,
        settings: deps.settings,
        speech: speech,
      );

      // Perubahan ke "Sedang Dikerjakan" tidak diumumkan.
      var updated = await deps.transactions
          .updateWorkStatus(transactionId, WorkStatus.dikerjakan);
      await announcer.announceIfNeeded(
        previousStatus: WorkStatus.menunggu,
        updated: updated,
      );
      expect(speech.spoken, isEmpty);

      // Perubahan ke "Selesai" diumumkan.
      updated = await deps.transactions
          .updateWorkStatus(transactionId, WorkStatus.selesai);
      final announced = await announcer.announceIfNeeded(
        previousStatus: WorkStatus.dikerjakan,
        updated: updated,
      );
      expect(announced, isTrue);
      expect(speech.spoken.length, 1);
      expect(speech.spoken.first, contains('B 1234 ABC'));
      expect(speech.spoken.first, contains('telah selesai'));
    });

    test('tidak mengulang pengumuman untuk transaksi yang sama', () async {
      final customer = await deps.customers.create(name: 'Siti');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'D 5678 EYZ',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );

      final announcer = ServiceAnnouncer(
        transactions: deps.transactions,
        settings: deps.settings,
        speech: speech,
      );

      var updated = await deps.transactions
          .updateWorkStatus(transactionId, WorkStatus.selesai);
      await announcer.announceIfNeeded(
        previousStatus: WorkStatus.dikerjakan,
        updated: updated,
      );
      expect(speech.spoken.length, 1);

      // Membuka halaman lagi (status tetap Selesai) tidak mengulang.
      final reloaded = await deps.transactions.findById(transactionId);
      await announcer.announceIfNeeded(
        previousStatus: WorkStatus.selesai,
        updated: reloaded!,
      );
      expect(speech.spoken.length, 1);

      // Status lain lalu kembali Selesai juga tidak mengulang.
      await deps.transactions
          .updateWorkStatus(transactionId, WorkStatus.dikerjakan);
      updated = await deps.transactions
          .updateWorkStatus(transactionId, WorkStatus.selesai);
      await announcer.announceIfNeeded(
        previousStatus: WorkStatus.dikerjakan,
        updated: updated,
      );
      expect(speech.spoken.length, 1);
    });

    test('tidak mengumumkan bila TTS dimatikan di pengaturan', () async {
      final customer = await deps.customers.create(name: 'Budi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 9012 XYZ',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );

      final current = await deps.settings.load();
      await deps.settings.save(
        current.copyWith(ttsEnabled: false),
      );

      final announcer = ServiceAnnouncer(
        transactions: deps.transactions,
        settings: deps.settings,
        speech: speech,
      );
      final updated = await deps.transactions
          .updateWorkStatus(transactionId, WorkStatus.selesai);
      final announced = await announcer.announceIfNeeded(
        previousStatus: WorkStatus.dikerjakan,
        updated: updated,
      );
      expect(announced, isFalse);
      expect(speech.spoken, isEmpty);
    });

    test('kegagalan TTS tidak menggagalkan penyimpanan transaksi', () async {
      final customer = await deps.customers.create(name: 'Tono');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 2222 CCC',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );

      speech.shouldFail = true;
      final announcer = ServiceAnnouncer(
        transactions: deps.transactions,
        settings: deps.settings,
        speech: speech,
      );
      final updated = await deps.transactions
          .updateWorkStatus(transactionId, WorkStatus.selesai);
      final announced = await announcer.announceIfNeeded(
        previousStatus: WorkStatus.dikerjakan,
        updated: updated,
      );
      expect(announced, isFalse);

      // Transaksi tetap tersimpan normal.
      final stored = await deps.transactions.findById(transactionId);
      expect(stored!.workStatus, WorkStatus.selesai);
    });
  });

  group('Tahap 5 - Stok sparepart', () {
    test('stok berkurang satu kali per transaksi', () async {
      final customer = await deps.customers.create(name: 'Andi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 1234 ABC',
      );
      await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
        partQty: 3,
      );

      final parts = await deps.parts.list();
      final part = parts.firstWhere((p) => p.name == 'Kampas Rem');
      expect(part.stock, 7);

      // Satu transaksi = satu pengurangan stok.
      final movements = await deps.parts.history(part.id!);
      final keluar =
          movements.where((m) => m.type == StockMovementType.keluar).toList();
      expect(keluar.length, 1);
      expect(keluar.first.qtyChange, -3);
    });

    test('pembatalan transaksi mengembalikan stok & tercatat sebagai koreksi',
        () async {
      final customer = await deps.customers.create(name: 'Siti');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'D 5678 EYZ',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
        partQty: 2,
      );

      final parts = await deps.parts.list();
      final part = parts.firstWhere((p) => p.name == 'Kampas Rem');
      expect(part.stock, 8);

      await deps.transactions.cancelTransaction(transactionId, 'Salah input');
      final afterCancel = await deps.parts.findById(part.id!);
      expect(afterCancel!.stock, 10);

      final movements = await deps.parts.history(part.id!);
      final koreksi =
          movements.where((m) => m.type == StockMovementType.koreksi).toList();
      expect(koreksi.length, 1);
      expect(koreksi.first.qtyChange, 2);
    });

    test('tambah stok tercatat dan stok menipis terdeteksi', () async {
      final part = await deps.parts.create(
        name: 'Oli 1L',
        sellPrice: 55000,
        stock: 3,
        minStock: 5,
      );
      expect(part.isLowStock, isTrue);

      final lowStock = await deps.parts.lowStock();
      expect(lowStock.any((p) => p.id == part.id), isTrue);

      await deps.parts.addStock(part.id!, 10, note: 'Restok supplier');
      final updated = await deps.parts.findById(part.id!);
      expect(updated!.stock, 13);
      expect(updated.isLowStock, isFalse);

      final movements = await deps.parts.history(part.id!);
      expect(movements.first.type, StockMovementType.masuk);
      expect(movements.first.qtyChange, 10);
    });
  });

  group('Tahap 6 - Pembayaran & laporan', () {
    test('pembayaran penuh menandai lunas & masuk pendapatan laporan',
        () async {
      final customer = await deps.customers.create(name: 'Andi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 1234 ABC',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );

      final transaction = await deps.transactions.findById(transactionId);
      final report = await deps.transactions.reportSummary(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      // Belum lunas: tidak masuk pendapatan.
      expect(report.revenue, 0);
      expect(report.unpaidAmount, transaction!.grandTotal);

      final paid = await deps.payments.addPayment(
        transactionId: transactionId,
        amount: transaction.grandTotal,
        method: PaymentMethod.tunai,
      );
      expect(paid.paymentStatus, PaymentStatus.lunas);

      final reportAfter = await deps.transactions.reportSummary(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      expect(reportAfter.revenue, transaction.grandTotal);
      expect(reportAfter.unpaidAmount, 0);

      // Dashboard ikut menampilkan pendapatan yang diterima.
      final dashboard = await deps.transactions.dashboardSummary(
        periodStart: DateTime.now().subtract(const Duration(days: 1)),
        periodEnd: DateTime.now().add(const Duration(days: 1)),
      );
      expect(dashboard.todayRevenue, transaction.grandTotal);
      expect(dashboard.unpaidCount, 0);
    });

    test('pembayaran sebagian tetap belum lunas', () async {
      final customer = await deps.customers.create(name: 'Siti');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'D 5678 EYZ',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );
      final transaction = await deps.transactions.findById(transactionId);

      final partial = await deps.payments.addPayment(
        transactionId: transactionId,
        amount: 10000,
        method: PaymentMethod.qris,
      );
      expect(partial.paymentStatus, PaymentStatus.belumDibayar);

      final report = await deps.transactions.reportSummary(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      expect(report.revenue, 0);
      expect(report.paidRevenue, 10000);
      expect(report.unpaidAmount, transaction!.grandTotal - 10000);

      // Riwayat pembayaran tetap tersimpan.
      final payments = await deps.payments.listByTransaction(transactionId);
      expect(payments.length, 1);
      expect(payments.first.method, PaymentMethod.qris);
    });

    test('transaksi batal tidak dihitung pendapatan', () async {
      final customer = await deps.customers.create(name: 'Budi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 9012 XYZ',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );
      final transaction = await deps.transactions.findById(transactionId);

      await deps.payments.addPayment(
        transactionId: transactionId,
        amount: transaction!.grandTotal,
        method: PaymentMethod.tunai,
      );
      await deps.transactions.cancelTransaction(transactionId, 'Batal');

      final report = await deps.transactions.reportSummary(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      expect(report.revenue, 0);
      expect(report.cancelledCount, 1);

      // Pembayaran pada transaksi batal ditolak.
      await expectLater(
        deps.payments.addPayment(
          transactionId: transactionId,
          amount: 1000,
          method: PaymentMethod.tunai,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('laporan penggunaan sparepart hanya menghitung transaksi aktif',
        () async {
      final customer = await deps.customers.create(name: 'Andi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 1234 ABC',
      );
      final transactionId = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
        partQty: 2,
      );

      var usage = await deps.transactions.partUsage(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      expect(usage.length, 1);
      expect(usage.first.qty, 2);
      expect(usage.first.total, 90000);

      await deps.transactions.cancelTransaction(transactionId, 'Batal');
      usage = await deps.transactions.partUsage(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      expect(usage, isEmpty);
    });

    test('daftar transaksi belum lunas hanya berisi yang belum lunas',
        () async {
      final customer = await deps.customers.create(name: 'Andi');
      final vehicle = await deps.vehicles.create(
        customerId: customer.id!,
        plateNumber: 'B 1234 ABC',
      );
      final lunas = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );
      final belumLunas = await buatTransaksi(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
      );

      final lunasTransaction = await deps.transactions.findById(lunas);
      await deps.payments.addPayment(
        transactionId: lunas,
        amount: lunasTransaction!.grandTotal,
        method: PaymentMethod.tunai,
      );

      final unpaid = await deps.transactions.unpaidTransactions();
      expect(unpaid.length, 1);
      expect(unpaid.first.id, belumLunas);
    });
  });

  group('Pengaturan bengkel', () {
    test('nilai pengaturan tersimpan & dimuat kembali', () async {
      final repository = SettingsRepository(database);
      final current = await repository.load();
      expect(current.workshopName, 'Dr4ox Motor');

      await repository.save(
        current.copyWith(
          workshopName: 'Dr4ox Motor Pusat',
          workshopAddress: 'Jl. Merdeka',
          ttsEnabled: false,
        ),
      );

      final updated = await repository.load();
      expect(updated.workshopName, 'Dr4ox Motor Pusat');
      expect(updated.workshopAddress, 'Jl. Merdeka');
      expect(updated.ttsEnabled, isFalse);
    });
  });
}
