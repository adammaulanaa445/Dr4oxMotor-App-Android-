import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dr4ox_motor/core/app_dependencies.dart';
import 'package:dr4ox_motor/data/local/app_database.dart';
import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';
import 'package:dr4ox_motor/data/repositories/receipt_repository.dart';
import 'package:dr4ox_motor/data/services/printing/receipt_print_service.dart';
import 'package:dr4ox_motor/data/services/receipt_pdf_service.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late AppDependencies deps;
  late ReceiptRepository receipts;

  setUp(() async {
    // Format tanggal Indonesia perlu diinisialisasi.
    await initializeDateFormatting('id_ID', null);
    database = AppDatabase.forTesting(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    deps = AppDependencies(database: database);
    await database.database;
    receipts = ReceiptRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> buatTransaksiLunas() async {
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
      name: 'Oli Mesin 1 Liter',
      code: 'OLI-001',
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
    await deps.payments.addPayment(
      transactionId: transaction.id!,
      amount: transaction.grandTotal,
      method: PaymentMethod.tunai,
    );
    return transaction.id!;
  }

  group('Tahap 7 - Data struk', () {
    test('struk berisi data transaksi, pelanggan, dan workshop', () async {
      await deps.settings.save(
        (await deps.settings.load()).copyWith(
          workshopName: 'Dr4ox Motor',
          workshopAddress: 'Jl. Merdeka No. 1',
          workshopPhone: '0812345000',
          receiptFooter: 'Terima kasih',
        ),
      );
      final transactionId = await buatTransaksiLunas();
      final receipt = await receipts.build(transactionId);

      expect(receipt, isNotNull);
      expect(receipt!.workshopName, 'Dr4ox Motor');
      expect(receipt.workshopAddress, 'Jl. Merdeka No. 1');
      expect(receipt.customerName, 'Andi Pratama');
      expect(receipt.plateNumber, 'B 1234 ABC');
      expect(receipt.vehicleDisplay, 'B 1234 ABC - Honda Beat');
      expect(receipt.serviceLines.length, 1);
      expect(receipt.partLines.length, 1);
      expect(receipt.totalItems, 3); // 1 layanan + 2 sparepart
      expect(receipt.paymentStatusLabel, 'Lunas');
      expect(receipt.paymentMethodLabel, 'Tunai');
      expect(receipt.remainingAmount, 0);
      expect(receipt.footer, 'Terima kasih');
    });

    test('struk memakai harga historis, bukan harga terbaru', () async {
      final transactionId = await buatTransaksiLunas();
      final before = await receipts.build(transactionId);

      // Ubah harga sparepart setelah transaksi dibuat.
      final parts = await deps.parts.list();
      final part = parts.firstWhere((p) => p.name == 'Oli Mesin 1 Liter');
      await deps.parts.update(part.copyWith(sellPrice: 99000));

      final after = await receipts.build(transactionId);
      expect(after!.partLines.first.unitPrice, before!.partLines.first.unitPrice);
      expect(after.grandTotal, before.grandTotal);
    });

    test('teks struk memuat ringkasan total & status', () async {
      final transactionId = await buatTransaksiLunas();
      final receipt = await receipts.build(transactionId);
      final text = receipts.toPlainText(receipt!);

      expect(text, contains('DR4OX MOTOR'));
      expect(text, contains('B 1234 ABC'));
      expect(text, contains('Andi Pratama'));
      expect(text, contains('Ganti Oli'));
      expect(text, contains('Oli Mesin 1 Liter'));
      expect(text, contains('TOTAL'));
      expect(text, contains('Lunas'));
    });
  });

  group('Tahap 7 - Berkas PDF', () {
    test('PDF berhasil dibuat dan berupa berkas PDF valid', () async {
      final transactionId = await buatTransaksiLunas();
      final receipt = await receipts.build(transactionId);
      final bytes = await const ReceiptPdfService().buildBytes(receipt!);

      expect(bytes.length, greaterThan(500));
      // Header berkas PDF selalu diawali %PDF-
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('nama berkas PDF aman untuk Android', () async {
      expect(
        ReceiptPdfService.safeFileName('TRX-20261021-0007'),
        'struk_TRX-20261021-0007.pdf',
      );
      expect(
        ReceiptPdfService.safeFileName('TRX/2026 10 21'),
        'struk_TRX_2026_10_21.pdf',
      );
    });
  });

  group('Tahap 8 - Paket ESC/POS (persiapan printer)', () {
    test('paket ESC/POS memuat data struk & kode kendali', () async {
      final transactionId = await buatTransaksiLunas();
      final receipt = await receipts.build(transactionId);
      final bytes = const EscPosPayloadBuilder().build(receipt!);
      final text = utf8.decode(bytes, allowMalformed: true);

      // Data struk ikut terbawa.
      expect(text, contains('DR4OX MOTOR'));
      expect(text, contains('B 1234 ABC'));
      expect(text, contains('Ganti Oli'));

      // Kode kendali ESC/POS: init (ESC @) & potong kertas (GS V).
      expect(bytes.contains(0x1B), isTrue);
      expect(bytes.contains(0x1D), isTrue);
      // Teks ASCII "DROX MOTOR" ada di dalam paket.
      expect(text.contains('DR4OX MOTOR'), isTrue);
    });

    test('layanan cetak yang belum tersedia memberi pesan jelas', () async {
      final transactionId = await buatTransaksiLunas();
      final receipt = await receipts.build(transactionId);
      final result = await const PrinterNotAvailableService().print(receipt!);

      expect(result.success, isFalse);
      expect(result.message, contains('belum aktif'));
    });
  });
}
